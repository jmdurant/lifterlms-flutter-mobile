<?php
/**
 * Stripe Payment Handler for LifterLMS Mobile App
 */

defined( 'ABSPATH' ) || exit;

/**
 * Stripe Handler class
 */
class LLMS_Mobile_Stripe_Handler {
    
    /**
     * Instance
     */
    private static $instance = null;
    
    /**
     * Stripe API version
     */
    const STRIPE_API_VERSION = '2023-10-16';
    
    /**
     * Get instance
     */
    public static function instance() {
        if ( is_null( self::$instance ) ) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    /**
     * Constructor
     */
    public function __construct() {
        $this->init_hooks();
    }
    
    /**
     * Initialize hooks
     */
    private function init_hooks() {
        add_action( 'rest_api_init', array( $this, 'register_routes' ) );
    }
    
    /**
     * Register REST routes
     */
    public function register_routes() {
        // Create payment intent
        register_rest_route( 'llms/v1', '/mobile-app/stripe/create-payment-intent', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'create_payment_intent' ),
            'permission_callback' => array( $this, 'is_user_logged_in' ),
            'args'                => array(
                'course_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
                'access_plan_id' => array(
                    'required' => false,
                    'type'     => 'integer',
                ),
                'coupon_code' => array(
                    'required' => false,
                    'type'     => 'string',
                ),
            ),
        ) );
        
        // Confirm payment
        register_rest_route( 'llms/v1', '/mobile-app/stripe/confirm-payment', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'confirm_payment' ),
            'permission_callback' => array( $this, 'is_user_logged_in' ),
            'args'                => array(
                'payment_intent_id' => array(
                    'required' => true,
                    'type'     => 'string',
                ),
                'course_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
            ),
        ) );
        
        // Get payment methods
        register_rest_route( 'llms/v1', '/mobile-app/stripe/payment-methods', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_payment_methods' ),
            'permission_callback' => array( $this, 'is_user_logged_in' ),
        ) );
        
        // Setup intent for saving card
        register_rest_route( 'llms/v1', '/mobile-app/stripe/setup-intent', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'create_setup_intent' ),
            'permission_callback' => array( $this, 'is_user_logged_in' ),
        ) );
        
        // Delete payment method
        register_rest_route( 'llms/v1', '/mobile-app/stripe/payment-methods/(?P<id>[a-zA-Z0-9_]+)', array(
            'methods'             => 'DELETE',
            'callback'            => array( $this, 'delete_payment_method' ),
            'permission_callback' => array( $this, 'is_user_logged_in' ),
        ) );
        
        // Webhook endpoint
        register_rest_route( 'llms/v1', '/mobile-app/stripe/webhook', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'handle_webhook' ),
            'permission_callback' => '__return_true',
        ) );
    }
    
    /**
     * Create payment intent
     */
    public function create_payment_intent( $request ) {
        $course_id = $request->get_param( 'course_id' );
        $access_plan_id = $request->get_param( 'access_plan_id' );
        $coupon_code = $request->get_param( 'coupon_code' );
        $user_id = get_current_user_id();
        
        try {
            // Get Stripe keys
            $secret_key = $this->get_secret_key();
            if ( ! $secret_key ) {
                throw new Exception( 'Stripe not configured' );
            }
            
            // Get course and pricing
            $course = new LLMS_Course( $course_id );
            if ( ! $course->exists() ) {
                throw new Exception( 'Course not found' );
            }
            
            // Get price from access plan or course
            $amount = $this->get_course_price( $course, $access_plan_id );
            
            // Apply coupon if provided
            if ( $coupon_code ) {
                $amount = $this->apply_coupon( $amount, $coupon_code, $course_id );
            }
            
            // Convert to cents for Stripe
            $amount_cents = intval( $amount * 100 );
            
            // Get or create Stripe customer
            $customer_id = $this->get_or_create_stripe_customer( $user_id, $secret_key );
            
            // Create payment intent
            $intent_data = array(
                'amount' => $amount_cents,
                'currency' => strtolower( get_lifterlms_currency() ),
                'customer' => $customer_id,
                'metadata' => array(
                    'user_id' => $user_id,
                    'course_id' => $course_id,
                    'access_plan_id' => $access_plan_id ?: '',
                    'platform' => 'mobile_app',
                ),
                'description' => sprintf( 'Course: %s', $course->get( 'title' ) ),
                'automatic_payment_methods' => array(
                    'enabled' => true,
                ),
            );
            
            $response = $this->stripe_request( 'POST', '/payment_intents', $intent_data, $secret_key );
            
            if ( isset( $response['error'] ) ) {
                throw new Exception( $response['error']['message'] );
            }
            
            // Store payment intent in database for tracking
            $this->store_payment_intent( $response['id'], $user_id, $course_id, $amount );
            
            return array(
                'payment_intent_id' => $response['id'],
                'client_secret' => $response['client_secret'],
                'amount' => $amount,
                'currency' => get_lifterlms_currency(),
                'publishable_key' => $this->get_publishable_key(),
            );
            
        } catch ( Exception $e ) {
            return new WP_Error( 'stripe_error', $e->getMessage(), array( 'status' => 400 ) );
        }
    }
    
    /**
     * Confirm payment and enroll user
     */
    public function confirm_payment( $request ) {
        $payment_intent_id = $request->get_param( 'payment_intent_id' );
        $course_id = $request->get_param( 'course_id' );
        $user_id = get_current_user_id();
        
        try {
            $secret_key = $this->get_secret_key();
            if ( ! $secret_key ) {
                throw new Exception( 'Stripe not configured' );
            }
            
            // Retrieve payment intent from Stripe
            $response = $this->stripe_request( 'GET', '/payment_intents/' . $payment_intent_id, null, $secret_key );
            
            if ( isset( $response['error'] ) ) {
                throw new Exception( $response['error']['message'] );
            }
            
            // Verify payment succeeded
            if ( $response['status'] !== 'succeeded' ) {
                throw new Exception( 'Payment not completed' );
            }
            
            // Verify metadata matches
            if ( $response['metadata']['user_id'] != $user_id || 
                 $response['metadata']['course_id'] != $course_id ) {
                throw new Exception( 'Payment verification failed' );
            }
            
            // Check if already enrolled (prevent duplicate enrollments)
            if ( llms_is_user_enrolled( $user_id, $course_id ) ) {
                return array(
                    'status' => 'already_enrolled',
                    'message' => 'User already enrolled in course',
                );
            }
            
            // Enroll user in course
            $enrollment = llms_enroll_student( $user_id, $course_id, 'mobile_app_stripe' );
            
            if ( ! $enrollment ) {
                throw new Exception( 'Failed to enroll user' );
            }
            
            // Store transaction record
            $this->store_transaction( array(
                'user_id' => $user_id,
                'course_id' => $course_id,
                'payment_intent_id' => $payment_intent_id,
                'amount' => $response['amount'] / 100,
                'currency' => $response['currency'],
                'status' => 'completed',
            ) );
            
            // Trigger enrollment actions
            do_action( 'llms_mobile_stripe_payment_completed', $user_id, $course_id, $payment_intent_id );
            
            return array(
                'status' => 'success',
                'message' => 'Payment successful and enrolled in course',
                'enrolled' => true,
            );
            
        } catch ( Exception $e ) {
            return new WP_Error( 'payment_confirmation_failed', $e->getMessage(), array( 'status' => 400 ) );
        }
    }
    
    /**
     * Get user's saved payment methods
     */
    public function get_payment_methods( $request ) {
        $user_id = get_current_user_id();
        
        try {
            $secret_key = $this->get_secret_key();
            if ( ! $secret_key ) {
                throw new Exception( 'Stripe not configured' );
            }
            
            $customer_id = get_user_meta( $user_id, '_llms_stripe_customer_id', true );
            
            if ( ! $customer_id ) {
                return array( 'payment_methods' => array() );
            }
            
            // Get payment methods from Stripe
            $response = $this->stripe_request( 
                'GET', 
                '/payment_methods?customer=' . $customer_id . '&type=card', 
                null, 
                $secret_key 
            );
            
            if ( isset( $response['error'] ) ) {
                throw new Exception( $response['error']['message'] );
            }
            
            // Format payment methods for mobile app
            $payment_methods = array();
            if ( isset( $response['data'] ) ) {
                foreach ( $response['data'] as $method ) {
                    $payment_methods[] = array(
                        'id' => $method['id'],
                        'brand' => $method['card']['brand'],
                        'last4' => $method['card']['last4'],
                        'exp_month' => $method['card']['exp_month'],
                        'exp_year' => $method['card']['exp_year'],
                        'is_default' => false, // You can implement default card logic
                    );
                }
            }
            
            return array( 'payment_methods' => $payment_methods );
            
        } catch ( Exception $e ) {
            return new WP_Error( 'stripe_error', $e->getMessage(), array( 'status' => 400 ) );
        }
    }
    
    /**
     * Create setup intent for saving card
     */
    public function create_setup_intent( $request ) {
        $user_id = get_current_user_id();
        
        try {
            $secret_key = $this->get_secret_key();
            if ( ! $secret_key ) {
                throw new Exception( 'Stripe not configured' );
            }
            
            // Get or create Stripe customer
            $customer_id = $this->get_or_create_stripe_customer( $user_id, $secret_key );
            
            // Create setup intent
            $response = $this->stripe_request( 
                'POST', 
                '/setup_intents', 
                array(
                    'customer' => $customer_id,
                    'payment_method_types' => array( 'card' ),
                    'metadata' => array(
                        'user_id' => $user_id,
                        'platform' => 'mobile_app',
                    ),
                ),
                $secret_key 
            );
            
            if ( isset( $response['error'] ) ) {
                throw new Exception( $response['error']['message'] );
            }
            
            return array(
                'setup_intent_id' => $response['id'],
                'client_secret' => $response['client_secret'],
                'publishable_key' => $this->get_publishable_key(),
            );
            
        } catch ( Exception $e ) {
            return new WP_Error( 'stripe_error', $e->getMessage(), array( 'status' => 400 ) );
        }
    }
    
    /**
     * Delete payment method
     */
    public function delete_payment_method( $request ) {
        $payment_method_id = $request->get_param( 'id' );
        $user_id = get_current_user_id();
        
        try {
            $secret_key = $this->get_secret_key();
            if ( ! $secret_key ) {
                throw new Exception( 'Stripe not configured' );
            }
            
            // Verify the payment method belongs to the user's customer
            $customer_id = get_user_meta( $user_id, '_llms_stripe_customer_id', true );
            if ( ! $customer_id ) {
                throw new Exception( 'No Stripe customer found' );
            }
            
            // Detach payment method
            $response = $this->stripe_request( 
                'POST', 
                '/payment_methods/' . $payment_method_id . '/detach', 
                null, 
                $secret_key 
            );
            
            if ( isset( $response['error'] ) ) {
                throw new Exception( $response['error']['message'] );
            }
            
            return array(
                'status' => 'success',
                'message' => 'Payment method removed',
            );
            
        } catch ( Exception $e ) {
            return new WP_Error( 'stripe_error', $e->getMessage(), array( 'status' => 400 ) );
        }
    }
    
    /**
     * Handle Stripe webhook
     */
    public function handle_webhook( $request ) {
        $payload = $request->get_body();
        $sig_header = $_SERVER['HTTP_STRIPE_SIGNATURE'] ?? '';
        $endpoint_secret = get_option( 'llms_mobile_stripe_webhook_secret', '' );
        
        try {
            // Verify webhook signature
            if ( $endpoint_secret ) {
                $this->verify_webhook_signature( $payload, $sig_header, $endpoint_secret );
            }
            
            $event = json_decode( $payload, true );
            
            // Handle the event
            switch ( $event['type'] ) {
                case 'payment_intent.succeeded':
                    $this->handle_payment_succeeded( $event['data']['object'] );
                    break;
                    
                case 'payment_intent.payment_failed':
                    $this->handle_payment_failed( $event['data']['object'] );
                    break;
                    
                case 'customer.subscription.created':
                case 'customer.subscription.updated':
                case 'customer.subscription.deleted':
                    // Handle subscription events if needed
                    break;
            }
            
            return array( 'received' => true );
            
        } catch ( Exception $e ) {
            return new WP_Error( 'webhook_error', $e->getMessage(), array( 'status' => 400 ) );
        }
    }
    
    /**
     * Get or create Stripe customer
     */
    private function get_or_create_stripe_customer( $user_id, $secret_key ) {
        $customer_id = get_user_meta( $user_id, '_llms_stripe_customer_id', true );
        
        if ( ! $customer_id ) {
            $user = get_user_by( 'id', $user_id );
            
            // Create new customer
            $response = $this->stripe_request( 
                'POST', 
                '/customers', 
                array(
                    'email' => $user->user_email,
                    'name' => $user->display_name,
                    'metadata' => array(
                        'user_id' => $user_id,
                        'platform' => 'mobile_app',
                    ),
                ),
                $secret_key 
            );
            
            if ( isset( $response['id'] ) ) {
                $customer_id = $response['id'];
                update_user_meta( $user_id, '_llms_stripe_customer_id', $customer_id );
            } else {
                throw new Exception( 'Failed to create Stripe customer' );
            }
        }
        
        return $customer_id;
    }
    
    /**
     * Get course price
     */
    private function get_course_price( $course, $access_plan_id = null ) {
        if ( $access_plan_id ) {
            $plan = new LLMS_Access_Plan( $access_plan_id );
            if ( $plan->exists() ) {
                return $plan->get_price();
            }
        }
        
        // Get default price
        return $course->get_price();
    }
    
    /**
     * Apply coupon to amount
     */
    private function apply_coupon( $amount, $coupon_code, $course_id ) {
        // This would integrate with LifterLMS coupon system
        // For now, return the original amount
        return $amount;
    }
    
    /**
     * Store payment intent record
     */
    private function store_payment_intent( $intent_id, $user_id, $course_id, $amount ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_stripe_intents';
        
        $wpdb->insert(
            $table_name,
            array(
                'intent_id' => $intent_id,
                'user_id' => $user_id,
                'course_id' => $course_id,
                'amount' => $amount,
                'status' => 'pending',
                'created_at' => current_time( 'mysql' ),
            )
        );
    }
    
    /**
     * Store transaction record
     */
    private function store_transaction( $data ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_stripe_transactions';
        
        $wpdb->insert(
            $table_name,
            array(
                'user_id' => $data['user_id'],
                'course_id' => $data['course_id'],
                'payment_intent_id' => $data['payment_intent_id'],
                'amount' => $data['amount'],
                'currency' => $data['currency'],
                'status' => $data['status'],
                'created_at' => current_time( 'mysql' ),
            )
        );
    }
    
    /**
     * Make Stripe API request
     */
    private function stripe_request( $method, $endpoint, $data = null, $secret_key = null ) {
        if ( ! $secret_key ) {
            $secret_key = $this->get_secret_key();
        }
        
        $url = 'https://api.stripe.com/v1' . $endpoint;
        
        $args = array(
            'method' => $method,
            'headers' => array(
                'Authorization' => 'Bearer ' . $secret_key,
                'Stripe-Version' => self::STRIPE_API_VERSION,
            ),
            'timeout' => 30,
        );
        
        if ( $data && in_array( $method, array( 'POST', 'PUT', 'PATCH' ) ) ) {
            $args['body'] = http_build_query( $data );
            $args['headers']['Content-Type'] = 'application/x-www-form-urlencoded';
        }
        
        $response = wp_remote_request( $url, $args );
        
        if ( is_wp_error( $response ) ) {
            throw new Exception( $response->get_error_message() );
        }
        
        $body = wp_remote_retrieve_body( $response );
        return json_decode( $body, true );
    }
    
    /**
     * Verify webhook signature
     */
    private function verify_webhook_signature( $payload, $sig_header, $endpoint_secret ) {
        $signed_payload = $payload;
        $elements = explode( ',', $sig_header );
        $timestamp = null;
        $signatures = array();
        
        foreach ( $elements as $element ) {
            $parts = explode( '=', $element, 2 );
            if ( $parts[0] === 't' ) {
                $timestamp = $parts[1];
            } elseif ( $parts[0] === 'v1' ) {
                $signatures[] = $parts[1];
            }
        }
        
        if ( ! $timestamp ) {
            throw new Exception( 'Invalid webhook signature' );
        }
        
        $signed_payload = $timestamp . '.' . $payload;
        $expected_signature = hash_hmac( 'sha256', $signed_payload, $endpoint_secret );
        
        $valid = false;
        foreach ( $signatures as $signature ) {
            if ( hash_equals( $expected_signature, $signature ) ) {
                $valid = true;
                break;
            }
        }
        
        if ( ! $valid ) {
            throw new Exception( 'Invalid webhook signature' );
        }
    }
    
    /**
     * Handle payment succeeded webhook
     */
    private function handle_payment_succeeded( $payment_intent ) {
        // Update payment status in database
        global $wpdb;
        $table_name = $wpdb->prefix . 'llms_mobile_stripe_intents';
        
        $wpdb->update(
            $table_name,
            array( 'status' => 'succeeded' ),
            array( 'intent_id' => $payment_intent['id'] )
        );
        
        // Additional processing if needed
        do_action( 'llms_mobile_stripe_payment_succeeded_webhook', $payment_intent );
    }
    
    /**
     * Handle payment failed webhook
     */
    private function handle_payment_failed( $payment_intent ) {
        // Update payment status in database
        global $wpdb;
        $table_name = $wpdb->prefix . 'llms_mobile_stripe_intents';
        
        $wpdb->update(
            $table_name,
            array( 'status' => 'failed' ),
            array( 'intent_id' => $payment_intent['id'] )
        );
        
        // Additional processing if needed
        do_action( 'llms_mobile_stripe_payment_failed_webhook', $payment_intent );
    }
    
    /**
     * Get Stripe secret key
     */
    private function get_secret_key() {
        $test_mode = get_option( 'llms_mobile_stripe_test_mode', 'yes' ) === 'yes';
        
        if ( $test_mode ) {
            return get_option( 'llms_mobile_stripe_test_secret_key', '' );
        } else {
            return get_option( 'llms_mobile_stripe_live_secret_key', '' );
        }
    }
    
    /**
     * Get Stripe publishable key
     */
    private function get_publishable_key() {
        $test_mode = get_option( 'llms_mobile_stripe_test_mode', 'yes' ) === 'yes';
        
        if ( $test_mode ) {
            return get_option( 'llms_mobile_stripe_test_publishable_key', '' );
        } else {
            return get_option( 'llms_mobile_stripe_live_publishable_key', '' );
        }
    }
    
    /**
     * Permission callback
     */
    public function is_user_logged_in() {
        return is_user_logged_in();
    }
}

// Initialize Stripe handler
LLMS_Mobile_Stripe_Handler::instance();
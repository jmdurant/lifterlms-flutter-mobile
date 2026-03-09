<?php
/**
 * REST API Extensions for LifterLMS Mobile App
 */

defined( 'ABSPATH' ) || exit;

/**
 * REST API class
 */
class LLMS_Mobile_REST_API {
    
    /**
     * Constructor
     */
    public function __construct() {
        add_action( 'rest_api_init', array( $this, 'register_routes' ) );
        add_filter( 'llms_rest_course_filters_get_item', array( $this, 'add_mobile_data_to_course' ), 10, 2 );
    }
    
    /**
     * Register additional REST routes
     */
    public function register_routes() {
        // Mobile app configuration endpoint
        register_rest_route( 'llms/v1', '/mobile-app/config', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_app_config' ),
            'permission_callback' => '__return_true',
        ) );
        
        // Check enrollment with IAP
        register_rest_route( 'llms/v1', '/mobile-app/check-enrollment', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'check_enrollment' ),
            'permission_callback' => array( $this, 'is_user_logged_in' ),
            'args'                => array(
                'course_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
            ),
        ) );
        
        // Get user's mobile data
        register_rest_route( 'llms/v1', '/mobile-app/user-data', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_user_mobile_data' ),
            'permission_callback' => array( $this, 'is_user_logged_in' ),
        ) );

        // Get lesson script (narration text)
        register_rest_route( 'llms/v1', '/mobile-app/lesson/(?P<lesson_id>\d+)/script', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_lesson_script' ),
            'permission_callback' => array( $this, 'is_user_logged_in' ),
            'args'                => array(
                'lesson_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
            ),
        ) );

        // Save lesson script (admin/MCP use)
        register_rest_route( 'llms/v1', '/mobile-app/lesson/(?P<lesson_id>\d+)/script', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'save_lesson_script' ),
            'permission_callback' => array( $this, 'can_edit_lessons' ),
            'args'                => array(
                'lesson_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
                'script' => array(
                    'required' => true,
                    'type'     => 'string',
                ),
            ),
        ) );
    }
    
    /**
     * Get app configuration
     */
    public function get_app_config( $request ) {
        return array(
            'features' => array(
                'iap_enabled' => llms_mobile_is_iap_enabled(),
                'push_enabled' => llms_mobile_is_push_enabled(),
                'social_enabled' => llms_mobile_is_social_enabled(),
            ),
            'iap' => array(
                'course_ids' => llms_mobile_get_iap_course_ids(),
                'apple_sandbox' => get_option( 'llms_mobile_apple_sandbox', 'no' ) === 'yes',
            ),
            'social' => array(
                'providers' => $this->get_enabled_social_providers(),
            ),
            'api_version' => '1.0.0',
            'min_app_version' => '1.0.0',
        );
    }
    
    /**
     * Check enrollment status with IAP info
     */
    public function check_enrollment( $request ) {
        $course_id = absint( $request->get_param( 'course_id' ) );
        $user_id = get_current_user_id();

        if ( ! $course_id ) {
            return new WP_Error( 'invalid_course_id', 'Invalid course ID', array( 'status' => 400 ) );
        }
        
        $is_enrolled = llms_is_user_enrolled( $user_id, $course_id );
        $is_iap = llms_mobile_is_course_iap( $course_id );
        
        $response = array(
            'enrolled' => $is_enrolled,
            'is_iap_available' => $is_iap,
            'course_id' => $course_id,
        );
        
        if ( ! $is_enrolled && $is_iap ) {
            $course = new LLMS_Course( $course_id );
            $response['iap_product_id'] = strval( $course_id );
            $response['price'] = $course->get_price();
            $response['currency'] = get_lifterlms_currency();
        }
        
        return $response;
    }
    
    /**
     * Get user's mobile-specific data
     */
    public function get_user_mobile_data( $request ) {
        $user_id = get_current_user_id();
        $student = llms_get_student( $user_id );

        $stats = array(
            'courses_enrolled'  => 0,
            'courses_completed' => 0,
            'certificates'      => 0,
            'achievements'      => 0,
        );

        if ( $student ) {
            $stats['courses_enrolled']  = count( $student->get_enrolled_courses() );
            $stats['courses_completed'] = count( $student->get_completed_courses() );
            $stats['certificates']      = count( $student->get_certificates() );
            $stats['achievements']      = count( $student->get_achievements() );
        }

        return array(
            'user_id'       => $user_id,
            'devices'       => $this->get_user_devices_safe( $user_id ),
            'push_enabled'  => llms_mobile_user_has_app( $user_id ),
            'iap_purchases' => $this->get_user_iap_purchases( $user_id ),
            'stats'         => $stats,
        );
    }
    
    /**
     * Add mobile data to course response
     */
    public function add_mobile_data_to_course( $response, $course ) {
        if ( ! isset( $response->data ) ) {
            return $response;
        }
        
        $course_id = $response->data['id'];
        
        // Add mobile-specific data
        $response->data['mobile'] = array(
            'is_iap' => llms_mobile_is_course_iap( $course_id ),
            'iap_product_id' => llms_mobile_is_course_iap( $course_id ) ? strval( $course_id ) : null,
        );
        
        return $response;
    }
    
    /**
     * Get enabled social providers
     */
    private function get_enabled_social_providers() {
        $providers = array();
        
        if ( get_option( 'llms_mobile_fb_client_id' ) ) {
            $providers[] = 'facebook';
        }
        
        if ( get_option( 'llms_mobile_google_client_id' ) ) {
            $providers[] = 'google';
        }
        
        // Apple is always available on iOS
        $providers[] = 'apple';
        
        return $providers;
    }
    
    /**
     * Get user devices (safe version)
     */
    private function get_user_devices_safe( $user_id ) {
        $devices = llms_mobile_get_user_devices( $user_id );
        
        // Don't expose full device tokens
        $safe_devices = array();
        foreach ( $devices as $device ) {
            $safe_devices[] = array(
                'platform' => $device->platform,
                'active' => $device->active,
                'created_at' => $device->created_at,
            );
        }
        
        return $safe_devices;
    }
    
    /**
     * Get user's IAP purchases
     */
    private function get_user_iap_purchases( $user_id ) {
        $purchases = get_user_meta( $user_id, '_llms_mobile_iap_purchase', false );
        
        $safe_purchases = array();
        foreach ( $purchases as $purchase ) {
            $safe_purchases[] = array(
                'course_id' => $purchase['course_id'],
                'platform' => $purchase['platform'],
                'date' => $purchase['date'],
            );
        }
        
        return $safe_purchases;
    }
    
    /**
     * Get lesson narration script
     */
    public function get_lesson_script( $request ) {
        $lesson_id = absint( $request->get_param( 'lesson_id' ) );

        if ( ! $lesson_id || get_post_type( $lesson_id ) !== 'lesson' ) {
            return new WP_Error( 'invalid_lesson', 'Invalid lesson ID.', array( 'status' => 400 ) );
        }

        $script = get_post_meta( $lesson_id, '_llms_lesson_script', true );

        return array(
            'lesson_id' => $lesson_id,
            'script'    => $script ?: '',
            'has_script' => ! empty( $script ),
        );
    }

    /**
     * Save lesson narration script
     */
    public function save_lesson_script( $request ) {
        $lesson_id = absint( $request->get_param( 'lesson_id' ) );
        $script    = $request->get_param( 'script' );

        if ( ! $lesson_id || get_post_type( $lesson_id ) !== 'lesson' ) {
            return new WP_Error( 'invalid_lesson', 'Invalid lesson ID.', array( 'status' => 400 ) );
        }

        // Sanitize but allow basic formatting
        $script = wp_kses_post( $script );

        update_post_meta( $lesson_id, '_llms_lesson_script', $script );

        return array(
            'status'    => 'success',
            'lesson_id' => $lesson_id,
            'length'    => strlen( $script ),
        );
    }

    /**
     * Permission callback - logged in
     */
    public function is_user_logged_in() {
        return is_user_logged_in();
    }

    /**
     * Permission callback - can edit lessons (admin/instructor)
     */
    public function can_edit_lessons() {
        return current_user_can( 'edit_posts' );
    }
}

// Initialize REST API
new LLMS_Mobile_REST_API();
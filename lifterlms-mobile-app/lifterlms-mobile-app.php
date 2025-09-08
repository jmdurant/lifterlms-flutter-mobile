<?php
/**
 * Plugin Name: LifterLMS - Mobile App
 * Plugin URI: https://lifterlms.com
 * Description: Mobile App Support for LifterLMS - Enables In-App Purchases, Push Notifications, and Social Login
 * Author: LifterLMS Mobile
 * Version: 1.0.0
 * Author URI: https://lifterlms.com
 * Text Domain: lifterlms-mobile-app
 * Domain Path: /languages/
 * Requires at least: 5.8
 * Requires PHP: 7.4
 * License: GPL v3
 */

defined( 'ABSPATH' ) || exit;

// Define plugin constants
define( 'LLMS_MOBILE_APP_FILE', __FILE__ );
define( 'LLMS_MOBILE_APP_PATH', plugin_dir_path( __FILE__ ) );
define( 'LLMS_MOBILE_APP_URL', plugin_dir_url( __FILE__ ) );
define( 'LLMS_MOBILE_APP_VERSION', '1.0.0' );

/**
 * Main plugin class
 */
class LifterLMS_Mobile_App {
    
    /**
     * Instance
     */
    private static $instance = null;
    
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
    private function __construct() {
        $this->init_hooks();
    }
    
    /**
     * Initialize hooks
     */
    private function init_hooks() {
        // Check if LifterLMS is active
        add_action( 'plugins_loaded', array( $this, 'init' ) );
        
        // Add settings tab
        add_filter( 'lifterlms_settings_tabs_array', array( $this, 'add_settings_tab' ), 10, 1 );
        
        // Register REST API routes
        add_action( 'rest_api_init', array( $this, 'register_rest_routes' ) );
        
        // Activation hook
        register_activation_hook( __FILE__, array( $this, 'activate' ) );
    }
    
    /**
     * Initialize plugin
     */
    public function init() {
        if ( ! class_exists( 'LifterLMS' ) ) {
            add_action( 'admin_notices', array( $this, 'admin_notice_missing_lifterlms' ) );
            return;
        }
        
        // Load files
        $this->includes();
        
        // Load text domain
        load_plugin_textdomain( 'lifterlms-mobile-app', false, dirname( plugin_basename( __FILE__ ) ) . '/languages' );
    }
    
    /**
     * Include required files
     */
    private function includes() {
        // Database handler
        require_once LLMS_MOBILE_APP_PATH . 'inc/class-database.php';
        
        // Settings page
        require_once LLMS_MOBILE_APP_PATH . 'inc/class-settings-mobile-app.php';
        
        // Core functionality
        require_once LLMS_MOBILE_APP_PATH . 'inc/class-rest-api.php';
        require_once LLMS_MOBILE_APP_PATH . 'inc/class-iap-handler.php';
        require_once LLMS_MOBILE_APP_PATH . 'inc/class-push-notifications.php';
        require_once LLMS_MOBILE_APP_PATH . 'inc/class-social-login.php';
        require_once LLMS_MOBILE_APP_PATH . 'inc/class-stripe-handler.php';
        require_once LLMS_MOBILE_APP_PATH . 'inc/class-instructor-social.php';
        require_once LLMS_MOBILE_APP_PATH . 'inc/class-favorites.php';
        require_once LLMS_MOBILE_APP_PATH . 'inc/class-quiz-handler.php';
        require_once LLMS_MOBILE_APP_PATH . 'inc/class-certificate-handler.php';
        
        // Helper functions
        require_once LLMS_MOBILE_APP_PATH . 'inc/functions.php';
    }
    
    /**
     * Add settings tab
     */
    public function add_settings_tab( $tabs ) {
        $tabs['mobile_app'] = __( 'Mobile App', 'lifterlms-mobile-app' );
        return $tabs;
    }
    
    /**
     * Register REST API routes
     */
    public function register_rest_routes() {
        // Product IAP endpoint
        register_rest_route( 'llms/v1', '/mobile-app/product-iap', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_iap_products' ),
            'permission_callback' => '__return_true',
        ) );
        
        // Verify receipt endpoint
        register_rest_route( 'llms/v1', '/mobile-app/verify-receipt', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'verify_receipt' ),
            'permission_callback' => array( $this, 'verify_receipt_permissions' ),
            'args'                => array(
                'receipt-data' => array(
                    'required' => true,
                    'type'     => 'string',
                ),
                'is-ios' => array(
                    'required' => true,
                    'type'     => 'boolean',
                ),
                'course-id' => array(
                    'required' => true,
                    'type'     => 'string',
                ),
            ),
        ) );
        
        // Social login endpoints
        register_rest_route( 'llms/v1', '/mobile-app/social-login', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'social_login' ),
            'permission_callback' => '__return_true',
        ) );
        
        // Push notification registration
        register_rest_route( 'llms/v1', '/mobile-app/register-device', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'register_device' ),
            'permission_callback' => array( $this, 'is_user_logged_in' ),
        ) );
    }
    
    /**
     * Get IAP products
     */
    public function get_iap_products( $request ) {
        $course_ids = get_option( 'llms_mobile_iap_course_ids', '' );
        
        if ( empty( $course_ids ) ) {
            return array();
        }
        
        $course_ids = explode( ',', $course_ids );
        $course_ids = array_map( 'trim', $course_ids );
        $course_ids = array_map( 'strval', $course_ids );
        
        return $course_ids;
    }
    
    /**
     * Verify receipt and enroll user
     */
    public function verify_receipt( $request ) {
        $receipt_data = $request->get_param( 'receipt-data' );
        $is_ios = $request->get_param( 'is-ios' );
        $course_id = $request->get_param( 'course-id' );
        $platform = $request->get_param( 'platform' );
        
        // Get current user
        $user_id = get_current_user_id();
        
        if ( ! $user_id ) {
            return new WP_Error( 'not_logged_in', 'User not logged in', array( 'status' => 401 ) );
        }
        
        // Verify the receipt
        if ( class_exists( 'LLMS_Mobile_IAP_Handler' ) ) {
            $iap_handler = new LLMS_Mobile_IAP_Handler();
            
            if ( $is_ios ) {
                $verified = $iap_handler->verify_apple_receipt( $receipt_data, $course_id );
            } else {
                $verified = $iap_handler->verify_google_receipt( $receipt_data, $course_id );
            }
            
            if ( $verified ) {
                // Enroll user in LifterLMS course
                $enrollment = llms_enroll_student( $user_id, $course_id, 'mobile_app_iap' );
                
                if ( $enrollment ) {
                    // Log the purchase
                    $this->log_iap_purchase( $user_id, $course_id, $receipt_data, $is_ios );
                    
                    return array(
                        'status' => 'success',
                        'message' => 'Enrollment successful',
                        'enrolled' => true,
                    );
                } else {
                    return new WP_Error( 'enrollment_failed', 'Failed to enroll user', array( 'status' => 500 ) );
                }
            } else {
                return new WP_Error( 'invalid_receipt', 'Receipt verification failed', array( 'status' => 400 ) );
            }
        }
        
        return new WP_Error( 'handler_missing', 'IAP handler not available', array( 'status' => 500 ) );
    }
    
    /**
     * Social login handler
     */
    public function social_login( $request ) {
        $provider = $request->get_param( 'provider' );
        $token = $request->get_param( 'token' );
        
        // This would verify the social token and create/login user
        // Implementation depends on social provider
        
        return array(
            'status' => 'success',
            'message' => 'Social login endpoint ready',
        );
    }
    
    /**
     * Register device for push notifications
     */
    public function register_device( $request ) {
        $device_token = $request->get_param( 'device_token' );
        $platform = $request->get_param( 'platform' ); // ios or android
        $user_id = get_current_user_id();
        
        if ( class_exists( 'LLMS_Mobile_Push_Notifications' ) ) {
            $push = new LLMS_Mobile_Push_Notifications();
            $result = $push->register_device( $user_id, $device_token, $platform );
            
            return array(
                'status' => 'success',
                'registered' => $result,
            );
        }
        
        return array(
            'status' => 'success',
            'message' => 'Push notification endpoint ready',
        );
    }
    
    /**
     * Log IAP purchase
     */
    private function log_iap_purchase( $user_id, $course_id, $receipt, $is_ios ) {
        // Store purchase record
        $purchase_data = array(
            'user_id' => $user_id,
            'course_id' => $course_id,
            'platform' => $is_ios ? 'ios' : 'android',
            'receipt' => $receipt,
            'date' => current_time( 'mysql' ),
        );
        
        // Store in user meta or custom table
        add_user_meta( $user_id, '_llms_mobile_iap_purchase', $purchase_data );
    }
    
    /**
     * Permission callback for receipt verification
     */
    public function verify_receipt_permissions() {
        return is_user_logged_in();
    }
    
    /**
     * Permission callback for logged in users
     */
    public function is_user_logged_in() {
        return is_user_logged_in();
    }
    
    /**
     * Admin notice for missing LifterLMS
     */
    public function admin_notice_missing_lifterlms() {
        ?>
        <div class="notice notice-error">
            <p><?php _e( 'LifterLMS Mobile App requires LifterLMS to be installed and activated.', 'lifterlms-mobile-app' ); ?></p>
        </div>
        <?php
    }
    
    /**
     * Activation hook
     */
    public function activate() {
        // Load required files first
        $this->includes();
        
        // Create database tables using our database class
        if ( class_exists( 'LLMS_Mobile_Database' ) ) {
            $database = LLMS_Mobile_Database::instance();
            $database->install_tables();
        }
        
        // Set default options
        $this->set_default_options();
        
        // Flush rewrite rules for REST API endpoints
        flush_rewrite_rules();
    }
    
    /**
     * Set default options
     */
    private function set_default_options() {
        add_option( 'llms_mobile_app_version', LLMS_MOBILE_APP_VERSION );
        add_option( 'llms_mobile_iap_enabled', 'yes' );
        add_option( 'llms_mobile_push_enabled', 'no' );
        add_option( 'llms_mobile_social_enabled', 'no' );
    }
}

// Initialize the plugin
function llms_mobile_app() {
    return LifterLMS_Mobile_App::instance();
}

// Start the plugin
llms_mobile_app();
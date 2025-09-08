<?php
/**
 * Database Handler for LifterLMS Mobile App
 */

defined( 'ABSPATH' ) || exit;

/**
 * Database class
 */
class LLMS_Mobile_Database {
    
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
    public function __construct() {
        // Install tables on plugin activation
        register_activation_hook( LLMS_MOBILE_APP_FILE, array( $this, 'install_tables' ) );
    }
    
    /**
     * Install database tables
     */
    public function install_tables() {
        global $wpdb;
        
        $charset_collate = $wpdb->get_charset_collate();
        
        // Devices table for push notifications
        $this->create_devices_table( $charset_collate );
        
        // IAP logs table
        $this->create_iap_logs_table( $charset_collate );
        
        // Social login logs table
        $this->create_social_login_table( $charset_collate );
        
        // Stripe payment tables
        $this->create_stripe_tables( $charset_collate );
        
        // Favorites table
        $this->create_favorites_table( $charset_collate );
        
        // Update database version
        update_option( 'llms_mobile_db_version', '1.0.0' );
    }
    
    /**
     * Create devices table
     */
    private function create_devices_table( $charset_collate ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_devices';
        
        $sql = "CREATE TABLE IF NOT EXISTS $table_name (
            id bigint(20) NOT NULL AUTO_INCREMENT,
            user_id bigint(20) NOT NULL,
            device_token text NOT NULL,
            platform varchar(20) NOT NULL,
            device_model varchar(100),
            app_version varchar(20),
            os_version varchar(20),
            active tinyint(1) DEFAULT 1,
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            updated_at datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            last_active datetime DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY user_id (user_id),
            KEY device_token (device_token(255)),
            KEY platform (platform),
            KEY active (active)
        ) $charset_collate;";
        
        require_once( ABSPATH . 'wp-admin/includes/upgrade.php' );
        dbDelta( $sql );
    }
    
    /**
     * Create IAP logs table
     */
    private function create_iap_logs_table( $charset_collate ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_iap_logs';
        
        $sql = "CREATE TABLE IF NOT EXISTS $table_name (
            id bigint(20) NOT NULL AUTO_INCREMENT,
            user_id bigint(20) NOT NULL,
            course_id bigint(20) NOT NULL,
            platform varchar(20) NOT NULL,
            product_id varchar(100),
            transaction_id varchar(255),
            receipt_data longtext,
            status varchar(20),
            amount decimal(10,2),
            currency varchar(3),
            success tinyint(1) NOT NULL,
            error text,
            timestamp datetime DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY user_id (user_id),
            KEY course_id (course_id),
            KEY platform (platform),
            KEY transaction_id (transaction_id),
            KEY timestamp (timestamp)
        ) $charset_collate;";
        
        require_once( ABSPATH . 'wp-admin/includes/upgrade.php' );
        dbDelta( $sql );
    }
    
    /**
     * Create social login table
     */
    private function create_social_login_table( $charset_collate ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_social_logins';
        
        $sql = "CREATE TABLE IF NOT EXISTS $table_name (
            id bigint(20) NOT NULL AUTO_INCREMENT,
            user_id bigint(20),
            provider varchar(20) NOT NULL,
            provider_user_id varchar(255) NOT NULL,
            email varchar(100),
            name varchar(255),
            profile_picture text,
            access_token text,
            refresh_token text,
            token_expires datetime,
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            updated_at datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY user_id (user_id),
            KEY provider (provider),
            KEY provider_user_id (provider_user_id),
            KEY email (email),
            UNIQUE KEY provider_user (provider, provider_user_id)
        ) $charset_collate;";
        
        require_once( ABSPATH . 'wp-admin/includes/upgrade.php' );
        dbDelta( $sql );
    }
    
    /**
     * Device Management Methods
     */
    
    /**
     * Register or update device
     */
    public function register_device( $args ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_devices';
        
        // Check if device exists
        $existing = $wpdb->get_row( $wpdb->prepare(
            "SELECT * FROM $table_name WHERE device_token = %s",
            $args['device_token']
        ) );
        
        if ( $existing ) {
            // Update existing device
            return $wpdb->update(
                $table_name,
                array(
                    'user_id' => $args['user_id'],
                    'platform' => $args['platform'],
                    'device_model' => isset( $args['device_model'] ) ? $args['device_model'] : null,
                    'app_version' => isset( $args['app_version'] ) ? $args['app_version'] : null,
                    'os_version' => isset( $args['os_version'] ) ? $args['os_version'] : null,
                    'active' => 1,
                    'last_active' => current_time( 'mysql' ),
                ),
                array( 'device_token' => $args['device_token'] ),
                array( '%d', '%s', '%s', '%s', '%s', '%d', '%s' ),
                array( '%s' )
            );
        } else {
            // Insert new device
            return $wpdb->insert(
                $table_name,
                array(
                    'user_id' => $args['user_id'],
                    'device_token' => $args['device_token'],
                    'platform' => $args['platform'],
                    'device_model' => isset( $args['device_model'] ) ? $args['device_model'] : null,
                    'app_version' => isset( $args['app_version'] ) ? $args['app_version'] : null,
                    'os_version' => isset( $args['os_version'] ) ? $args['os_version'] : null,
                    'active' => 1,
                    'created_at' => current_time( 'mysql' ),
                    'last_active' => current_time( 'mysql' ),
                ),
                array( '%d', '%s', '%s', '%s', '%s', '%s', '%d', '%s', '%s' )
            );
        }
    }
    
    /**
     * Unregister device
     */
    public function unregister_device( $device_token ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_devices';
        
        return $wpdb->update(
            $table_name,
            array( 'active' => 0 ),
            array( 'device_token' => $device_token ),
            array( '%d' ),
            array( '%s' )
        );
    }
    
    /**
     * Get user devices
     */
    public function get_user_devices( $user_id, $active_only = true ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_devices';
        
        $where = $active_only ? "AND active = 1" : "";
        
        return $wpdb->get_results( $wpdb->prepare(
            "SELECT * FROM $table_name WHERE user_id = %d $where ORDER BY last_active DESC",
            $user_id
        ) );
    }
    
    /**
     * Update device activity
     */
    public function update_device_activity( $device_token ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_devices';
        
        return $wpdb->update(
            $table_name,
            array( 'last_active' => current_time( 'mysql' ) ),
            array( 'device_token' => $device_token ),
            array( '%s' ),
            array( '%s' )
        );
    }
    
    /**
     * IAP Management Methods
     */
    
    /**
     * Log IAP transaction
     */
    public function log_iap_transaction( $args ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_iap_logs';
        
        return $wpdb->insert(
            $table_name,
            array(
                'user_id' => $args['user_id'],
                'course_id' => $args['course_id'],
                'platform' => $args['platform'],
                'product_id' => isset( $args['product_id'] ) ? $args['product_id'] : null,
                'transaction_id' => isset( $args['transaction_id'] ) ? $args['transaction_id'] : null,
                'receipt_data' => isset( $args['receipt_data'] ) ? $args['receipt_data'] : null,
                'status' => isset( $args['status'] ) ? $args['status'] : 'pending',
                'amount' => isset( $args['amount'] ) ? $args['amount'] : null,
                'currency' => isset( $args['currency'] ) ? $args['currency'] : null,
                'success' => $args['success'],
                'error' => isset( $args['error'] ) ? $args['error'] : null,
                'timestamp' => current_time( 'mysql' ),
            ),
            array( '%d', '%d', '%s', '%s', '%s', '%s', '%s', '%f', '%s', '%d', '%s', '%s' )
        );
    }
    
    /**
     * Get user IAP history
     */
    public function get_user_iap_history( $user_id, $limit = 50 ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_iap_logs';
        
        return $wpdb->get_results( $wpdb->prepare(
            "SELECT * FROM $table_name WHERE user_id = %d ORDER BY timestamp DESC LIMIT %d",
            $user_id,
            $limit
        ) );
    }
    
    /**
     * Check if transaction exists
     */
    public function transaction_exists( $transaction_id ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_iap_logs';
        
        $result = $wpdb->get_var( $wpdb->prepare(
            "SELECT COUNT(*) FROM $table_name WHERE transaction_id = %s AND success = 1",
            $transaction_id
        ) );
        
        return $result > 0;
    }
    
    /**
     * Social Login Management Methods
     */
    
    /**
     * Save social login
     */
    public function save_social_login( $args ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_social_logins';
        
        // Check if social login exists
        $existing = $wpdb->get_row( $wpdb->prepare(
            "SELECT * FROM $table_name WHERE provider = %s AND provider_user_id = %s",
            $args['provider'],
            $args['provider_user_id']
        ) );
        
        if ( $existing ) {
            // Update existing
            return $wpdb->update(
                $table_name,
                array(
                    'user_id' => isset( $args['user_id'] ) ? $args['user_id'] : $existing->user_id,
                    'email' => isset( $args['email'] ) ? $args['email'] : $existing->email,
                    'name' => isset( $args['name'] ) ? $args['name'] : $existing->name,
                    'profile_picture' => isset( $args['profile_picture'] ) ? $args['profile_picture'] : $existing->profile_picture,
                    'access_token' => isset( $args['access_token'] ) ? $args['access_token'] : $existing->access_token,
                    'refresh_token' => isset( $args['refresh_token'] ) ? $args['refresh_token'] : $existing->refresh_token,
                    'token_expires' => isset( $args['token_expires'] ) ? $args['token_expires'] : $existing->token_expires,
                ),
                array(
                    'provider' => $args['provider'],
                    'provider_user_id' => $args['provider_user_id'],
                ),
                null,
                array( '%s', '%s' )
            );
        } else {
            // Insert new
            return $wpdb->insert(
                $table_name,
                array(
                    'user_id' => isset( $args['user_id'] ) ? $args['user_id'] : null,
                    'provider' => $args['provider'],
                    'provider_user_id' => $args['provider_user_id'],
                    'email' => isset( $args['email'] ) ? $args['email'] : null,
                    'name' => isset( $args['name'] ) ? $args['name'] : null,
                    'profile_picture' => isset( $args['profile_picture'] ) ? $args['profile_picture'] : null,
                    'access_token' => isset( $args['access_token'] ) ? $args['access_token'] : null,
                    'refresh_token' => isset( $args['refresh_token'] ) ? $args['refresh_token'] : null,
                    'token_expires' => isset( $args['token_expires'] ) ? $args['token_expires'] : null,
                )
            );
        }
    }
    
    /**
     * Get social login by provider
     */
    public function get_social_login( $provider, $provider_user_id ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_social_logins';
        
        return $wpdb->get_row( $wpdb->prepare(
            "SELECT * FROM $table_name WHERE provider = %s AND provider_user_id = %s",
            $provider,
            $provider_user_id
        ) );
    }
    
    /**
     * Get user's social logins
     */
    public function get_user_social_logins( $user_id ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_social_logins';
        
        return $wpdb->get_results( $wpdb->prepare(
            "SELECT * FROM $table_name WHERE user_id = %d",
            $user_id
        ) );
    }
    
    /**
     * Create Stripe tables
     */
    private function create_stripe_tables( $charset_collate ) {
        global $wpdb;
        
        // Stripe payment intents table
        $table_name = $wpdb->prefix . 'llms_mobile_stripe_intents';
        
        $sql = "CREATE TABLE IF NOT EXISTS $table_name (
            id bigint(20) NOT NULL AUTO_INCREMENT,
            intent_id varchar(255) NOT NULL,
            user_id bigint(20) NOT NULL,
            course_id bigint(20) NOT NULL,
            amount decimal(10,2) NOT NULL,
            currency varchar(3),
            status varchar(20) DEFAULT 'pending',
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            updated_at datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY user_id (user_id),
            KEY course_id (course_id),
            KEY intent_id (intent_id),
            KEY status (status)
        ) $charset_collate;";
        
        require_once( ABSPATH . 'wp-admin/includes/upgrade.php' );
        dbDelta( $sql );
        
        // Stripe transactions table
        $table_name = $wpdb->prefix . 'llms_mobile_stripe_transactions';
        
        $sql = "CREATE TABLE IF NOT EXISTS $table_name (
            id bigint(20) NOT NULL AUTO_INCREMENT,
            user_id bigint(20) NOT NULL,
            course_id bigint(20) NOT NULL,
            payment_intent_id varchar(255),
            payment_method_id varchar(255),
            amount decimal(10,2) NOT NULL,
            currency varchar(3),
            status varchar(20),
            description text,
            metadata text,
            error_message text,
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY user_id (user_id),
            KEY course_id (course_id),
            KEY payment_intent_id (payment_intent_id),
            KEY status (status),
            KEY created_at (created_at)
        ) $charset_collate;";
        
        require_once( ABSPATH . 'wp-admin/includes/upgrade.php' );
        dbDelta( $sql );
        
        // Stripe customer payment methods table
        $table_name = $wpdb->prefix . 'llms_mobile_stripe_payment_methods';
        
        $sql = "CREATE TABLE IF NOT EXISTS $table_name (
            id bigint(20) NOT NULL AUTO_INCREMENT,
            user_id bigint(20) NOT NULL,
            payment_method_id varchar(255) NOT NULL,
            type varchar(20),
            card_brand varchar(20),
            card_last4 varchar(4),
            card_exp_month tinyint(2),
            card_exp_year smallint(4),
            is_default tinyint(1) DEFAULT 0,
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY user_id (user_id),
            KEY payment_method_id (payment_method_id),
            UNIQUE KEY user_payment_method (user_id, payment_method_id)
        ) $charset_collate;";
        
        require_once( ABSPATH . 'wp-admin/includes/upgrade.php' );
        dbDelta( $sql );
    }
    
    /**
     * Create favorites table
     */
    private function create_favorites_table( $charset_collate ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_favorites';
        
        $sql = "CREATE TABLE IF NOT EXISTS $table_name (
            id bigint(20) NOT NULL AUTO_INCREMENT,
            user_id bigint(20) NOT NULL,
            object_id bigint(20) NOT NULL,
            object_type varchar(20) NOT NULL,
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY user_id (user_id),
            KEY object_id (object_id),
            KEY object_type (object_type),
            KEY user_object (user_id, object_id, object_type),
            UNIQUE KEY unique_favorite (user_id, object_id, object_type)
        ) $charset_collate;";
        
        require_once( ABSPATH . 'wp-admin/includes/upgrade.php' );
        dbDelta( $sql );
    }
    
    /**
     * Clean up old inactive devices
     */
    public function cleanup_inactive_devices( $days = 90 ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_devices';
        
        $date = date( 'Y-m-d H:i:s', strtotime( "-$days days" ) );
        
        return $wpdb->query( $wpdb->prepare(
            "DELETE FROM $table_name WHERE last_active < %s",
            $date
        ) );
    }
}

// Initialize database
LLMS_Mobile_Database::instance();
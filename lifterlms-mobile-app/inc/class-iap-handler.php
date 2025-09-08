<?php
/**
 * In-App Purchase Handler for LifterLMS Mobile App
 */

defined( 'ABSPATH' ) || exit;

/**
 * IAP Handler class
 */
class LLMS_Mobile_IAP_Handler {
    
    /**
     * Apple receipt validation URLs
     */
    const APPLE_PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';
    const APPLE_SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';
    
    /**
     * Google Play API URL
     */
    const GOOGLE_API_URL = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';
    
    /**
     * Verify Apple receipt
     */
    public function verify_apple_receipt( $receipt_data, $course_id ) {
        $shared_secret = get_option( 'llms_mobile_apple_shared_secret', '' );
        $use_sandbox = get_option( 'llms_mobile_apple_sandbox', 'no' ) === 'yes';
        
        if ( empty( $shared_secret ) ) {
            error_log( 'LLMS Mobile: Apple shared secret not configured' );
            return false;
        }
        
        // Prepare receipt data
        $post_data = json_encode( array(
            'receipt-data' => $receipt_data,
            'password'     => $shared_secret,
        ) );
        
        // Try production first, then sandbox
        $url = $use_sandbox ? self::APPLE_SANDBOX_URL : self::APPLE_PRODUCTION_URL;
        
        $response = $this->send_apple_request( $url, $post_data );
        
        // If production fails with 21007 (sandbox receipt), try sandbox
        if ( ! $use_sandbox && $response && $response['status'] == 21007 ) {
            $response = $this->send_apple_request( self::APPLE_SANDBOX_URL, $post_data );
        }
        
        // Validate response
        if ( $response && isset( $response['status'] ) && $response['status'] == 0 ) {
            // Receipt is valid
            // Check if product ID matches course
            if ( isset( $response['receipt']['in_app'] ) ) {
                foreach ( $response['receipt']['in_app'] as $purchase ) {
                    if ( $purchase['product_id'] == $course_id ) {
                        // Log successful verification
                        $this->log_verification( 'apple', $course_id, true );
                        return true;
                    }
                }
            }
        }
        
        // Log failed verification
        $this->log_verification( 'apple', $course_id, false, $response );
        return false;
    }
    
    /**
     * Send request to Apple
     */
    private function send_apple_request( $url, $post_data ) {
        $args = array(
            'body'    => $post_data,
            'headers' => array(
                'Content-Type' => 'application/json',
            ),
            'timeout' => 30,
        );
        
        $response = wp_remote_post( $url, $args );
        
        if ( is_wp_error( $response ) ) {
            error_log( 'LLMS Mobile: Apple receipt verification error - ' . $response->get_error_message() );
            return false;
        }
        
        $body = wp_remote_retrieve_body( $response );
        return json_decode( $body, true );
    }
    
    /**
     * Verify Google receipt
     */
    public function verify_google_receipt( $receipt_data, $course_id ) {
        $service_account_json = get_option( 'llms_mobile_google_service_account', '' );
        
        if ( empty( $service_account_json ) ) {
            error_log( 'LLMS Mobile: Google service account not configured' );
            return false;
        }
        
        try {
            // Parse receipt data
            $receipt = json_decode( $receipt_data, true );
            
            if ( ! isset( $receipt['packageName'] ) || ! isset( $receipt['productId'] ) || ! isset( $receipt['purchaseToken'] ) ) {
                error_log( 'LLMS Mobile: Invalid Google receipt data' );
                return false;
            }
            
            // Get access token
            $access_token = $this->get_google_access_token( $service_account_json );
            
            if ( ! $access_token ) {
                error_log( 'LLMS Mobile: Failed to get Google access token' );
                return false;
            }
            
            // Verify purchase with Google Play API
            $package_name = $receipt['packageName'];
            $product_id = $receipt['productId'];
            $purchase_token = $receipt['purchaseToken'];
            
            $url = self::GOOGLE_API_URL . "/{$package_name}/purchases/products/{$product_id}/tokens/{$purchase_token}";
            
            $args = array(
                'headers' => array(
                    'Authorization' => 'Bearer ' . $access_token,
                ),
                'timeout' => 30,
            );
            
            $response = wp_remote_get( $url, $args );
            
            if ( is_wp_error( $response ) ) {
                error_log( 'LLMS Mobile: Google verification error - ' . $response->get_error_message() );
                return false;
            }
            
            $body = wp_remote_retrieve_body( $response );
            $result = json_decode( $body, true );
            
            // Check if purchase is valid
            if ( isset( $result['purchaseState'] ) && $result['purchaseState'] == 0 ) {
                // Purchase is valid (0 = purchased)
                if ( $product_id == $course_id ) {
                    // Log successful verification
                    $this->log_verification( 'google', $course_id, true );
                    return true;
                }
            }
            
        } catch ( Exception $e ) {
            error_log( 'LLMS Mobile: Google verification exception - ' . $e->getMessage() );
        }
        
        // Log failed verification
        $this->log_verification( 'google', $course_id, false );
        return false;
    }
    
    /**
     * Get Google access token using service account
     */
    private function get_google_access_token( $service_account_json ) {
        try {
            $service_account = json_decode( $service_account_json, true );
            
            if ( ! $service_account || ! isset( $service_account['private_key'] ) ) {
                return false;
            }
            
            // Create JWT
            $header = array(
                'alg' => 'RS256',
                'typ' => 'JWT',
            );
            
            $claim = array(
                'iss'   => $service_account['client_email'],
                'scope' => 'https://www.googleapis.com/auth/androidpublisher',
                'aud'   => 'https://oauth2.googleapis.com/token',
                'exp'   => time() + 3600,
                'iat'   => time(),
            );
            
            $header_encoded = $this->base64url_encode( json_encode( $header ) );
            $claim_encoded = $this->base64url_encode( json_encode( $claim ) );
            
            $signature = '';
            $private_key = $service_account['private_key'];
            
            if ( ! function_exists( 'openssl_sign' ) ) {
                error_log( 'LLMS Mobile: OpenSSL functions not available' );
                return false;
            }
            
            openssl_sign( "$header_encoded.$claim_encoded", $signature, $private_key, 'sha256' );
            $signature_encoded = $this->base64url_encode( $signature );
            
            $jwt = "$header_encoded.$claim_encoded.$signature_encoded";
            
            // Exchange JWT for access token
            $response = wp_remote_post( 'https://oauth2.googleapis.com/token', array(
                'body' => array(
                    'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                    'assertion'  => $jwt,
                ),
            ) );
            
            if ( is_wp_error( $response ) ) {
                return false;
            }
            
            $body = wp_remote_retrieve_body( $response );
            $result = json_decode( $body, true );
            
            return isset( $result['access_token'] ) ? $result['access_token'] : false;
            
        } catch ( Exception $e ) {
            error_log( 'LLMS Mobile: Access token error - ' . $e->getMessage() );
            return false;
        }
    }
    
    /**
     * Base64 URL encode
     */
    private function base64url_encode( $data ) {
        return str_replace( array( '+', '/', '=' ), array( '-', '_', '' ), base64_encode( $data ) );
    }
    
    /**
     * Log verification attempt
     */
    private function log_verification( $platform, $course_id, $success, $response = null ) {
        $log_entry = array(
            'timestamp' => current_time( 'mysql' ),
            'platform'  => $platform,
            'course_id' => $course_id,
            'success'   => $success,
            'user_id'   => get_current_user_id(),
        );
        
        if ( ! $success && $response ) {
            $log_entry['error'] = json_encode( $response );
        }
        
        // Store in database or log file
        error_log( 'LLMS Mobile IAP: ' . json_encode( $log_entry ) );
        
        // Optionally store in database
        global $wpdb;
        $table_name = $wpdb->prefix . 'llms_mobile_iap_logs';
        
        // Create table if it doesn't exist
        $this->maybe_create_log_table();
        
        $wpdb->insert( $table_name, $log_entry );
    }
    
    /**
     * Maybe create IAP log table
     */
    private function maybe_create_log_table() {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_iap_logs';
        $charset_collate = $wpdb->get_charset_collate();
        
        // Check if table exists
        if ( $wpdb->get_var( "SHOW TABLES LIKE '$table_name'" ) != $table_name ) {
            $sql = "CREATE TABLE $table_name (
                id bigint(20) NOT NULL AUTO_INCREMENT,
                timestamp datetime DEFAULT CURRENT_TIMESTAMP,
                platform varchar(20) NOT NULL,
                course_id bigint(20) NOT NULL,
                user_id bigint(20) NOT NULL,
                success tinyint(1) NOT NULL,
                error text,
                PRIMARY KEY (id),
                KEY user_id (user_id),
                KEY course_id (course_id)
            ) $charset_collate;";
            
            require_once( ABSPATH . 'wp-admin/includes/upgrade.php' );
            dbDelta( $sql );
        }
    }
}
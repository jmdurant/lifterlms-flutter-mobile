<?php
/**
 * Push Notifications Handler for LifterLMS Mobile App
 */

defined( 'ABSPATH' ) || exit;

/**
 * Push Notifications class
 */
class LLMS_Mobile_Push_Notifications {
    
    /**
     * Firebase API URL
     */
    const FIREBASE_API_URL = 'https://fcm.googleapis.com/v1/projects/%s/messages:send';
    
    /**
     * Constructor
     */
    public function __construct() {
        // Hook into LifterLMS events
        $this->init_hooks();
    }
    
    /**
     * Initialize hooks for notifications
     */
    private function init_hooks() {
        // Course enrollment
        add_action( 'llms_user_enrolled_in_course', array( $this, 'send_enrollment_notification' ), 10, 2 );
        
        // Course completion
        add_action( 'llms_user_course_completed', array( $this, 'send_completion_notification' ), 10, 3 );
        
        // Lesson completion
        add_action( 'llms_mark_complete', array( $this, 'send_lesson_complete_notification' ), 10, 3 );
        
        // Quiz completion
        add_action( 'llms_quiz_completed', array( $this, 'send_quiz_complete_notification' ), 10, 3 );
        
        // Certificate earned
        add_action( 'llms_user_earned_certificate', array( $this, 'send_certificate_notification' ), 10, 3 );
        
        // Achievement earned
        add_action( 'llms_user_earned_achievement', array( $this, 'send_achievement_notification' ), 10, 3 );
    }
    
    /**
     * Register device for push notifications
     */
    public function register_device( $user_id, $device_token, $platform ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_devices';
        
        // Check if device already exists
        $existing = $wpdb->get_row( $wpdb->prepare(
            "SELECT * FROM $table_name WHERE device_token = %s",
            $device_token
        ) );
        
        if ( $existing ) {
            // Update existing device
            $wpdb->update(
                $table_name,
                array(
                    'user_id' => $user_id,
                    'platform' => $platform,
                    'active' => 1,
                    'updated_at' => current_time( 'mysql' ),
                ),
                array( 'device_token' => $device_token )
            );
        } else {
            // Insert new device
            $wpdb->insert(
                $table_name,
                array(
                    'user_id' => $user_id,
                    'device_token' => $device_token,
                    'platform' => $platform,
                    'active' => 1,
                    'created_at' => current_time( 'mysql' ),
                    'updated_at' => current_time( 'mysql' ),
                )
            );
        }
        
        return true;
    }
    
    /**
     * Unregister device
     */
    public function unregister_device( $device_token ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_devices';
        
        $wpdb->update(
            $table_name,
            array( 'active' => 0 ),
            array( 'device_token' => $device_token )
        );
        
        return true;
    }
    
    /**
     * Get user devices
     */
    private function get_user_devices( $user_id ) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'llms_mobile_devices';
        
        return $wpdb->get_results( $wpdb->prepare(
            "SELECT * FROM $table_name WHERE user_id = %d AND active = 1",
            $user_id
        ) );
    }
    
    /**
     * Send push notification
     */
    public function send_notification( $user_id, $title, $body, $data = array() ) {
        // Check if push notifications are enabled
        if ( get_option( 'llms_mobile_push_enabled', 'no' ) !== 'yes' ) {
            return false;
        }
        
        // Get user devices
        $devices = $this->get_user_devices( $user_id );
        
        if ( empty( $devices ) ) {
            return false;
        }
        
        // Get Firebase access token
        $access_token = $this->get_firebase_access_token();
        
        if ( ! $access_token ) {
            error_log( 'LLMS Mobile: Failed to get Firebase access token' );
            return false;
        }
        
        $project_id = get_option( 'llms_mobile_firebase_project_id', '' );
        
        if ( empty( $project_id ) ) {
            error_log( 'LLMS Mobile: Firebase project ID not configured' );
            return false;
        }
        
        $success_count = 0;
        
        foreach ( $devices as $device ) {
            $message = array(
                'message' => array(
                    'token' => $device->device_token,
                    'notification' => array(
                        'title' => $title,
                        'body' => $body,
                    ),
                    'data' => $data,
                ),
            );
            
            // Add platform-specific options
            if ( $device->platform === 'ios' ) {
                $message['message']['apns'] = array(
                    'payload' => array(
                        'aps' => array(
                            'sound' => 'default',
                            'badge' => 1,
                        ),
                    ),
                );
            } else {
                $message['message']['android'] = array(
                    'priority' => 'high',
                    'notification' => array(
                        'sound' => 'default',
                    ),
                );
            }
            
            $url = sprintf( self::FIREBASE_API_URL, $project_id );
            
            $response = wp_remote_post( $url, array(
                'headers' => array(
                    'Authorization' => 'Bearer ' . $access_token,
                    'Content-Type' => 'application/json',
                ),
                'body' => json_encode( $message ),
                'timeout' => 30,
            ) );
            
            if ( ! is_wp_error( $response ) ) {
                $body = wp_remote_retrieve_body( $response );
                $result = json_decode( $body, true );
                
                if ( isset( $result['name'] ) ) {
                    $success_count++;
                    $this->log_notification( $user_id, $device->device_token, $title, true );
                } else {
                    $this->log_notification( $user_id, $device->device_token, $title, false, $body );
                }
            } else {
                $this->log_notification( $user_id, $device->device_token, $title, false, $response->get_error_message() );
            }
        }
        
        return $success_count > 0;
    }
    
    /**
     * Get Firebase access token
     */
    private function get_firebase_access_token() {
        $service_account_json = get_option( 'llms_mobile_firebase_service_account', '' );
        
        if ( empty( $service_account_json ) ) {
            return false;
        }
        
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
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud'   => 'https://oauth2.googleapis.com/token',
                'exp'   => time() + 3600,
                'iat'   => time(),
            );
            
            $header_encoded = $this->base64url_encode( json_encode( $header ) );
            $claim_encoded = $this->base64url_encode( json_encode( $claim ) );
            
            $signature = '';
            $private_key = $service_account['private_key'];
            
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
            error_log( 'LLMS Mobile: Firebase access token error - ' . $e->getMessage() );
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
     * Send enrollment notification
     */
    public function send_enrollment_notification( $user_id, $course_id ) {
        $course = new LLMS_Course( $course_id );
        $title = __( 'Course Enrollment', 'lifterlms-mobile-app' );
        $body = sprintf( __( 'You have been enrolled in %s', 'lifterlms-mobile-app' ), $course->get( 'title' ) );
        
        $this->send_notification( $user_id, $title, $body, array(
            'type' => 'enrollment',
            'course_id' => strval( $course_id ),
        ) );
    }
    
    /**
     * Send completion notification
     */
    public function send_completion_notification( $user_id, $course_id, $progress ) {
        $course = new LLMS_Course( $course_id );
        $title = __( 'Course Completed!', 'lifterlms-mobile-app' );
        $body = sprintf( __( 'Congratulations! You have completed %s', 'lifterlms-mobile-app' ), $course->get( 'title' ) );
        
        $this->send_notification( $user_id, $title, $body, array(
            'type' => 'completion',
            'course_id' => strval( $course_id ),
        ) );
    }
    
    /**
     * Send lesson complete notification
     */
    public function send_lesson_complete_notification( $user_id, $lesson_id, $course_id = null ) {
        $lesson = new LLMS_Lesson( $lesson_id );
        $title = __( 'Lesson Completed', 'lifterlms-mobile-app' );
        $body = sprintf( __( 'You have completed: %s', 'lifterlms-mobile-app' ), $lesson->get( 'title' ) );
        
        $this->send_notification( $user_id, $title, $body, array(
            'type' => 'lesson_complete',
            'lesson_id' => strval( $lesson_id ),
            'course_id' => strval( $course_id ),
        ) );
    }
    
    /**
     * Send quiz complete notification
     */
    public function send_quiz_complete_notification( $user_id, $quiz_id, $attempt ) {
        $quiz = llms_get_post( $quiz_id );
        $title = __( 'Quiz Completed', 'lifterlms-mobile-app' );
        $body = sprintf( __( 'You scored %s%% on %s', 'lifterlms-mobile-app' ), $attempt->get( 'grade' ), $quiz->get( 'title' ) );
        
        $this->send_notification( $user_id, $title, $body, array(
            'type' => 'quiz_complete',
            'quiz_id' => strval( $quiz_id ),
            'grade' => strval( $attempt->get( 'grade' ) ),
        ) );
    }
    
    /**
     * Send certificate notification
     */
    public function send_certificate_notification( $user_id, $certificate_id, $related_id ) {
        $title = __( 'Certificate Earned!', 'lifterlms-mobile-app' );
        $body = __( 'Congratulations! You have earned a new certificate.', 'lifterlms-mobile-app' );
        
        $this->send_notification( $user_id, $title, $body, array(
            'type' => 'certificate',
            'certificate_id' => strval( $certificate_id ),
        ) );
    }
    
    /**
     * Send achievement notification
     */
    public function send_achievement_notification( $user_id, $achievement_id, $related_id ) {
        $achievement = new LLMS_User_Achievement( $achievement_id );
        $title = __( 'Achievement Unlocked!', 'lifterlms-mobile-app' );
        $body = sprintf( __( 'You have earned: %s', 'lifterlms-mobile-app' ), $achievement->get( 'title' ) );
        
        $this->send_notification( $user_id, $title, $body, array(
            'type' => 'achievement',
            'achievement_id' => strval( $achievement_id ),
        ) );
    }
    
    /**
     * Log notification
     */
    private function log_notification( $user_id, $device_token, $title, $success, $error = null ) {
        $log_entry = array(
            'timestamp' => current_time( 'mysql' ),
            'user_id' => $user_id,
            'device_token' => substr( $device_token, 0, 20 ) . '...',
            'title' => $title,
            'success' => $success,
        );
        
        if ( ! $success && $error ) {
            $log_entry['error'] = $error;
        }
        
        error_log( 'LLMS Mobile Push: ' . json_encode( $log_entry ) );
    }
}
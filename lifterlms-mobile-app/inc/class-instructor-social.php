<?php
/**
 * Add social media fields to instructor REST API responses
 */

defined( 'ABSPATH' ) || exit;

/**
 * Instructor Social Media class
 */
class LLMS_Mobile_Instructor_Social {
    
    /**
     * Constructor
     */
    public function __construct() {
        // Add social fields to instructor REST API response
        add_filter( 'llms_rest_prepare_instructor', array( $this, 'add_social_fields' ), 10, 3 );
        
        // Register REST field for instructors
        add_action( 'rest_api_init', array( $this, 'register_social_fields' ) );
    }
    
    /**
     * Register social media REST fields
     */
    public function register_social_fields() {
        register_rest_field( 'user', 'social', array(
            'get_callback'    => array( $this, 'get_user_social_media' ),
            'update_callback' => array( $this, 'update_user_social_media' ),
            'schema'          => array(
                'description' => 'Social media profiles',
                'type'        => 'object',
                'properties'  => array(
                    'facebook' => array(
                        'type' => 'string',
                        'format' => 'uri',
                    ),
                    'twitter' => array(
                        'type' => 'string',
                        'format' => 'uri',
                    ),
                    'youtube' => array(
                        'type' => 'string',
                        'format' => 'uri',
                    ),
                    'linkedin' => array(
                        'type' => 'string',
                        'format' => 'uri',
                    ),
                    'instagram' => array(
                        'type' => 'string',
                        'format' => 'uri',
                    ),
                ),
            ),
        ) );
    }
    
    /**
     * Get user's social media profiles
     */
    public function get_user_social_media( $user ) {
        $user_id = is_array( $user ) ? $user['id'] : $user->ID;
        
        return array(
            'facebook'  => get_user_meta( $user_id, 'social_facebook', true ),
            'twitter'   => get_user_meta( $user_id, 'social_twitter', true ),
            'youtube'   => get_user_meta( $user_id, 'social_youtube', true ),
            'linkedin'  => get_user_meta( $user_id, 'social_linkedin', true ),
            'instagram' => get_user_meta( $user_id, 'social_instagram', true ),
        );
    }
    
    /**
     * Update user's social media profiles
     */
    public function update_user_social_media( $value, $user, $field_name ) {
        $user_id = $user->ID;
        
        if ( ! current_user_can( 'edit_user', $user_id ) ) {
            return new WP_Error( 'rest_cannot_edit', 'Sorry, you cannot edit this user.', array( 'status' => 401 ) );
        }
        
        if ( isset( $value['facebook'] ) ) {
            update_user_meta( $user_id, 'social_facebook', esc_url_raw( $value['facebook'] ) );
        }
        if ( isset( $value['twitter'] ) ) {
            update_user_meta( $user_id, 'social_twitter', esc_url_raw( $value['twitter'] ) );
        }
        if ( isset( $value['youtube'] ) ) {
            update_user_meta( $user_id, 'social_youtube', esc_url_raw( $value['youtube'] ) );
        }
        if ( isset( $value['linkedin'] ) ) {
            update_user_meta( $user_id, 'social_linkedin', esc_url_raw( $value['linkedin'] ) );
        }
        if ( isset( $value['instagram'] ) ) {
            update_user_meta( $user_id, 'social_instagram', esc_url_raw( $value['instagram'] ) );
        }
        
        return true;
    }
    
    /**
     * Add social fields to instructor REST response
     */
    public function add_social_fields( $response, $instructor, $request ) {
        $data = $response->get_data();
        
        // Add social media fields
        $data['social'] = $this->get_user_social_media( $instructor );
        
        $response->set_data( $data );
        return $response;
    }
}

// Initialize
new LLMS_Mobile_Instructor_Social();
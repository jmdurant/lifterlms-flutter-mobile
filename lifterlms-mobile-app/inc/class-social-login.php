<?php
/**
 * Social Login Handler for LifterLMS Mobile App
 */

defined( 'ABSPATH' ) || exit;

/**
 * Social Login class
 */
class LLMS_Mobile_Social_Login {
    
    /**
     * Instance
     */
    private static $instance = null;
    
    /**
     * Database instance
     */
    private $database;
    
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
        $this->database = LLMS_Mobile_Database::instance();
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
        // Check if social login is enabled
        register_rest_route( 'llms/v1', '/mobile-app/enable-social', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'is_social_enabled' ),
            'permission_callback' => '__return_true',
        ) );
        
        // Verify Google login
        register_rest_route( 'llms/v1', '/mobile-app/verify-google', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'verify_google' ),
            'permission_callback' => '__return_true',
            'args'                => array(
                'idToken' => array(
                    'required' => true,
                    'type'     => 'string',
                ),
            ),
        ) );
        
        // Verify Apple login
        register_rest_route( 'llms/v1', '/mobile-app/verify-apple', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'verify_apple' ),
            'permission_callback' => '__return_true',
            'args'                => array(
                'identityToken' => array(
                    'required' => true,
                    'type'     => 'string',
                ),
                'email' => array(
                    'required' => false,
                    'type'     => 'string',
                ),
                'fullName' => array(
                    'required' => false,
                    'type'     => 'string',
                ),
            ),
        ) );
        
        // Verify Facebook login
        register_rest_route( 'llms/v1', '/mobile-app/verify-facebook', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'verify_facebook' ),
            'permission_callback' => '__return_true',
            'args'                => array(
                'token' => array(
                    'required' => true,
                    'type'     => 'string',
                ),
            ),
        ) );
    }
    
    /**
     * Check if social login is enabled
     */
    public function is_social_enabled( $request ) {
        return array(
            'enabled' => get_option( 'llms_mobile_social_enabled', 'no' ) === 'yes',
            'providers' => $this->get_enabled_providers(),
        );
    }
    
    /**
     * Get enabled providers
     */
    private function get_enabled_providers() {
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
     * Verify Google login
     */
    public function verify_google( $request ) {
        $id_token = $request->get_param( 'idToken' );
        
        try {
            // Verify token with Google
            $google_client_id = get_option( 'llms_mobile_google_client_id', '' );
            
            if ( empty( $google_client_id ) ) {
                throw new Exception( 'Google login not configured' );
            }
            
            // Verify the ID token
            $url = 'https://oauth2.googleapis.com/tokeninfo?id_token=' . $id_token;
            $response = wp_remote_get( $url );
            
            if ( is_wp_error( $response ) ) {
                throw new Exception( 'Failed to verify token with Google' );
            }
            
            $body = wp_remote_retrieve_body( $response );
            $token_info = json_decode( $body, true );
            
            // Validate token
            if ( ! isset( $token_info['aud'] ) || $token_info['aud'] !== $google_client_id ) {
                throw new Exception( 'Invalid token audience' );
            }
            
            if ( ! isset( $token_info['email'] ) ) {
                throw new Exception( 'Email not provided' );
            }
            
            // Get or create user
            $user_data = $this->get_or_create_user( array(
                'email' => $token_info['email'],
                'name' => isset( $token_info['name'] ) ? $token_info['name'] : '',
                'provider' => 'google',
                'provider_user_id' => $token_info['sub'],
                'profile_picture' => isset( $token_info['picture'] ) ? $token_info['picture'] : '',
            ) );
            
            // Save social login record
            $this->database->save_social_login( array(
                'user_id' => $user_data['user_id'],
                'provider' => 'google',
                'provider_user_id' => $token_info['sub'],
                'email' => $token_info['email'],
                'name' => isset( $token_info['name'] ) ? $token_info['name'] : '',
                'profile_picture' => isset( $token_info['picture'] ) ? $token_info['picture'] : '',
            ) );
            
            return $user_data;
            
        } catch ( Exception $e ) {
            return new WP_Error( 'google_login_failed', $e->getMessage(), array( 'status' => 400 ) );
        }
    }
    
    /**
     * Verify Apple login
     */
    public function verify_apple( $request ) {
        $identity_token = $request->get_param( 'identityToken' );
        $email = $request->get_param( 'email' );
        $full_name = $request->get_param( 'fullName' );
        
        try {
            // Parse the identity token
            $token_parts = explode( '.', $identity_token );
            
            if ( count( $token_parts ) !== 3 ) {
                throw new Exception( 'Invalid identity token format' );
            }
            
            // Decode header to get key ID
            $header = json_decode( base64_decode( $token_parts[0] ), true );
            
            if ( ! isset( $header['kid'] ) ) {
                throw new Exception( 'Key ID not found in token' );
            }
            
            // Get Apple's public keys
            $public_key = $this->get_apple_public_key( $header['kid'] );
            
            if ( ! $public_key ) {
                throw new Exception( 'Failed to get Apple public key' );
            }
            
            // Verify and decode the token
            $payload = $this->verify_jwt( $identity_token, $public_key );
            
            if ( ! $payload ) {
                throw new Exception( 'Failed to verify identity token' );
            }
            
            // Validate token claims
            if ( $payload->iss !== 'https://appleid.apple.com' ) {
                throw new Exception( 'Invalid token issuer' );
            }
            
            if ( $payload->exp < time() ) {
                throw new Exception( 'Token has expired' );
            }
            
            // Get email from token or request
            $user_email = ! empty( $payload->email ) ? $payload->email : $email;
            
            if ( empty( $user_email ) ) {
                throw new Exception( 'Email not provided' );
            }
            
            // Get or create user
            $user_data = $this->get_or_create_user( array(
                'email' => $user_email,
                'name' => $full_name ?: '',
                'provider' => 'apple',
                'provider_user_id' => $payload->sub,
            ) );
            
            // Save social login record
            $this->database->save_social_login( array(
                'user_id' => $user_data['user_id'],
                'provider' => 'apple',
                'provider_user_id' => $payload->sub,
                'email' => $user_email,
                'name' => $full_name ?: '',
            ) );
            
            return $user_data;
            
        } catch ( Exception $e ) {
            return new WP_Error( 'apple_login_failed', $e->getMessage(), array( 'status' => 400 ) );
        }
    }
    
    /**
     * Get Apple public key
     */
    private function get_apple_public_key( $kid ) {
        // Fetch Apple's public keys
        $response = wp_remote_get( 'https://appleid.apple.com/auth/keys' );
        
        if ( is_wp_error( $response ) ) {
            return false;
        }
        
        $body = wp_remote_retrieve_body( $response );
        $keys_data = json_decode( $body, true );
        
        if ( ! isset( $keys_data['keys'] ) ) {
            return false;
        }
        
        // Find the key with matching kid
        foreach ( $keys_data['keys'] as $key ) {
            if ( $key['kid'] === $kid ) {
                // Convert JWK to PEM format
                return $this->jwk_to_pem( $key );
            }
        }
        
        return false;
    }
    
    /**
     * Convert JWK to PEM format
     */
    private function jwk_to_pem( $jwk ) {
        if ( $jwk['kty'] !== 'RSA' ) {
            return false;
        }
        
        $n = $this->base64url_decode( $jwk['n'] );
        $e = $this->base64url_decode( $jwk['e'] );
        
        $modulus = pack( 'Ca*a*', 2, $this->encode_length( strlen( $n ) ), $n );
        $exponent = pack( 'Ca*a*', 2, $this->encode_length( strlen( $e ) ), $e );
        
        $rsa_public_key = pack( 'Ca*a*a*',
            48,
            $this->encode_length( strlen( $modulus ) + strlen( $exponent ) ),
            $modulus,
            $exponent
        );
        
        $der = pack( 'a*a*',
            pack( 'H*', '300d06092a864886f70d0101010500' ),
            pack( 'Ca*a*',
                3,
                $this->encode_length( strlen( $rsa_public_key ) + 1 ),
                chr(0) . $rsa_public_key
            )
        );
        
        $der = pack( 'Ca*a*', 48, $this->encode_length( strlen( $der ) ), $der );
        
        return "-----BEGIN PUBLIC KEY-----\n" . 
               chunk_split( base64_encode( $der ), 64, "\n" ) . 
               "-----END PUBLIC KEY-----";
    }
    
    /**
     * Encode ASN.1 length
     */
    private function encode_length( $length ) {
        if ( $length <= 0x7F ) {
            return chr( $length );
        }
        
        $temp = ltrim( pack( 'N', $length ), chr(0) );
        return pack( 'Ca*', 0x80 | strlen( $temp ), $temp );
    }
    
    /**
     * Base64 URL decode
     */
    private function base64url_decode( $data ) {
        return base64_decode( strtr( $data, '-_', '+/' ) . str_repeat( '=', 3 - ( 3 + strlen( $data ) ) % 4 ) );
    }
    
    /**
     * Verify JWT token
     */
    private function verify_jwt( $token, $public_key ) {
        // Use PHP's openssl functions to verify the JWT
        $token_parts = explode( '.', $token );
        
        if ( count( $token_parts ) !== 3 ) {
            return false;
        }
        
        $header_payload = $token_parts[0] . '.' . $token_parts[1];
        $signature = $this->base64url_decode( $token_parts[2] );
        
        $verified = openssl_verify( $header_payload, $signature, $public_key, OPENSSL_ALGO_SHA256 );
        
        if ( $verified !== 1 ) {
            return false;
        }
        
        // Decode and return payload
        return json_decode( base64_decode( $token_parts[1] ) );
    }
    
    /**
     * Verify Facebook login
     */
    public function verify_facebook( $request ) {
        $access_token = $request->get_param( 'token' );
        
        try {
            $fb_app_id = get_option( 'llms_mobile_fb_client_id', '' );
            $fb_app_secret = get_option( 'llms_mobile_fb_client_secret', '' );
            
            if ( empty( $fb_app_id ) || empty( $fb_app_secret ) ) {
                throw new Exception( 'Facebook login not configured' );
            }
            
            // Verify the access token with Facebook
            $url = sprintf(
                'https://graph.facebook.com/debug_token?input_token=%s&access_token=%s|%s',
                $access_token,
                $fb_app_id,
                $fb_app_secret
            );
            
            $response = wp_remote_get( $url );
            
            if ( is_wp_error( $response ) ) {
                throw new Exception( 'Failed to verify token with Facebook' );
            }
            
            $body = wp_remote_retrieve_body( $response );
            $token_data = json_decode( $body, true );
            
            if ( ! isset( $token_data['data']['is_valid'] ) || ! $token_data['data']['is_valid'] ) {
                throw new Exception( 'Invalid Facebook token' );
            }
            
            // Get user info from Facebook
            $user_url = sprintf(
                'https://graph.facebook.com/me?fields=id,email,name,picture&access_token=%s',
                $access_token
            );
            
            $user_response = wp_remote_get( $user_url );
            
            if ( is_wp_error( $user_response ) ) {
                throw new Exception( 'Failed to get user info from Facebook' );
            }
            
            $user_body = wp_remote_retrieve_body( $user_response );
            $fb_user = json_decode( $user_body, true );
            
            if ( ! isset( $fb_user['email'] ) ) {
                throw new Exception( 'Email not provided by Facebook' );
            }
            
            // Get or create user
            $user_data = $this->get_or_create_user( array(
                'email' => $fb_user['email'],
                'name' => isset( $fb_user['name'] ) ? $fb_user['name'] : '',
                'provider' => 'facebook',
                'provider_user_id' => $fb_user['id'],
                'profile_picture' => isset( $fb_user['picture']['data']['url'] ) ? $fb_user['picture']['data']['url'] : '',
            ) );
            
            // Save social login record
            $this->database->save_social_login( array(
                'user_id' => $user_data['user_id'],
                'provider' => 'facebook',
                'provider_user_id' => $fb_user['id'],
                'email' => $fb_user['email'],
                'name' => isset( $fb_user['name'] ) ? $fb_user['name'] : '',
                'profile_picture' => isset( $fb_user['picture']['data']['url'] ) ? $fb_user['picture']['data']['url'] : '',
                'access_token' => $access_token,
            ) );
            
            return $user_data;
            
        } catch ( Exception $e ) {
            return new WP_Error( 'facebook_login_failed', $e->getMessage(), array( 'status' => 400 ) );
        }
    }
    
    /**
     * Get or create user
     */
    private function get_or_create_user( $args ) {
        // Check if user exists with this email
        $user = get_user_by( 'email', $args['email'] );
        
        if ( ! $user ) {
            // Check if social login exists
            $social_login = $this->database->get_social_login( $args['provider'], $args['provider_user_id'] );
            
            if ( $social_login && $social_login->user_id ) {
                $user = get_user_by( 'id', $social_login->user_id );
            }
        }
        
        if ( ! $user ) {
            // Create new user
            $username = $this->generate_username( $args['email'], $args['name'] );
            $password = wp_generate_password( 12, true );
            
            $user_id = wp_create_user( $username, $password, $args['email'] );
            
            if ( is_wp_error( $user_id ) ) {
                throw new Exception( 'Failed to create user: ' . $user_id->get_error_message() );
            }
            
            // Update user meta
            if ( ! empty( $args['name'] ) ) {
                $name_parts = explode( ' ', $args['name'], 2 );
                update_user_meta( $user_id, 'first_name', $name_parts[0] );
                if ( isset( $name_parts[1] ) ) {
                    update_user_meta( $user_id, 'last_name', $name_parts[1] );
                }
            }
            
            // Mark as social login user
            update_user_meta( $user_id, 'llms_mobile_social_login', true );
            update_user_meta( $user_id, 'llms_mobile_social_provider', $args['provider'] );
            
            $user = get_user_by( 'id', $user_id );
        }
        
        // Generate JWT token for mobile app
        $token = $this->generate_jwt_token( $user );
        
        return array(
            'user_id' => $user->ID,
            'email' => $user->user_email,
            'name' => $user->display_name,
            'token' => $token,
            'avatar' => get_avatar_url( $user->ID ),
        );
    }
    
    /**
     * Generate username from email or name
     */
    private function generate_username( $email, $name = '' ) {
        if ( ! empty( $name ) ) {
            $base_username = sanitize_user( strtolower( str_replace( ' ', '', $name ) ), true );
        } else {
            $email_parts = explode( '@', $email );
            $base_username = sanitize_user( $email_parts[0], true );
        }
        
        $username = $base_username;
        $suffix = 1;
        
        while ( username_exists( $username ) ) {
            $username = $base_username . $suffix;
            $suffix++;
        }
        
        return $username;
    }
    
    /**
     * Generate JWT token for user
     */
    private function generate_jwt_token( $user ) {
        // This would integrate with your JWT authentication plugin
        // For now, return a placeholder
        
        // If using JWT Authentication plugin
        if ( class_exists( 'Jwt_Auth_Public' ) ) {
            $jwt_auth = new Jwt_Auth_Public( 'jwt-auth', '1.0.0' );
            $token = $jwt_auth->generate_token( $user );
            return $token;
        }
        
        // Fallback: generate a simple token
        $secret = wp_salt( 'auth' );
        $payload = array(
            'iss' => get_bloginfo( 'url' ),
            'iat' => time(),
            'exp' => time() + ( 7 * DAY_IN_SECONDS ),
            'data' => array(
                'user' => array(
                    'id' => $user->ID,
                    'email' => $user->user_email,
                ),
            ),
        );
        
        // Simple encoding (you should use a proper JWT library in production)
        $header = base64_encode( json_encode( array( 'typ' => 'JWT', 'alg' => 'HS256' ) ) );
        $payload = base64_encode( json_encode( $payload ) );
        $signature = base64_encode( hash_hmac( 'sha256', "$header.$payload", $secret, true ) );
        
        return "$header.$payload.$signature";
    }
}

// Initialize social login
LLMS_Mobile_Social_Login::instance();
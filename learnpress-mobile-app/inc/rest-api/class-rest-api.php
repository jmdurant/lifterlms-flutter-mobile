<?php

if ( ! class_exists( '\Firebase\JWT\JWT' ) ) {
	foreach ( glob( LP_PLUGIN_PATH . 'inc/jwt/includes/php-jwt/*.php' ) as $filename ) {
		require_once $filename;
	}
}

class LP_Jwt_Mobile_App_V1_Controller {

	protected static $instance = null;

	protected $namespace = 'lp/v1';

	protected $rest_base = 'mobile-app';

	public function __construct() {
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
	}

	public function register_routes() {
		register_rest_route(
			$this->namespace,
			'/' . $this->rest_base . '/verify-facebook',
			array(
				array(
					'methods'             => WP_REST_Server::CREATABLE,
					'callback'            => array( $this, 'verify_facebook' ),
					'permission_callback' => '__return_true',
					'args'                => array(
						'token' => array(
							'required' => true,
							'type'     => 'string',
						),
					),
				),
			)
		);

		register_rest_route(
			$this->namespace,
			'/' . $this->rest_base . '/verify-google',
			array(
				array(
					'methods'             => WP_REST_Server::CREATABLE,
					'callback'            => array( $this, 'verify_google' ),
					'permission_callback' => '__return_true',
					'args'                => array(
						'idToken' => array(
							'required' => true,
							'type'     => 'string',
						),
					),
				),
			)
		);

		register_rest_route(
			$this->namespace,
			'/' . $this->rest_base . '/verify-apple',
			array(
				array(
					'methods'             => WP_REST_Server::CREATABLE,
					'callback'            => array( $this, 'verify_apple' ),
					'permission_callback' => '__return_true',
					'args'                => array(
						'identityToken' => array(
							'required' => true,
							'type'     => 'string',
						),
					),
				),
			)
		);

		register_rest_route(
			$this->namespace,
			'/' . $this->rest_base . '/enable-social',
			array(
				array(
					'methods'             => 'GET',
					'permission_callback' => '__return_true',
					'callback'            => array( $this, 'enable_social' ),
				),
			)
		);
	}

	public function enable_social( $request ) {
		return LP()->settings()->get( 'mobile_enable_social_login' ) === 'yes' ? true : false;
	}

	public function verify_apple( $request ) {
		$identity_token = $request['identityToken'];

		try {
			list($header, $payload, $signature) = explode( '.', $identity_token );

			if ( \LP_Addon_Mobile_App_Preload::version_lp_current_is_higher( '4.2.3.3' ) ) {
				$header = \LP\Firebase\JWT\JWT::jsonDecode( base64_decode( $header ) );
			} else {
				$header = \Firebase\JWT\JWT::jsonDecode( base64_decode( $header ) );
			}

			$public_key = $this->get_apple_identity_public_key( $header->kid );

			if ( \LP_Addon_Mobile_App_Preload::version_lp_current_is_higher( '4.2.3.3' ) ) {
				$payload = \LP\Firebase\JWT\JWT::decode( $identity_token, $public_key, array( 'RS256' ) );
			} else {
				$payload = \Firebase\JWT\JWT::decode( $identity_token, $public_key, array( 'RS256' ) );
			}

			if ( $payload->iss !== 'https://appleid.apple.com' ) {
				throw new Exception( 'Invalid audience' );
			}

			if ( $payload->exp < time() ) {
				throw new Exception( 'Expired token' );
			}

			if ( empty( $payload->email ) ) {
				throw new Exception( 'Invalid email' );
			}

			$data = $this->get_data_token( $payload->email, '' );

			return $data;
		} catch ( \Throwable $th ) {
			return new WP_Error( 'rest_verify_apple_failed', $th->getMessage(), array( 'status' => 500 ) );
		}
	}

	protected function get_apple_identity_public_key( $kid = '' ) {
		$request = wp_remote_get( 'https://appleid.apple.com/auth/keys' );

		$body = wp_remote_retrieve_body( $request );

		$lists = json_decode( $body, true );

		$key = array_search( $kid, array_column( $lists['keys'], 'kid' ) );

		if ( ! class_exists( '\LP_Mobile_App\Vendor\JWK' ) ) {
			require_once LP_ADDON_MOBILE_APP_PATH . '/inc/third-party/jwk/JWK.php';
		}

		$parsed_public_key = \LP_Mobile_App\Vendor\JWK::parseKey( $lists['keys'][ $key ] );

		$public_key_details = openssl_pkey_get_details( $parsed_public_key );

		if ( ! isset( $public_key_details['key'] ) ) {
			throw new Exception( 'Invalid public key details.' );
		}

		return $public_key_details['key'];
	}


	public function verify_google( $request ) {
		$id_token = $request['idToken'];

		try {
			$request = wp_remote_get( 'https://oauth2.googleapis.com/tokeninfo?id_token=' . $id_token );

			$body = wp_remote_retrieve_body( $request );

			$body = json_decode( $body, true );

			if ( isset( $body['error'] ) ) {
				throw new Exception( $body['error_description'] ?? 'Error when verify token' );
			}

			$client_id = LP()->settings()->get( 'lp_mobile_gg_web_client_id' );

			if ( empty( $body['aud'] ) || empty( $client_id ) || $client_id !== $body['aud'] ) {
				throw new Exception( 'Invalid client id' );
			}

			$data = $this->get_data_token( $body['email'], $body['name'] ?? '' );

			return $data;
		} catch ( \Throwable $th ) {
			return new WP_Error( 'error', $th->getMessage() );
		}
	}

	public function verify_facebook( $request ) {
		$client_id     = LP()->settings()->get( 'lp_mobile_fb_client_id' );
		$client_secret = LP()->settings()->get( 'lp_mobile_fb_client_secret' );

		try {
			if ( empty( $client_id ) || empty( $client_secret ) ) {
				throw new Exception( __( 'Facebook Client ID or Client Secret is empty.', 'learnpress-mobile-app' ) );
			}

			$response = wp_remote_get( 'https://graph.facebook.com/oauth/access_token?client_id=' . $client_id . '&client_secret=' . $client_secret . '&grant_type=client_credentials' );
			$body     = wp_remote_retrieve_body( $response );
			$result   = json_decode( $body, true );

			if ( ! isset( $result['access_token'] ) ) {
				throw new Exception( __( 'Facebook Client ID or Client Secret is invalid.', 'learnpress-mobile-app' ) );
			}

			$token = $request['token'];

			$response = wp_remote_get( 'https://graph.facebook.com/debug_token?input_token=' . $token . '&access_token=' . $result['access_token'] );
			$body     = wp_remote_retrieve_body( $response );
			$result   = json_decode( $body, true );

			if ( $client_id == $result['data']['app_id'] && $result['data']['is_valid'] ) {
				$fb_me = wp_remote_get( 'https://graph.facebook.com/me?access_token=' . $token . '&fields=email,name,first_name,last_name' );

				$fb_me_body = wp_remote_retrieve_body( $fb_me );

				$fb_me_result = json_decode( $fb_me_body, true );

				if ( ! isset( $fb_me_result['email'] ) ) {
					throw new Exception( __( 'Facebook email is empty.', 'learnpress-mobile-app' ) );
				}

				$data = $this->get_data_token( $fb_me_result['email'], $fb_me_result['name'] ?? '' );

				return $data;
			} else {
				throw new Exception( __( 'Error when debug token.', 'learnpress-mobile-app' ) );
			}
		} catch ( \Throwable $th ) {
			return new WP_Error( 'error', $th->getMessage() );
		}
	}

	public function get_data_token( $email, $name = '' ) {

		$user_id = $this->register_or_login( $email, $name );

		if ( is_wp_error( $user_id ) ) {
			if ( isset( $user_id->errors['registration-error-email-exists'] ) ) {
				$user = get_user_by( 'email', $email );

				if ( $user ) {
					$user_id = $user->ID;
				}
			} else {
				throw new Exception( $user_id->get_error_message() );
			}
		}

		if ( empty( $user ) ) {
			$user = get_user_by( 'id', $user_id );
		}

		$issued_at  = time();
		$not_before = apply_filters( 'lp_jwt_auth_not_before', $issued_at, $issued_at );
		$expire     = apply_filters( 'lp_jwt_auth_expire', $issued_at + WEEK_IN_SECONDS, $issued_at );

		if ( ! class_exists( '\LP\Firebase\JWT\JWT' ) ) {
			foreach ( glob( LP_PLUGIN_PATH . 'inc/jwt/includes/php-jwt/*.php' ) as $filename ) {
				require_once $filename;
			}
		}

		$token = array(
			'iss'  => get_bloginfo( 'url' ),
			'iat'  => $issued_at,
			'nbf'  => $not_before,
			'exp'  => $expire,
			'data' => array(
				'user' => array(
					'id' => $user->data->ID,
				),
			),
		);

		$secret_key = defined( 'LP_SECURE_AUTH_KEY' ) ? LP_SECURE_AUTH_KEY : SECURE_AUTH_KEY;

		if ( \LP_Addon_Mobile_App_Preload::version_lp_current_is_higher( '4.2.3.3' ) ) {
			$token = \LP\Firebase\JWT\JWT::encode( apply_filters( 'lp_jwt_auth_token_before_sign', $token, $user ), $secret_key, 'HS256' );
		} else {
			$token = \Firebase\JWT\JWT::encode( apply_filters( 'lp_jwt_auth_token_before_sign', $token, $user ), $secret_key, 'HS256' );
		}

		$data = array(
			'token'             => $token,
			'user_id'           => $user->data->ID,
			'user_login'        => $user->data->user_login,
			'user_email'        => $user->data->user_email,
			'user_display_name' => $user->data->display_name,
		);

		return apply_filters( 'lp_jwt_auth_token_before_dispatch', $data, $user );
	}

	public function register_or_login( $email, $name = '' ) {
		$password = wp_generate_password();

		$args = array();

		if ( $name ) {
			$name = explode( ' ', $name );

			if ( ! empty( $name[0] ) ) {
				$args['first_name'] = $name[0];
			}

			if ( ! empty( $name[1] ) ) {
				$args['last_name'] = $name[1];
			}
		}

		$user_name = $this->create_new_customer_username( $email, $args );

		$customer = LP_Forms_Handler::learnpress_create_new_customer( $email, $user_name, $password, $password, $args );

		return $customer;
	}

	function create_new_customer_username( $email, $new_user_args = array(), $suffix = '' ) {
		$username_parts = array();

		if ( isset( $new_user_args['first_name'] ) ) {
			$username_parts[] = sanitize_user( $new_user_args['first_name'], true );
		}

		if ( isset( $new_user_args['last_name'] ) ) {
			$username_parts[] = sanitize_user( $new_user_args['last_name'], true );
		}

		// Remove empty parts.
		$username_parts = array_filter( $username_parts );

		// If there are no parts, e.g. name had unicode chars, or was not provided, fallback to email.
		if ( empty( $username_parts ) ) {
			$email_parts    = explode( '@', $email );
			$email_username = $email_parts[0];

			// Exclude common prefixes.
			if ( in_array(
				$email_username,
				array(
					'sales',
					'hello',
					'mail',
					'contact',
					'info',
				),
				true
			) ) {
				// Get the domain part.
				$email_username = $email_parts[1];
			}

			$username_parts[] = sanitize_user( $email_username, true );
		}

		$username = function_exists( 'mb_strtolower' ) ? mb_strtolower( implode( '.', $username_parts ) ) : strtolower( implode( '.', $username_parts ) );

		if ( $suffix ) {
			$username .= $suffix;
		}

		$illegal_logins = (array) apply_filters( 'illegal_user_logins', array() );

		// Stop illegal logins and generate a new random username.
		if ( in_array( strtolower( $username ), array_map( 'strtolower', $illegal_logins ), true ) ) {
			$new_args = array();

			$new_args['first_name'] = apply_filters(
				'lp_mobile_generated_customer_username',
				'lp_mobile_user_' . zeroise( wp_rand( 0, 9999 ), 4 ),
				$email,
				$new_user_args,
				$suffix
			);

			return $this->create_new_customer_username( $email, $new_args, $suffix );
		}

		if ( username_exists( $username ) ) {
			$suffix = '-' . zeroise( wp_rand( 0, 9999 ), 4 );
			return $this->create_new_customer_username( $email, $new_user_args, $suffix );
		}

		return apply_filters( 'lp_mobile_new_customer_username', $username, $email, $new_user_args, $suffix );
	}

	public static function instance() {
		if ( ! self::$instance ) {
			self::$instance = new self();
		}

		return self::$instance;
	}
}

LP_Jwt_Mobile_App_V1_Controller::instance();

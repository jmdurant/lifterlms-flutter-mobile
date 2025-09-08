<?php
/**
 * LearnPress Mobile App - Push Notifications REST API
 *
 * @package LearnPress/Mobile-App/Classes
 * @version 1.0.0
 * @author Nhamdv <email@email.com>
 */
class LP_Mobile_Push_Notifications_Rest_API {

	private static $instance = null;

	protected $namespace = 'learnpress/v1';

	protected $rest_base = 'push-notifications';

	public function __construct() {
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
	}

	public function register_routes() {
		register_rest_route(
			$this->namespace,
			'/' . $this->rest_base . '/register-device',
			array(
				'methods'             => 'POST',
				'callback'            => array( $this, 'register_device' ),
				'permission_callback' => array( $this, 'permission_callback' ),
			)
		);

		register_rest_route(
			$this->namespace,
			'/' . $this->rest_base . '/delete-device',
			array(
				'methods'             => 'POST',
				'callback'            => array( $this, 'delete_device_token' ),
				'permission_callback' => array( $this, 'permission_callback' ),
			)
		);

		register_rest_route(
			$this->namespace,
			'/' . $this->rest_base . '/send-notification',
			array(
				'methods'             => 'POST',
				'callback'            => array( $this, 'send_notification' ),
				'permission_callback' => array( $this, 'permission_callback' ),
			)
		);

		register_rest_route(
			$this->namespace,
			'/' . $this->rest_base . '/get-notifications',
			array(
				'methods'             => 'GET',
				'callback'            => array( $this, 'get_notifications' ),
				'permission_callback' => array( $this, 'permission_callback' ),
			)
		);
	}

	public function permission_callback() {
		$enabled = LP_Settings::get_option( 'lp_push_notification_enable' );

		if ( $enabled !== 'yes' ) {
			return new WP_Error( 'lp_push_notification_disabled', __( 'Push notification is disabled', 'learnpress-mobile-app' ), array( 'status' => 403 ) );
		}

		return is_user_logged_in();
	}

	public function register_device( $request ) {
		$user_id  = get_current_user_id();
		$database = LP_Mobile_Push_Notifications_Database::instance();

		if ( ! $user_id ) {
			return new WP_Error( 'lp_push_notification_user_not_logged_in', __( 'User is not logged in', 'learnpress-mobile-app' ), array( 'status' => 403 ) );
		}

		$device_token = $request->get_param( 'device_token' );
		$device_type  = $request->get_param( 'device_type' );

		$device = $database->add_device_token(
			array(
				'user_id'      => $user_id,
				'device_token' => $device_token,
				'device_type'  => $device_type,
			)
		);

		return rest_ensure_response( array( 'success' => true ) );
	}

	public function delete_device_token( $request ) {
		$database = LP_Mobile_Push_Notifications_Database::instance();

		$device_token = $request->get_param( 'device_token' );

		$database->delete_device_token_by_tokens( array( $device_token ) );

		return rest_ensure_response( array( 'success' => true ) );
	}

	public function send_notification( $request ) {
		$database = LP_Mobile_Push_Notifications_Database::instance();

		if ( ! current_user_can( 'manage_options' ) ) {
			return new WP_Error( 'lp_push_notification_user_not_admin', __( 'User is not admin', 'learnpress-mobile-app' ), array( 'status' => 403 ) );
		}

		$token = $request->get_param( 'device_token' );

		if ( empty( $token ) ) {
			return new WP_Error( 'lp_push_notification_device_token_empty', __( 'Device token is empty', 'learnpress-mobile-app' ), array( 'status' => 403 ) );
		}

		// Get request header.
		$platform = ! empty( $request->get_header( 'x-platform' ) ) ? sanitize_text_field( $request->get_header( 'x-platform' )  ) : '';
		$project_id   = learnpress_mobile_push_notification_settings( $platform )['project_id'];
		$access_token = learnpress_push_notifications_get_access_token( $platform );

		$notification = array(
			'title' => $request->get_param( 'title' ),
			'body'  => $request->get_param( 'body' ),
		);

		$fields = array(
			'message' => array(
				'token'        => $token,
				'notification' => $notification,
				'apns'         => array(
					'payload' => array(
						'aps' => array(
							'content_available' => '1',
							'mutable_content'  => '1',
						),
					),
				),
				'android' => array(
					'priority' => 'high',
				)
			),
		);

		$headers = array(
			'Authorization' => 'Bearer ' . $access_token,
			'Content-Type'  => 'application/json',
		);

		$request = wp_remote_post(
			'https://fcm.googleapis.com/v1/projects/' . $project_id . '/messages:send',
			array(
				'headers'   => $headers,
				'sslverify' => false,
				'body'      => json_encode( $fields ),
			)
		);

		$request_body = wp_remote_retrieve_body( $request );

		$response = json_decode( $request_body );

		if ( ! empty( $response->failure ) ) {
			$database->delete_device_token();
		}

		return rest_ensure_response( array( 'success' => true ) );
	}

	public function get_notifications( $request ) {
		$notifications = array(
			array(
				'id'      => 1,
				'title'   => 'Welcome to Eduma App',
				'content' => 'React Native LMS Mobile App for iOS & Android.',
				'time'    => '10:00 23/12/2022',
			),
			array(
				'id'      => 2,
				'title'   => '',
				'content' => 'Education WordPress Theme – Eduma is made for Education Website, LMS, Training Center, Courses Hub, College, Academy, University, School, Kindergarten, etc.',
				'time'    => '10:00 23/12/2022',
			),
			array(
				'id'      => 3,
				'title'   => '',
				'content' => 'Push Notification will be added soon. We are working on it. Thank you for your patience.',
				'time'    => '15:00 23/12/2022',
			),
		);

		return rest_ensure_response(
			array(
				'success'     => true,
				'data'        => $notifications,
				'total_pages' => 1,
			)
		);
	}

	public static function instance() {
		if ( is_null( self::$instance ) ) {
			self::$instance = new self();
		}
		return self::$instance;
	}
}

LP_Mobile_Push_Notifications_Rest_API::instance();

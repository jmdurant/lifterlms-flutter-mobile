<?php
class LP_Mobile_LearnPress_Rest_API {

	private static $instance = null;

	protected $namespace = 'learnpress/v1';

	protected $new_namespace = 'lp/v1';

	protected $rest_base = 'mobile-app';

	public function __construct() {
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
	}

	public function register_routes() {
		register_rest_route(
			$this->namespace,
			'/' . $this->rest_base . '/product-iap',
			array(
				'methods'             => 'GET',
				'callback'            => array( $this, 'product_iap' ),
				'permission_callback' => '__return_true',
			)
		);

		register_rest_route(
			$this->new_namespace,
			'/' . $this->rest_base . '/product-iap',
			array(
				'methods'             => 'GET',
				'callback'            => array( $this, 'product_iap' ),
				'permission_callback' => '__return_true',
			)
		);
	}

	public function product_iap( $request ) {
		$course_ids = LP_Settings::get_option( 'in_app_purchase_course_ids', array() );

		$course_ids = explode( ',', $course_ids );
		// Convert to array item to string.
		$course_ids = array_map( 'trim', $course_ids );
		$course_ids = array_map( 'strval', $course_ids );

		return $course_ids;
	}

	public static function instance() {
		if ( is_null( self::$instance ) ) {
			self::$instance = new self();
		}
		return self::$instance;
	}
}

LP_Mobile_LearnPress_Rest_API::instance();

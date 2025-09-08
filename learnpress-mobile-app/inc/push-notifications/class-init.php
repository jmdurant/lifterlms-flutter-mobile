<?php
class LP_Mobile_Push_Notifications_Init {

	private static $instance = null;

	public function __construct() {
		$this->includes();
	}

	public function includes() {
		require_once LP_ADDON_MOBILE_APP_PATH . '/inc/push-notifications/class-database.php';
		require_once LP_ADDON_MOBILE_APP_PATH . '/inc/push-notifications/class-rest-api.php';
	}

	public static function instance() {
		if ( is_null( self::$instance ) ) {
			self::$instance = new self();
		}

		return self::$instance;
	}
}
LP_Mobile_Push_Notifications_Init::instance();

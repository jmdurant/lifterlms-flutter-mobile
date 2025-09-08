<?php

/**
 * Class LP_Addon_APP_PURCHASE
 *
 * @since 4.1.5
 */
class LP_Addon_Mobile_App extends LP_Addon {
	/**
	 * App Purchase version
	 *
	 * @var string
	 */
	public $version = LP_ADDON_MOBILE_APP_VER;

	/**
	 * LP require version
	 *
	 * @var null|string
	 */
	public $require_version = LP_ADDON_MOBILE_APP_REQUIRE_VER;

	/**
	 * Path file addon
	 *
	 * @var null|string
	 */
	public $plugin_file = LP_ADDON_MOBILE_APP_FILE;

	/**
	 * LP_Addon_APP_PURCHASE constructor.
	 */
	public function __construct() {
		parent::__construct();

		//add settings learnpress.
		add_filter( 'learn-press/admin/settings-tabs-array', array( $this, 'admin_settings' ) );
		add_filter( 'learnpress_metabox_settings_sanitize_option', array( $this, 'sanitize_option' ), 10, 3 );
		add_filter( 'lp_metabox_setting_ouput_textarea', array( $this, 'output_option' ), 10, 3 );

	}

	public function _includes() {
		include_once LP_ADDON_MOBILE_APP_PATH . '/inc/functions.php';

		// Rest API
		include_once LP_ADDON_MOBILE_APP_PATH . '/inc/rest-api/class-rest-api.php';
		include_once LP_ADDON_MOBILE_APP_PATH . '/inc/rest-api/class-learnpress-rest-api.php';

		// Push Notifications
		include_once LP_ADDON_MOBILE_APP_PATH . '/inc/push-notifications/class-init.php';
	}

	public function admin_settings( $tabs ) {
		$tabs['mobile_app'] = include_once LP_ADDON_MOBILE_APP_PATH . '/inc/class-settings.php';

		return $tabs;
	}

	public function sanitize_option( $value, $option, $raw_value ) {
		if ( 'learn_press_in_app_purchase_service_account' === $option['id'] || 'learn_press_lp_push_notification_service_account' === $option['id'] ) {
			$value = trim( $raw_value );
		}

		return $value;
	}

	public function output_option( $value, $option, $raw_value ) {
		if ( 'learn_press_in_app_purchase_service_account' === $option['id'] || 'learn_press_lp_push_notification_service_account' === $option['id'] ) {
			$value = $raw_value;
		}

		return $value;
	}
}

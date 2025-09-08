<?php
/**
 * Plugin Name: LearnPress - Mobile App
 * Plugin URI: http://thimpress.com/learnpress
 * Description: Mobile App Settings for LearnPress
 * Author: ThimPress
 * Version: 4.0.3
 * Author URI: http://thimpress.com
 * Tags: learnpress, lms, add-on, app
 * Text Domain: learnpress-mobile-app
 * Domain Path: /languages/
 * Require_LP_Version: 4.2.5.7
 */

defined( 'ABSPATH' ) || exit;

define( 'LP_ADDON_MOBILE_APP_PATH', plugin_dir_path( __FILE__ ) );

const LP_ADDON_MOBILE_APP_FILE = __FILE__;

/**
 * Class LP_Addon_APP_PURCHASE_Preload
 */
class LP_Addon_Mobile_App_Preload {
	/**
	 * @var array
	 */
	public static $addon_info = array();
	/**
	 * @var LP_Addon_Mobile_App $addon
	 */
	public static $addon;

	/**
	 * Singleton.
	 *
	 * @return LP_Addon_Mobile_App_Preload|mixed
	 */
	public static function instance() {
		static $instance;
		if ( is_null( $instance ) ) {
			$instance = new self();
		}

		return $instance;
	}

	protected function __construct() {
		$can_load = true;
		// Set Base name plugin.
		define( 'LP_ADDON_MOBILE_APP_BASENAME', plugin_basename( LP_ADDON_MOBILE_APP_PATH ) );

		// Set version addon for LP check .
		include_once ABSPATH . 'wp-admin/includes/plugin.php';
		self::$addon_info = get_file_data(
			LP_ADDON_MOBILE_APP_FILE,
			array(
				'Name'               => 'Plugin Name',
				'Require_LP_Version' => 'Require_LP_Version',
				'Version'            => 'Version',
			)
		);

		define( 'LP_ADDON_MOBILE_APP_VER', self::$addon_info['Version'] );
		define( 'LP_ADDON_MOBILE_APP_REQUIRE_VER', self::$addon_info['Require_LP_Version'] );

		// Check LP activated .
		if ( ! is_plugin_active( 'learnpress/learnpress.php' ) ) {
			$can_load = false;
		} elseif ( version_compare( LP_ADDON_MOBILE_APP_REQUIRE_VER, get_option( 'learnpress_version', '3.0.0' ), '>' ) ) {
			$can_load = false;
		}

		if ( ! $can_load ) {
			add_action( 'admin_notices', array( $this, 'show_note_errors_require_lp' ) );
			deactivate_plugins( LP_ADDON_MOBILE_APP_BASENAME );

			if ( isset( $_GET['activate'] ) ) {
				unset( $_GET['activate'] );
			}

			return;
		}

		// Sure LP loaded.
		add_action( 'learn-press/ready', array( $this, 'load' ) );

		// Install addon.
		$this->install();
	}

	public function install() {
		require_once plugin_dir_path( __FILE__ ) . 'inc/push-notifications/class-install.php';

		register_activation_hook( __FILE__, array( 'LP_Mobile_Push_Notifications_Install', 'instance' ) );
	}

	/**
	 * Load addon
	 */
	public function load() {
		self::$addon = LP_Addon::load( 'LP_Addon_Mobile_App', 'inc/load.php', __FILE__ );
	}

	public function show_note_errors_require_lp() {
		?>
		<div class="notice notice-error">
			<p><?php echo( 'Please active <strong>LP version ' . LP_ADDON_MOBILE_APP_REQUIRE_VER . ' or later</strong> before active <strong>' . self::$addon_info['Name'] . '</strong>' ); ?></p>
		</div>
		<?php
	}

	/**
	 * Check version LP you want is higher LP install current.
	 *
	 * @param $version_compare
	 *
	 * @return bool
	 */
	public static function version_lp_current_is_higher( $version_compare ): bool {
		$is_higher = false;

		try {
			if ( version_compare( get_option( 'learnpress_version', '4.0.0' ), $version_compare, '>' ) ) {
				$is_higher = true;
			}
		} catch ( Throwable $e ) {

		}

		return $is_higher;
	}
}

LP_Addon_Mobile_App_Preload::instance();

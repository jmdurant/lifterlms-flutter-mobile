<?php
class LP_Mobile_Push_Notifications_Install {

	private static $instance = null;

	public function __construct() {
		$this->create_table_devices();
	}

	public function create_table_devices() {
		global $wpdb;

		$wpdb->hide_errors();

		$table_name = $wpdb->prefix . 'learnpress_push_notifications_devices';

		$charset_collate = '';

		if ( $wpdb->has_cap( 'collation' ) ) {
			$charset_collate = $wpdb->get_charset_collate();
		}

		// Create table save device.
		$sql = "CREATE TABLE $table_name (
			id bigint(20) NOT NULL AUTO_INCREMENT,
			user_id bigint(20) NOT NULL,
			device_token text NOT NULL,
			device_type varchar(100) NOT NULL,
			last_active datetime NOT NULL,
			PRIMARY KEY  (id),
			KEY user_id (user_id)
		) $charset_collate;";

		require_once ABSPATH . 'wp-admin/includes/upgrade.php';

		dbDelta( $sql );
	}

	public static function instance() {
		if ( is_null( self::$instance ) ) {
			self::$instance = new self();
		}

		return self::$instance;
	}
}

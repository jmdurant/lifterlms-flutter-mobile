<?php
class LP_Mobile_Push_Notifications_Database {

	private static $instance = null;

	public function create( $args ) {
		global $wpdb;

		$wpdb->insert(
			$wpdb->prefix . 'learnpress_push_notifications_devices',
			array(
				'user_id'      => $args['user_id'],
				'device_token' => $args['device_token'],
				'device_type'  => $args['device_type'],
				'last_active'  => current_time( 'mysql', true ),
			),
			array(
				'%d',
				'%s',
				'%s',
				'%s',
			)
		);

		return $wpdb->insert_id;
	}

	public function update( $args ) {
		global $wpdb;

		$update = $wpdb->update(
			$wpdb->prefix . 'learnpress_push_notifications_devices',
			array(
				'last_active' => current_time( 'mysql', true ),
			),
			array(
				'user_id'      => $args['user_id'],
				'device_token' => $args['device_token'],
			),
			array(
				'%s',
			),
			array(
				'%d',
				'%s',
			)
		);

		return $update;
	}

	public function get_by_user_id( $user_id ) {
		global $wpdb;

		$table_name = $wpdb->prefix . 'learnpress_push_notifications_devices';

		$sql = $wpdb->prepare( "SELECT * FROM $table_name WHERE user_id = %d", $user_id );

		$devices = $wpdb->get_results( $sql, ARRAY_A );

		return $devices;
	}

	public function get_devices_tokens_by_user_id( $user_id ) {
		$devices = $this->get_by_user_id( $user_id );

		if ( $devices ) {
			return wp_list_pluck( $devices, 'device_token' );
		}

		return array();
	}

	// Get device_tokens by user_ids
	public function get_device_tokens_by_user_ids( $user_ids ) {
		global $wpdb;

		$table_name = $wpdb->prefix . 'learnpress_push_notifications_devices';

		$sql = "SELECT * FROM $table_name WHERE user_id IN (" . implode( ',', $user_ids ) . ")";

		$devices = $wpdb->get_results( $sql, ARRAY_A );

		$device_tokens = array();

		if ( ! empty( $devices ) ) {
			$device_tokens = wp_list_pluck( $devices, 'device_token' );
		}

		return $device_tokens;
	}

	public function get_all_device_tokens() {
		global $wpdb;

		$table_name = $wpdb->prefix . 'learnpress_push_notifications_devices';

		$sql = "SELECT * FROM $table_name";

		$devices = $wpdb->get_results( $sql, ARRAY_A );

		$device_tokens = array();

		if ( ! empty( $devices ) ) {
			$device_tokens = wp_list_pluck( $devices, 'device_token' );
		}

		return $device_tokens;
	}

	public function add_device_token( $args ) {
		$devices = $this->get_devices_tokens_by_user_id( $args['user_id'] );

		if ( in_array( $args['device_token'], $devices ) ) {
			$this->update( $args );
		} else {
			$this->create( $args );
		}

		$this->delete_device_token();
	}

	public function delete_device_token() {
		global $wpdb;

		// Delete all device token if last_active is older than 2 month.
		$last_active = gmdate( 'Y-m-d H:i:s', strtotime( '-2 month' ) );

		$query = $wpdb->prepare( "DELETE FROM {$wpdb->prefix}learnpress_push_notifications_devices WHERE last_active < %s", $last_active );

		$wpdb->query( $query );
	}

	public function delete_device_token_by_tokens( $device_tokens ) {
		global $wpdb;

		$wpdb->query( "DELETE FROM {$wpdb->prefix}learnpress_push_notifications_devices WHERE device_token IN ('" . implode( "','", $device_tokens ) . "')" );

		return $wpdb->last_error;
	}

	public function delete_by_user_id( $user_id ) {
		global $wpdb;

		$wpdb->delete(
			$wpdb->prefix . 'learnpress_push_notifications_devices',
			array(
				'user_id' => $user_id,
			),
			array(
				'%d',
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

<?php
/**
 * CME (Continuing Medical Education) Credit Handler for LifterLMS Mobile App
 *
 * Tracks CME credits, attestations, and credit transcripts.
 */

defined( 'ABSPATH' ) || exit;

/**
 * CME handler class
 */
class LLMS_Mobile_CME_Handler {

	/**
	 * Supported credit types
	 */
	const CREDIT_TYPES = array(
		'ama_pra_1'   => 'AMA PRA Category 1',
		'ama_pra_2'   => 'AMA PRA Category 2',
		'ancc'        => 'ANCC Contact Hours',
		'acpe'        => 'ACPE Credits',
		'aafp'        => 'AAFP Prescribed Credits',
		'aapa'        => 'AAPA Category 1 CME',
		'moc'         => 'MOC Points',
		'ce'          => 'CE Credits',
		'ceu'         => 'CEU Credits',
		'custom'      => 'Custom Credits',
	);

	/**
	 * Instance
	 */
	private static $instance = null;

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
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );

		// Auto-award credits when a course is completed
		add_action( 'lifterlms_course_completed', array( $this, 'on_course_completed' ), 10, 2 );
	}

	/**
	 * Register REST API routes
	 */
	public function register_routes() {
		$namespace = 'llms/v1';

		// Get user's CME credit transcript
		register_rest_route( $namespace, '/mobile-app/cme/credits', array(
			'methods'             => 'GET',
			'callback'            => array( $this, 'get_user_credits' ),
			'permission_callback' => array( $this, 'check_permissions' ),
			'args'                => array(
				'credit_type' => array(
					'required' => false,
					'type'     => 'string',
				),
				'status' => array(
					'required' => false,
					'type'     => 'string',
					'default'  => 'all',
				),
			),
		) );

		// Get credit summary (totals by type)
		register_rest_route( $namespace, '/mobile-app/cme/summary', array(
			'methods'             => 'GET',
			'callback'            => array( $this, 'get_credit_summary' ),
			'permission_callback' => array( $this, 'check_permissions' ),
		) );

		// Submit attestation to claim credits
		register_rest_route( $namespace, '/mobile-app/cme/attest', array(
			'methods'             => 'POST',
			'callback'            => array( $this, 'submit_attestation' ),
			'permission_callback' => array( $this, 'check_permissions' ),
			'args'                => array(
				'course_id' => array(
					'required' => true,
					'type'     => 'integer',
				),
			),
		) );

		// Get CME configuration for a course
		register_rest_route( $namespace, '/mobile-app/cme/course/(?P<course_id>\d+)', array(
			'methods'             => 'GET',
			'callback'            => array( $this, 'get_course_cme_config' ),
			'permission_callback' => array( $this, 'check_permissions' ),
			'args'                => array(
				'course_id' => array(
					'required' => true,
					'type'     => 'integer',
				),
			),
		) );

		// Get supported credit types
		register_rest_route( $namespace, '/mobile-app/cme/credit-types', array(
			'methods'             => 'GET',
			'callback'            => array( $this, 'get_credit_types' ),
			'permission_callback' => '__return_true',
		) );

		// Manually add a CME credit entry
		register_rest_route( $namespace, '/mobile-app/cme/manual', array(
			'methods'             => 'POST',
			'callback'            => array( $this, 'add_manual_credit' ),
			'permission_callback' => array( $this, 'check_permissions' ),
			'args'                => array(
				'activity_title' => array(
					'required' => true,
					'type'     => 'string',
				),
				'credit_type' => array(
					'required' => true,
					'type'     => 'string',
				),
				'credit_hours' => array(
					'required' => true,
					'type'     => 'number',
				),
				'earned_date' => array(
					'required' => true,
					'type'     => 'string',
				),
				'expiration_date' => array(
					'required' => false,
					'type'     => 'string',
				),
				'provider' => array(
					'required' => false,
					'type'     => 'string',
				),
			),
		) );

		// Update a manual CME credit entry
		register_rest_route( $namespace, '/mobile-app/cme/manual/(?P<credit_id>\d+)', array(
			'methods'             => 'PUT',
			'callback'            => array( $this, 'update_manual_credit' ),
			'permission_callback' => array( $this, 'check_permissions' ),
			'args'                => array(
				'credit_id' => array(
					'required' => true,
					'type'     => 'integer',
				),
			),
		) );

		// Delete a manual CME credit entry
		register_rest_route( $namespace, '/mobile-app/cme/manual/(?P<credit_id>\d+)', array(
			'methods'             => 'DELETE',
			'callback'            => array( $this, 'delete_manual_credit' ),
			'permission_callback' => array( $this, 'check_permissions' ),
			'args'                => array(
				'credit_id' => array(
					'required' => true,
					'type'     => 'integer',
				),
			),
		) );

		// Download credit transcript as data
		register_rest_route( $namespace, '/mobile-app/cme/transcript', array(
			'methods'             => 'GET',
			'callback'            => array( $this, 'get_transcript' ),
			'permission_callback' => array( $this, 'check_permissions' ),
			'args'                => array(
				'start_date' => array(
					'required' => false,
					'type'     => 'string',
				),
				'end_date' => array(
					'required' => false,
					'type'     => 'string',
				),
			),
		) );
	}

	/**
	 * Hook: auto-award credits when course is completed (if no evaluation required)
	 */
	public function on_course_completed( $user_id, $course_id ) {
		$user_id   = absint( $user_id );
		$course_id = absint( $course_id );

		if ( ! $user_id || ! $course_id ) {
			return;
		}

		$cme_config = $this->get_course_cme_settings( $course_id );

		if ( empty( $cme_config['enabled'] ) ) {
			return;
		}

		// If evaluation is required, don't auto-award — user must complete evaluation first
		if ( ! empty( $cme_config['evaluation_required'] ) ) {
			return;
		}

		// If attestation is required, don't auto-award — user must attest first
		if ( ! empty( $cme_config['attestation_required'] ) ) {
			return;
		}

		// Auto-award credits
		$this->award_credits( $user_id, $course_id );
	}

	/**
	 * Award CME credits to a user for a course
	 */
	public function award_credits( $user_id, $course_id ) {
		global $wpdb;

		$user_id   = absint( $user_id );
		$course_id = absint( $course_id );
		$config    = $this->get_course_cme_settings( $course_id );

		if ( empty( $config['enabled'] ) || empty( $config['credit_type'] ) || empty( $config['credit_hours'] ) ) {
			return false;
		}

		$table = $wpdb->prefix . 'llms_mobile_cme_credits';

		// Check if credits already awarded for this course
		$existing = $wpdb->get_var( $wpdb->prepare(
			"SELECT COUNT(*) FROM $table WHERE user_id = %d AND course_id = %d AND status != 'revoked'",
			$user_id,
			$course_id
		) );

		if ( $existing > 0 ) {
			return false;
		}

		$expiration_months = absint( $config['expiration_months'] ?? 0 );
		$expiration_date   = null;

		if ( $expiration_months > 0 ) {
			$expiration_date = gmdate( 'Y-m-d H:i:s', strtotime( "+{$expiration_months} months" ) );
		}

		$result = $wpdb->insert(
			$table,
			array(
				'user_id'         => $user_id,
				'course_id'       => $course_id,
				'credit_type'     => sanitize_text_field( $config['credit_type'] ),
				'credit_hours'    => floatval( $config['credit_hours'] ),
				'earned_date'     => current_time( 'mysql' ),
				'expiration_date' => $expiration_date,
				'status'          => 'active',
			),
			array( '%d', '%d', '%s', '%f', '%s', '%s', '%s' )
		);

		if ( $result ) {
			// Send push notification
			llms_mobile_send_push_notification(
				$user_id,
				'CME Credits Earned',
				sprintf(
					'You earned %s %s credits for completing %s.',
					$config['credit_hours'],
					self::CREDIT_TYPES[ $config['credit_type'] ] ?? $config['credit_type'],
					get_the_title( $course_id )
				),
				array( 'type' => 'cme_credit', 'course_id' => $course_id )
			);
		}

		return $result;
	}

	/**
	 * Get user's CME credits
	 */
	public function get_user_credits( $request ) {
		global $wpdb;

		$user_id     = get_current_user_id();
		$table       = $wpdb->prefix . 'llms_mobile_cme_credits';
		$credit_type = sanitize_text_field( $request->get_param( 'credit_type' ) ?? '' );
		$status      = sanitize_text_field( $request->get_param( 'status' ) ?? 'all' );

		$where  = array( 'user_id = %d' );
		$values = array( $user_id );

		if ( ! empty( $credit_type ) ) {
			$where[]  = 'credit_type = %s';
			$values[] = $credit_type;
		}

		if ( $status !== 'all' ) {
			$where[]  = 'status = %s';
			$values[] = $status;
		}

		$where_clause = implode( ' AND ', $where );

		$credits = $wpdb->get_results( $wpdb->prepare(
			"SELECT * FROM $table WHERE $where_clause ORDER BY earned_date DESC",
			...$values
		) );

		if ( ! is_array( $credits ) ) {
			$credits = array();
		}

		// Enrich with course/activity data
		$result = array();
		foreach ( $credits as $credit ) {
			$source = isset( $credit->source ) ? $credit->source : 'course';
			$title  = '';

			if ( $source === 'manual' ) {
				$title = isset( $credit->activity_title ) ? $credit->activity_title : '';
			} else {
				$course_id = absint( $credit->course_id );
				$title = $course_id > 0 ? get_the_title( $course_id ) : '';
			}

			$result[] = array(
				'id'              => absint( $credit->id ),
				'course_id'       => absint( $credit->course_id ),
				'course_title'    => $title,
				'activity_title'  => isset( $credit->activity_title ) ? $credit->activity_title : '',
				'provider'        => isset( $credit->provider ) ? $credit->provider : '',
				'source'          => $source,
				'credit_type'     => $credit->credit_type,
				'credit_type_label' => self::CREDIT_TYPES[ $credit->credit_type ] ?? $credit->credit_type,
				'credit_hours'    => floatval( $credit->credit_hours ),
				'earned_date'     => $credit->earned_date,
				'expiration_date' => $credit->expiration_date,
				'status'          => $this->calculate_credit_status( $credit ),
			);
		}

		return $result;
	}

	/**
	 * Get credit summary (totals by type)
	 */
	public function get_credit_summary( $request ) {
		global $wpdb;

		$user_id = get_current_user_id();
		$table   = $wpdb->prefix . 'llms_mobile_cme_credits';

		$results = $wpdb->get_results( $wpdb->prepare(
			"SELECT credit_type,
					SUM(credit_hours) as total_hours,
					COUNT(*) as total_activities,
					MIN(earned_date) as first_earned,
					MAX(earned_date) as last_earned
			 FROM $table
			 WHERE user_id = %d AND status = 'active'
			 GROUP BY credit_type",
			$user_id
		) );

		if ( ! is_array( $results ) ) {
			$results = array();
		}

		// Check for expired credits
		$this->update_expired_credits( $user_id );

		$summary = array();
		foreach ( $results as $row ) {
			$summary[] = array(
				'credit_type'       => $row->credit_type,
				'credit_type_label' => self::CREDIT_TYPES[ $row->credit_type ] ?? $row->credit_type,
				'total_hours'       => floatval( $row->total_hours ),
				'total_activities'  => absint( $row->total_activities ),
				'first_earned'      => $row->first_earned,
				'last_earned'       => $row->last_earned,
			);
		}

		// Also include expired totals
		$expired = $wpdb->get_results( $wpdb->prepare(
			"SELECT credit_type, SUM(credit_hours) as total_hours
			 FROM $table
			 WHERE user_id = %d AND status = 'expired'
			 GROUP BY credit_type",
			$user_id
		) );

		$expired_map = array();
		if ( is_array( $expired ) ) {
			foreach ( $expired as $row ) {
				$expired_map[ $row->credit_type ] = floatval( $row->total_hours );
			}
		}

		return array(
			'active_credits'  => $summary,
			'expired_credits' => $expired_map,
			'total_active_hours' => array_sum( array_column( $summary, 'total_hours' ) ),
		);
	}

	/**
	 * Submit attestation and claim credits
	 */
	public function submit_attestation( $request ) {
		global $wpdb;

		$user_id   = get_current_user_id();
		$course_id = absint( $request->get_param( 'course_id' ) );

		if ( ! $course_id ) {
			return new WP_Error( 'invalid_course', 'Invalid course ID.', array( 'status' => 400 ) );
		}

		// Verify the user completed the course
		if ( ! llms_is_complete( $user_id, $course_id, 'course' ) ) {
			return new WP_Error( 'course_not_completed', 'You must complete the course before claiming credits.', array( 'status' => 400 ) );
		}

		$config = $this->get_course_cme_settings( $course_id );

		if ( empty( $config['enabled'] ) ) {
			return new WP_Error( 'cme_not_enabled', 'CME credits are not available for this course.', array( 'status' => 400 ) );
		}

		// Check if evaluation is required and completed
		if ( ! empty( $config['evaluation_required'] ) ) {
			$eval_table = $wpdb->prefix . 'llms_mobile_cme_evaluations';
			$eval_exists = $wpdb->get_var( $wpdb->prepare(
				"SELECT COUNT(*) FROM $eval_table WHERE user_id = %d AND course_id = %d",
				$user_id,
				$course_id
			) );

			if ( ! $eval_exists ) {
				return new WP_Error( 'evaluation_required', 'You must complete the post-activity evaluation before claiming credits.', array( 'status' => 400 ) );
			}
		}

		// Check if already attested
		$attest_table = $wpdb->prefix . 'llms_mobile_cme_attestations';
		$already_attested = $wpdb->get_var( $wpdb->prepare(
			"SELECT COUNT(*) FROM $attest_table WHERE user_id = %d AND course_id = %d",
			$user_id,
			$course_id
		) );

		if ( $already_attested > 0 ) {
			return new WP_Error( 'already_attested', 'You have already claimed credits for this course.', array( 'status' => 400 ) );
		}

		// Record attestation
		$attestation_text = sanitize_text_field( $config['attestation_text'] ?? '' );
		if ( empty( $attestation_text ) ) {
			$attestation_text = 'I attest that I have completed this educational activity and claim the designated credits.';
		}

		$wpdb->insert(
			$attest_table,
			array(
				'user_id'          => $user_id,
				'course_id'        => $course_id,
				'attestation_text' => $attestation_text,
				'credit_type'      => sanitize_text_field( $config['credit_type'] ),
				'credit_hours'     => floatval( $config['credit_hours'] ),
				'signed_date'      => current_time( 'mysql' ),
			),
			array( '%d', '%d', '%s', '%s', '%f', '%s' )
		);

		// Award credits
		$awarded = $this->award_credits( $user_id, $course_id );

		if ( ! $awarded ) {
			return new WP_Error( 'award_failed', 'Credits may have already been awarded.', array( 'status' => 400 ) );
		}

		return array(
			'status'       => 'success',
			'message'      => 'Credits claimed successfully.',
			'credit_type'  => $config['credit_type'],
			'credit_hours' => floatval( $config['credit_hours'] ),
		);
	}

	/**
	 * Get CME configuration for a course
	 */
	public function get_course_cme_config( $request ) {
		$course_id = absint( $request->get_param( 'course_id' ) );

		if ( ! $course_id ) {
			return new WP_Error( 'invalid_course', 'Invalid course ID.', array( 'status' => 400 ) );
		}

		$config = $this->get_course_cme_settings( $course_id );
		$user_id = get_current_user_id();

		// Check user's status for this course
		$has_attested = false;
		$has_evaluated = false;
		$credits_awarded = false;

		if ( $user_id ) {
			global $wpdb;

			$attest_table = $wpdb->prefix . 'llms_mobile_cme_attestations';
			$has_attested = (bool) $wpdb->get_var( $wpdb->prepare(
				"SELECT COUNT(*) FROM $attest_table WHERE user_id = %d AND course_id = %d",
				$user_id,
				$course_id
			) );

			$eval_table = $wpdb->prefix . 'llms_mobile_cme_evaluations';
			$has_evaluated = (bool) $wpdb->get_var( $wpdb->prepare(
				"SELECT COUNT(*) FROM $eval_table WHERE user_id = %d AND course_id = %d",
				$user_id,
				$course_id
			) );

			$credit_table = $wpdb->prefix . 'llms_mobile_cme_credits';
			$credits_awarded = (bool) $wpdb->get_var( $wpdb->prepare(
				"SELECT COUNT(*) FROM $credit_table WHERE user_id = %d AND course_id = %d AND status != 'revoked'",
				$user_id,
				$course_id
			) );
		}

		return array(
			'enabled'               => ! empty( $config['enabled'] ),
			'credit_type'           => $config['credit_type'] ?? '',
			'credit_type_label'     => self::CREDIT_TYPES[ $config['credit_type'] ?? '' ] ?? '',
			'credit_hours'          => floatval( $config['credit_hours'] ?? 0 ),
			'expiration_months'     => absint( $config['expiration_months'] ?? 0 ),
			'attestation_required'  => ! empty( $config['attestation_required'] ),
			'attestation_text'      => $config['attestation_text'] ?? '',
			'evaluation_required'   => ! empty( $config['evaluation_required'] ),
			'disclosure_text'       => $config['disclosure_text'] ?? '',
			'user_status'           => array(
				'has_attested'    => $has_attested,
				'has_evaluated'   => $has_evaluated,
				'credits_awarded' => $credits_awarded,
			),
		);
	}

	/**
	 * Get supported credit types
	 */
	public function get_credit_types( $request ) {
		$types = array();
		foreach ( self::CREDIT_TYPES as $key => $label ) {
			$types[] = array(
				'id'    => $key,
				'label' => $label,
			);
		}
		return $types;
	}

	/**
	 * Get transcript data
	 */
	public function get_transcript( $request ) {
		global $wpdb;

		$user_id    = get_current_user_id();
		$table      = $wpdb->prefix . 'llms_mobile_cme_credits';
		$start_date = sanitize_text_field( $request->get_param( 'start_date' ) ?? '' );
		$end_date   = sanitize_text_field( $request->get_param( 'end_date' ) ?? '' );

		$where  = array( 'c.user_id = %d' );
		$values = array( $user_id );

		if ( ! empty( $start_date ) ) {
			$where[]  = 'c.earned_date >= %s';
			$values[] = $start_date;
		}

		if ( ! empty( $end_date ) ) {
			$where[]  = 'c.earned_date <= %s';
			$values[] = $end_date;
		}

		$where_clause = implode( ' AND ', $where );

		$credits = $wpdb->get_results( $wpdb->prepare(
			"SELECT c.*, a.attestation_text, a.signed_date as attestation_date
			 FROM $table c
			 LEFT JOIN {$wpdb->prefix}llms_mobile_cme_attestations a
			   ON c.user_id = a.user_id AND c.course_id = a.course_id
			 WHERE $where_clause
			 ORDER BY c.earned_date DESC",
			...$values
		) );

		if ( ! is_array( $credits ) ) {
			$credits = array();
		}

		$user = get_userdata( $user_id );

		$transcript_items = array();
		foreach ( $credits as $credit ) {
			$transcript_items[] = array(
				'course_title'       => get_the_title( $credit->course_id ),
				'credit_type'        => $credit->credit_type,
				'credit_type_label'  => self::CREDIT_TYPES[ $credit->credit_type ] ?? $credit->credit_type,
				'credit_hours'       => floatval( $credit->credit_hours ),
				'earned_date'        => $credit->earned_date,
				'expiration_date'    => $credit->expiration_date,
				'status'             => $this->calculate_credit_status( $credit ),
				'attestation_date'   => $credit->attestation_date,
			);
		}

		return array(
			'user' => array(
				'name'  => $user ? $user->display_name : '',
				'email' => $user ? $user->user_email : '',
			),
			'generated_date' => current_time( 'mysql' ),
			'date_range'     => array(
				'start' => $start_date ?: null,
				'end'   => $end_date ?: null,
			),
			'credits'        => $transcript_items,
			'totals'         => $this->calculate_transcript_totals( $credits ),
		);
	}

	/**
	 * Add a manual CME credit entry
	 */
	public function add_manual_credit( $request ) {
		global $wpdb;

		$user_id        = get_current_user_id();
		$activity_title = sanitize_text_field( $request->get_param( 'activity_title' ) );
		$credit_type    = sanitize_text_field( $request->get_param( 'credit_type' ) );
		$credit_hours   = floatval( $request->get_param( 'credit_hours' ) );
		$earned_date    = sanitize_text_field( $request->get_param( 'earned_date' ) );
		$expiration_date = sanitize_text_field( $request->get_param( 'expiration_date' ) ?? '' );
		$provider       = sanitize_text_field( $request->get_param( 'provider' ) ?? '' );

		if ( empty( $activity_title ) ) {
			return new WP_Error( 'missing_title', 'Activity title is required.', array( 'status' => 400 ) );
		}

		if ( ! isset( self::CREDIT_TYPES[ $credit_type ] ) ) {
			return new WP_Error( 'invalid_credit_type', 'Invalid credit type.', array( 'status' => 400 ) );
		}

		if ( $credit_hours <= 0 || $credit_hours > 999 ) {
			return new WP_Error( 'invalid_hours', 'Credit hours must be between 0 and 999.', array( 'status' => 400 ) );
		}

		// Validate date format
		$parsed_date = strtotime( $earned_date );
		if ( ! $parsed_date ) {
			return new WP_Error( 'invalid_date', 'Invalid earned date.', array( 'status' => 400 ) );
		}
		$earned_date = gmdate( 'Y-m-d H:i:s', $parsed_date );

		$parsed_expiration = null;
		if ( ! empty( $expiration_date ) ) {
			$parsed_expiration = strtotime( $expiration_date );
			if ( ! $parsed_expiration ) {
				return new WP_Error( 'invalid_date', 'Invalid expiration date.', array( 'status' => 400 ) );
			}
			$parsed_expiration = gmdate( 'Y-m-d H:i:s', $parsed_expiration );
		}

		$table = $wpdb->prefix . 'llms_mobile_cme_credits';

		$result = $wpdb->insert(
			$table,
			array(
				'user_id'         => $user_id,
				'course_id'       => 0,
				'credit_type'     => $credit_type,
				'credit_hours'    => $credit_hours,
				'earned_date'     => $earned_date,
				'expiration_date' => $parsed_expiration,
				'status'          => 'active',
				'source'          => 'manual',
				'activity_title'  => $activity_title,
				'provider'        => $provider,
			),
			array( '%d', '%d', '%s', '%f', '%s', '%s', '%s', '%s', '%s', '%s' )
		);

		if ( ! $result ) {
			return new WP_Error( 'insert_failed', 'Failed to save credit entry.', array( 'status' => 500 ) );
		}

		return array(
			'status'  => 'success',
			'message' => 'Credit entry added.',
			'id'      => $wpdb->insert_id,
		);
	}

	/**
	 * Update a manual CME credit entry
	 */
	public function update_manual_credit( $request ) {
		global $wpdb;

		$user_id   = get_current_user_id();
		$credit_id = absint( $request->get_param( 'credit_id' ) );
		$table     = $wpdb->prefix . 'llms_mobile_cme_credits';

		// Verify ownership and that it's a manual entry
		$existing = $wpdb->get_row( $wpdb->prepare(
			"SELECT * FROM $table WHERE id = %d AND user_id = %d",
			$credit_id,
			$user_id
		) );

		if ( ! $existing ) {
			return new WP_Error( 'not_found', 'Credit entry not found.', array( 'status' => 404 ) );
		}

		if ( ( $existing->source ?? 'course' ) !== 'manual' ) {
			return new WP_Error( 'not_manual', 'Only manual entries can be edited.', array( 'status' => 400 ) );
		}

		$updates = array();
		$formats = array();

		$activity_title = $request->get_param( 'activity_title' );
		if ( $activity_title !== null ) {
			$updates['activity_title'] = sanitize_text_field( $activity_title );
			$formats[] = '%s';
		}

		$credit_type = $request->get_param( 'credit_type' );
		if ( $credit_type !== null ) {
			$credit_type = sanitize_text_field( $credit_type );
			if ( ! isset( self::CREDIT_TYPES[ $credit_type ] ) ) {
				return new WP_Error( 'invalid_credit_type', 'Invalid credit type.', array( 'status' => 400 ) );
			}
			$updates['credit_type'] = $credit_type;
			$formats[] = '%s';
		}

		$credit_hours = $request->get_param( 'credit_hours' );
		if ( $credit_hours !== null ) {
			$credit_hours = floatval( $credit_hours );
			if ( $credit_hours <= 0 || $credit_hours > 999 ) {
				return new WP_Error( 'invalid_hours', 'Credit hours must be between 0 and 999.', array( 'status' => 400 ) );
			}
			$updates['credit_hours'] = $credit_hours;
			$formats[] = '%f';
		}

		$earned_date = $request->get_param( 'earned_date' );
		if ( $earned_date !== null ) {
			$parsed = strtotime( sanitize_text_field( $earned_date ) );
			if ( ! $parsed ) {
				return new WP_Error( 'invalid_date', 'Invalid earned date.', array( 'status' => 400 ) );
			}
			$updates['earned_date'] = gmdate( 'Y-m-d H:i:s', $parsed );
			$formats[] = '%s';
		}

		$expiration_date = $request->get_param( 'expiration_date' );
		if ( $expiration_date !== null ) {
			if ( empty( $expiration_date ) ) {
				$updates['expiration_date'] = null;
				$formats[] = '%s';
			} else {
				$parsed = strtotime( sanitize_text_field( $expiration_date ) );
				if ( ! $parsed ) {
					return new WP_Error( 'invalid_date', 'Invalid expiration date.', array( 'status' => 400 ) );
				}
				$updates['expiration_date'] = gmdate( 'Y-m-d H:i:s', $parsed );
				$formats[] = '%s';
			}
		}

		$provider = $request->get_param( 'provider' );
		if ( $provider !== null ) {
			$updates['provider'] = sanitize_text_field( $provider );
			$formats[] = '%s';
		}

		if ( empty( $updates ) ) {
			return new WP_Error( 'no_changes', 'No fields to update.', array( 'status' => 400 ) );
		}

		$wpdb->update( $table, $updates, array( 'id' => $credit_id ), $formats, array( '%d' ) );

		return array(
			'status'  => 'success',
			'message' => 'Credit entry updated.',
		);
	}

	/**
	 * Delete a manual CME credit entry
	 */
	public function delete_manual_credit( $request ) {
		global $wpdb;

		$user_id   = get_current_user_id();
		$credit_id = absint( $request->get_param( 'credit_id' ) );
		$table     = $wpdb->prefix . 'llms_mobile_cme_credits';

		// Verify ownership and that it's a manual entry
		$existing = $wpdb->get_row( $wpdb->prepare(
			"SELECT * FROM $table WHERE id = %d AND user_id = %d",
			$credit_id,
			$user_id
		) );

		if ( ! $existing ) {
			return new WP_Error( 'not_found', 'Credit entry not found.', array( 'status' => 404 ) );
		}

		if ( ( $existing->source ?? 'course' ) !== 'manual' ) {
			return new WP_Error( 'not_manual', 'Only manual entries can be deleted.', array( 'status' => 400 ) );
		}

		$wpdb->delete( $table, array( 'id' => $credit_id ), array( '%d' ) );

		return array(
			'status'  => 'success',
			'message' => 'Credit entry deleted.',
		);
	}

	/**
	 * Get CME settings for a course (stored as post meta)
	 */
	private function get_course_cme_settings( $course_id ) {
		return array(
			'enabled'              => get_post_meta( $course_id, '_llms_cme_enabled', true ) === 'yes',
			'credit_type'          => get_post_meta( $course_id, '_llms_cme_credit_type', true ),
			'credit_hours'         => get_post_meta( $course_id, '_llms_cme_credit_hours', true ),
			'expiration_months'    => get_post_meta( $course_id, '_llms_cme_expiration_months', true ),
			'attestation_required' => get_post_meta( $course_id, '_llms_cme_attestation_required', true ) === 'yes',
			'attestation_text'     => get_post_meta( $course_id, '_llms_cme_attestation_text', true ),
			'evaluation_required'  => get_post_meta( $course_id, '_llms_cme_evaluation_required', true ) === 'yes',
			'disclosure_text'      => get_post_meta( $course_id, '_llms_cme_disclosure_text', true ),
		);
	}

	/**
	 * Calculate effective credit status (checks expiration)
	 */
	private function calculate_credit_status( $credit ) {
		if ( $credit->status === 'revoked' ) {
			return 'revoked';
		}

		if ( ! empty( $credit->expiration_date ) && strtotime( $credit->expiration_date ) < time() ) {
			return 'expired';
		}

		return 'active';
	}

	/**
	 * Update expired credits in bulk
	 */
	private function update_expired_credits( $user_id ) {
		global $wpdb;

		$table = $wpdb->prefix . 'llms_mobile_cme_credits';

		$wpdb->query( $wpdb->prepare(
			"UPDATE $table SET status = 'expired'
			 WHERE user_id = %d AND status = 'active' AND expiration_date IS NOT NULL AND expiration_date < %s",
			absint( $user_id ),
			current_time( 'mysql' )
		) );
	}

	/**
	 * Calculate transcript totals grouped by credit type
	 */
	private function calculate_transcript_totals( $credits ) {
		$totals = array();

		foreach ( $credits as $credit ) {
			$type = $credit->credit_type;
			if ( ! isset( $totals[ $type ] ) ) {
				$totals[ $type ] = array(
					'credit_type'       => $type,
					'credit_type_label' => self::CREDIT_TYPES[ $type ] ?? $type,
					'total_hours'       => 0,
					'active_hours'      => 0,
					'expired_hours'     => 0,
				);
			}

			$hours  = floatval( $credit->credit_hours );
			$status = $this->calculate_credit_status( $credit );

			$totals[ $type ]['total_hours'] += $hours;

			if ( $status === 'active' ) {
				$totals[ $type ]['active_hours'] += $hours;
			} else {
				$totals[ $type ]['expired_hours'] += $hours;
			}
		}

		return array_values( $totals );
	}

	/**
	 * Permission callback
	 */
	public function check_permissions() {
		return is_user_logged_in();
	}
}

// Initialize
LLMS_Mobile_CME_Handler::instance();

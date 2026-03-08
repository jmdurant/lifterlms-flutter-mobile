<?php
/**
 * CME Post-Activity Evaluations for LifterLMS Mobile App
 *
 * Manages post-activity surveys that are required before CME credits are awarded.
 * Evaluation questions are configured per-course via post meta.
 */

defined( 'ABSPATH' ) || exit;

/**
 * CME Evaluations class
 */
class LLMS_Mobile_CME_Evaluations {

	/**
	 * Supported question types for evaluations
	 */
	const QUESTION_TYPES = array( 'rating', 'text', 'yes_no', 'multiple_choice' );

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
	}

	/**
	 * Register REST API routes
	 */
	public function register_routes() {
		$namespace = 'llms/v1';

		// Get evaluation questions for a course
		register_rest_route( $namespace, '/mobile-app/cme/evaluation/(?P<course_id>\d+)', array(
			'methods'             => 'GET',
			'callback'            => array( $this, 'get_evaluation_questions' ),
			'permission_callback' => array( $this, 'check_permissions' ),
			'args'                => array(
				'course_id' => array(
					'required' => true,
					'type'     => 'integer',
				),
			),
		) );

		// Submit evaluation responses
		register_rest_route( $namespace, '/mobile-app/cme/evaluation/(?P<course_id>\d+)', array(
			'methods'             => 'POST',
			'callback'            => array( $this, 'submit_evaluation' ),
			'permission_callback' => array( $this, 'check_permissions' ),
			'args'                => array(
				'course_id' => array(
					'required' => true,
					'type'     => 'integer',
				),
				'responses' => array(
					'required' => true,
					'type'     => 'array',
				),
			),
		) );

		// Check if user has completed evaluation
		register_rest_route( $namespace, '/mobile-app/cme/evaluation/(?P<course_id>\d+)/status', array(
			'methods'             => 'GET',
			'callback'            => array( $this, 'get_evaluation_status' ),
			'permission_callback' => array( $this, 'check_permissions' ),
			'args'                => array(
				'course_id' => array(
					'required' => true,
					'type'     => 'integer',
				),
			),
		) );
	}

	/**
	 * Get evaluation questions for a course
	 */
	public function get_evaluation_questions( $request ) {
		$course_id = absint( $request->get_param( 'course_id' ) );

		if ( ! $course_id ) {
			return new WP_Error( 'invalid_course', 'Invalid course ID.', array( 'status' => 400 ) );
		}

		$questions = $this->get_course_evaluation_questions( $course_id );

		if ( empty( $questions ) ) {
			// Return default evaluation questions if none configured
			$questions = $this->get_default_questions();
		}

		$disclosure = get_post_meta( $course_id, '_llms_cme_disclosure_text', true );

		return array(
			'course_id'       => $course_id,
			'course_title'    => get_the_title( $course_id ),
			'disclosure_text' => sanitize_text_field( $disclosure ),
			'questions'       => $questions,
		);
	}

	/**
	 * Submit evaluation responses
	 */
	public function submit_evaluation( $request ) {
		global $wpdb;

		$user_id   = get_current_user_id();
		$course_id = absint( $request->get_param( 'course_id' ) );
		$responses = $request->get_param( 'responses' );

		if ( ! $course_id ) {
			return new WP_Error( 'invalid_course', 'Invalid course ID.', array( 'status' => 400 ) );
		}

		// Verify course is completed
		if ( ! llms_is_complete( $user_id, $course_id, 'course' ) ) {
			return new WP_Error( 'course_not_completed', 'You must complete the course before submitting an evaluation.', array( 'status' => 400 ) );
		}

		// Check for existing evaluation
		$table = $wpdb->prefix . 'llms_mobile_cme_evaluations';
		$existing = $wpdb->get_var( $wpdb->prepare(
			"SELECT COUNT(*) FROM $table WHERE user_id = %d AND course_id = %d",
			$user_id,
			$course_id
		) );

		if ( $existing > 0 ) {
			return new WP_Error( 'already_evaluated', 'You have already submitted an evaluation for this course.', array( 'status' => 400 ) );
		}

		// Validate responses
		if ( ! is_array( $responses ) || empty( $responses ) ) {
			return new WP_Error( 'invalid_responses', 'Evaluation responses are required.', array( 'status' => 400 ) );
		}

		$questions = $this->get_course_evaluation_questions( $course_id );
		if ( empty( $questions ) ) {
			$questions = $this->get_default_questions();
		}

		// Validate that all required questions are answered
		$required_ids = array();
		foreach ( $questions as $q ) {
			if ( ! empty( $q['required'] ) ) {
				$required_ids[] = $q['id'];
			}
		}

		$answered_ids = array_column( $responses, 'question_id' );
		$missing = array_diff( $required_ids, $answered_ids );

		if ( ! empty( $missing ) ) {
			return new WP_Error(
				'missing_responses',
				'Please answer all required questions.',
				array( 'status' => 400, 'missing_question_ids' => array_values( $missing ) )
			);
		}

		// Sanitize responses
		$sanitized_responses = array();
		foreach ( $responses as $response ) {
			$sanitized_responses[] = array(
				'question_id' => sanitize_text_field( $response['question_id'] ?? '' ),
				'answer'      => sanitize_text_field( $response['answer'] ?? '' ),
			);
		}

		// Store evaluation
		$result = $wpdb->insert(
			$table,
			array(
				'user_id'      => $user_id,
				'course_id'    => $course_id,
				'responses'    => wp_json_encode( $sanitized_responses ),
				'submitted_at' => current_time( 'mysql' ),
			),
			array( '%d', '%d', '%s', '%s' )
		);

		if ( ! $result ) {
			return new WP_Error( 'save_failed', 'Failed to save evaluation.', array( 'status' => 500 ) );
		}

		return array(
			'status'  => 'success',
			'message' => 'Evaluation submitted successfully.',
		);
	}

	/**
	 * Get evaluation completion status
	 */
	public function get_evaluation_status( $request ) {
		global $wpdb;

		$user_id   = get_current_user_id();
		$course_id = absint( $request->get_param( 'course_id' ) );

		if ( ! $course_id ) {
			return new WP_Error( 'invalid_course', 'Invalid course ID.', array( 'status' => 400 ) );
		}

		$table = $wpdb->prefix . 'llms_mobile_cme_evaluations';
		$evaluation = $wpdb->get_row( $wpdb->prepare(
			"SELECT submitted_at FROM $table WHERE user_id = %d AND course_id = %d",
			$user_id,
			$course_id
		) );

		return array(
			'completed'    => ! empty( $evaluation ),
			'submitted_at' => $evaluation ? $evaluation->submitted_at : null,
		);
	}

	/**
	 * Get evaluation questions configured for a course
	 */
	private function get_course_evaluation_questions( $course_id ) {
		$questions_json = get_post_meta( $course_id, '_llms_cme_evaluation_questions', true );

		if ( empty( $questions_json ) ) {
			return array();
		}

		$questions = json_decode( $questions_json, true );

		if ( ! is_array( $questions ) ) {
			return array();
		}

		// Validate and sanitize each question
		$valid = array();
		foreach ( $questions as $q ) {
			if ( empty( $q['id'] ) || empty( $q['text'] ) || empty( $q['type'] ) ) {
				continue;
			}

			if ( ! in_array( $q['type'], self::QUESTION_TYPES, true ) ) {
				continue;
			}

			$valid[] = array(
				'id'       => sanitize_text_field( $q['id'] ),
				'text'     => sanitize_text_field( $q['text'] ),
				'type'     => $q['type'],
				'required' => ! empty( $q['required'] ),
				'options'  => isset( $q['options'] ) && is_array( $q['options'] )
					? array_map( 'sanitize_text_field', $q['options'] )
					: array(),
			);
		}

		return $valid;
	}

	/**
	 * Default evaluation questions (ACCME standard)
	 */
	private function get_default_questions() {
		return array(
			array(
				'id'       => 'relevance',
				'text'     => 'The content of this activity was relevant to my practice.',
				'type'     => 'rating',
				'required' => true,
				'options'  => array( '1', '2', '3', '4', '5' ),
			),
			array(
				'id'       => 'objectives_met',
				'text'     => 'The learning objectives were met.',
				'type'     => 'rating',
				'required' => true,
				'options'  => array( '1', '2', '3', '4', '5' ),
			),
			array(
				'id'       => 'bias_free',
				'text'     => 'The activity was free of commercial bias.',
				'type'     => 'yes_no',
				'required' => true,
				'options'  => array(),
			),
			array(
				'id'       => 'practice_change',
				'text'     => 'As a result of this activity, I plan to change my practice.',
				'type'     => 'yes_no',
				'required' => true,
				'options'  => array(),
			),
			array(
				'id'       => 'practice_change_detail',
				'text'     => 'If yes, please describe what changes you plan to make.',
				'type'     => 'text',
				'required' => false,
				'options'  => array(),
			),
			array(
				'id'       => 'barriers',
				'text'     => 'What barriers, if any, do you perceive in implementing these changes?',
				'type'     => 'multiple_choice',
				'required' => false,
				'options'  => array(
					'No barriers',
					'Cost',
					'Lack of time',
					'Lack of resources',
					'Patient compliance',
					'Insurance/reimbursement issues',
					'Other',
				),
			),
			array(
				'id'       => 'comments',
				'text'     => 'Additional comments or suggestions for future activities.',
				'type'     => 'text',
				'required' => false,
				'options'  => array(),
			),
		);
	}

	/**
	 * Permission callback
	 */
	public function check_permissions() {
		return is_user_logged_in();
	}
}

// Initialize
LLMS_Mobile_CME_Evaluations::instance();

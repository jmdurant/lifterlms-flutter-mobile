<?php
/**
 * Quiz Handler for LifterLMS Mobile App
 * 
 * Provides full quiz functionality using LifterLMS core classes
 */

defined( 'ABSPATH' ) || exit;

/**
 * Quiz handler class
 */
class LLMS_Mobile_Quiz_Handler {
    
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
        // Register REST API routes
        add_action( 'rest_api_init', array( $this, 'register_routes' ) );
    }
    
    /**
     * Register REST API routes
     */
    public function register_routes() {
        $namespace = 'llms/v1';
        
        // Get quiz data
        register_rest_route( $namespace, '/mobile-app/quiz/(?P<quiz_id>\d+)', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_quiz' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'quiz_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
            ),
        ) );
        
        // Get quiz questions
        register_rest_route( $namespace, '/mobile-app/quiz/(?P<quiz_id>\d+)/questions', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_quiz_questions' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'quiz_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
            ),
        ) );
        
        // Start quiz attempt
        register_rest_route( $namespace, '/mobile-app/quiz/(?P<quiz_id>\d+)/start', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'start_quiz_attempt' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'quiz_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
                'lesson_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
            ),
        ) );
        
        // Submit answer
        register_rest_route( $namespace, '/mobile-app/quiz/attempt/(?P<attempt_id>\d+)/answer', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'submit_answer' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'attempt_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
                'question_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
                'answer' => array(
                    'required' => true,
                    'type'     => 'string',
                ),
            ),
        ) );
        
        // Submit all answers and complete quiz in one call
        register_rest_route( $namespace, '/mobile-app/quiz/attempt/(?P<attempt_id>\d+)/submit-all', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'submit_all_answers' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'attempt_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
                'answers' => array(
                    'required' => true,
                    'type'     => 'object',
                ),
            ),
        ) );
        
        // Complete quiz attempt
        register_rest_route( $namespace, '/mobile-app/quiz/attempt/(?P<attempt_id>\d+)/complete', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'complete_quiz_attempt' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'attempt_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
            ),
        ) );
        
        // Get quiz results
        register_rest_route( $namespace, '/mobile-app/quiz/attempt/(?P<attempt_id>\d+)/results', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_quiz_results' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'attempt_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
            ),
        ) );
        
        // Get user's quiz attempts
        register_rest_route( $namespace, '/mobile-app/quiz/(?P<quiz_id>\d+)/attempts', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_user_attempts' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'quiz_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
            ),
        ) );
        
        // Resume quiz attempt
        register_rest_route( $namespace, '/mobile-app/quiz/attempt/(?P<attempt_id>\d+)/resume', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'resume_quiz_attempt' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'attempt_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
            ),
        ) );
        
        // Reset quiz attempts (for testing/development)
        register_rest_route( $namespace, '/mobile-app/quiz/(?P<quiz_id>\d+)/reset', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'reset_quiz_attempts' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'quiz_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
            ),
        ) );
    }
    
    /**
     * Get quiz data
     */
    public function get_quiz( $request ) {
        $quiz_id = $request->get_param( 'quiz_id' );
        
        // Get quiz object using LifterLMS
        $quiz = llms_get_post( $quiz_id );
        
        if ( ! $quiz || ! is_a( $quiz, 'LLMS_Quiz' ) ) {
            return new WP_Error( 'quiz_not_found', 'Quiz not found', array( 'status' => 404 ) );
        }
        
        // Get quiz data
        $quiz_data = array(
            'id' => $quiz->get( 'id' ),
            'title' => $quiz->get( 'title' ),
            'content' => $quiz->get( 'content' ),
            'lesson_id' => $quiz->get( 'lesson_id' ),
            'course_id' => $quiz->get_course()->get( 'id' ),
            'passing_grade' => $quiz->get( 'passing_grade' ),
            'time_limit' => $quiz->get( 'time_limit' ),
            'allowed_attempts' => $quiz->get( 'allowed_attempts' ),
            'question_count' => count( $quiz->get_questions( 'ids' ) ),
            'randomize_questions' => $quiz->get( 'random_questions' ) === 'yes',
            'show_correct_answers' => $quiz->get( 'show_correct_answer' ) === 'yes',
            'points' => $quiz->get( 'points' ),
        );
        
        // Check if user can take quiz
        $user_id = get_current_user_id();
        $student = llms_get_student( $user_id );
        
        $quiz_data['can_take'] = true;
        $quiz_data['remaining_attempts'] = null;
        
        // Check enrollment
        if ( ! $student->is_enrolled( $quiz_data['course_id'] ) ) {
            $quiz_data['can_take'] = false;
            $quiz_data['reason'] = 'Not enrolled in course';
        }
        
        // Get all attempts for this quiz
        $all_attempts = $student->quizzes()->get_attempts_by_quiz( $quiz_id );
        $quiz_data['attempts_taken'] = count( $all_attempts );
        
        // Check for in-progress attempts
        $in_progress_attempts = array();
        foreach ( $all_attempts as $attempt ) {
            if ( $attempt->get( 'status' ) === 'in-progress' ) {
                $in_progress_attempts[] = array(
                    'id' => $attempt->get( 'attempt_id' ),
                    'attempt_key' => $attempt->get( 'attempt_key' ),
                    'start_date' => $attempt->get( 'start_date' ),
                );
            }
        }
        
        $quiz_data['in_progress_attempts'] = $in_progress_attempts;
        $quiz_data['has_in_progress_attempt'] = count( $in_progress_attempts ) > 0;
        
        // Check attempts limit
        if ( $quiz->get( 'allowed_attempts' ) > 0 ) {
            $quiz_data['remaining_attempts'] = $quiz->get( 'allowed_attempts' ) - count( $all_attempts );
            
            if ( $quiz_data['remaining_attempts'] <= 0 && !$quiz_data['has_in_progress_attempt'] ) {
                $quiz_data['can_take'] = false;
                $quiz_data['reason'] = 'No attempts remaining';
            }
        }
        
        // Get best attempt score if available
        $best_grade = 0;
        foreach ( $all_attempts as $attempt ) {
            if ( $attempt->get( 'status' ) === 'complete' ) {
                $grade = $attempt->get( 'grade' );
                if ( $grade > $best_grade ) {
                    $best_grade = $grade;
                }
            }
        }
        $quiz_data['best_grade'] = $best_grade;
        
        return array(
            'success' => true,
            'quiz' => $quiz_data,
        );
    }
    
    /**
     * Get quiz questions
     */
    public function get_quiz_questions( $request ) {
        $quiz_id = $request->get_param( 'quiz_id' );
        
        $quiz = llms_get_post( $quiz_id );
        
        if ( ! $quiz || ! is_a( $quiz, 'LLMS_Quiz' ) ) {
            return new WP_Error( 'quiz_not_found', 'Quiz not found', array( 'status' => 404 ) );
        }
        
        // Get question IDs
        $question_ids = $quiz->get_questions( 'ids' );
        
        // Randomize if needed
        if ( $quiz->get( 'random_questions' ) === 'yes' ) {
            shuffle( $question_ids );
        }
        
        // Format questions for mobile
        $questions = array();
        foreach ( $question_ids as $qid ) {
            $question = llms_get_post( $qid );
            
            if ( ! $question ) {
                continue;
            }
            
            $question_data = array(
                'id' => $qid,
                'title' => $question->get( 'title' ),
                'content' => $question->get( 'content' ),
                'type' => $question->get( 'question_type' ),
                'points' => $question->get( 'points' ),
                'multi_choices' => $question->get( 'multi_choices' ) === 'yes',
                'clarifications' => $question->get( 'clarifications' ),
                'clarifications_enabled' => $question->get( 'clarifications_enabled' ) === 'yes',
                'description' => $question->get( 'description' ),
                'image' => $this->get_question_image( $question ),
                'video' => $question->get( 'video_src' ),
            );
            
            // Get answer choices based on question type
            $question_data['choices'] = $this->get_question_choices( $question );
            
            $questions[] = $question_data;
        }
        
        return array(
            'success' => true,
            'questions' => $questions,
            'total' => count( $questions ),
        );
    }
    
    /**
     * Start quiz attempt
     */
    public function start_quiz_attempt( $request ) {
        $quiz_id = $request->get_param( 'quiz_id' );
        $lesson_id = $request->get_param( 'lesson_id' );
        $user_id = get_current_user_id();
        
        // Verify quiz exists
        $quiz = llms_get_post( $quiz_id );
        if ( ! $quiz || ! is_a( $quiz, 'LLMS_Quiz' ) ) {
            return new WP_Error( 'quiz_not_found', 'Quiz not found', array( 'status' => 404 ) );
        }
        
        // Check if user is enrolled
        $student = llms_get_student( $user_id );
        $course_id = $quiz->get_course()->get( 'id' );
        
        if ( ! $student->is_enrolled( $course_id ) ) {
            return new WP_Error( 'not_enrolled', 'You must be enrolled to take this quiz', array( 'status' => 403 ) );
        }
        
        // Check for existing in-progress attempt
        // get_attempts_by_quiz returns all attempts, find in-progress ones
        $all_attempts = $student->quizzes()->get_attempts_by_quiz( $quiz_id );
        $existing_attempt = null;
        
        foreach ( $all_attempts as $att ) {
            if ( $att->get( 'status' ) === 'in-progress' ) {
                $existing_attempt = $att;
                break;
            }
        }
        
        if ( $existing_attempt ) {
            // Resume existing attempt instead of creating new one
            $attempt = $existing_attempt;
        } else {
            // Initialize new quiz attempt using LifterLMS
            error_log('Calling LLMS_Quiz_Attempt::init with quiz_id=' . $quiz_id . ', lesson_id=' . $lesson_id . ', user_id=' . $user_id);
            $attempt = LLMS_Quiz_Attempt::init( $quiz_id, $lesson_id, $user_id );
            error_log('LLMS_Quiz_Attempt::init returned: ' . var_export($attempt, true));
            
            // Simple debug without crashing
            if ( $attempt ) {
                error_log('Quiz attempt created for quiz ' . $quiz_id);
                error_log('Attempt class: ' . get_class($attempt));
                
                // Try different ways to get the ID
                $try_attempt_id = $attempt->get('attempt_id');
                $try_id = $attempt->get('id');
                
                error_log('attempt->get(attempt_id): ' . var_export($try_attempt_id, true));
                error_log('attempt->get(id): ' . var_export($try_id, true));
                
                // Check if it has a get_id method
                if (method_exists($attempt, 'get_id')) {
                    error_log('attempt->get_id(): ' . $attempt->get_id());
                }
                
                // Check direct property access
                if (property_exists($attempt, 'id')) {
                    error_log('attempt->id: ' . $attempt->id);
                }
                if (property_exists($attempt, 'attempt_id')) {
                    error_log('attempt->attempt_id: ' . $attempt->attempt_id);
                }
            } else {
                error_log('Failed to create quiz attempt for quiz ' . $quiz_id);
            }
            
            if ( ! $attempt ) {
                // Check if max attempts reached
                $max_attempts = $quiz->get( 'allowed_attempts' );
                $attempts_count = count( $student->quizzes()->get_all( $quiz_id ) );
                
                if ( $max_attempts > 0 && $attempts_count >= $max_attempts ) {
                    return new WP_Error( 
                        'max_attempts_reached', 
                        'Maximum number of attempts reached for this quiz', 
                        array( 'status' => 403 ) 
                    );
                }
                
                return new WP_Error( 'attempt_failed', 'Failed to start quiz attempt', array( 'status' => 500 ) );
            }
            
            // Start the attempt
            error_log('START_QUIZ: About to call attempt->start()');
            $attempt->start();
            error_log('START_QUIZ: After attempt->start(), status=' . $attempt->get('status'));
            
            // Get the actual ID from database
            $attempt_id = null;
            global $wpdb;
            $table = $wpdb->prefix . 'lifterlms_quiz_attempts';
            $latest = $wpdb->get_row($wpdb->prepare(
                "SELECT * FROM $table WHERE student_id = %d AND quiz_id = %d ORDER BY id DESC LIMIT 1",
                $user_id,
                $quiz_id
            ));
            
            if ($latest) {
                $attempt_id = $latest->id;
                error_log('START_QUIZ: Got attempt_id from DB = ' . $attempt_id . ', status in DB = ' . $latest->status);
            }
        }
        
        // Get questions for this attempt
        // Use the quiz object to get questions, not the attempt
        $quiz = llms_get_post( $quiz_id );
        $question_ids = $quiz->get_questions( 'ids' );
        
        // Randomize if needed
        if ( $quiz->get( 'random_questions' ) === 'yes' ) {
            shuffle( $question_ids );
        }
        
        // Format questions
        $questions = array();
        foreach ( $question_ids as $qid ) {
            $question = llms_get_post( $qid );
            
            if ( ! $question ) {
                continue;
            }
            
            $questions[] = $this->format_question_for_attempt( $question, $attempt );
        }
        
        // Try to get the attempt ID if we don't have it yet
        if (!isset($attempt_id)) {
            // Last resort - check database directly
            global $wpdb;
            $table = $wpdb->prefix . 'lifterlms_quiz_attempts';
            $user_id = get_current_user_id();
            $latest = $wpdb->get_row($wpdb->prepare(
                "SELECT * FROM $table WHERE student_id = %d AND quiz_id = %d ORDER BY id DESC LIMIT 1",
                $user_id,
                $quiz_id
            ));
            
            if ($latest) {
                $attempt_id = $latest->id;
            }
        }
        
        return array(
            'success' => true,
            'attempt_id' => $attempt_id ?? $attempt->get( 'attempt_id' ),
            'attempt_key' => $attempt->get( 'attempt_key' ),
            'questions' => $questions,
            'time_limit' => $quiz->get( 'time_limit' ),
            'started_at' => $attempt->get( 'start_date' ),
            'quiz' => array(
                'id' => $quiz_id,
                'title' => $quiz->get( 'title' ),
                'passing_grade' => $quiz->get( 'passing_grade' ),
            ),
        );
    }
    
    /**
     * Submit answer for a question
     */
    public function submit_answer( $request ) {
        $attempt_id = $request->get_param( 'attempt_id' );
        $question_id = $request->get_param( 'question_id' );
        $answer = $request->get_param( 'answer' );
        
        error_log('SUBMIT_ANSWER: attempt_id=' . $attempt_id . ', question_id=' . $question_id);
        
        // Get attempt
        $attempt = new LLMS_Quiz_Attempt( $attempt_id );
        
        if ( ! $attempt->exists() ) {
            error_log('SUBMIT_ANSWER: Attempt does not exist');
            return new WP_Error( 'attempt_not_found', 'Quiz attempt not found', array( 'status' => 404 ) );
        }
        
        // Log attempt status
        $status = $attempt->get( 'status' );
        error_log('SUBMIT_ANSWER: Attempt status = ' . $status);
        
        // Verify attempt belongs to current user
        if ( $attempt->get( 'student_id' ) != get_current_user_id() ) {
            error_log('SUBMIT_ANSWER: User mismatch');
            return new WP_Error( 'unauthorized', 'Unauthorized access', array( 'status' => 403 ) );
        }
        
        // Check if attempt is still in progress (status can be 'incomplete' or 'in-progress')
        if ( $attempt->get( 'status' ) !== 'in-progress' && $attempt->get( 'status' ) !== 'incomplete' ) {
            error_log('SUBMIT_ANSWER: Attempt not in progress, status=' . $status);
            return new WP_Error( 'attempt_ended', 'This quiz attempt has ended (status: ' . $status . ')', array( 'status' => 400 ) );
        }
        
        // Debug log the answer format
        $question = llms_get_post( $question_id );
        if ( $question ) {
            $question_type = $question->get('question_type');
            error_log('SUBMIT_ANSWER: Question type: ' . $question_type);
            error_log('SUBMIT_ANSWER: Multi choices: ' . $question->get('multi_choices'));
            
            // For choice and picture_choice questions, answer must be an array
            if ( in_array( $question_type, array( 'choice', 'picture_choice' ) ) ) {
                if ( ! is_array( $answer ) ) {
                    $answer = array( $answer );
                    error_log('SUBMIT_ANSWER: Converted answer to array for ' . $question_type);
                }
            }
            // For true_false questions, answer must also be an array
            elseif ( $question_type === 'true_false' ) {
                if ( ! is_array( $answer ) ) {
                    $answer = array( $answer );
                    error_log('SUBMIT_ANSWER: Converted answer to array for true_false');
                }
            }
            // For reorder questions, convert array to comma-separated string
            elseif ( $question_type === 'reorder' ) {
                if ( is_array( $answer ) ) {
                    $answer = implode( ',', $answer );
                    error_log('SUBMIT_ANSWER: Converted array to string for reorder');
                }
            }
            // For scale and blank questions, also need array format
            elseif ( in_array( $question_type, array( 'scale', 'blank' ) ) ) {
                if ( ! is_array( $answer ) ) {
                    $answer = array( strval( $answer ) );
                    error_log('SUBMIT_ANSWER: Converted answer to array for ' . $question_type);
                }
            }
        }
        error_log('SUBMIT_ANSWER: About to submit answer for question ' . $question_id);
        error_log('SUBMIT_ANSWER: Answer type: ' . gettype($answer));
        error_log('SUBMIT_ANSWER: Answer value: ' . print_r($answer, true));
        
        // Submit answer using LifterLMS
        $attempt->answer_question( $question_id, $answer );
        
        // Get the graded result
        $question_data = $attempt->get_question( $question_id );
        
        return array(
            'success' => true,
            'question_id' => $question_id,
            'answer_recorded' => true,
            'earned_points' => $question_data['earned'] ?? 0,
            'correct' => $question_data['correct'] ?? false,
        );
    }
    
    /**
     * Submit all answers and complete quiz in one call
     */
    public function submit_all_answers( $request ) {
        $attempt_id = $request->get_param( 'attempt_id' );
        $answers = $request->get_param( 'answers' );
        
        // Get attempt
        $attempt = new LLMS_Quiz_Attempt( $attempt_id );
        
        if ( ! $attempt->exists() ) {
            return new WP_Error( 'attempt_not_found', 'Quiz attempt not found', array( 'status' => 404 ) );
        }
        
        // Verify attempt belongs to current user
        if ( $attempt->get( 'student_id' ) != get_current_user_id() ) {
            return new WP_Error( 'unauthorized', 'Unauthorized access', array( 'status' => 403 ) );
        }
        
        // Check if attempt is still in progress (status can be 'incomplete' or 'in-progress')
        if ( $attempt->get( 'status' ) !== 'in-progress' && $attempt->get( 'status' ) !== 'incomplete' ) {
            return new WP_Error( 'attempt_ended', 'This quiz attempt has ended', array( 'status' => 400 ) );
        }
        
        // Submit all answers
        $submitted_count = 0;
        foreach ( $answers as $question_id => $answer ) {
            // Format answer based on question type
            $question = llms_get_post( $question_id );
            if ( $question ) {
                $question_type = $question->get('question_type');
                
                // Reorder questions - convert array to comma-separated string
                if ( $question_type === 'reorder' ) {
                    if ( is_array( $answer ) ) {
                        // Join array elements into comma-separated string
                        $answer = implode( ',', $answer );
                    }
                }
                // Choice-based questions need array format
                elseif ( in_array( $question_type, array( 'choice', 'picture_choice', 'true_false' ) ) ) {
                    if ( ! is_array( $answer ) ) {
                        $answer = array( $answer );
                    }
                }
                // Scale and blank questions also need array format
                elseif ( in_array( $question_type, array( 'scale', 'blank' ) ) ) {
                    if ( ! is_array( $answer ) ) {
                        $answer = array( strval( $answer ) );
                    }
                }
            }
            
            // Submit answer using LifterLMS
            $attempt->answer_question( $question_id, $answer );
            $submitted_count++;
        }
        
        // End the attempt and calculate grade
        $attempt->end();
        
        // Get final results
        $quiz = llms_get_post( $attempt->get( 'quiz_id' ) );
        $student = llms_get_student( get_current_user_id() );
        
        return array(
            'success' => true,
            'submitted_answers' => $submitted_count,
            'grade' => $attempt->get( 'grade' ),
            'passed' => $attempt->is_passing(),
            'points_earned' => $attempt->get( 'earned_points' ),
            'points_possible' => $attempt->get( 'possible_points' ),
            'attempt_id' => $attempt_id,
            'completed_at' => $attempt->get( 'end_date' ),
        );
    }
    
    /**
     * Complete quiz attempt
     */
    public function complete_quiz_attempt( $request ) {
        $attempt_id = $request->get_param( 'attempt_id' );
        
        // Get attempt
        $attempt = new LLMS_Quiz_Attempt( $attempt_id );
        
        if ( ! $attempt->exists() ) {
            return new WP_Error( 'attempt_not_found', 'Quiz attempt not found', array( 'status' => 404 ) );
        }
        
        // Verify attempt belongs to current user
        if ( $attempt->get( 'student_id' ) != get_current_user_id() ) {
            return new WP_Error( 'unauthorized', 'Unauthorized access', array( 'status' => 403 ) );
        }
        
        // End the attempt - LifterLMS handles grading
        $attempt->end();
        
        // Get final results
        $quiz = llms_get_post( $attempt->get( 'quiz_id' ) );
        $student = llms_get_student( get_current_user_id() );
        
        // Get the actual question count from the quiz
        $actual_question_count = count( $quiz->get_questions( 'ids' ) );
        $attempt_question_count = $attempt->get_count( 'questions' );
        
        error_log('COMPLETE_QUIZ: Quiz has ' . $actual_question_count . ' questions');
        error_log('COMPLETE_QUIZ: Attempt recorded ' . $attempt_question_count . ' questions');
        
        $results = array(
            'success' => true,
            'attempt_id' => $attempt_id,
            'grade' => $attempt->get( 'grade' ),
            'passed' => $attempt->is_passing(),
            'points_earned' => $attempt->get( 'earned_points' ),
            'points_possible' => $attempt->get( 'possible_points' ),
            'questions_correct' => $attempt->get_count( 'correct_answers' ),
            'questions_total' => $actual_question_count,  // Use actual quiz question count
            'completed_at' => $attempt->get( 'end_date' ),
        );
        
        // Check if certificate was earned
        $course_id = $quiz->get_course()->get( 'id' );
        $certificates = $student->get_certificates( $course_id );
        
        if ( ! empty( $certificates ) ) {
            $results['certificate_earned'] = true;
            $results['certificate_id'] = $certificates[0];
        }
        
        // Add question results if showing correct answers
        if ( $quiz->get( 'show_correct_answer' ) === 'yes' ) {
            $results['questions'] = $this->get_attempt_question_results( $attempt );
        }
        
        return $results;
    }
    
    /**
     * Get quiz results
     */
    public function get_quiz_results( $request ) {
        $attempt_id = $request->get_param( 'attempt_id' );
        
        $attempt = new LLMS_Quiz_Attempt( $attempt_id );
        
        if ( ! $attempt->exists() ) {
            return new WP_Error( 'attempt_not_found', 'Quiz attempt not found', array( 'status' => 404 ) );
        }
        
        // Verify attempt belongs to current user
        if ( $attempt->get( 'student_id' ) != get_current_user_id() ) {
            return new WP_Error( 'unauthorized', 'Unauthorized access', array( 'status' => 403 ) );
        }
        
        $quiz = llms_get_post( $attempt->get( 'quiz_id' ) );
        
        $results = array(
            'success' => true,
            'attempt' => array(
                'id' => $attempt_id,
                'status' => $attempt->get( 'status' ),
                'grade' => $attempt->get( 'grade' ),
                'passed' => $attempt->is_passing(),
                'points_earned' => $attempt->get( 'earned_points' ),
                'points_possible' => $attempt->get( 'possible_points' ),
                'questions_correct' => $attempt->get_count( 'correct_answers' ),
                'questions_total' => $attempt->get_count( 'questions' ),
                'start_date' => $attempt->get( 'start_date' ),
                'end_date' => $attempt->get( 'end_date' ),
            ),
            'quiz' => array(
                'id' => $quiz->get( 'id' ),
                'title' => $quiz->get( 'title' ),
                'passing_grade' => $quiz->get( 'passing_grade' ),
            ),
        );
        
        // Add detailed question results if allowed
        if ( $quiz->get( 'show_correct_answer' ) === 'yes' || $attempt->get( 'status' ) === 'complete' ) {
            $results['questions'] = $this->get_attempt_question_results( $attempt );
        }
        
        return $results;
    }
    
    /**
     * Get user's quiz attempts
     */
    public function get_user_attempts( $request ) {
        $quiz_id = $request->get_param( 'quiz_id' );
        $user_id = get_current_user_id();
        
        $student = llms_get_student( $user_id );
        $attempts = $student->quizzes()->get_attempts_by_quiz( $quiz_id );
        
        $formatted_attempts = array();
        
        foreach ( $attempts as $attempt ) {
            $formatted_attempts[] = array(
                'id' => $attempt->get( 'attempt_id' ),
                'status' => $attempt->get( 'status' ),
                'grade' => $attempt->get( 'grade' ),
                'passed' => $attempt->is_passing(),
                'start_date' => $attempt->get( 'start_date' ),
                'end_date' => $attempt->get( 'end_date' ),
            );
        }
        
        return array(
            'success' => true,
            'attempts' => $formatted_attempts,
            'total' => count( $formatted_attempts ),
        );
    }
    
    /**
     * Resume quiz attempt
     */
    public function resume_quiz_attempt( $request ) {
        $attempt_id = $request->get_param( 'attempt_id' );
        
        $attempt = new LLMS_Quiz_Attempt( $attempt_id );
        
        if ( ! $attempt->exists() ) {
            return new WP_Error( 'attempt_not_found', 'Quiz attempt not found', array( 'status' => 404 ) );
        }
        
        // Verify attempt belongs to current user
        if ( $attempt->get( 'student_id' ) != get_current_user_id() ) {
            return new WP_Error( 'unauthorized', 'Unauthorized access', array( 'status' => 403 ) );
        }
        
        // Check if attempt can be resumed
        if ( $attempt->get( 'status' ) !== 'in-progress' ) {
            return new WP_Error( 'cannot_resume', 'This quiz attempt cannot be resumed', array( 'status' => 400 ) );
        }
        
        // Get quiz
        $quiz = llms_get_post( $attempt->get( 'quiz_id' ) );
        
        // Get questions and answered status
        $question_ids = $attempt->get_question_ids();
        $questions = array();
        
        foreach ( $question_ids as $qid ) {
            $question = llms_get_post( $qid );
            
            if ( ! $question ) {
                continue;
            }
            
            $question_data = $this->format_question_for_attempt( $question, $attempt );
            
            // Check if already answered
            $attempt_question = $attempt->get_question( $qid );
            if ( $attempt_question && isset( $attempt_question['answer'] ) ) {
                $question_data['answered'] = true;
                $question_data['given_answer'] = $attempt_question['answer'];
            }
            
            $questions[] = $question_data;
        }
        
        // Calculate time remaining if there's a time limit
        $time_remaining = null;
        if ( $quiz->get( 'time_limit' ) > 0 ) {
            $start_time = strtotime( $attempt->get( 'start_date' ) );
            $elapsed = time() - $start_time;
            $time_limit_seconds = $quiz->get( 'time_limit' ) * 60;
            $time_remaining = max( 0, $time_limit_seconds - $elapsed );
        }
        
        return array(
            'success' => true,
            'attempt_id' => $attempt_id,
            'questions' => $questions,
            'time_remaining' => $time_remaining,
            'quiz' => array(
                'id' => $quiz->get( 'id' ),
                'title' => $quiz->get( 'title' ),
                'passing_grade' => $quiz->get( 'passing_grade' ),
            ),
        );
    }
    
    /**
     * Helper: Get question choices
     */
    private function get_question_choices( $question ) {
        $choices = array();
        $type = $question->get( 'question_type' );
        
        switch ( $type ) {
            case 'choice':
            case 'picture_choice':
                $question_choices = $question->get_choices();
                
                foreach ( $question_choices as $choice ) {
                    $choice_data = array(
                        'id' => $choice->get( 'id' ),
                        'marker' => $choice->get( 'marker' ),
                        'choice' => $choice->get( 'choice' ),
                        'choice_type' => $choice->get( 'choice_type' ),
                    );
                    
                    // Add image for picture choice
                    if ( $type === 'picture_choice' ) {
                        $choice_data['image'] = $choice->get( 'choice' );
                        $choice_data['text'] = $choice->get( 'choice_text' );
                    }
                    
                    $choices[] = $choice_data;
                }
                break;
                
            case 'true_false':
                $choices = array(
                    array( 'id' => 'true', 'choice' => 'True' ),
                    array( 'id' => 'false', 'choice' => 'False' ),
                );
                break;
                
            case 'reorder':
                // Get reorder items
                $question_choices = $question->get_choices();
                
                if ( $question_choices ) {
                    foreach ( $question_choices as $choice ) {
                        $choices[] = array(
                            'id' => $choice->get( 'id' ),
                            'order' => $choice->get( 'order' ),
                            'choice' => $choice->get( 'choice' ),
                        );
                    }
                    
                    // Shuffle for display (correct order is stored)
                    shuffle( $choices );
                }
                break;
                
            case 'scale':
                // Get scale range
                $choices = array(
                    'min' => $question->get( 'minimum' ) ?: 1,
                    'max' => $question->get( 'maximum' ) ?: 10,
                    'min_label' => $question->get( 'minimum_label' ) ?: '',
                    'max_label' => $question->get( 'maximum_label' ) ?: '',
                );
                break;
                
            case 'blank':
            case 'fill_in_the_blank':
                // For blank questions, get the content with blanks marked
                $content = $question->get( 'content' );
                $blank_count = substr_count( $content, '[blank]' );
                
                $choices = array(
                    'blank_count' => $blank_count ?: 1,
                    'blank_type' => 'text',
                );
                break;
                
            case 'short_answer':
            case 'long_answer':
            case 'code':
                // These types don't have predefined choices
                $choices = null;
                break;
        }
        
        return $choices;
    }
    
    /**
     * Helper: Get question image
     */
    private function get_question_image( $question ) {
        $image_id = $question->get( 'image' );
        
        if ( ! $image_id ) {
            return null;
        }
        
        $image_url = wp_get_attachment_url( $image_id );
        
        return $image_url ?: null;
    }
    
    /**
     * Helper: Format question for attempt
     */
    private function format_question_for_attempt( $question, $attempt ) {
        $question_data = array(
            'id' => $question->get( 'id' ),
            'title' => $question->get( 'title' ),
            'content' => $question->get( 'content' ),
            'type' => $question->get( 'question_type' ),
            'points' => $question->get( 'points' ),
            'multi_choices' => $question->get( 'multi_choices' ) === 'yes',
            'description' => $question->get( 'description' ),
            'image' => $this->get_question_image( $question ),
            'video' => $question->get( 'video_src' ),
            'choices' => $this->get_question_choices( $question ),
            'answered' => false,
        );
        
        return $question_data;
    }
    
    /**
     * Helper: Get attempt question results
     */
    private function get_attempt_question_results( $attempt ) {
        $questions = array();
        // LLMS_Quiz_Attempt doesn't have get_question_ids(), so get from quiz
        $quiz_id = $attempt->get( 'quiz_id' );
        $quiz = llms_get_post( $quiz_id );
        
        if ( ! $quiz ) {
            return array();
        }
        
        $question_ids = $quiz->get_questions( 'ids' );
        
        foreach ( $question_ids as $qid ) {
            $question = llms_get_post( $qid );
            $attempt_question = $attempt->get_question( $qid );
            
            error_log('Question ' . $qid . ' - attempt data: ' . print_r($attempt_question, true));
            
            if ( ! $question ) {
                error_log('Question ' . $qid . ' not found');
                continue;
            }
            
            if ( ! $attempt_question ) {
                error_log('No attempt data for question ' . $qid);
                // Still include the question with default values
                $attempt_question = array(
                    'points' => 0,
                    'earned' => 0,
                    'correct' => false,
                    'answer' => null,
                );
            }
            
            $result = array(
                'id' => $qid,
                'content' => $question->get( 'content' ),
                'type' => $question->get( 'question_type' ),
                'points' => $attempt_question['points'] ?? 0,
                'earned' => $attempt_question['earned'] ?? 0,
                'correct' => $attempt_question['correct'] ?? false,
                'answer' => $attempt_question['answer'] ?? null,
            );
            
            // Add correct answer if showing
            $quiz = llms_get_post( $attempt->get( 'quiz_id' ) );
            if ( $quiz->get( 'show_correct_answer' ) === 'yes' ) {
                // Get correct answer based on question type
                $type = $question->get( 'question_type' );
                
                if ( in_array( $type, array( 'choice', 'picture_choice' ) ) ) {
                    $choices = $question->get_choices();
                    foreach ( $choices as $choice ) {
                        if ( $choice->is_correct() ) {
                            $result['correct_answer'] = $choice->get( 'marker' );
                            break;
                        }
                    }
                } elseif ( $type === 'true_false' ) {
                    $result['correct_answer'] = $question->get( 'correct_answer' );
                } else {
                    // For text-based answers
                    $result['correct_answer'] = $question->get( 'correct_answer' );
                }
                
                // Add clarification if available
                if ( $question->get( 'clarifications_enabled' ) === 'yes' ) {
                    $result['clarification'] = $question->get( 'clarifications' );
                }
            }
            
            $questions[] = $result;
        }
        
        return $questions;
    }
    
    /**
     * Reset quiz attempts for a user (testing/development)
     */
    public function reset_quiz_attempts( $request ) {
        $quiz_id = $request->get_param( 'quiz_id' );
        $user_id = get_current_user_id();
        
        // Get student
        $student = llms_get_student( $user_id );
        
        if ( ! $student ) {
            return new WP_Error( 'user_not_found', 'User not found', array( 'status' => 404 ) );
        }
        
        // Get all attempts for this quiz
        $attempts = $student->quizzes()->get_all( $quiz_id );
        
        $deleted_count = 0;
        
        // Delete each attempt
        foreach ( $attempts as $attempt ) {
            if ( is_a( $attempt, 'LLMS_Quiz_Attempt' ) ) {
                // Mark attempt as deleted (LifterLMS doesn't truly delete, just marks)
                $attempt->delete();
                $deleted_count++;
            }
        }
        
        return array(
            'success' => true,
            'message' => sprintf( 'Deleted %d quiz attempts', $deleted_count ),
            'deleted_count' => $deleted_count,
        );
    }
    
    /**
     * Permission callback
     */
    public function check_permissions() {
        return is_user_logged_in();
    }
}

// Initialize quiz handler
LLMS_Mobile_Quiz_Handler::instance();
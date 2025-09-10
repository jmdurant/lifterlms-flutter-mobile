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
        
        // Add grading support for advanced question types (not supported in core LifterLMS)
        add_filter( 'llms_blank_question_pre_grade', array( $this, 'grade_blank_question' ), 10, 3 );
        add_filter( 'llms_reorder_question_pre_grade', array( $this, 'grade_reorder_question' ), 10, 3 );
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
                    'validate_callback' => function( $value ) {
                        // Accept string, array, or null
                        return is_string( $value ) || is_array( $value ) || is_null( $value );
                    },
                    'sanitize_callback' => function( $value ) {
                        // Pass through as-is, we'll handle conversion in the method
                        return $value;
                    },
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
                    'validate_callback' => function( $value ) {
                        // Accept object/array of answers
                        return is_array( $value ) || is_object( $value );
                    },
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
        // IMPORTANT: We get ALL questions from the quiz, not just what's in the attempt
        // This ensures all question types are included
        $quiz = llms_get_post( $quiz_id );
        $question_ids = $quiz->get_questions( 'ids' );
        
        error_log('START_QUIZ: Quiz has ' . count($question_ids) . ' total questions');
        error_log('START_QUIZ: Question IDs: ' . implode(', ', $question_ids));
        
        // Check what questions are in the attempt
        $attempt_questions = $attempt->get_questions();
        $attempt_question_ids = array();
        if ( is_array( $attempt_questions ) ) {
            foreach ( $attempt_questions as $q ) {
                if ( isset( $q['id'] ) ) {
                    $attempt_question_ids[] = $q['id'];
                }
            }
        }
        error_log('START_QUIZ: Attempt has ' . count($attempt_question_ids) . ' questions: ' . implode(', ', $attempt_question_ids));
        
        // Find missing questions
        $missing_questions = array_diff( $question_ids, $attempt_question_ids );
        if ( ! empty( $missing_questions ) ) {
            error_log('START_QUIZ: Missing questions in attempt: ' . implode(', ', $missing_questions));
            
            // Add missing questions to the attempt
            foreach ( $missing_questions as $missing_qid ) {
                $missing_question = llms_get_post( $missing_qid );
                if ( $missing_question ) {
                    error_log('START_QUIZ: Adding missing question ' . $missing_qid . ' to attempt');
                    $attempt->add_question( array(
                        'id' => $missing_qid,
                        'points' => $missing_question->get( 'points' ) ?: 1,
                    ) );
                }
            }
        }
        
        // Randomize if needed
        if ( $quiz->get( 'random_questions' ) === 'yes' ) {
            shuffle( $question_ids );
        }
        
        // Format questions
        $questions = array();
        foreach ( $question_ids as $qid ) {
            $question = llms_get_post( $qid );
            
            if ( ! $question ) {
                error_log('START_QUIZ: Question ' . $qid . ' not found');
                continue;
            }
            
            $question_data = $this->format_question_for_attempt( $question, $attempt );
            error_log('START_QUIZ: Adding question ' . $qid . ' type: ' . $question->get('question_type') . 
                     ', points: ' . $question->get('points') . 
                     ', auto_gradable: ' . ($question_data['auto_gradable'] ? 'yes' : 'no') .
                     ', grading: ' . $question_data['grading_notes']);
            $questions[] = $question_data;
        }
        
        error_log('START_QUIZ: Returning ' . count($questions) . ' questions to app');
        
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
            'attempt_id' => $attempt_id,
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
            error_log('SUBMIT_ANSWER: Received answer type: ' . gettype($answer));
            error_log('SUBMIT_ANSWER: Received answer value: ' . print_r($answer, true));
            
            // Handle answer format based on question type
            // Regular choice questions - keep as array of IDs
            if ( $question_type === 'choice' ) {
                // Keep choice answers as IDs in array format
                if ( ! is_array( $answer ) ) {
                    $answer = array( $answer );
                }
                error_log('SUBMIT_ANSWER: Choice answer (keeping IDs): ' . print_r($answer, true));
            }
            // Picture choice - keep as array of IDs (don't convert to markers)
            elseif ( $question_type === 'picture_choice' ) {
                // Keep picture choice answers as IDs in array format
                if ( ! is_array( $answer ) ) {
                    $answer = array( $answer );
                }
                error_log('SUBMIT_ANSWER: Picture choice answer (keeping IDs): ' . print_r($answer, true));
            }
            // True/false - convert "true"/"false" strings to actual choice IDs
            elseif ( $question_type === 'true_false' ) {
                // If we get "true" or "false" as strings, convert to the actual choice ID
                $raw_answers = is_array( $answer ) ? $answer : array( $answer );
                $converted_answers = array();
                
                // Get the choices to find the IDs for true/false
                $choices = $question->get_choices();
                $true_id = null;
                $false_id = null;
                
                foreach ( $choices as $choice ) {
                    $choice_text = strtolower( $choice->get( 'choice' ) );
                    if ( $choice_text === 'true' ) {
                        $true_id = $choice->get( 'id' );
                    } elseif ( $choice_text === 'false' ) {
                        $false_id = $choice->get( 'id' );
                    }
                }
                
                // Convert each answer
                foreach ( $raw_answers as $ans ) {
                    $ans_str = strval( $ans );
                    if ( strtolower( $ans_str ) === 'true' && $true_id ) {
                        $converted_answers[] = $true_id;
                        error_log('SUBMIT_ANSWER: Converted "true" to choice ID: ' . $true_id);
                    } elseif ( strtolower( $ans_str ) === 'false' && $false_id ) {
                        $converted_answers[] = $false_id;
                        error_log('SUBMIT_ANSWER: Converted "false" to choice ID: ' . $false_id);
                    } else {
                        // Already an ID or unrecognized - keep as is
                        $converted_answers[] = $ans;
                    }
                }
                
                $answer = $converted_answers;
                error_log('SUBMIT_ANSWER: True/false final answer: ' . print_r($answer, true));
            }
            // Reorder questions - LifterLMS expects ARRAY of choice IDs
            elseif ( $question_type === 'reorder' ) {
                // Convert to array if string
                if ( ! is_array( $answer ) ) {
                    $answer = explode( ',', $answer );
                    error_log('SUBMIT_ANSWER: Converted comma-separated string to array for reorder');
                }
                // Ensure all elements are strings
                $answer = array_map( 'strval', $answer );
                error_log('SUBMIT_ANSWER: Reorder answer array: ' . implode(',', $answer));
            }
            // Scale questions - LifterLMS expects array with single value
            elseif ( $question_type === 'scale' ) {
                // Accept either format
                if ( ! is_array( $answer ) ) {
                    $answer = array( strval( $answer ) );
                    error_log('SUBMIT_ANSWER: Converted to array for scale');
                } else {
                    // Ensure all elements are strings
                    $answer = array_map( 'strval', $answer );
                    error_log('SUBMIT_ANSWER: Keeping array format for scale');
                }
            }
            // Blank/fill-in-the-blank questions - LifterLMS expects ARRAY of strings
            elseif ( in_array( $question_type, array( 'blank', 'fill_in_the_blank' ) ) ) {
                // Always use array format
                if ( ! is_array( $answer ) ) {
                    $answer = array( strval($answer) );
                    error_log('SUBMIT_ANSWER: Converted string to array for blank');
                } else {
                    // Ensure all elements are strings
                    $answer = array_map( 'strval', $answer );
                    error_log('SUBMIT_ANSWER: Keeping array format for blank');
                }
                error_log('SUBMIT_ANSWER: Blank answer final: ' . print_r($answer, true));
            }
            // Other types (short_answer, long_answer, etc.) - keep as string
            else {
                if ( is_array( $answer ) ) {
                    // If we get an array for a text answer, join it
                    $answer = implode( ' ', $answer );
                    error_log('SUBMIT_ANSWER: Converted array to string for ' . $question_type);
                }
            }
        }
        // Log what the correct answer should be for debugging
        if ( $question ) {
            $question_type = $question->get('question_type');
            error_log('SUBMIT_ANSWER: Question type: ' . $question_type);
            
            // Log correct answer format
            if ( in_array( $question_type, array( 'choice', 'picture_choice' ) ) ) {
                $choices = $question->get_choices();
                foreach ( $choices as $choice ) {
                    if ( $choice->is_correct() ) {
                        error_log('SUBMIT_ANSWER: Correct choice ID: ' . $choice->get( 'id' ));
                        error_log('SUBMIT_ANSWER: Correct choice marker: ' . $choice->get( 'marker' ));
                        $choice_text = $choice->get( 'choice' );
                        if ( is_array( $choice_text ) ) {
                            error_log('SUBMIT_ANSWER: Correct choice text: [image array]');
                        } else {
                            error_log('SUBMIT_ANSWER: Correct choice text: ' . $choice_text);
                        }
                    }
                }
            } elseif ( $question_type === 'true_false' ) {
                error_log('SUBMIT_ANSWER: Correct true/false answer: ' . $question->get( 'correct_answer' ));
            } elseif ( $question_type === 'blank' ) {
                // Debug what's in the database for blank questions
                $this->debug_question_data( $question_id );
                
                // Try different field names that LifterLMS might use
                $correct = $question->get( 'correct_answer' );
                if ( empty( $correct ) ) {
                    // Try alternate field name
                    $correct = $question->get( 'correct_value' );
                    if ( empty( $correct ) ) {
                        // Check post meta directly
                        $correct = get_post_meta( $question_id, '_llms_correct_value', true );
                    }
                }
                
                if ( empty( $correct ) ) {
                    error_log('SUBMIT_ANSWER: Blank question - no correct answer defined (manual grading required)');
                } else {
                    error_log('SUBMIT_ANSWER: Correct blank answer: ' . $correct);
                    error_log('SUBMIT_ANSWER:   Correct type: ' . gettype($correct));
                    error_log('SUBMIT_ANSWER:   Our answer: ' . print_r($answer, true));
                    error_log('SUBMIT_ANSWER:   Our type: ' . gettype($answer));
                    
                    // Check if they match
                    if ( is_array($answer) && count($answer) === 1 ) {
                        $our_answer = $answer[0];
                        if ( $our_answer == $correct ) {
                            error_log('SUBMIT_ANSWER:   Answers MATCH (loose comparison)');
                        } else {
                            error_log('SUBMIT_ANSWER:   Answers DO NOT match');
                            error_log('SUBMIT_ANSWER:     Our: "' . $our_answer . '" (' . gettype($our_answer) . ')');
                            error_log('SUBMIT_ANSWER:     Expected: "' . $correct . '" (' . gettype($correct) . ')');
                        }
                    }
                }
            } elseif ( $question_type === 'reorder' ) {
                // Debug what's in the database for reorder questions
                $this->debug_question_data( $question_id );
                
                // For reorder questions, the correct answer is the original order of choices
                $choices = $question->get_choices();
                error_log('SUBMIT_ANSWER: Reorder has ' . count($choices) . ' choices');
                
                // Build the correct sequence from the original order
                $correct_sequence_array = array();
                foreach ( $choices as $idx => $choice ) {
                    $choice_id = $choice->get('id');
                    $correct_sequence_array[] = $choice_id;
                    error_log('SUBMIT_ANSWER:   Choice ' . $idx . ' - ID: ' . $choice_id . 
                             ', marker: ' . $choice->get('marker'));
                }
                
                // The correct answer for reorder is the original order
                $correct_sequence = implode(',', $correct_sequence_array);
                error_log('SUBMIT_ANSWER: Correct reorder sequence: ' . $correct_sequence);
                
                // Check if the submitted answer matches
                $submitted_sequence = is_array($answer) ? implode(',', $answer) : $answer;
                if ( $submitted_sequence === $correct_sequence ) {
                    error_log('SUBMIT_ANSWER: Reorder answer MATCHES expected sequence');
                } else {
                    error_log('SUBMIT_ANSWER: Reorder answer does NOT match');
                    error_log('SUBMIT_ANSWER:   Submitted: ' . $submitted_sequence);
                    error_log('SUBMIT_ANSWER:   Expected: ' . $correct_sequence);
                }
            } elseif ( $question_type === 'scale' ) {
                error_log('SUBMIT_ANSWER: Scale question - any answer within range is correct');
            }
        }
        
        error_log('SUBMIT_ANSWER: About to submit answer for question ' . $question_id);
        error_log('SUBMIT_ANSWER: Final answer type: ' . gettype($answer));
        error_log('SUBMIT_ANSWER: Final answer value: ' . print_r($answer, true));
        
        // Submit answer using LifterLMS
        $attempt->answer_question( $question_id, $answer );
        
        // Get all questions to find our submitted answer
        $all_questions = $attempt->get_questions();
        $stored_answer = null;
        $is_correct = null;
        
        foreach ( $all_questions as $q ) {
            if ( is_array( $q ) && isset( $q['id'] ) && $q['id'] == $question_id ) {
                $stored_answer = $q['answer'] ?? null;
                $is_correct = $q['correct'] ?? null;
                error_log('SUBMIT_ANSWER: Found question in attempt');
                error_log('SUBMIT_ANSWER: Stored answer: ' . print_r($stored_answer, true));
                error_log('SUBMIT_ANSWER: Marked correct: ' . ($is_correct ? 'YES' : 'NO'));
                error_log('SUBMIT_ANSWER: Points earned: ' . ($q['earned'] ?? 0));
                
                // Log what LifterLMS thinks is the correct answer
                $this->log_correct_answer( $question, $question_type );
                
                // For incorrect answers, try to get the correct answer from LifterLMS
                if ( ! $is_correct ) {
                    // Try different methods to get the correct answer
                    if ( method_exists( $attempt, 'get_question_correct_answer' ) ) {
                        $llms_correct = $attempt->get_question_correct_answer( $question_id );
                        error_log('SUBMIT_ANSWER: LifterLMS correct answer (method): ' . print_r($llms_correct, true));
                    }
                    
                    // For reorder, log more details about what went wrong
                    if ( $question_type === 'reorder' ) {
                        error_log('SUBMIT_ANSWER: Reorder marked incorrect!');
                        error_log('SUBMIT_ANSWER:   We submitted: ' . print_r($stored_answer, true));
                        error_log('SUBMIT_ANSWER:   Type: ' . gettype($stored_answer));
                        
                        // Check if the question object has the expected answer
                        // Note: get_array() requires a parameter
                        error_log('SUBMIT_ANSWER:   Checking what LifterLMS expects...');
                    }
                }
                break;
            }
        }
        
        if ( $stored_answer === null ) {
            error_log('SUBMIT_ANSWER: WARNING - Could not find question ' . $question_id . ' in attempt questions');
            
            // Try to add it if missing
            $question_obj = llms_get_post( $question_id );
            if ( $question_obj ) {
                $points = $question_obj->get( 'points' ) ?: 1;
                $attempt->add_question( array(
                    'id' => $question_id,
                    'points' => $points,
                ) );
                $attempt->answer_question( $question_id, $answer );
                error_log('SUBMIT_ANSWER: Added missing question and submitted answer');
            }
        }
        
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
                
                // Handle answer format based on question type (same logic as submit_answer)
                // Regular choice questions - keep as array of IDs
                if ( $question_type === 'choice' ) {
                    if ( ! is_array( $answer ) ) {
                        $answer = array( $answer );
                    }
                }
                // Picture choice - keep as array of IDs
                elseif ( $question_type === 'picture_choice' ) {
                    if ( ! is_array( $answer ) ) {
                        $answer = array( $answer );
                    }
                }
                // True/false - keep as array of IDs
                elseif ( $question_type === 'true_false' ) {
                    if ( ! is_array( $answer ) ) {
                        $answer = array( $answer );
                    }
                }
                // Reorder questions - LifterLMS expects ARRAY
                elseif ( $question_type === 'reorder' ) {
                    if ( ! is_array( $answer ) ) {
                        $answer = explode( ',', $answer );
                    }
                }
                // Scale questions - LifterLMS expects array
                elseif ( $question_type === 'scale' ) {
                    if ( ! is_array( $answer ) ) {
                        $answer = array( strval( $answer ) );
                    } else {
                        $answer = array_map( 'strval', $answer );
                    }
                }
                // Blank questions - LifterLMS expects array
                elseif ( in_array( $question_type, array( 'blank', 'fill_in_the_blank' ) ) ) {
                    if ( ! is_array( $answer ) ) {
                        $answer = array( strval( $answer ) );
                    } else {
                        $answer = array_map( 'strval', $answer );
                    }
                }
                // Other types - keep as string
                else {
                    if ( is_array( $answer ) ) {
                        $answer = implode( ' ', $answer );
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
        
        // Debug log the questions and their answers
        $all_questions = $attempt->get_questions();
        $total_points_earned = 0;
        $total_points_possible = 0;
        $questions_correct = 0;
        $auto_gradable_count = 0;
        
        foreach ( $all_questions as $idx => $q ) {
            if ( is_array( $q ) ) {
                // Get question object to check type
                $question_obj = llms_get_post( $q['id'] );
                $question_type = $question_obj ? $question_obj->get( 'question_type' ) : '';
                
                // Determine if this question should count toward grade
                // Include blank questions if they have a correct answer defined
                $is_auto_gradable = in_array( $question_type, array( 'choice', 'picture_choice', 'true_false', 'reorder', 'blank' ) );
                
                $points_possible = isset($q['points']) ? floatval($q['points']) : 0;
                $points_earned = isset($q['earned']) ? floatval($q['earned']) : 0;
                $is_correct = isset($q['correct']) && $q['correct'];
                
                // Only count auto-gradable questions in total possible points
                if ( $is_auto_gradable ) {
                    $total_points_possible += $points_possible;
                    $total_points_earned += $points_earned;
                    $auto_gradable_count++;
                    if ( $is_correct ) {
                        $questions_correct++;
                    }
                }
                
                error_log('Question ' . $q['id'] . ' (' . $question_type . ') - answer: ' . print_r($q['answer'] ?? 'null', true) . 
                         ', correct: ' . ($is_correct ? 'YES' : 'NO') . 
                         ', earned: ' . $points_earned . '/' . $points_possible . ' points' .
                         ', auto-gradable: ' . ($is_auto_gradable ? 'YES' : 'NO'));
            } else {
                error_log('Question ' . $idx . ' - attempt data: ' . print_r($q, true));
            }
        }
        
        error_log('COMPLETE_QUIZ: Total points earned (auto-gradable only): ' . $total_points_earned . '/' . $total_points_possible);
        error_log('COMPLETE_QUIZ: Questions correct: ' . $questions_correct . '/' . $auto_gradable_count . ' (auto-gradable)');
        
        // Calculate percentage grade based on points
        $percentage_grade = $total_points_possible > 0 ? 
            round(($total_points_earned / $total_points_possible) * 100, 2) : 0;
        
        $results = array(
            'success' => true,
            'attempt_id' => $attempt_id,
            'grade' => $attempt->get( 'grade' ),  // Official LifterLMS grade
            'calculated_grade' => $percentage_grade,  // Our calculated grade
            'passed' => $attempt->is_passing(),
            'points_earned' => $total_points_earned,
            'points_possible' => $total_points_possible,
            'questions_correct' => $questions_correct,
            'questions_total' => $actual_question_count,
            'auto_gradable_total' => $auto_gradable_count,
            'completed_at' => $attempt->get( 'end_date' ),
        );
        
        // Check if certificate was earned
        $course = $quiz->get_course();
        if ( $course ) {
            $course_id = $course->get( 'id' );
            // Get certificates without specifying order (avoiding SQL error)
            $certificates = $student->get_certificates();
            
            // Filter for this specific course
            $course_certificates = array();
            foreach ( $certificates as $cert ) {
                // Handle both object and array formats
                $post_id = is_array( $cert ) ? ( $cert['post_id'] ?? null ) : ( isset( $cert->post_id ) ? $cert->post_id : null );
                if ( $post_id && $post_id == $course_id ) {
                    $course_certificates[] = $cert;
                }
            }
            
            if ( ! empty( $course_certificates ) ) {
                $results['certificate_earned'] = true;
                // Handle both object and array formats for certificate ID
                $first_cert = $course_certificates[0];
                $cert_id = is_array( $first_cert ) ? 
                    ( $first_cert['certificate_id'] ?? null ) : 
                    ( isset( $first_cert->certificate_id ) ? $first_cert->certificate_id : null );
                $results['certificate_id'] = $cert_id;
            }
        }
        
        // Add question results if showing correct answers
        if ( $quiz->get( 'show_correct_answer' ) === 'yes' ) {
            $results['questions'] = $this->get_attempt_question_results( $attempt );
        }
        
        return $results;
    }
    
    /**
     * Log the correct answer for a question
     */
    private function log_correct_answer( $question, $question_type ) {
        error_log('CORRECT_ANSWER: Checking correct answer for ' . $question_type);
        
        // Try the standard correct_answer field first
        $correct_answer = $question->get( 'correct_answer' );
        if ( ! empty( $correct_answer ) ) {
            error_log('CORRECT_ANSWER: From correct_answer field: ' . print_r($correct_answer, true));
        }
        
        // Check choices for questions with choices
        if ( in_array( $question_type, array( 'choice', 'picture_choice', 'true_false', 'reorder' ) ) ) {
            $choices = $question->get_choices();
            error_log('CORRECT_ANSWER: Checking ' . count($choices) . ' choices');
            
            $correct_choices = array();
            $all_choices = array();
            
            foreach ( $choices as $idx => $choice ) {
                $choice_id = $choice->get('id');
                $choice_text = $choice->get('choice');
                $marker = $choice->get('marker');
                $is_correct = $choice->is_correct();
                
                // Handle image choices (picture_choice) where text might be an array
                $text_preview = is_array($choice_text) ? '[image]' : substr($choice_text, 0, 50);
                
                $all_choices[] = array(
                    'index' => $idx,
                    'id' => $choice_id,
                    'marker' => $marker,
                    'text' => $text_preview,
                    'correct' => $is_correct
                );
                
                if ( $is_correct ) {
                    $correct_choices[] = $choice_id;
                }
            }
            
            error_log('CORRECT_ANSWER: All choices: ' . print_r($all_choices, true));
            
            if ( $question_type === 'reorder' ) {
                // For reorder, all choices are "correct" but the order matters
                // The correct answer is the original order
                $correct_order = array();
                foreach ( $choices as $idx => $choice ) {
                    $correct_order[] = $choice->get('id');
                }
                error_log('CORRECT_ANSWER: Reorder correct sequence: ' . implode(',', $correct_order));
            } else {
                // For other choice questions, log which ones are marked correct
                if ( ! empty( $correct_choices ) ) {
                    error_log('CORRECT_ANSWER: Correct choice IDs: ' . implode(',', $correct_choices));
                }
            }
        }
        
        // For blank/text questions, check for additional grading options
        if ( in_array( $question_type, array( 'blank', 'fill_in_the_blank', 'short_answer', 'long_answer' ) ) ) {
            // Check for conditional answers or other grading options
            $question_id = $question->get('id');
            $meta = get_post_meta( $question_id );
            
            $grading_options = array();
            if ( isset( $meta['_llms_case_sensitive'] ) ) {
                $grading_options['case_sensitive'] = $meta['_llms_case_sensitive'][0];
            }
            if ( isset( $meta['_llms_trim_whitespace'] ) ) {
                $grading_options['trim_whitespace'] = $meta['_llms_trim_whitespace'][0];
            }
            if ( isset( $meta['_llms_conditional_answer'] ) ) {
                $grading_options['conditional_answers'] = $meta['_llms_conditional_answer'][0];
            }
            
            if ( ! empty( $grading_options ) ) {
                error_log('CORRECT_ANSWER: Grading options: ' . print_r($grading_options, true));
            }
        }
    }
    
    /**
     * Debug function to inspect question data in database
     */
    private function debug_question_data( $question_id ) {
        global $wpdb;
        
        // Get ALL post meta for the question to see what's available
        $all_meta = get_post_meta( $question_id );
        
        error_log('DEBUG_QUESTION ' . $question_id . ': All meta keys available:');
        error_log('  Keys: ' . implode(', ', array_keys($all_meta)));
        
        // Look for specific fields that might affect grading
        $important_fields = array(
            '_llms_correct_answer',
            '_llms_correct',
            '_llms_auto_grade',
            '_llms_conditional_answer',
            '_llms_conditional_logic',
            '_llms_case_sensitive',
            '_llms_trim_whitespace',
            '_llms_question_type',
            '_llms_multi_choices',
            '_llms_points',
            '_llms_answer_type',
            '_llms_answer_options',
            '_llms_grading_type'
        );
        
        foreach ( $important_fields as $field ) {
            if ( isset( $all_meta[$field] ) ) {
                $value = $all_meta[$field][0];
                // Unserialize if needed
                $unserialized = @unserialize($value);
                if ($unserialized !== false) {
                    error_log('  ' . $field . ' = ' . print_r($unserialized, true));
                } else {
                    error_log('  ' . $field . ' = ' . $value);
                }
            }
        }
        
        // Also check choice data for this question
        $choices_meta = $wpdb->get_results( $wpdb->prepare(
            "SELECT meta_key, meta_value FROM {$wpdb->postmeta} WHERE post_id = %d AND meta_key LIKE '_llms_choice_%'",
            $question_id
        ), ARRAY_A );
        
        if ( ! empty($choices_meta) ) {
            error_log('  Choice data:');
            foreach ( $choices_meta as $meta ) {
                $value = @unserialize($meta['meta_value']);
                if ($value !== false && is_array($value)) {
                    error_log('    ' . $meta['meta_key'] . ' = ID:' . ($value['id'] ?? '?') . 
                             ', correct:' . ($value['correct'] ?? 'false') . 
                             ', marker:' . ($value['marker'] ?? '?'));
                }
            }
        }
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
        
        // Calculate actual points from questions
        $all_questions = $attempt->get_questions();
        $total_points_earned = 0;
        $total_points_possible = 0;
        $questions_correct = 0;
        
        foreach ( $all_questions as $q ) {
            if ( is_array( $q ) ) {
                $total_points_possible += isset($q['points']) ? floatval($q['points']) : 0;
                $total_points_earned += isset($q['earned']) ? floatval($q['earned']) : 0;
                if ( isset($q['correct']) && $q['correct'] ) {
                    $questions_correct++;
                }
            }
        }
        
        $results = array(
            'success' => true,
            'attempt' => array(
                'id' => $attempt_id,
                'status' => $attempt->get( 'status' ),
                'grade' => $attempt->get( 'grade' ),
                'passed' => $attempt->is_passing(),
                'points_earned' => $total_points_earned,
                'points_possible' => $total_points_possible,
                'questions_correct' => $questions_correct,
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
                    // Store the correct order first
                    $correct_order = array();
                    foreach ( $question_choices as $choice ) {
                        $choice_data = array(
                            'id' => $choice->get( 'id' ),
                            'order' => $choice->get( 'order' ),
                            'choice' => $choice->get( 'choice' ),
                        );
                        $choices[] = $choice_data;
                        $correct_order[] = $choice_data['id'];
                    }
                    
                    error_log('START_QUIZ: Reorder question CORRECT order: ' . implode(',', $correct_order));
                    
                    // DON'T shuffle - LifterLMS doesn't know about our shuffle
                    // The app should display them in the wrong order already from LifterLMS
                    // shuffle( $choices );
                    
                    $display_order = array_column($choices, 'id');
                    error_log('START_QUIZ: Reorder question order sent to app: ' . implode(',', $display_order));
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
        $question_type = $question->get( 'question_type' );
        
        // Determine if this question type can be auto-graded
        $auto_gradable = false;
        $grading_notes = '';
        
        if ( in_array( $question_type, array( 'choice', 'picture_choice', 'true_false' ) ) ) {
            $auto_gradable = true;
            $grading_notes = 'Auto-graded';
        } elseif ( $question_type === 'blank' || $question_type === 'fill_in_the_blank' ) {
            // Blank questions need a correct answer to be auto-gradable
            $correct_answer = $question->get( 'correct_answer' );
            $auto_gradable = ! empty( $correct_answer );
            $grading_notes = $auto_gradable ? 'Auto-graded (exact match)' : 'Manual grading (no correct answer)';
        } elseif ( $question_type === 'scale' ) {
            // Scale questions typically don't have correct answers
            $auto_gradable = false;
            $grading_notes = 'Opinion/scale - not graded';
        } elseif ( $question_type === 'reorder' ) {
            $auto_gradable = true;
            $grading_notes = 'Auto-graded (exact order)';
        } else {
            $grading_notes = 'Manual grading required';
        }
        
        $question_data = array(
            'id' => $question->get( 'id' ),
            'title' => $question->get( 'title' ),
            'content' => $question->get( 'content' ),
            'type' => $question_type,
            'points' => $question->get( 'points' ),
            'multi_choices' => $question->get( 'multi_choices' ) === 'yes',
            'description' => $question->get( 'description' ),
            'image' => $this->get_question_image( $question ),
            'video' => $question->get( 'video_src' ),
            'choices' => $this->get_question_choices( $question ),
            'answered' => false,
            'auto_gradable' => $auto_gradable,
            'grading_notes' => $grading_notes,
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
    
    /**
     * Grade blank/fill-in-the-blank questions (not supported in core LifterLMS)
     */
    public function grade_blank_question( $grade, $answer, $question ) {
        // Get the correct answer
        $correct_value = get_post_meta( $question->get( 'id' ), '_llms_correct_value', true );
        
        if ( empty( $correct_value ) ) {
            // No correct answer defined, needs manual grading
            return null;
        }
        
        // Convert answer to string for comparison
        $user_answer = is_array( $answer ) && count( $answer ) > 0 ? $answer[0] : $answer;
        $user_answer = strval( $user_answer );
        
        // Check case sensitivity setting
        $case_sensitive = get_post_meta( $question->get( 'id' ), '_llms_case_sensitive', true );
        
        if ( $case_sensitive !== 'yes' ) {
            $user_answer = strtolower( $user_answer );
            $correct_value = strtolower( $correct_value );
        }
        
        // Grade the answer
        return ( $user_answer === $correct_value ) ? 'yes' : 'no';
    }
    
    /**
     * Grade reorder questions (not supported in core LifterLMS)
     */
    public function grade_reorder_question( $grade, $answer, $question ) {
        // Get the correct order from choices
        $choices = $question->get_choices();
        if ( empty( $choices ) ) {
            return null;
        }
        
        // Build correct order array based on marker order
        $correct_order = array();
        foreach ( $choices as $choice ) {
            $marker = $choice->get( 'marker' );
            $id = $choice->get( 'id' );
            // Use marker as index to ensure correct order
            $correct_order[intval($marker)] = $id;
        }
        
        // Sort by marker to get correct sequence
        ksort( $correct_order );
        $correct_order = array_values( $correct_order );
        
        // Ensure answer is array
        if ( ! is_array( $answer ) ) {
            if ( is_string( $answer ) && strpos( $answer, ',' ) !== false ) {
                $answer = explode( ',', $answer );
            } else {
                $answer = array( $answer );
            }
        }
        
        // Compare arrays
        return ( $answer === $correct_order ) ? 'yes' : 'no';
    }
}

// Initialize quiz handler
LLMS_Mobile_Quiz_Handler::instance();
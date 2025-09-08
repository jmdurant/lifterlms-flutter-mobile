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
        
        // Check attempts limit
        if ( $quiz->get( 'allowed_attempts' ) > 0 ) {
            $attempts = $student->quizzes()->get_attempts_by_quiz( $quiz_id );
            $quiz_data['remaining_attempts'] = $quiz->get( 'allowed_attempts' ) - count( $attempts );
            
            if ( $quiz_data['remaining_attempts'] <= 0 ) {
                $quiz_data['can_take'] = false;
                $quiz_data['reason'] = 'No attempts remaining';
            }
        }
        
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
        
        // Initialize quiz attempt using LifterLMS
        $attempt = LLMS_Quiz_Attempt::init( $quiz_id, $lesson_id, $user_id );
        
        if ( ! $attempt ) {
            return new WP_Error( 'attempt_failed', 'Failed to start quiz attempt', array( 'status' => 500 ) );
        }
        
        // Start the attempt
        $attempt->start();
        
        // Get questions for this attempt
        $question_ids = $attempt->get_question_ids();
        
        // Format questions
        $questions = array();
        foreach ( $question_ids as $qid ) {
            $question = llms_get_post( $qid );
            
            if ( ! $question ) {
                continue;
            }
            
            $questions[] = $this->format_question_for_attempt( $question, $attempt );
        }
        
        return array(
            'success' => true,
            'attempt_id' => $attempt->get( 'attempt_id' ),
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
        
        // Get attempt
        $attempt = new LLMS_Quiz_Attempt( $attempt_id );
        
        if ( ! $attempt->exists() ) {
            return new WP_Error( 'attempt_not_found', 'Quiz attempt not found', array( 'status' => 404 ) );
        }
        
        // Verify attempt belongs to current user
        if ( $attempt->get( 'student_id' ) != get_current_user_id() ) {
            return new WP_Error( 'unauthorized', 'Unauthorized access', array( 'status' => 403 ) );
        }
        
        // Check if attempt is still in progress
        if ( $attempt->get( 'status' ) !== 'in-progress' ) {
            return new WP_Error( 'attempt_ended', 'This quiz attempt has ended', array( 'status' => 400 ) );
        }
        
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
        
        $results = array(
            'success' => true,
            'attempt_id' => $attempt_id,
            'grade' => $attempt->get( 'grade' ),
            'passed' => $attempt->is_passing(),
            'points_earned' => $attempt->get( 'earned_points' ),
            'points_possible' => $attempt->get( 'possible_points' ),
            'questions_correct' => $attempt->get_count( 'correct_answers' ),
            'questions_total' => $attempt->get_count( 'questions' ),
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
                
            case 'fill_in_the_blank':
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
        $question_ids = $attempt->get_question_ids();
        
        foreach ( $question_ids as $qid ) {
            $question = llms_get_post( $qid );
            $attempt_question = $attempt->get_question( $qid );
            
            if ( ! $question || ! $attempt_question ) {
                continue;
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
     * Permission callback
     */
    public function check_permissions() {
        return is_user_logged_in();
    }
}

// Initialize quiz handler
LLMS_Mobile_Quiz_Handler::instance();
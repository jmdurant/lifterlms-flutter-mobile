<?php
/**
 * Certificate Handler for LifterLMS Mobile App
 * 
 * Manages certificates earned through LifterLMS courses
 */

defined( 'ABSPATH' ) || exit;

/**
 * Certificate handler class
 */
class LLMS_Mobile_Certificate_Handler {
    
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
        
        // Get user's certificates
        register_rest_route( $namespace, '/mobile-app/certificates', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_user_certificates' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'course_id' => array(
                    'required' => false,
                    'type'     => 'integer',
                ),
                'limit' => array(
                    'required' => false,
                    'type'     => 'integer',
                    'default'  => 20,
                ),
                'page' => array(
                    'required' => false,
                    'type'     => 'integer',
                    'default'  => 1,
                ),
            ),
        ) );
        
        // Get specific certificate
        register_rest_route( $namespace, '/mobile-app/certificate/(?P<certificate_id>\d+)', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_certificate' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'certificate_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
            ),
        ) );
        
        // Download certificate PDF
        register_rest_route( $namespace, '/mobile-app/certificate/(?P<certificate_id>\d+)/download', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'download_certificate' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'certificate_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
            ),
        ) );
        
        // Get certificate HTML for display
        register_rest_route( $namespace, '/mobile-app/certificate/(?P<certificate_id>\d+)/html', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_certificate_html' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'certificate_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
            ),
        ) );
        
        // Share certificate
        register_rest_route( $namespace, '/mobile-app/certificate/(?P<certificate_id>\d+)/share', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'share_certificate' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'certificate_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
                'method' => array(
                    'required' => false,
                    'type'     => 'string',
                    'enum'     => array( 'email', 'link', 'social' ),
                    'default'  => 'link',
                ),
            ),
        ) );
        
        // Verify certificate authenticity
        register_rest_route( $namespace, '/mobile-app/certificate/verify', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'verify_certificate' ),
            'permission_callback' => '__return_true', // Public endpoint
            'args'                => array(
                'certificate_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
                'verification_code' => array(
                    'required' => false,
                    'type'     => 'string',
                ),
            ),
        ) );
        
        // Get certificates by course
        register_rest_route( $namespace, '/mobile-app/course/(?P<course_id>\d+)/certificates', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_course_certificates' ),
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
     * Get user's certificates
     */
    public function get_user_certificates( $request ) {
        $user_id = get_current_user_id();
        $course_id = $request->get_param( 'course_id' );
        $limit = $request->get_param( 'limit' );
        $page = $request->get_param( 'page' );
        
        $student = llms_get_student( $user_id );
        
        if ( ! $student ) {
            return new WP_Error( 'student_not_found', 'Student not found', array( 'status' => 404 ) );
        }
        
        // Get certificates
        $certificates_data = array();
        
        if ( $course_id ) {
            // Get certificates for specific course
            $certificate_ids = $student->get_certificates( $course_id );
        } else {
            // Get all certificates
            $query_args = array(
                'author' => $user_id,
                'post_type' => 'llms_my_certificate',
                'post_status' => 'publish',
                'posts_per_page' => $limit,
                'paged' => $page,
                'orderby' => 'date',
                'order' => 'DESC',
            );
            
            $query = new WP_Query( $query_args );
            $certificate_ids = wp_list_pluck( $query->posts, 'ID' );
        }
        
        foreach ( $certificate_ids as $cert_id ) {
            // Check if certificate post exists
            if ( ! get_post( $cert_id ) ) {
                continue;
            }
            
            $certificate = new LLMS_User_Certificate( $cert_id );
            
            $certificates_data[] = $this->format_certificate( $certificate );
        }
        
        return array(
            'success' => true,
            'certificates' => $certificates_data,
            'total' => count( $certificates_data ),
            'page' => $page,
        );
    }
    
    /**
     * Get specific certificate
     */
    public function get_certificate( $request ) {
        $certificate_id = $request->get_param( 'certificate_id' );
        $user_id = get_current_user_id();
        
        // Check if certificate post exists
        if ( ! get_post( $certificate_id ) ) {
            return new WP_Error( 'certificate_not_found', 'Certificate not found', array( 'status' => 404 ) );
        }
        
        $certificate = new LLMS_User_Certificate( $certificate_id );
        
        // Verify certificate belongs to user
        if ( $certificate->get_user_id() != $user_id ) {
            return new WP_Error( 'unauthorized', 'Unauthorized access', array( 'status' => 403 ) );
        }
        
        return array(
            'success' => true,
            'certificate' => $this->format_certificate( $certificate, true ),
        );
    }
    
    /**
     * Download certificate PDF
     */
    public function download_certificate( $request ) {
        $certificate_id = $request->get_param( 'certificate_id' );
        $user_id = get_current_user_id();
        
        // Check if certificate post exists
        if ( ! get_post( $certificate_id ) ) {
            return new WP_Error( 'certificate_not_found', 'Certificate not found', array( 'status' => 404 ) );
        }
        
        $certificate = new LLMS_User_Certificate( $certificate_id );
        
        // Verify certificate belongs to user
        if ( $certificate->get_user_id() != $user_id ) {
            return new WP_Error( 'unauthorized', 'Unauthorized access', array( 'status' => 403 ) );
        }
        
        // Get download URL
        $download_url = $certificate->get_download_url();
        
        if ( ! $download_url ) {
            // Generate PDF if not exists
            $download_url = $this->generate_certificate_pdf( $certificate );
        }
        
        return array(
            'success' => true,
            'download_url' => $download_url,
            'filename' => sanitize_file_name( $certificate->get( 'title' ) . '.pdf' ),
        );
    }
    
    /**
     * Get certificate HTML
     */
    public function get_certificate_html( $request ) {
        $certificate_id = $request->get_param( 'certificate_id' );
        $user_id = get_current_user_id();
        
        // Check if certificate post exists
        if ( ! get_post( $certificate_id ) ) {
            return new WP_Error( 'certificate_not_found', 'Certificate not found', array( 'status' => 404 ) );
        }
        
        $certificate = new LLMS_User_Certificate( $certificate_id );
        
        // Verify certificate belongs to user
        if ( $certificate->get_user_id() != $user_id ) {
            return new WP_Error( 'unauthorized', 'Unauthorized access', array( 'status' => 403 ) );
        }
        
        // Get certificate content with merge codes replaced
        $content = $certificate->get( 'content' );
        
        // Apply merge codes
        $content = $this->apply_merge_codes( $content, $certificate );
        
        // Add basic styling for mobile display
        $html = '<html><head>';
        $html .= '<meta name="viewport" content="width=device-width, initial-scale=1.0">';
        $html .= '<style>';
        $html .= 'body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }';
        $html .= '.certificate { max-width: 100%; background: white; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }';
        $html .= '.certificate h1 { text-align: center; color: #333; }';
        $html .= '.certificate h2 { text-align: center; color: #666; }';
        $html .= '.certificate .content { margin: 20px 0; }';
        $html .= '.certificate .footer { text-align: center; margin-top: 30px; font-size: 0.9em; color: #666; }';
        $html .= '</style>';
        $html .= '</head><body>';
        $html .= '<div class="certificate">';
        $html .= $content;
        $html .= '</div>';
        $html .= '</body></html>';
        
        return array(
            'success' => true,
            'html' => $html,
            'certificate_id' => $certificate_id,
        );
    }
    
    /**
     * Share certificate
     */
    public function share_certificate( $request ) {
        $certificate_id = $request->get_param( 'certificate_id' );
        $method = $request->get_param( 'method' );
        $user_id = get_current_user_id();
        
        // Check if certificate post exists
        if ( ! get_post( $certificate_id ) ) {
            return new WP_Error( 'certificate_not_found', 'Certificate not found', array( 'status' => 404 ) );
        }
        
        $certificate = new LLMS_User_Certificate( $certificate_id );
        
        // Verify certificate belongs to user
        if ( $certificate->get_user_id() != $user_id ) {
            return new WP_Error( 'unauthorized', 'Unauthorized access', array( 'status' => 403 ) );
        }
        
        $share_data = array(
            'success' => true,
            'method' => $method,
        );
        
        switch ( $method ) {
            case 'link':
                // Generate shareable link
                $share_data['share_url'] = $this->generate_share_link( $certificate );
                $share_data['message'] = sprintf(
                    'Check out my certificate: %s',
                    $certificate->get( 'title' )
                );
                break;
                
            case 'email':
                // Prepare email data
                $share_data['email_subject'] = sprintf(
                    'Certificate: %s',
                    $certificate->get( 'title' )
                );
                $share_data['email_body'] = sprintf(
                    "I've earned a certificate in %s!\n\nView certificate: %s",
                    $certificate->get( 'title' ),
                    $this->generate_share_link( $certificate )
                );
                break;
                
            case 'social':
                // Prepare social share data
                $share_data['title'] = $certificate->get( 'title' );
                $share_data['description'] = sprintf(
                    'I earned a certificate in %s',
                    $certificate->get( 'title' )
                );
                $share_data['url'] = $this->generate_share_link( $certificate );
                $share_data['image'] = $this->get_certificate_image( $certificate );
                break;
        }
        
        return $share_data;
    }
    
    /**
     * Verify certificate authenticity
     */
    public function verify_certificate( $request ) {
        $certificate_id = $request->get_param( 'certificate_id' );
        $verification_code = $request->get_param( 'verification_code' );
        
        // Check if certificate post exists
        if ( ! get_post( $certificate_id ) ) {
            return array(
                'success' => false,
                'valid' => false,
                'message' => 'Certificate not found',
            );
        }
        
        $certificate = new LLMS_User_Certificate( $certificate_id );
        
        // Verify certificate is valid
        $is_valid = true;
        
        // Check if certificate has been revoked
        if ( get_post_status( $certificate_id ) !== 'publish' ) {
            $is_valid = false;
        }
        
        // Verify with code if provided
        if ( $verification_code ) {
            $stored_code = get_post_meta( $certificate_id, '_llms_verification_code', true );
            if ( $stored_code && $stored_code !== $verification_code ) {
                $is_valid = false;
            }
        }
        
        if ( $is_valid ) {
            $user = get_userdata( $certificate->get_user_id() );
            $course = get_post( $certificate->get( 'parent' ) );
            
            return array(
                'success' => true,
                'valid' => true,
                'certificate' => array(
                    'id' => $certificate_id,
                    'title' => $certificate->get( 'title' ),
                    'earned_date' => $certificate->get_earned_date(),
                    'student_name' => $user ? $user->display_name : 'Unknown',
                    'course_title' => $course ? $course->post_title : 'Unknown',
                ),
                'message' => 'Certificate is valid and authentic',
            );
        }
        
        return array(
            'success' => true,
            'valid' => false,
            'message' => 'Certificate verification failed',
        );
    }
    
    /**
     * Get certificates for a course
     */
    public function get_course_certificates( $request ) {
        $course_id = $request->get_param( 'course_id' );
        $user_id = get_current_user_id();
        
        $student = llms_get_student( $user_id );
        
        if ( ! $student ) {
            return new WP_Error( 'student_not_found', 'Student not found', array( 'status' => 404 ) );
        }
        
        // Check if enrolled
        if ( ! $student->is_enrolled( $course_id ) ) {
            return array(
                'success' => true,
                'certificates' => array(),
                'message' => 'Not enrolled in this course',
            );
        }
        
        // Get certificates for course
        $certificate_ids = $student->get_certificates( $course_id );
        $certificates_data = array();
        
        foreach ( $certificate_ids as $cert_id ) {
            // Check if certificate post exists
            if ( ! get_post( $cert_id ) ) {
                continue;
            }
            
            $certificate = new LLMS_User_Certificate( $cert_id );
            
            $certificates_data[] = $this->format_certificate( $certificate );
        }
        
        // Get available certificates (not yet earned)
        $course = llms_get_post( $course_id );
        $available_certificates = array();
        
        if ( $course ) {
            // Get certificate templates for this course
            $templates = $course->get_certificates();
            
            foreach ( $templates as $template_id ) {
                // Check if not already earned
                $earned = false;
                foreach ( $certificate_ids as $earned_id ) {
                    $earned_cert = new LLMS_User_Certificate( $earned_id );
                    if ( $earned_cert->get( 'certificate_template' ) == $template_id ) {
                        $earned = true;
                        break;
                    }
                }
                
                if ( ! $earned ) {
                    $template = get_post( $template_id );
                    if ( $template ) {
                        $available_certificates[] = array(
                            'template_id' => $template_id,
                            'title' => $template->post_title,
                            'description' => $template->post_excerpt,
                            'requirements' => $this->get_certificate_requirements( $template_id, $course_id ),
                        );
                    }
                }
            }
        }
        
        return array(
            'success' => true,
            'earned' => $certificates_data,
            'available' => $available_certificates,
            'course_id' => $course_id,
        );
    }
    
    /**
     * Helper: Format certificate data
     */
    private function format_certificate( $certificate, $detailed = false ) {
        $data = array(
            'id' => $certificate->get( 'id' ),
            'title' => $certificate->get( 'title' ),
            'earned_date' => $certificate->get( 'earned_date' ),
            'course_id' => $certificate->get( 'parent' ),
            'course_title' => get_the_title( $certificate->get( 'parent' ) ),
            'preview_url' => get_permalink( $certificate->get( 'id' ) ),
            'download_url' => add_query_arg( 'download', 'true', get_permalink( $certificate->get( 'id' ) ) ),
        );
        
        if ( $detailed ) {
            // Add more details
            $user = get_userdata( $certificate->get( 'user_id' ) );
            $course = llms_get_post( $certificate->get( 'parent' ) );
            
            $data['student'] = array(
                'id' => $certificate->get( 'user_id' ),
                'name' => $user ? $user->display_name : '',
                'email' => $user ? $user->user_email : '',
            );
            
            if ( $course ) {
                $data['course'] = array(
                    'id' => $course->get( 'id' ),
                    'title' => $course->get( 'title' ),
                    'permalink' => get_permalink( $course->get( 'id' ) ),
                );
            }
            
            // Add certificate template info
            $template_id = $certificate->get( 'certificate_template' );
            if ( $template_id ) {
                $template = get_post( $template_id );
                if ( $template ) {
                    $data['template'] = array(
                        'id' => $template_id,
                        'title' => $template->post_title,
                    );
                }
            }
            
            // Add verification code if exists
            $verification_code = get_post_meta( $certificate->get( 'id' ), '_llms_verification_code', true );
            if ( $verification_code ) {
                $data['verification_code'] = $verification_code;
            }
        }
        
        return $data;
    }
    
    /**
     * Helper: Generate certificate PDF
     */
    private function generate_certificate_pdf( $certificate ) {
        // This would integrate with LifterLMS's PDF generation
        // For now, return the web URL
        return get_permalink( $certificate->get( 'id' ) ) . '?download=pdf';
    }
    
    /**
     * Helper: Apply merge codes to certificate content
     */
    private function apply_merge_codes( $content, $certificate ) {
        // Replace LifterLMS merge codes
        $user = get_userdata( $certificate->get_user_id() );
        $course = get_post( $certificate->get( 'parent' ) );
        
        $merge_codes = array(
            '{student_name}' => $user ? $user->display_name : '',
            '{student_first_name}' => $user ? $user->first_name : '',
            '{student_last_name}' => $user ? $user->last_name : '',
            '{student_email}' => $user ? $user->user_email : '',
            '{course_title}' => $course ? $course->post_title : '',
            '{earned_date}' => $certificate->get_earned_date(),
            '{certificate_title}' => $certificate->get( 'title' ),
            '{current_date}' => current_time( 'Y-m-d' ),
        );
        
        foreach ( $merge_codes as $code => $value ) {
            $content = str_replace( $code, $value, $content );
        }
        
        // Apply LifterLMS merge codes
        if ( class_exists( 'LLMS_Merge_Codes' ) ) {
            $merge = new LLMS_Merge_Codes();
            $content = $merge->replace_all( $content, $user, $course );
        }
        
        return $content;
    }
    
    /**
     * Helper: Generate shareable link
     */
    private function generate_share_link( $certificate ) {
        return get_permalink( $certificate->get( 'id' ) );
    }
    
    /**
     * Helper: Get certificate image
     */
    private function get_certificate_image( $certificate ) {
        // Check if certificate has featured image
        $thumbnail_id = get_post_thumbnail_id( $certificate->get( 'id' ) );
        
        if ( $thumbnail_id ) {
            return wp_get_attachment_url( $thumbnail_id );
        }
        
        // Return default certificate image
        return LLMS_MOBILE_APP_URL . 'assets/images/default-certificate.png';
    }
    
    /**
     * Helper: Get certificate requirements
     */
    private function get_certificate_requirements( $template_id, $course_id ) {
        $requirements = array();
        
        // Get engagement triggers for this certificate
        $triggers = get_post_meta( $template_id, '_llms_engagement_triggers', true );
        
        if ( $triggers ) {
            foreach ( $triggers as $trigger ) {
                $requirements[] = $this->format_requirement( $trigger );
            }
        } else {
            // Default requirement is course completion
            $requirements[] = array(
                'type' => 'course_completed',
                'description' => 'Complete the course',
                'progress' => $this->get_course_progress( $course_id ),
            );
        }
        
        return $requirements;
    }
    
    /**
     * Helper: Format requirement
     */
    private function format_requirement( $trigger ) {
        $requirement = array(
            'type' => $trigger['type'] ?? 'unknown',
            'description' => '',
            'progress' => 0,
        );
        
        switch ( $requirement['type'] ) {
            case 'course_completed':
                $requirement['description'] = 'Complete the course';
                break;
                
            case 'course_passed':
                $requirement['description'] = 'Pass the course';
                break;
                
            case 'quiz_passed':
                $requirement['description'] = 'Pass all quizzes';
                break;
                
            default:
                $requirement['description'] = 'Meet course requirements';
        }
        
        return $requirement;
    }
    
    /**
     * Helper: Get course progress
     */
    private function get_course_progress( $course_id ) {
        $student = llms_get_student( get_current_user_id() );
        
        if ( $student ) {
            return $student->get_progress( $course_id, 'course' );
        }
        
        return 0;
    }
    
    /**
     * Permission callback
     */
    public function check_permissions() {
        return is_user_logged_in();
    }
}

// Initialize certificate handler
LLMS_Mobile_Certificate_Handler::instance();
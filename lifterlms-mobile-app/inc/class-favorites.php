<?php
/**
 * Favorites Handler for LifterLMS Mobile App
 * 
 * Handles favorites/wishlist functionality for courses and course content
 */

defined( 'ABSPATH' ) || exit;

/**
 * Favorites class
 */
class LLMS_Mobile_Favorites {
    
    /**
     * Instance
     */
    private static $instance = null;
    
    /**
     * Table name
     */
    private $table_name;
    
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
        global $wpdb;
        $this->table_name = $wpdb->prefix . 'llms_mobile_favorites';
        
        // Register REST API routes
        add_action( 'rest_api_init', array( $this, 'register_routes' ) );
    }
    
    /**
     * Register REST API routes
     */
    public function register_routes() {
        $namespace = 'llms/v1';
        
        // Get user favorites
        register_rest_route( $namespace, '/favorites', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_favorites' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'type' => array(
                    'required' => false,
                    'type'     => 'string',
                    'enum'     => array( 'course', 'lesson', 'section', 'all' ),
                    'default'  => 'all',
                ),
            ),
        ) );
        
        // Toggle favorite
        register_rest_route( $namespace, '/favorites/toggle', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'toggle_favorite' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'object_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
                'object_type' => array(
                    'required' => true,
                    'type'     => 'string',
                    'enum'     => array( 'course', 'lesson', 'section' ),
                ),
            ),
        ) );
        
        // Add favorite
        register_rest_route( $namespace, '/favorites/add', array(
            'methods'             => 'POST',
            'callback'            => array( $this, 'add_favorite' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'object_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
                'object_type' => array(
                    'required' => true,
                    'type'     => 'string',
                    'enum'     => array( 'course', 'lesson', 'section' ),
                ),
            ),
        ) );
        
        // Remove favorite
        register_rest_route( $namespace, '/favorites/remove', array(
            'methods'             => 'DELETE',
            'callback'            => array( $this, 'remove_favorite' ),
            'permission_callback' => array( $this, 'check_permissions' ),
            'args'                => array(
                'object_id' => array(
                    'required' => true,
                    'type'     => 'integer',
                ),
                'object_type' => array(
                    'required' => true,
                    'type'     => 'string',
                    'enum'     => array( 'course', 'lesson', 'section' ),
                ),
            ),
        ) );
        
        // Check if favorited
        register_rest_route( $namespace, '/favorites/check/(?P<object_type>course|lesson|section)/(?P<object_id>\d+)', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'check_favorite' ),
            'permission_callback' => array( $this, 'check_permissions' ),
        ) );
        
        // Get favorite courses with details
        register_rest_route( $namespace, '/favorites/courses', array(
            'methods'             => 'GET',
            'callback'            => array( $this, 'get_favorite_courses' ),
            'permission_callback' => array( $this, 'check_permissions' ),
        ) );
    }
    
    /**
     * Get user favorites
     */
    public function get_favorites( $request ) {
        global $wpdb;
        
        $user_id = get_current_user_id();
        $type = $request->get_param( 'type' );
        
        $where = "user_id = %d";
        $prepare_args = array( $user_id );
        
        if ( $type !== 'all' ) {
            $where .= " AND object_type = %s";
            $prepare_args[] = $type;
        }
        
        $results = $wpdb->get_results( $wpdb->prepare(
            "SELECT * FROM {$this->table_name} WHERE $where ORDER BY created_at DESC",
            $prepare_args
        ) );
        
        return array(
            'success' => true,
            'favorites' => $results,
            'count' => count( $results ),
        );
    }
    
    /**
     * Toggle favorite status
     */
    public function toggle_favorite( $request ) {
        $user_id = get_current_user_id();
        $object_id = $request->get_param( 'object_id' );
        $object_type = $request->get_param( 'object_type' );
        
        if ( $this->is_favorite( $user_id, $object_id, $object_type ) ) {
            return $this->remove_favorite_internal( $user_id, $object_id, $object_type );
        } else {
            return $this->add_favorite_internal( $user_id, $object_id, $object_type );
        }
    }
    
    /**
     * Add favorite
     */
    public function add_favorite( $request ) {
        $user_id = get_current_user_id();
        $object_id = $request->get_param( 'object_id' );
        $object_type = $request->get_param( 'object_type' );
        
        return $this->add_favorite_internal( $user_id, $object_id, $object_type );
    }
    
    /**
     * Remove favorite
     */
    public function remove_favorite( $request ) {
        $user_id = get_current_user_id();
        $object_id = $request->get_param( 'object_id' );
        $object_type = $request->get_param( 'object_type' );
        
        return $this->remove_favorite_internal( $user_id, $object_id, $object_type );
    }
    
    /**
     * Check if item is favorited
     */
    public function check_favorite( $request ) {
        $user_id = get_current_user_id();
        $object_id = $request->get_param( 'object_id' );
        $object_type = $request->get_param( 'object_type' );
        
        $is_favorite = $this->is_favorite( $user_id, $object_id, $object_type );
        
        return array(
            'success' => true,
            'is_favorite' => $is_favorite,
            'object_id' => $object_id,
            'object_type' => $object_type,
        );
    }
    
    /**
     * Get favorite courses with full details
     */
    public function get_favorite_courses( $request ) {
        global $wpdb;
        
        $user_id = get_current_user_id();
        
        // Get favorite course IDs
        $favorites = $wpdb->get_results( $wpdb->prepare(
            "SELECT object_id, created_at FROM {$this->table_name} 
             WHERE user_id = %d AND object_type = 'course' 
             ORDER BY created_at DESC",
            $user_id
        ) );
        
        if ( empty( $favorites ) ) {
            return array(
                'success' => true,
                'courses' => array(),
                'count' => 0,
            );
        }
        
        $courses = array();
        
        foreach ( $favorites as $favorite ) {
            $course = new LLMS_Course( $favorite->object_id );
            
            if ( ! $course->exists() ) {
                continue;
            }
            
            // Build course data
            $course_data = array(
                'id' => $course->get( 'id' ),
                'title' => $course->get( 'title' ),
                'content' => $course->get( 'content' ),
                'excerpt' => $course->get( 'excerpt' ),
                'permalink' => get_permalink( $course->get( 'id' ) ),
                'featured_image' => get_the_post_thumbnail_url( $course->get( 'id' ), 'full' ),
                'favorited_at' => $favorite->created_at,
                'is_favorite' => true,
                
                // Course meta
                'price' => $course->get_price(),
                'on_sale' => $course->on_sale(),
                'sale_price' => $course->get_sale_price(),
                'regular_price' => $course->get_regular_price(),
                
                // Progress info if enrolled
                'is_enrolled' => llms_is_user_enrolled( $user_id, $course->get( 'id' ) ),
                'progress' => 0,
            );
            
            // Add progress if enrolled
            if ( $course_data['is_enrolled'] ) {
                $student = llms_get_student( $user_id );
                if ( $student ) {
                    $course_data['progress'] = $student->get_progress( $course->get( 'id' ), 'course' );
                }
            }
            
            // Add instructor info
            $instructors = $course->get_instructors();
            if ( ! empty( $instructors ) ) {
                $instructor = get_userdata( $instructors[0]['id'] );
                if ( $instructor ) {
                    $course_data['instructor'] = array(
                        'id' => $instructor->ID,
                        'name' => $instructor->display_name,
                        'avatar' => get_avatar_url( $instructor->ID ),
                    );
                }
            }
            
            // Add course categories
            $categories = wp_get_post_terms( $course->get( 'id' ), 'course_cat', array( 'fields' => 'names' ) );
            $course_data['categories'] = $categories;
            
            // Add difficulty and duration
            $course_data['difficulty'] = $course->get( 'difficulty' );
            $course_data['duration'] = $course->get( 'length' );
            
            // Add total lessons/sections
            $sections = $course->get_sections();
            $total_lessons = 0;
            foreach ( $sections as $section ) {
                $total_lessons += count( $section->get_lessons() );
            }
            $course_data['total_sections'] = count( $sections );
            $course_data['total_lessons'] = $total_lessons;
            
            $courses[] = $course_data;
        }
        
        return array(
            'success' => true,
            'courses' => $courses,
            'count' => count( $courses ),
        );
    }
    
    /**
     * Internal method to add favorite
     */
    private function add_favorite_internal( $user_id, $object_id, $object_type ) {
        global $wpdb;
        
        // Check if already favorited
        if ( $this->is_favorite( $user_id, $object_id, $object_type ) ) {
            return array(
                'success' => true,
                'message' => 'Already favorited',
                'is_favorite' => true,
            );
        }
        
        // Validate object exists
        if ( ! $this->validate_object( $object_id, $object_type ) ) {
            return new WP_Error( 'invalid_object', 'Invalid object ID or type', array( 'status' => 400 ) );
        }
        
        // Add to favorites
        $result = $wpdb->insert(
            $this->table_name,
            array(
                'user_id' => $user_id,
                'object_id' => $object_id,
                'object_type' => $object_type,
                'created_at' => current_time( 'mysql' ),
            ),
            array( '%d', '%d', '%s', '%s' )
        );
        
        if ( $result === false ) {
            return new WP_Error( 'database_error', 'Failed to add favorite', array( 'status' => 500 ) );
        }
        
        // Trigger action hook
        do_action( 'llms_mobile_favorite_added', $user_id, $object_id, $object_type );
        
        return array(
            'success' => true,
            'message' => 'Added to favorites',
            'is_favorite' => true,
        );
    }
    
    /**
     * Internal method to remove favorite
     */
    private function remove_favorite_internal( $user_id, $object_id, $object_type ) {
        global $wpdb;
        
        $result = $wpdb->delete(
            $this->table_name,
            array(
                'user_id' => $user_id,
                'object_id' => $object_id,
                'object_type' => $object_type,
            ),
            array( '%d', '%d', '%s' )
        );
        
        if ( $result === false ) {
            return new WP_Error( 'database_error', 'Failed to remove favorite', array( 'status' => 500 ) );
        }
        
        // Trigger action hook
        do_action( 'llms_mobile_favorite_removed', $user_id, $object_id, $object_type );
        
        return array(
            'success' => true,
            'message' => 'Removed from favorites',
            'is_favorite' => false,
        );
    }
    
    /**
     * Check if item is favorited
     */
    private function is_favorite( $user_id, $object_id, $object_type ) {
        global $wpdb;
        
        $count = $wpdb->get_var( $wpdb->prepare(
            "SELECT COUNT(*) FROM {$this->table_name} 
             WHERE user_id = %d AND object_id = %d AND object_type = %s",
            $user_id,
            $object_id,
            $object_type
        ) );
        
        return $count > 0;
    }
    
    /**
     * Validate object exists
     */
    private function validate_object( $object_id, $object_type ) {
        switch ( $object_type ) {
            case 'course':
                $course = new LLMS_Course( $object_id );
                return $course->exists();
                
            case 'lesson':
                $lesson = new LLMS_Lesson( $object_id );
                return $lesson->exists();
                
            case 'section':
                $section = new LLMS_Section( $object_id );
                return $section->exists();
                
            default:
                return false;
        }
    }
    
    /**
     * Permission callback
     */
    public function check_permissions() {
        return is_user_logged_in();
    }
    
    /**
     * Get user's favorite count
     */
    public function get_user_favorite_count( $user_id, $object_type = null ) {
        global $wpdb;
        
        $where = "user_id = %d";
        $prepare_args = array( $user_id );
        
        if ( $object_type ) {
            $where .= " AND object_type = %s";
            $prepare_args[] = $object_type;
        }
        
        return $wpdb->get_var( $wpdb->prepare(
            "SELECT COUNT(*) FROM {$this->table_name} WHERE $where",
            $prepare_args
        ) );
    }
    
    /**
     * Clear user favorites
     */
    public function clear_user_favorites( $user_id, $object_type = null ) {
        global $wpdb;
        
        $where = array( 'user_id' => $user_id );
        $format = array( '%d' );
        
        if ( $object_type ) {
            $where['object_type'] = $object_type;
            $format[] = '%s';
        }
        
        return $wpdb->delete( $this->table_name, $where, $format );
    }
}

// Initialize favorites
LLMS_Mobile_Favorites::instance();
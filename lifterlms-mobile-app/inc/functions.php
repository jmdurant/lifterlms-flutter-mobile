<?php
/**
 * Helper functions for LifterLMS Mobile App
 */

defined( 'ABSPATH' ) || exit;

/**
 * Check if IAP is enabled
 */
function llms_mobile_is_iap_enabled() {
    return get_option( 'llms_mobile_iap_enabled', 'yes' ) === 'yes';
}

/**
 * Check if push notifications are enabled
 */
function llms_mobile_is_push_enabled() {
    return get_option( 'llms_mobile_push_enabled', 'no' ) === 'yes';
}

/**
 * Check if social login is enabled
 */
function llms_mobile_is_social_enabled() {
    return get_option( 'llms_mobile_social_enabled', 'no' ) === 'yes';
}

/**
 * Get IAP course IDs
 */
function llms_mobile_get_iap_course_ids() {
    $course_ids = get_option( 'llms_mobile_iap_course_ids', '' );
    
    if ( empty( $course_ids ) ) {
        return array();
    }
    
    $course_ids = explode( ',', $course_ids );
    $course_ids = array_map( 'trim', $course_ids );
    $course_ids = array_map( 'intval', $course_ids );
    
    return array_filter( $course_ids );
}

/**
 * Check if course is available for IAP
 */
function llms_mobile_is_course_iap( $course_id ) {
    $iap_courses = llms_mobile_get_iap_course_ids();
    return in_array( intval( $course_id ), $iap_courses );
}

/**
 * Get mobile app settings
 */
function llms_mobile_get_settings() {
    return array(
        'iap_enabled' => llms_mobile_is_iap_enabled(),
        'push_enabled' => llms_mobile_is_push_enabled(),
        'social_enabled' => llms_mobile_is_social_enabled(),
        'iap_courses' => llms_mobile_get_iap_course_ids(),
        'apple_sandbox' => get_option( 'llms_mobile_apple_sandbox', 'no' ) === 'yes',
    );
}

/**
 * Send push notification to user
 */
function llms_mobile_send_push_notification( $user_id, $title, $body, $data = array() ) {
    if ( ! llms_mobile_is_push_enabled() ) {
        return false;
    }
    
    if ( class_exists( 'LLMS_Mobile_Push_Notifications' ) ) {
        $push = new LLMS_Mobile_Push_Notifications();
        return $push->send_notification( $user_id, $title, $body, $data );
    }
    
    return false;
}

/**
 * Log mobile app activity
 */
function llms_mobile_log( $message, $type = 'info' ) {
    if ( defined( 'WP_DEBUG' ) && WP_DEBUG ) {
        error_log( sprintf( '[LLMS Mobile %s]: %s', strtoupper( $type ), $message ) );
    }
}

/**
 * Get user's mobile devices
 */
function llms_mobile_get_user_devices( $user_id ) {
    global $wpdb;
    
    $table_name = $wpdb->prefix . 'llms_mobile_devices';
    
    return $wpdb->get_results( $wpdb->prepare(
        "SELECT * FROM $table_name WHERE user_id = %d AND active = 1",
        $user_id
    ) );
}

/**
 * Check if user has mobile app
 */
function llms_mobile_user_has_app( $user_id ) {
    $devices = llms_mobile_get_user_devices( $user_id );
    return ! empty( $devices );
}

/**
 * Format price for mobile app
 */
function llms_mobile_format_price( $price ) {
    return array(
        'raw' => $price,
        'formatted' => llms_price( $price ),
        'currency' => get_lifterlms_currency_symbol(),
    );
}

/**
 * Get course data for mobile app
 */
function llms_mobile_get_course_data( $course_id ) {
    $course = new LLMS_Course( $course_id );
    
    if ( ! $course->exists() ) {
        return false;
    }
    
    return array(
        'id' => $course->get( 'id' ),
        'title' => $course->get( 'title' ),
        'description' => $course->get( 'excerpt' ),
        'image' => get_the_post_thumbnail_url( $course_id, 'full' ),
        'price' => llms_mobile_format_price( $course->get_price() ),
        'is_free' => $course->is_free(),
        'is_iap' => llms_mobile_is_course_iap( $course_id ),
        'instructor' => array(
            'id' => $course->get_instructor()->get( 'id' ),
            'name' => $course->get_instructor()->get_name(),
            'avatar' => get_avatar_url( $course->get_instructor()->get( 'id' ) ),
        ),
        'duration' => $course->get( 'length' ),
        'difficulty' => $course->get_difficulty(),
        'categories' => wp_get_post_terms( $course_id, 'course_cat', array( 'fields' => 'names' ) ),
        'tags' => wp_get_post_terms( $course_id, 'course_tag', array( 'fields' => 'names' ) ),
    );
}
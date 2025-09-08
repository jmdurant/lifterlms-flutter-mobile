<?php
/**
 * LifterLMS Mobile App Settings Page
 */

defined( 'ABSPATH' ) || exit;

class LLMS_Settings_Mobile_App extends LLMS_Settings_Page {
    
    /**
     * Constructor
     */
    public function __construct() {
        $this->id    = 'mobile_app';
        $this->label = __( 'Mobile App', 'lifterlms-mobile-app' );
        
        add_filter( 'lifterlms_settings_tabs_array', array( $this, 'add_settings_page' ), 20 );
        add_action( 'lifterlms_settings_' . $this->id, array( $this, 'output' ) );
        add_action( 'lifterlms_settings_save_' . $this->id, array( $this, 'save' ) );
    }
    
    /**
     * Get settings array
     */
    public function get_settings() {
        return apply_filters( 'llms_mobile_app_settings', array(
            
            // In-App Purchase Settings
            array(
                'type'  => 'sectionstart',
                'id'    => 'llms_mobile_iap_settings',
                'class' => 'top',
            ),
            
            array(
                'title' => __( 'In-App Purchase Settings', 'lifterlms-mobile-app' ),
                'type'  => 'title',
                'desc'  => __( 'Configure in-app purchase settings for mobile app.', 'lifterlms-mobile-app' ),
                'id'    => 'llms_mobile_iap_settings_title',
            ),
            
            array(
                'title'   => __( 'IAP Course IDs', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enter course IDs separated by comma (e.g., 1,2,3). These courses will be available for in-app purchase.', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_iap_course_ids',
                'type'    => 'text',
                'default' => '',
            ),
            
            array(
                'title'   => __( 'Apple Sandbox Mode', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enable sandbox mode for testing Apple in-app purchases', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_apple_sandbox',
                'type'    => 'checkbox',
                'default' => 'no',
            ),
            
            array(
                'title'   => __( 'Apple Shared Secret', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enter your Apple shared secret for receipt validation. Get this from App Store Connect.', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_apple_shared_secret',
                'type'    => 'password',
                'default' => '',
            ),
            
            array(
                'title'   => __( 'Google Service Account JSON', 'lifterlms-mobile-app' ),
                'desc'    => $this->get_google_service_account_description(),
                'id'      => 'llms_mobile_google_service_account',
                'type'    => 'textarea',
                'default' => '',
                'css'     => 'width:100%; height: 200px;',
            ),
            
            array(
                'type' => 'sectionend',
                'id'   => 'llms_mobile_iap_settings',
            ),
            
            // Push Notifications Settings
            array(
                'type'  => 'sectionstart',
                'id'    => 'llms_mobile_push_settings',
            ),
            
            array(
                'title' => __( 'Push Notifications', 'lifterlms-mobile-app' ),
                'type'  => 'title',
                'desc'  => __( 'Configure push notifications for mobile app.', 'lifterlms-mobile-app' ),
                'id'    => 'llms_mobile_push_settings_title',
            ),
            
            array(
                'title'   => __( 'Enable Push Notifications', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enable push notifications for mobile app users', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_push_enabled',
                'type'    => 'checkbox',
                'default' => 'no',
            ),
            
            array(
                'title'   => __( 'Firebase Project ID', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enter your Firebase project ID', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_firebase_project_id',
                'type'    => 'text',
                'default' => '',
            ),
            
            array(
                'title'   => __( 'Firebase Service Account JSON', 'lifterlms-mobile-app' ),
                'desc'    => $this->get_firebase_service_account_description(),
                'id'      => 'llms_mobile_firebase_service_account',
                'type'    => 'textarea',
                'default' => '',
                'css'     => 'width:100%; height: 200px;',
            ),
            
            array(
                'type' => 'sectionend',
                'id'   => 'llms_mobile_push_settings',
            ),
            
            // Social Login Settings
            array(
                'type'  => 'sectionstart',
                'id'    => 'llms_mobile_social_settings',
            ),
            
            array(
                'title' => __( 'Social Login', 'lifterlms-mobile-app' ),
                'type'  => 'title',
                'desc'  => __( 'Configure social login for mobile app.', 'lifterlms-mobile-app' ),
                'id'    => 'llms_mobile_social_settings_title',
            ),
            
            array(
                'title'   => __( 'Enable Social Login', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enable social login for mobile app users', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_social_enabled',
                'type'    => 'checkbox',
                'default' => 'no',
            ),
            
            array(
                'title'   => __( 'Facebook App ID', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enter your Facebook App ID', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_fb_client_id',
                'type'    => 'text',
                'default' => '',
            ),
            
            array(
                'title'   => __( 'Facebook App Secret', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enter your Facebook App Secret', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_fb_client_secret',
                'type'    => 'password',
                'default' => '',
            ),
            
            array(
                'title'   => __( 'Google Web Client ID', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enter your Google Web Client ID', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_google_client_id',
                'type'    => 'text',
                'default' => '',
            ),
            
            array(
                'type' => 'sectionend',
                'id'   => 'llms_mobile_social_settings',
            ),
            
            // Stripe Payment Settings
            array(
                'type'  => 'sectionstart',
                'id'    => 'llms_mobile_stripe_settings',
            ),
            
            array(
                'title' => __( 'Stripe Payments', 'lifterlms-mobile-app' ),
                'type'  => 'title',
                'desc'  => __( 'Configure Stripe payment gateway for mobile app.', 'lifterlms-mobile-app' ),
                'id'    => 'llms_mobile_stripe_settings_title',
            ),
            
            array(
                'title'   => __( 'Enable Stripe Payments', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enable Stripe payment gateway for mobile app users', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_stripe_enabled',
                'type'    => 'checkbox',
                'default' => 'no',
            ),
            
            array(
                'title'   => __( 'Test Mode', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enable test mode to use Stripe test API keys', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_stripe_test_mode',
                'type'    => 'checkbox',
                'default' => 'yes',
            ),
            
            array(
                'title'   => __( 'Test Publishable Key', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enter your Stripe test publishable key (pk_test_...)', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_stripe_test_publishable_key',
                'type'    => 'text',
                'default' => '',
            ),
            
            array(
                'title'   => __( 'Test Secret Key', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enter your Stripe test secret key (sk_test_...)', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_stripe_test_secret_key',
                'type'    => 'password',
                'default' => '',
            ),
            
            array(
                'title'   => __( 'Live Publishable Key', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enter your Stripe live publishable key (pk_live_...)', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_stripe_live_publishable_key',
                'type'    => 'text',
                'default' => '',
            ),
            
            array(
                'title'   => __( 'Live Secret Key', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enter your Stripe live secret key (sk_live_...)', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_stripe_live_secret_key',
                'type'    => 'password',
                'default' => '',
            ),
            
            array(
                'title'   => __( 'Webhook Endpoint Secret', 'lifterlms-mobile-app' ),
                'desc'    => sprintf( 
                    __( 'Enter your webhook endpoint secret from Stripe. Configure webhook URL as: %s', 'lifterlms-mobile-app' ),
                    '<code>' . get_site_url() . '/wp-json/llms/v1/mobile-app/stripe/webhook</code>'
                ),
                'id'      => 'llms_mobile_stripe_webhook_secret',
                'type'    => 'password',
                'default' => '',
            ),
            
            array(
                'title'   => __( 'Statement Descriptor', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Text that appears on customer credit card statements (max 22 characters)', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_stripe_statement_descriptor',
                'type'    => 'text',
                'default' => get_bloginfo( 'name' ),
            ),
            
            array(
                'title'   => __( 'Payment Methods', 'lifterlms-mobile-app' ),
                'desc'    => __( 'Enable saving payment methods for future purchases', 'lifterlms-mobile-app' ),
                'id'      => 'llms_mobile_stripe_save_payment_methods',
                'type'    => 'checkbox',
                'default' => 'yes',
            ),
            
            array(
                'type' => 'sectionend',
                'id'   => 'llms_mobile_stripe_settings',
            ),
            
        ) );
    }
    
    /**
     * Get Google service account description
     */
    private function get_google_service_account_description() {
        return '<ol>
            <li>Go to the <a href="https://console.cloud.google.com/" target="_blank">Google Cloud Console</a></li>
            <li>Select your project or create a new one</li>
            <li>Go to IAM & Admin > Service Accounts</li>
            <li>Create a new service account</li>
            <li>Download the JSON key file</li>
            <li>Paste the entire JSON content here</li>
        </ol>';
    }
    
    /**
     * Get Firebase service account description
     */
    private function get_firebase_service_account_description() {
        return '<ol>
            <li>Go to the <a href="https://console.firebase.google.com/" target="_blank">Firebase Console</a></li>
            <li>Select your project</li>
            <li>Go to Project Settings > Service Accounts</li>
            <li>Click "Generate new private key"</li>
            <li>Download the JSON file</li>
            <li>Paste the entire JSON content here</li>
        </ol>';
    }
}

return new LLMS_Settings_Mobile_App();
<?php
if ( ! class_exists( 'LP_Mobile_App_Purchase_Settings' ) ) {
	class LP_Mobile_App_Purchase_Settings extends LP_Abstract_Settings_Page {
		/**
		 * Constructor
		 */
		public function __construct() {
			$this->id   = 'mobile_app';
			$this->text = esc_html__( 'Mobile App', 'learnpress-mobile-app' );

			parent::__construct();
		}

		public function get_settings( $section = '', $tab = '' ) {
			return $this->setting_v4();
		}

		public function setting_v4() {
			$settings = array(
				array(
					'type'  => 'title',
					'title' => esc_html__( 'In App Purchase', 'learnpress' ),
				),
				array(
					'name'    => esc_html__( 'Courses In App Purchase', 'learnpress-mobile-app' ),
					'id'      => 'in_app_purchase_course_ids',
					'type'    => 'text',
					'default' => '',
					'desc'    => 'Enter course ids separated by comma. Example: 1,2,3',
				),
				array(
					'name'    => esc_html__( 'Enable Apple Sanbox', 'learnpress-mobile-app' ),
					'desc'    => esc_html__( 'Enable Sanbox', 'learnpress-mobile-app' ),
					'id'      => 'in_app_purchase_apple_sandbox',
					'type'    => 'checkbox',
					'default' => false,
				),
				array(
					'name'    => esc_html__( 'Apple Shared Secret.', 'learnpress-mobile-app' ),
					'id'      => 'in_app_purchase_apple_shared_secret',
					'type'    => 'text',
					'default' => '',
				),
				array(
					'name'    => esc_html__( 'Google Play Service Account Json', 'learnpress-mobile-app' ),
					'id'      => 'in_app_purchase_service_account',
					'type'    => 'html',
					'default' => '
					<textarea name="learn_press_in_app_purchase_service_account" id="learn_press_in_app_purchase_service_account" style="width: 400px">' . get_option( 'learn_press_in_app_purchase_service_account', '' ) . '</textarea>
					<ol>
						<li>Go to the Google Cloud Console (<a href="https://console.cloud.google.com/" target="_new">https://console.cloud.google.com/</a>).</li>
						<li>Make sure you are signed in with the Google account that is associated with your Google Play Developer account.</li>
						<li>Click on the project that you want to use for verifying receipts and validating purchases. If you don\'t have a project set up yet, you will need to create one.</li>
						<li>In the side menu, click on the "IAM &amp; Admin" option.</li><li>In the IAM &amp; Admin menu, click on the "Service Accounts" option.</li>
						<li>Click on the "Create Service Account" button.</li><li>Give your service account a name and description.</li><li>Click on the "Create" button.</li>
						<li>In the "Create Service Account Key" modal, select the "JSON" key type and then click on the "Create" button.</li>
						<li>Your service account JSON file will be downloaded to your computer.</li>
					</ol>',
				),
				array(
					'type' => 'sectionend',
					'id'   => 'lp_profile_general',
				),
				array(
					'type'  => 'title',
					'title' => esc_html__( 'Push Notifications', 'learnpress-mobile-app' ),
				),
				array(
					'name'    => esc_html__( 'Enable Push Notifications', 'learnpress-mobile-app' ),
					'desc'    => esc_html__( 'Enable Push Notifications', 'learnpress-mobile-app' ),
					'id'      => 'lp_push_notification_enable',
					'type'    => 'checkbox',
					'default' => false,
				),
				array(
					'name'    => esc_html__( 'Firebase Project ID.', 'learnpress-mobile-app' ),
					'id'      => 'lp_push_notification_project_id',
					'type'    => 'text',
					'default' => '',
					'desc'    => 'You can find it in your Firebase project settings. <a href="https://console.cloud.google.com/project/_/settings/general/" target="_blank">General project settings</a>',
				),
				array(
					'name'    => esc_html__( 'Firebase Service Account Json', 'learnpress-mobile-app' ),
					'id'      => 'lp_push_notification_service_account',
					'type'    => 'html',
					'default' => '
					<textarea name="learn_press_lp_push_notification_service_account" id="learn_press_lp_push_notification_service_account" rows="4" style="width: 400px">' . get_option( 'learn_press_lp_push_notification_service_account', '' ) . '</textarea>
					<ol>
						<li>Go to the Firebase console <a href="https://console.firebase.google.com/" target="_blank">https://console.firebase.google.com/</a></li>
						<li>Click on the project that you want to access the service account for.</li>
						<li>Click on the gear icon next to the project name and select Project settings.</li>
						<li>Click on the Service accounts tab.</li>
						<li>Under the "Firebase Admin SDK" section, click on the "Generate new private key" button. This will download the service account JSON file to your computer.</li>
					</ol>
					',
				),
				array(
					'type' => 'sectionend',
				),
				array(
					'type'  => 'title',
					'title' => esc_html__( 'Social Login', 'learnpress-mobile-app' ),
				),
				array(
					'name'    => esc_html__( 'Enable Social Login', 'learnpress-mobile-app' ),
					'id'      => 'mobile_enable_social_login',
					'type'    => 'checkbox',
					'default' => false,
				),
				array(
					'name'    => esc_html__( 'Facebook Client ID.', 'learnpress-mobile-app' ),
					'id'      => 'lp_mobile_fb_client_id',
					'type'    => 'text',
					'default' => '',
				),
				array(
					'name'    => esc_html__( 'Facebook Client Secret.', 'learnpress-mobile-app' ),
					'id'      => 'lp_mobile_fb_client_secret',
					'type'    => 'text',
					'default' => '',
				),
				array(
					'name'    => esc_html__( 'Google Web Client ID.', 'learnpress-mobile-app' ),
					'id'      => 'lp_mobile_gg_web_client_id',
					'type'    => 'text',
					'default' => '',
				),
				array(
					'type' => 'sectionend',
				),
			);

			return apply_filters( 'learnpress/app-purchase/settings', $settings );
		}
	}

	return new LP_Mobile_App_Purchase_Settings();
}

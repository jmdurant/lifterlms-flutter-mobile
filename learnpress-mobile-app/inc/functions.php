<?php
// Get iap token
if ( ! function_exists( 'learnpress_mobile_iap_settings' ) ) {
	function learnpress_mobile_iap_settings( $platform = '' ) {
		$apple_token_secret = LP()->settings()->get( 'in_app_purchase_apple_shared_secret', '' );
		$google_service_account     = LP()->settings()->get( 'in_app_purchase_service_account', '' );

		return apply_filters(
			'learnpress_mobile_iap_settings',
			array(
				'apple_token_secret'        => $apple_token_secret,
				'google_service_account'   => $google_service_account,
			),
			$platform
		);
	}
}

if ( ! function_exists( 'learnpress_mobile_push_notification_settings' ) ) {
	function learnpress_mobile_push_notification_settings( $platform = '' ) {
		$firebase_project_id = LP()->settings()->get( 'lp_push_notification_project_id', '' );
		$firebase_service_account     = LP()->settings()->get( 'lp_push_notification_service_account', '' );

		return apply_filters(
			'learnpress_mobile_push_notification_settings',
			array(
				'project_id'        => $firebase_project_id,
				'service_account'   => $firebase_service_account,
			),
			$platform
		);
	}
}

if ( ! function_exists( 'learnpress_in_app_purchase_get_access_token' ) ) {
	function learnpress_in_app_purchase_get_access_token( $platform = '' ) {
		$service_account = learnpress_mobile_iap_settings( $platform )['google_service_account'];

		if ( ! empty( $service_account ) ) {
			return learnpress_mobile_app_get_access_token( $service_account, 'https://www.googleapis.com/auth/androidpublisher' );
		}

		return '';
	}
}

if ( ! function_exists( 'learnpress_push_notifications_get_access_token' ) ) {
	function learnpress_push_notifications_get_access_token( $platform = '' ) {
		$service_account = learnpress_mobile_push_notification_settings( $platform )['service_account'];

		if ( ! empty( $service_account ) ) {
			return learnpress_mobile_app_get_access_token( $service_account, 'https://www.googleapis.com/auth/firebase.messaging' );
		}

		return '';
	}
}

function learnpress_mobile_app_get_access_token( $service_account = '', $scope = '' ) {
	try {
		$json = json_decode( $service_account, true );

		$header = array(
			'alg' => 'RS256',
			'typ' => 'JWT',
		);

		$claim = array(
			'iss'   => $json['client_email'],
			'sub'   => $json['client_email'],
			'scope' => $scope,
			'aud'   => 'https://oauth2.googleapis.com/token',
			'exp'   => time() + 3600,
			'iat'   => time(),
		);

		$header = json_encode( $header );
		$claim  = json_encode( $claim );

		$header = str_replace( array( '+', '/', '=' ), array( '-', '_', '' ), base64_encode( $header ) );
		$claim  = str_replace( array( '+', '/', '=' ), array( '-', '_', '' ), base64_encode( $claim ) );

		$signature = '';

		$private_key = $json['private_key'];

		// check if openssl_sign is available
		if ( ! function_exists( 'openssl_sign' ) ) {
			throw new Exception( 'openssl_sign function is not available' );
		}

		openssl_sign( "$header.$claim", $signature, $private_key, 'sha256' );

		$signature = str_replace( array( '+', '/', '=' ), array( '-', '_', '' ), base64_encode( $signature ) );

		$jwt = "$header.$claim.$signature";

		$response = wp_remote_post(
			'https://oauth2.googleapis.com/token',
			array(
				'body'    => array(
					'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
					'assertion'  => $jwt,
				),
				'headers' => array(
					'Content-Type' => 'application/x-www-form-urlencoded',
				),
			)
		);

		if ( is_wp_error( $response ) ) {
			throw new Exception( $response->get_error_message() );
		}

		$result = json_decode( wp_remote_retrieve_body( $response ), true );

		return $result['access_token'] ?? '';
	} catch ( \Throwable $th ) {
		return '';
	}
}


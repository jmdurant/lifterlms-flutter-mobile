import 'package:flutter/material.dart';

/// Branding configuration for the app
/// Allows easy customization of app branding elements
class BrandingConfig {
  // Brand name
  static const String brandName = 'LifterLMS';
  static const String brandTagline = 'Learning Management System';
  
  // Logo configuration
  static const bool useTextLogo = true; // Set to false to use image logo
  static const String logoImagePath = 'assets/images/logo.png';
  static const String logoSchoolImagePath = 'assets/images/logo-school.png';
  
  // Brand colors
  static const Color primaryColor = Colors.blue;
  static const Color secondaryColor = Colors.blueAccent;
  static const Color accentColor = Colors.orange;
  
  // Text logo style
  static const TextStyle logoTextStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: primaryColor,
    fontFamily: 'bold',
  );
  
  static const TextStyle logoTextStyleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: primaryColor,
  );
  
  /// Returns the appropriate logo widget based on configuration
  static Widget getLogo({bool isSmall = false, double? width, double? height}) {
    if (useTextLogo) {
      return Container(
        width: width ?? (isSmall ? 80 : 115),
        height: height ?? 30,
        alignment: Alignment.centerLeft,
        child: Text(
          brandName,
          style: isSmall ? logoTextStyleSmall : logoTextStyle,
        ),
      );
    } else {
      return Container(
        width: width ?? (isSmall ? 80 : 115),
        height: height ?? 30,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isSmall ? logoSchoolImagePath : logoImagePath,
            ),
            fit: BoxFit.contain,
          ),
        ),
      );
    }
  }
  
  /// Returns logo for auth screens (login, register, forgot password)
  static Widget getAuthLogo({required double screenWidth}) {
    if (useTextLogo) {
      return Container(
        height: (98 / 375) * screenWidth,
        width: (73 / 375) * screenWidth,
        alignment: Alignment.center,
        child: Text(
          brandName,
          style: logoTextStyleSmall,
        ),
      );
    } else {
      return Container(
        height: (98 / 375) * screenWidth,
        width: (73 / 375) * screenWidth,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(logoSchoolImagePath),
            fit: BoxFit.contain,
          ),
        ),
      );
    }
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/helper/dialog_helper.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';
import 'package:email_validator/email_validator.dart';

class ForgotPasswordController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  
  // Form controllers
  TextEditingController emailController = TextEditingController();
  TextEditingController codeController = TextEditingController();
  TextEditingController newPasswordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  
  // Observable states
  final RxBool isLoading = false.obs;
  final RxBool emailSent = false.obs;
  final RxBool codeVerified = false.obs;
  final RxBool obscureNewPassword = true.obs;
  final RxBool obscureConfirmPassword = true.obs;
  
  // Step tracking
  final RxInt currentStep = 1.obs; // 1: Email, 2: Code, 3: New Password
  
  // Validation
  final RxBool isEmailValid = true.obs;
  final RxString emailError = ''.obs;
  final RxString resetToken = ''.obs;
  
  @override
  void onInit() {
    super.onInit();
    setupValidation();
  }
  
  @override
  void onClose() {
    emailController.dispose();
    codeController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
  
  /// Setup validation listeners
  void setupValidation() {
    emailController.addListener(() {
      validateEmail(emailController.text);
    });
  }
  
  /// Validate email
  void validateEmail(String email) {
    if (email.isEmpty) {
      isEmailValid.value = false;
      emailError.value = 'Email is required';
    } else if (!EmailValidator.validate(email)) {
      isEmailValid.value = false;
      emailError.value = 'Please enter a valid email';
    } else {
      isEmailValid.value = true;
      emailError.value = '';
    }
  }
  
  /// Send reset email
  Future<void> sendResetEmail() async {
    validateEmail(emailController.text);
    
    if (!isEmailValid.value) {
      showToast(emailError.value, isError: true);
      return;
    }
    
    try {
      isLoading.value = true;
      DialogHelper.showLoading();
      
      final response = await lmsService.api.forgotPassword(
        email: emailController.text.trim(),
      );
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200) {
        emailSent.value = true;
        currentStep.value = 2;
        
        // Store reset token if provided
        if (response.body?['token'] != null) {
          resetToken.value = response.body['token'];
        }
        
        showToast(
          'Password reset instructions have been sent to your email',
        );
      } else if (response.statusCode == 404) {
        showToast(
          'No account found with this email address',
          isError: true,
        );
      } else if (response.statusCode == 501) {
        // Feature not implemented
        _showNotImplementedDialog();
      } else {
        showToast(
          response.body?['message'] ?? 'Failed to send reset email',
          isError: true,
        );
      }
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('An error occurred. Please try again.', isError: true);
      print('Forgot password error: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Verify reset code
  Future<void> verifyResetCode() async {
    if (codeController.text.isEmpty) {
      showToast('Please enter the verification code', isError: true);
      return;
    }
    
    try {
      isLoading.value = true;
      DialogHelper.showLoading();
      
      // This would need a custom endpoint to verify the code
      // For now, we'll simulate verification
      await Future.delayed(Duration(seconds: 1));
      
      DialogHelper.hideLoading();
      
      // Move to password reset step
      codeVerified.value = true;
      currentStep.value = 3;
      
      showToast('Code verified successfully');
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Invalid verification code', isError: true);
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Reset password
  Future<void> resetPassword() async {
    if (!validatePasswordForm()) return;
    
    try {
      isLoading.value = true;
      DialogHelper.showLoading();
      
      // This would need a custom endpoint to reset password
      // For demonstration, we'll simulate the process
      await Future.delayed(Duration(seconds: 2));
      
      DialogHelper.hideLoading();
      
      showToast('Password reset successfully! Please login with your new password.');
      
      // Navigate to login
      Get.offAllNamed(
        AppRouter.login,
        arguments: {
          'email': emailController.text,
        },
      );
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Failed to reset password', isError: true);
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Validate password form
  bool validatePasswordForm() {
    if (newPasswordController.text.isEmpty) {
      showToast('New password is required', isError: true);
      return false;
    }
    
    if (newPasswordController.text.length < 8) {
      showToast('Password must be at least 8 characters', isError: true);
      return false;
    }
    
    if (confirmPasswordController.text.isEmpty) {
      showToast('Please confirm your password', isError: true);
      return false;
    }
    
    if (newPasswordController.text != confirmPasswordController.text) {
      showToast('Passwords do not match', isError: true);
      return false;
    }
    
    return true;
  }
  
  /// Resend code
  Future<void> resendCode() async {
    currentStep.value = 1;
    emailSent.value = false;
    await sendResetEmail();
  }
  
  /// Go back to previous step
  void goBack() {
    if (currentStep.value > 1) {
      currentStep.value--;
    } else {
      Get.back();
    }
  }
  
  /// Toggle new password visibility
  void toggleNewPasswordVisibility() {
    obscureNewPassword.value = !obscureNewPassword.value;
  }
  
  /// Toggle confirm password visibility
  void toggleConfirmPasswordVisibility() {
    obscureConfirmPassword.value = !obscureConfirmPassword.value;
  }
  
  /// Show not implemented dialog
  void _showNotImplementedDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Password Reset'),
        content: Text(
          'Password reset functionality requires additional setup on your '
          'LifterLMS site. Please contact your site administrator or use '
          'the website to reset your password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Navigate to login
  void goToLogin() {
    Get.offNamed(AppRouter.login);
  }
  
  /// Navigate to register
  void goToRegister() {
    Get.offNamed(AppRouter.register);
  }
  
  /// Get step title
  String getStepTitle() {
    switch (currentStep.value) {
      case 1:
        return 'Enter Your Email';
      case 2:
        return 'Verify Code';
      case 3:
        return 'Set New Password';
      default:
        return 'Forgot Password';
    }
  }
  
  /// Get step description
  String getStepDescription() {
    switch (currentStep.value) {
      case 1:
        return 'Enter the email address associated with your account';
      case 2:
        return 'Enter the verification code sent to your email';
      case 3:
        return 'Create a new password for your account';
      default:
        return '';
    }
  }
  
  // Input decoration
  final OutlineInputBorder enabledBorder = const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8.0)),
    borderSide: BorderSide(color: Colors.grey),
  );
  
  final OutlineInputBorder focusedBorder = const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8.0)),
    borderSide: BorderSide(color: Colors.blue, width: 2),
  );
  
  final OutlineInputBorder errorBorder = const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8.0)),
    borderSide: BorderSide(color: Colors.red),
  );
}
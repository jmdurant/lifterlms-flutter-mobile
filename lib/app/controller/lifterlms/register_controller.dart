import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/helper/dialog_helper.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';
import 'package:email_validator/email_validator.dart';

class RegisterController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  
  // Form controllers
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  
  // Observable states
  final RxBool isLoading = false.obs;
  final RxBool obscurePassword = true.obs;
  final RxBool obscureConfirmPassword = true.obs;
  final RxBool agreeToTerms = false.obs;
  final RxBool subscribeNewsletter = false.obs;
  
  // Validation states
  final RxBool isUsernameValid = true.obs;
  final RxBool isEmailValid = true.obs;
  final RxBool isPasswordValid = true.obs;
  final RxBool isPasswordMatch = true.obs;
  final RxString passwordStrength = ''.obs;
  
  // Error messages
  final RxString usernameError = ''.obs;
  final RxString emailError = ''.obs;
  final RxString passwordError = ''.obs;
  final RxString confirmPasswordError = ''.obs;
  
  @override
  void onInit() {
    super.onInit();
    setupValidationListeners();
  }
  
  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    super.onClose();
  }
  
  /// Setup validation listeners
  void setupValidationListeners() {
    // Username validation
    usernameController.addListener(() {
      validateUsername(usernameController.text);
    });
    
    // Email validation
    emailController.addListener(() {
      validateEmail(emailController.text);
    });
    
    // Password validation
    passwordController.addListener(() {
      validatePassword(passwordController.text);
      checkPasswordMatch();
    });
    
    // Confirm password validation
    confirmPasswordController.addListener(() {
      checkPasswordMatch();
    });
  }
  
  /// Toggle password visibility
  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }
  
  /// Toggle confirm password visibility
  void toggleConfirmPasswordVisibility() {
    obscureConfirmPassword.value = !obscureConfirmPassword.value;
  }
  
  /// Toggle terms agreement
  void toggleTermsAgreement(bool value) {
    agreeToTerms.value = value;
  }
  
  /// Toggle newsletter subscription
  void toggleNewsletter(bool value) {
    subscribeNewsletter.value = value;
  }
  
  /// Validate username
  void validateUsername(String username) {
    if (username.isEmpty) {
      isUsernameValid.value = false;
      usernameError.value = 'Username is required';
    } else if (username.length < 3) {
      isUsernameValid.value = false;
      usernameError.value = 'Username must be at least 3 characters';
    } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      isUsernameValid.value = false;
      usernameError.value = 'Username can only contain letters, numbers, and underscores';
    } else {
      isUsernameValid.value = true;
      usernameError.value = '';
    }
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
  
  /// Validate password
  void validatePassword(String password) {
    if (password.isEmpty) {
      isPasswordValid.value = false;
      passwordError.value = 'Password is required';
      passwordStrength.value = '';
    } else if (password.length < 8) {
      isPasswordValid.value = false;
      passwordError.value = 'Password must be at least 8 characters';
      passwordStrength.value = 'Weak';
    } else {
      isPasswordValid.value = true;
      passwordError.value = '';
      
      // Calculate password strength
      int strength = 0;
      if (password.length >= 8) strength++;
      if (password.length >= 12) strength++;
      if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
      if (RegExp(r'[a-z]').hasMatch(password)) strength++;
      if (RegExp(r'[0-9]').hasMatch(password)) strength++;
      if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;
      
      if (strength <= 2) {
        passwordStrength.value = 'Weak';
      } else if (strength <= 4) {
        passwordStrength.value = 'Medium';
      } else {
        passwordStrength.value = 'Strong';
      }
    }
  }
  
  /// Check if passwords match
  void checkPasswordMatch() {
    if (confirmPasswordController.text.isEmpty) {
      isPasswordMatch.value = false;
      confirmPasswordError.value = '';
    } else if (passwordController.text != confirmPasswordController.text) {
      isPasswordMatch.value = false;
      confirmPasswordError.value = 'Passwords do not match';
    } else {
      isPasswordMatch.value = true;
      confirmPasswordError.value = '';
    }
  }
  
  /// Validate form
  bool validateForm() {
    // Validate all fields
    validateUsername(usernameController.text);
    validateEmail(emailController.text);
    validatePassword(passwordController.text);
    checkPasswordMatch();
    
    if (firstNameController.text.trim().isEmpty) {
      showToast('First name is required', isError: true);
      return false;
    }
    
    if (lastNameController.text.trim().isEmpty) {
      showToast('Last name is required', isError: true);
      return false;
    }
    
    if (!isUsernameValid.value) {
      showToast(usernameError.value, isError: true);
      return false;
    }
    
    if (!isEmailValid.value) {
      showToast(emailError.value, isError: true);
      return false;
    }
    
    if (!isPasswordValid.value) {
      showToast(passwordError.value, isError: true);
      return false;
    }
    
    if (!isPasswordMatch.value) {
      showToast('Passwords do not match', isError: true);
      return false;
    }
    
    if (!agreeToTerms.value) {
      showToast('Please agree to the Terms and Conditions', isError: true);
      return false;
    }
    
    return true;
  }
  
  /// Register user
  Future<void> register() async {
    if (!validateForm()) return;
    
    try {
      isLoading.value = true;
      DialogHelper.showLoading();
      
      // Prepare user data
      final userData = {
        'username': usernameController.text.trim(),
        'email': emailController.text.trim(),
        'password': passwordController.text,
        'first_name': firstNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'display_name': '${firstNameController.text.trim()} ${lastNameController.text.trim()}',
        'roles': ['student'], // Default role for LifterLMS
      };
      
      // Add phone if provided
      if (phoneController.text.isNotEmpty) {
        userData['billing_phone'] = phoneController.text.trim();
      }
      
      // Add newsletter preference
      if (subscribeNewsletter.value) {
        userData['meta'] = {
          'subscribe_newsletter': true,
        };
      }
      
      // Register user
      final response = await lmsService.api.register(userData: userData);
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Registration successful
        showToast('Registration successful! Please login.');
        
        // Auto-fill login form with credentials
        Get.offNamed(
          AppRouter.login,
          arguments: {
            'username': usernameController.text,
            'password': passwordController.text,
          },
        );
      } else if (response.statusCode == 400) {
        // Validation error
        final error = response.body?['message'] ?? 'Registration failed';
        
        if (error.toString().contains('username')) {
          showToast('Username already exists', isError: true);
        } else if (error.toString().contains('email')) {
          showToast('Email already registered', isError: true);
        } else {
          showToast(error.toString(), isError: true);
        }
      } else if (response.statusCode == 501) {
        // Registration endpoint not implemented
        showToast(
          'Registration not configured. Please contact administrator.',
          isError: true
        );
      } else {
        showToast(
          response.body?['message'] ?? 'Registration failed. Please try again.',
          isError: true
        );
      }
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('An error occurred. Please try again.', isError: true);
      print('Registration error: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Check if username is available
  Future<void> checkUsernameAvailability() async {
    final username = usernameController.text.trim();
    if (username.length < 3) return;
    
    try {
      // This would need a custom endpoint to check username availability
      // For now, we'll skip this check
    } catch (e) {
      print('Error checking username: $e');
    }
  }
  
  /// Check if email is available
  Future<void> checkEmailAvailability() async {
    final email = emailController.text.trim();
    if (!EmailValidator.validate(email)) return;
    
    try {
      // This would need a custom endpoint to check email availability
      // For now, we'll skip this check
    } catch (e) {
      print('Error checking email: $e');
    }
  }
  
  /// Navigate to login
  void goToLogin() {
    Get.offNamed(AppRouter.login);
  }
  
  /// Open terms and conditions
  void openTermsAndConditions() {
    // Navigate to terms page or open URL
    Get.toNamed(AppRouter.terms);
  }
  
  /// Open privacy policy
  void openPrivacyPolicy() {
    // Navigate to privacy page or open URL
    Get.toNamed(AppRouter.privacy);
  }
  
  /// Get password strength color
  Color getPasswordStrengthColor() {
    switch (passwordStrength.value) {
      case 'Strong':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'Weak':
        return Colors.red;
      default:
        return Colors.grey;
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
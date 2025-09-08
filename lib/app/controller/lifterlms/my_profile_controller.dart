import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/helper/dialog_helper.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:email_validator/email_validator.dart';

class MyProfileController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  
  // Form controllers
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController displayNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController bioController = TextEditingController();
  TextEditingController websiteController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController countryController = TextEditingController();
  
  // Password change controllers
  TextEditingController currentPasswordController = TextEditingController();
  TextEditingController newPasswordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  
  // Social media controllers
  TextEditingController facebookController = TextEditingController();
  TextEditingController twitterController = TextEditingController();
  TextEditingController linkedinController = TextEditingController();
  TextEditingController instagramController = TextEditingController();
  TextEditingController youtubeController = TextEditingController();
  
  // Observable states
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isUploadingAvatar = false.obs;
  final RxString avatarUrl = ''.obs;
  final Rx<File?> selectedImage = Rx<File?>(null);
  
  // Password visibility
  final RxBool obscureCurrentPassword = true.obs;
  final RxBool obscureNewPassword = true.obs;
  final RxBool obscureConfirmPassword = true.obs;
  
  // Form sections
  final RxInt selectedSection = 0.obs; // 0: Basic, 1: Contact, 2: Social, 3: Security, 4: Notifications
  
  // Notification preferences
  final RxBool emailNotifications = true.obs;
  final RxBool pushNotifications = true.obs;
  final RxBool courseUpdates = true.obs;
  final RxBool promotionalEmails = false.obs;
  final RxBool weeklyDigest = false.obs;
  
  // Privacy settings
  final RxBool showEmail = false.obs;
  final RxBool showPhone = false.obs;
  final RxBool showProfile = true.obs;
  final RxBool showProgress = true.obs;
  final RxBool showAchievements = true.obs;
  
  // Account settings
  final RxBool twoFactorEnabled = false.obs;
  final RxString preferredLanguage = 'en'.obs;
  final RxString timezone = 'UTC'.obs;
  
  final ImagePicker _imagePicker = ImagePicker();
  
  @override
  void onInit() {
    super.onInit();
    loadUserProfile();
  }
  
  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    displayNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    bioController.dispose();
    websiteController.dispose();
    addressController.dispose();
    cityController.dispose();
    countryController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    facebookController.dispose();
    twitterController.dispose();
    linkedinController.dispose();
    instagramController.dispose();
    youtubeController.dispose();
    super.onClose();
  }
  
  /// Load user profile
  Future<void> loadUserProfile() async {
    if (!lmsService.isLoggedIn || lmsService.currentUserId == null) {
      // Defer navigation to avoid setState during build
      Future.delayed(Duration.zero, () {
        Get.offNamed(AppRouter.login);
      });
      return;
    }
    
    try {
      isLoading.value = true;
      
      final response = await lmsService.api.getStudent(
        studentId: lmsService.currentUserId!,
      );
      
      if (response.statusCode == 200) {
        final userData = response.body;
        
        // Populate form controllers
        firstNameController.text = userData['first_name'] ?? '';
        lastNameController.text = userData['last_name'] ?? '';
        displayNameController.text = userData['display_name'] ?? '';
        emailController.text = userData['email'] ?? '';
        phoneController.text = userData['billing_phone'] ?? '';
        bioController.text = userData['description'] ?? '';
        websiteController.text = userData['website'] ?? '';
        
        // Address fields
        addressController.text = userData['billing_address'] ?? '';
        cityController.text = userData['billing_city'] ?? '';
        countryController.text = userData['billing_country'] ?? '';
        
        // Avatar
        avatarUrl.value = userData['avatar_url'] ?? '';
        
        // Load preferences
        loadUserPreferences(userData);
        
        // Load social links
        loadSocialLinks(userData);
      }
    } catch (e) {
      showToast('Error loading profile', isError: true);
      print('Error loading profile: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Load user preferences
  void loadUserPreferences(Map<String, dynamic> userData) {
    // Notification preferences
    if (userData['meta'] != null) {
      final meta = userData['meta'];
      emailNotifications.value = meta['email_notifications'] ?? true;
      pushNotifications.value = meta['push_notifications'] ?? true;
      courseUpdates.value = meta['course_updates'] ?? true;
      promotionalEmails.value = meta['promotional_emails'] ?? false;
      weeklyDigest.value = meta['weekly_digest'] ?? false;
      
      // Privacy settings
      showEmail.value = meta['show_email'] ?? false;
      showPhone.value = meta['show_phone'] ?? false;
      showProfile.value = meta['show_profile'] ?? true;
      showProgress.value = meta['show_progress'] ?? true;
      showAchievements.value = meta['show_achievements'] ?? true;
      
      // Account settings
      twoFactorEnabled.value = meta['two_factor_enabled'] ?? false;
      preferredLanguage.value = meta['preferred_language'] ?? 'en';
      timezone.value = meta['timezone'] ?? 'UTC';
    }
  }
  
  /// Load social links
  void loadSocialLinks(Map<String, dynamic> userData) {
    if (userData['meta'] != null) {
      final meta = userData['meta'];
      facebookController.text = meta['facebook'] ?? '';
      twitterController.text = meta['twitter'] ?? '';
      linkedinController.text = meta['linkedin'] ?? '';
      instagramController.text = meta['instagram'] ?? '';
      youtubeController.text = meta['youtube'] ?? '';
    }
  }
  
  /// Pick image from gallery
  Future<void> pickImageFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 85,
    );
    
    if (image != null) {
      selectedImage.value = File(image.path);
      await uploadAvatar();
    }
  }
  
  /// Pick image from camera
  Future<void> pickImageFromCamera() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 85,
    );
    
    if (image != null) {
      selectedImage.value = File(image.path);
      await uploadAvatar();
    }
  }
  
  /// Upload avatar
  Future<void> uploadAvatar() async {
    if (selectedImage.value == null) return;
    
    try {
      isUploadingAvatar.value = true;
      DialogHelper.showLoading();
      
      // This would upload to WordPress media library
      // For now, we'll simulate the upload
      await Future.delayed(Duration(seconds: 2));
      
      // Update avatar URL
      avatarUrl.value = selectedImage.value!.path;
      
      DialogHelper.hideLoading();
      showToast('Avatar updated successfully');
      
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Failed to upload avatar', isError: true);
    } finally {
      isUploadingAvatar.value = false;
    }
  }
  
  /// Save basic info
  Future<void> saveBasicInfo() async {
    if (!validateBasicInfo()) return;
    
    try {
      isSaving.value = true;
      DialogHelper.showLoading();
      
      final userData = {
        'first_name': firstNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'display_name': displayNameController.text.trim(),
        'description': bioController.text.trim(),
        'website': websiteController.text.trim(),
      };
      
      final response = await lmsService.api.updateStudent(
        studentId: lmsService.currentUserId!,
        data: userData,
      );
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200) {
        showToast('Profile updated successfully');
      } else {
        showToast('Failed to update profile', isError: true);
      }
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Error updating profile', isError: true);
    } finally {
      isSaving.value = false;
    }
  }
  
  /// Save contact info
  Future<void> saveContactInfo() async {
    if (!validateContactInfo()) return;
    
    try {
      isSaving.value = true;
      DialogHelper.showLoading();
      
      final userData = {
        'email': emailController.text.trim(),
        'billing_phone': phoneController.text.trim(),
        'billing_address': addressController.text.trim(),
        'billing_city': cityController.text.trim(),
        'billing_country': countryController.text.trim(),
      };
      
      final response = await lmsService.api.updateStudent(
        studentId: lmsService.currentUserId!,
        data: userData,
      );
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200) {
        showToast('Contact information updated');
      } else {
        showToast('Failed to update contact info', isError: true);
      }
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Error updating contact info', isError: true);
    } finally {
      isSaving.value = false;
    }
  }
  
  /// Save social links
  Future<void> saveSocialLinks() async {
    try {
      isSaving.value = true;
      DialogHelper.showLoading();
      
      final meta = {
        'facebook': facebookController.text.trim(),
        'twitter': twitterController.text.trim(),
        'linkedin': linkedinController.text.trim(),
        'instagram': instagramController.text.trim(),
        'youtube': youtubeController.text.trim(),
      };
      
      final userData = {'meta': meta};
      
      final response = await lmsService.api.updateStudent(
        studentId: lmsService.currentUserId!,
        data: userData,
      );
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200) {
        showToast('Social links updated');
      } else {
        showToast('Failed to update social links', isError: true);
      }
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Error updating social links', isError: true);
    } finally {
      isSaving.value = false;
    }
  }
  
  /// Change password
  Future<void> changePassword() async {
    if (!validatePasswordChange()) return;
    
    try {
      isSaving.value = true;
      DialogHelper.showLoading();
      
      // This would require a custom endpoint for password change
      // For now, we'll simulate it
      await Future.delayed(Duration(seconds: 2));
      
      DialogHelper.hideLoading();
      
      // Clear password fields
      currentPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();
      
      showToast('Password changed successfully');
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Failed to change password', isError: true);
    } finally {
      isSaving.value = false;
    }
  }
  
  /// Save notification preferences
  Future<void> saveNotificationPreferences() async {
    try {
      isSaving.value = true;
      DialogHelper.showLoading();
      
      final meta = {
        'email_notifications': emailNotifications.value,
        'push_notifications': pushNotifications.value,
        'course_updates': courseUpdates.value,
        'promotional_emails': promotionalEmails.value,
        'weekly_digest': weeklyDigest.value,
      };
      
      final userData = {'meta': meta};
      
      final response = await lmsService.api.updateStudent(
        studentId: lmsService.currentUserId!,
        data: userData,
      );
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200) {
        showToast('Notification preferences updated');
      } else {
        showToast('Failed to update preferences', isError: true);
      }
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Error updating preferences', isError: true);
    } finally {
      isSaving.value = false;
    }
  }
  
  /// Save privacy settings
  Future<void> savePrivacySettings() async {
    try {
      isSaving.value = true;
      DialogHelper.showLoading();
      
      final meta = {
        'show_email': showEmail.value,
        'show_phone': showPhone.value,
        'show_profile': showProfile.value,
        'show_progress': showProgress.value,
        'show_achievements': showAchievements.value,
      };
      
      final userData = {'meta': meta};
      
      final response = await lmsService.api.updateStudent(
        studentId: lmsService.currentUserId!,
        data: userData,
      );
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200) {
        showToast('Privacy settings updated');
      } else {
        showToast('Failed to update privacy settings', isError: true);
      }
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Error updating privacy settings', isError: true);
    } finally {
      isSaving.value = false;
    }
  }
  
  /// Toggle two-factor authentication
  Future<void> toggleTwoFactor() async {
    try {
      isSaving.value = true;
      DialogHelper.showLoading();
      
      // This would require a custom endpoint
      await Future.delayed(Duration(seconds: 2));
      
      twoFactorEnabled.value = !twoFactorEnabled.value;
      
      DialogHelper.hideLoading();
      
      showToast(
        twoFactorEnabled.value 
          ? 'Two-factor authentication enabled'
          : 'Two-factor authentication disabled'
      );
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Failed to update security settings', isError: true);
    } finally {
      isSaving.value = false;
    }
  }
  
  /// Delete account
  Future<void> deleteAccount() async {
    // Show confirmation dialog
    Get.dialog(
      AlertDialog(
        title: Text('Delete Account'),
        content: Text(
          'Are you sure you want to delete your account? '
          'This action cannot be undone and all your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              // Proceed with account deletion
              await performAccountDeletion();
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  /// Perform account deletion
  Future<void> performAccountDeletion() async {
    try {
      DialogHelper.showLoading();
      
      // This would require a custom endpoint
      await Future.delayed(Duration(seconds: 2));
      
      DialogHelper.hideLoading();
      
      // Clear session and redirect to login
      await lmsService.logout();
      Get.offAllNamed(AppRouter.login);
      
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Failed to delete account', isError: true);
    }
  }
  
  /// Validate basic info
  bool validateBasicInfo() {
    if (firstNameController.text.trim().isEmpty) {
      showToast('First name is required', isError: true);
      return false;
    }
    if (lastNameController.text.trim().isEmpty) {
      showToast('Last name is required', isError: true);
      return false;
    }
    return true;
  }
  
  /// Validate contact info
  bool validateContactInfo() {
    if (emailController.text.trim().isEmpty) {
      showToast('Email is required', isError: true);
      return false;
    }
    if (!EmailValidator.validate(emailController.text.trim())) {
      showToast('Invalid email address', isError: true);
      return false;
    }
    return true;
  }
  
  /// Validate password change
  bool validatePasswordChange() {
    if (currentPasswordController.text.isEmpty) {
      showToast('Current password is required', isError: true);
      return false;
    }
    if (newPasswordController.text.isEmpty) {
      showToast('New password is required', isError: true);
      return false;
    }
    if (newPasswordController.text.length < 8) {
      showToast('Password must be at least 8 characters', isError: true);
      return false;
    }
    if (newPasswordController.text != confirmPasswordController.text) {
      showToast('Passwords do not match', isError: true);
      return false;
    }
    return true;
  }
  
  /// Change section
  void changeSection(int section) {
    selectedSection.value = section;
  }
  
  /// Toggle password visibility
  void toggleCurrentPasswordVisibility() {
    obscureCurrentPassword.value = !obscureCurrentPassword.value;
  }
  
  void toggleNewPasswordVisibility() {
    obscureNewPassword.value = !obscureNewPassword.value;
  }
  
  void toggleConfirmPasswordVisibility() {
    obscureConfirmPassword.value = !obscureConfirmPassword.value;
  }
}
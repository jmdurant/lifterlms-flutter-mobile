import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/helper/dialog_helper.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class PaymentController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  
  // Course and plan data
  final Rx<LLMSCourseModel?> course = Rx<LLMSCourseModel?>(null);
  final Rx<dynamic> selectedAccessPlan = Rx<dynamic>(null);
  final RxList<dynamic> availablePlans = <dynamic>[].obs;
  
  // Pricing
  final RxDouble originalPrice = 0.0.obs;
  final RxDouble discountedPrice = 0.0.obs;
  final RxDouble discountPercentage = 0.0.obs;
  final RxBool hasDiscount = false.obs;
  
  // Coupon
  TextEditingController couponController = TextEditingController();
  final RxString appliedCoupon = ''.obs;
  final RxDouble couponDiscount = 0.0.obs;
  final RxBool isValidatingCoupon = false.obs;
  final RxBool couponApplied = false.obs;
  
  // Payment methods
  final RxList<Map<String, dynamic>> paymentMethods = <Map<String, dynamic>>[
    {'id': 'stripe', 'name': 'Credit/Debit Card', 'icon': Icons.credit_card, 'enabled': true},
    {'id': 'paypal', 'name': 'PayPal', 'icon': Icons.payment, 'enabled': true},
    {'id': 'razorpay', 'name': 'Razorpay', 'icon': Icons.account_balance, 'enabled': false},
    {'id': 'bank_transfer', 'name': 'Bank Transfer', 'icon': Icons.account_balance_wallet, 'enabled': false},
    {'id': 'crypto', 'name': 'Cryptocurrency', 'icon': Icons.currency_bitcoin, 'enabled': false},
  ].obs;
  
  final RxString selectedPaymentMethod = 'stripe'.obs;
  
  // Billing information
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController zipController = TextEditingController();
  TextEditingController countryController = TextEditingController();
  
  // Card details (for Stripe)
  TextEditingController cardNumberController = TextEditingController();
  TextEditingController cardHolderController = TextEditingController();
  TextEditingController expiryController = TextEditingController();
  TextEditingController cvvController = TextEditingController();
  
  // Order summary
  final RxDouble subtotal = 0.0.obs;
  final RxDouble tax = 0.0.obs;
  final RxDouble taxRate = 0.0.obs;
  final RxDouble total = 0.0.obs;
  final RxString currency = 'USD'.obs;
  
  // UI states
  final RxBool isLoading = false.obs;
  final RxBool isProcessingPayment = false.obs;
  final RxBool agreeToTerms = false.obs;
  final RxBool savePaymentMethod = false.obs;
  final RxInt currentStep = 1.obs; // 1: Plan, 2: Billing, 3: Payment, 4: Confirmation
  
  // Payment result
  final RxString orderId = ''.obs;
  final RxString transactionId = ''.obs;
  final RxBool paymentSuccessful = false.obs;
  
  // Installment options
  final RxBool hasInstallmentOptions = false.obs;
  final RxInt selectedInstallments = 1.obs;
  final RxList<Map<String, dynamic>> installmentPlans = <Map<String, dynamic>>[].obs;
  
  @override
  void onInit() {
    super.onInit();
    
    // Get course and plan from arguments
    final args = Get.arguments;
    if (args != null) {
      if (args['course'] != null) {
        course.value = args['course'];
      }
      if (args['access_plan'] != null) {
        selectedAccessPlan.value = args['access_plan'];
        extractPricing();
      }
      
      loadPaymentData();
    }
  }
  
  @override
  void onClose() {
    couponController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    cityController.dispose();
    stateController.dispose();
    zipController.dispose();
    countryController.dispose();
    cardNumberController.dispose();
    cardHolderController.dispose();
    expiryController.dispose();
    cvvController.dispose();
    super.onClose();
  }
  
  /// Load payment data
  Future<void> loadPaymentData() async {
    try {
      isLoading.value = true;
      
      // Load user billing info if logged in
      if (lmsService.isLoggedIn) {
        await loadUserBillingInfo();
      }
      
      // Load available payment plans
      await loadAccessPlans();
      
      // Load payment methods configuration
      await loadPaymentMethods();
      
      // Calculate pricing
      calculatePricing();
      
    } catch (e) {
      showToast('Error loading payment data', isError: true);
      print('Error loading payment data: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Load user billing information
  Future<void> loadUserBillingInfo() async {
    try {
      final response = await lmsService.api.getStudent(
        studentId: lmsService.currentUserId!,
      );
      
      if (response.statusCode == 200) {
        final userData = response.body;
        
        firstNameController.text = userData['first_name'] ?? '';
        lastNameController.text = userData['last_name'] ?? '';
        emailController.text = userData['email'] ?? '';
        phoneController.text = userData['billing_phone'] ?? '';
        addressController.text = userData['billing_address'] ?? '';
        cityController.text = userData['billing_city'] ?? '';
        stateController.text = userData['billing_state'] ?? '';
        zipController.text = userData['billing_postcode'] ?? '';
        countryController.text = userData['billing_country'] ?? '';
      }
    } catch (e) {
      print('Error loading billing info: $e');
    }
  }
  
  /// Load access plans
  Future<void> loadAccessPlans() async {
    if (course.value == null) return;
    
    try {
      final response = await lmsService.api.getAccessPlans(
        courseId: course.value!.id,
      );
      
      if (response.statusCode == 200) {
        availablePlans.clear();
        if (response.body is List) {
          availablePlans.addAll(response.body);
          
          // Select first plan if none selected
          if (selectedAccessPlan.value == null && availablePlans.isNotEmpty) {
            selectedAccessPlan.value = availablePlans.first;
            extractPricing();
          }
        }
      }
    } catch (e) {
      print('Error loading access plans: $e');
    }
  }
  
  /// Load payment methods
  Future<void> loadPaymentMethods() async {
    try {
      // This would load enabled payment methods from server
      // For now, using default configuration
      
      // Check for installment options
      checkInstallmentOptions();
      
    } catch (e) {
      print('Error loading payment methods: $e');
    }
  }
  
  /// Extract pricing from access plan
  void extractPricing() {
    if (selectedAccessPlan.value == null) return;
    
    final plan = selectedAccessPlan.value;
    
    originalPrice.value = (plan['price'] ?? 0).toDouble();
    
    // Check for sale price
    if (plan['on_sale'] == true && plan['sale_price'] != null) {
      discountedPrice.value = (plan['sale_price'] ?? 0).toDouble();
      hasDiscount.value = true;
      
      if (originalPrice.value > 0) {
        discountPercentage.value = 
          ((originalPrice.value - discountedPrice.value) / originalPrice.value) * 100;
      }
    } else {
      discountedPrice.value = originalPrice.value;
      hasDiscount.value = false;
    }
    
    // Set currency
    currency.value = plan['currency'] ?? 'USD';
  }
  
  /// Calculate pricing
  void calculatePricing() {
    // Base price
    subtotal.value = hasDiscount.value ? discountedPrice.value : originalPrice.value;
    
    // Apply coupon discount
    if (couponApplied.value) {
      subtotal.value -= couponDiscount.value;
    }
    
    // Calculate tax (example: 10%)
    taxRate.value = 0.10; // This would come from settings
    tax.value = subtotal.value * taxRate.value;
    
    // Calculate total
    total.value = subtotal.value + tax.value;
    
    // Apply installments if selected
    if (selectedInstallments.value > 1) {
      total.value = total.value / selectedInstallments.value;
    }
  }
  
  /// Apply coupon
  Future<void> applyCoupon() async {
    final couponCode = couponController.text.trim();
    
    if (couponCode.isEmpty) {
      showToast('Please enter a coupon code', isError: true);
      return;
    }
    
    try {
      isValidatingCoupon.value = true;
      
      // This would validate coupon with server
      // For now, simulate validation
      await Future.delayed(Duration(seconds: 2));
      
      // Simulate successful coupon
      if (couponCode.toUpperCase() == 'SAVE20') {
        appliedCoupon.value = couponCode;
        couponDiscount.value = subtotal.value * 0.20; // 20% discount
        couponApplied.value = true;
        
        calculatePricing();
        showToast('Coupon applied successfully!');
      } else {
        showToast('Invalid coupon code', isError: true);
      }
      
    } catch (e) {
      showToast('Error validating coupon', isError: true);
    } finally {
      isValidatingCoupon.value = false;
    }
  }
  
  /// Remove coupon
  void removeCoupon() {
    appliedCoupon.value = '';
    couponDiscount.value = 0;
    couponApplied.value = false;
    couponController.clear();
    
    calculatePricing();
    showToast('Coupon removed');
  }
  
  /// Select payment method
  void selectPaymentMethod(String methodId) {
    final method = paymentMethods.firstWhere((m) => m['id'] == methodId);
    
    if (method['enabled'] == true) {
      selectedPaymentMethod.value = methodId;
    } else {
      showToast('This payment method is not available yet', isError: true);
    }
  }
  
  /// Process payment
  Future<void> processPayment() async {
    if (!validatePaymentForm()) return;
    
    if (!agreeToTerms.value) {
      showToast('Please agree to the terms and conditions', isError: true);
      return;
    }
    
    try {
      isProcessingPayment.value = true;
      DialogHelper.showLoading();
      
      // Prepare order data
      final orderData = {
        'course_id': course.value?.id,
        'access_plan_id': selectedAccessPlan.value['id'],
        'payment_method': selectedPaymentMethod.value,
        'amount': total.value,
        'currency': currency.value,
        'coupon': appliedCoupon.value,
        'billing': {
          'first_name': firstNameController.text.trim(),
          'last_name': lastNameController.text.trim(),
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
          'address': addressController.text.trim(),
          'city': cityController.text.trim(),
          'state': stateController.text.trim(),
          'zip': zipController.text.trim(),
          'country': countryController.text.trim(),
        },
      };
      
      // Process based on payment method
      switch (selectedPaymentMethod.value) {
        case 'stripe':
          await processStripePayment(orderData);
          break;
        case 'paypal':
          await processPayPalPayment(orderData);
          break;
        default:
          throw Exception('Payment method not supported');
      }
      
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Payment failed. Please try again.', isError: true);
      print('Payment error: $e');
    } finally {
      isProcessingPayment.value = false;
    }
  }
  
  /// Process Stripe payment
  Future<void> processStripePayment(Map<String, dynamic> orderData) async {
    // This would integrate with Stripe SDK
    // For now, simulate payment
    await Future.delayed(Duration(seconds: 3));
    
    DialogHelper.hideLoading();
    
    // Simulate successful payment
    paymentSuccessful.value = true;
    orderId.value = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    transactionId.value = 'TXN-${DateTime.now().millisecondsSinceEpoch}';
    
    // Enroll user in course
    await enrollUserInCourse();
    
    // Move to confirmation step
    currentStep.value = 4;
    
    showToast('Payment successful!');
  }
  
  /// Process PayPal payment
  Future<void> processPayPalPayment(Map<String, dynamic> orderData) async {
    DialogHelper.hideLoading();
    
    // This would redirect to PayPal
    final paypalUrl = 'https://www.paypal.com/checkout';
    
    if (await canLaunch(paypalUrl)) {
      await launch(paypalUrl);
      
      // Listen for return from PayPal
      // For now, simulate success after delay
      await Future.delayed(Duration(seconds: 5));
      
      paymentSuccessful.value = true;
      orderId.value = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
      transactionId.value = 'TXN-${DateTime.now().millisecondsSinceEpoch}';
      
      await enrollUserInCourse();
      currentStep.value = 4;
      
      showToast('Payment successful!');
    } else {
      throw Exception('Could not open PayPal');
    }
  }
  
  /// Enroll user in course after successful payment
  Future<void> enrollUserInCourse() async {
    if (course.value == null) return;
    
    try {
      final response = await lmsService.enrollInCourse(course.value!.id);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('User enrolled successfully');
      }
    } catch (e) {
      print('Error enrolling user: $e');
    }
  }
  
  /// Validate payment form
  bool validatePaymentForm() {
    // Validate billing info
    if (firstNameController.text.trim().isEmpty) {
      showToast('First name is required', isError: true);
      return false;
    }
    
    if (lastNameController.text.trim().isEmpty) {
      showToast('Last name is required', isError: true);
      return false;
    }
    
    if (emailController.text.trim().isEmpty) {
      showToast('Email is required', isError: true);
      return false;
    }
    
    // Validate card details for Stripe
    if (selectedPaymentMethod.value == 'stripe') {
      if (cardNumberController.text.trim().isEmpty) {
        showToast('Card number is required', isError: true);
        return false;
      }
      
      if (cardHolderController.text.trim().isEmpty) {
        showToast('Card holder name is required', isError: true);
        return false;
      }
      
      if (expiryController.text.trim().isEmpty) {
        showToast('Expiry date is required', isError: true);
        return false;
      }
      
      if (cvvController.text.trim().isEmpty) {
        showToast('CVV is required', isError: true);
        return false;
      }
    }
    
    return true;
  }
  
  /// Check installment options
  void checkInstallmentOptions() {
    if (total.value > 100) {
      hasInstallmentOptions.value = true;
      
      installmentPlans.value = [
        {'months': 1, 'amount': total.value, 'label': 'Pay in full'},
        {'months': 3, 'amount': total.value / 3, 'label': '3 monthly payments'},
        {'months': 6, 'amount': total.value / 6, 'label': '6 monthly payments'},
        {'months': 12, 'amount': total.value / 12, 'label': '12 monthly payments'},
      ];
    }
  }
  
  /// Select installment plan
  void selectInstallmentPlan(int months) {
    selectedInstallments.value = months;
    calculatePricing();
  }
  
  /// Change access plan
  void changeAccessPlan(dynamic plan) {
    selectedAccessPlan.value = plan;
    extractPricing();
    calculatePricing();
  }
  
  /// Navigate to next step
  void nextStep() {
    if (currentStep.value < 4) {
      currentStep.value++;
    }
  }
  
  /// Navigate to previous step
  void previousStep() {
    if (currentStep.value > 1) {
      currentStep.value--;
    }
  }
  
  /// Continue shopping
  void continueShopping() {
    Get.offAllNamed(AppRouter.courses);
  }
  
  /// Go to my courses
  void goToMyCourses() {
    Get.offAllNamed(AppRouter.myCourses);
  }
  
  /// Start learning
  void startLearning() {
    if (course.value != null) {
      Get.offAllNamed(
        AppRouter.getLearning(),
        arguments: {'id': course.value!.id},
      );
    }
  }
  
  /// Format price
  String formatPrice(double price) {
    final symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'INR': '₹',
    };
    
    final symbol = symbols[currency.value] ?? currency.value;
    return '$symbol${price.toStringAsFixed(2)}';
  }
  
  /// Get step title
  String getStepTitle() {
    switch (currentStep.value) {
      case 1:
        return 'Select Plan';
      case 2:
        return 'Billing Information';
      case 3:
        return 'Payment Method';
      case 4:
        return 'Confirmation';
      default:
        return 'Payment';
    }
  }
  
}
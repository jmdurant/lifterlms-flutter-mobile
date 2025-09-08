import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/api/api.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/helper/dialog_helper.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class CertificateModel {
  final int id;
  final String title;
  final String earnedDate;
  final int courseId;
  final String courseTitle;
  final String? previewUrl;
  final String? downloadUrl;
  final String? verificationCode;

  CertificateModel({
    required this.id,
    required this.title,
    required this.earnedDate,
    required this.courseId,
    required this.courseTitle,
    this.previewUrl,
    this.downloadUrl,
    this.verificationCode,
  });

  factory CertificateModel.fromJson(Map<String, dynamic> json) {
    return CertificateModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      earnedDate: json['earned_date'] ?? '',
      courseId: json['course_id'] ?? 0,
      courseTitle: json['course_title'] ?? '',
      previewUrl: json['preview_url'],
      downloadUrl: json['download_url'],
      verificationCode: json['verification_code'],
    );
  }
}

class CertificatesController extends GetxController implements GetxService {
  final ApiService apiService = Get.find<ApiService>();
  final LMSService lmsService = LMSService.to;
  
  // Observable lists
  final RxList<CertificateModel> _certificates = <CertificateModel>[].obs;
  final RxList<CertificateModel> _filteredCertificates = <CertificateModel>[].obs;
  
  // Getters
  List<CertificateModel> get certificates => _filteredCertificates.isEmpty && searchQuery.isEmpty 
      ? _certificates 
      : _filteredCertificates;
  
  // Loading states
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  
  // Pagination
  final RxInt currentPage = 1.obs;
  final RxBool hasMoreData = true.obs;
  final int perPage = 20;
  
  // Search and filter
  final RxString searchQuery = ''.obs;
  final RxInt selectedCourseFilter = 0.obs; // 0 = all courses
  
  // Error handling
  final RxString errorMessage = ''.obs;
  final RxBool hasError = false.obs;
  
  // Selected certificate for detail view
  final Rx<CertificateModel?> selectedCertificate = Rx<CertificateModel?>(null);
  
  // Certificate stats
  final RxInt totalCertificates = 0.obs;
  final RxMap<int, int> certificatesPerCourse = <int, int>{}.obs;
  
  @override
  void onInit() {
    super.onInit();
    if (lmsService.isLoggedIn) {
      loadCertificates();
    }
  }
  
  /// Load user's certificates
  Future<void> loadCertificates({bool isRefresh = false}) async {
    if (!lmsService.isLoggedIn) {
      _handleError('Please login to view certificates');
      return;
    }
    
    if (isRefresh) {
      currentPage.value = 1;
      hasMoreData.value = true;
      _certificates.clear();
      _filteredCertificates.clear();
      certificatesPerCourse.clear();
    }
    
    try {
      isLoading.value = true;
      errorMessage.value = '';
      hasError.value = false;
      
      // Call the certificates API endpoint
      final response = await apiService.getPrivate(
        'wp-json/llms/v1/mobile-app/certificates',
        lmsService.currentUserToken ?? '',
        {
          'page': currentPage.value.toString(),
          'limit': perPage.toString(),
        },
      );
      
      if (response.statusCode == 200) {
        final data = response.body;
        
        if (data['success'] == true && data['certificates'] != null) {
          final List<dynamic> certificatesList = data['certificates'];
          
          for (var certData in certificatesList) {
            try {
              final certificate = CertificateModel.fromJson(certData);
              _certificates.add(certificate);
              
              // Update stats
              certificatesPerCourse[certificate.courseId] = 
                  (certificatesPerCourse[certificate.courseId] ?? 0) + 1;
            } catch (e) {
              print('Error parsing certificate: $e');
            }
          }
          
          totalCertificates.value = data['total'] ?? _certificates.length;
          
          // Check if there's more data
          if (certificatesList.length < perPage) {
            hasMoreData.value = false;
          }
        }
      } else {
        _handleError('Failed to load certificates');
      }
    } catch (e) {
      _handleError('Error loading certificates: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Load more certificates (pagination)
  Future<void> loadMoreCertificates() async {
    if (isLoadingMore.value || !hasMoreData.value) return;
    
    try {
      isLoadingMore.value = true;
      currentPage.value++;
      
      await loadCertificates();
    } finally {
      isLoadingMore.value = false;
    }
  }
  
  /// View certificate details
  Future<void> viewCertificate(CertificateModel certificate) async {
    selectedCertificate.value = certificate;
    
    // Navigate to certificate detail screen
    Get.toNamed(
      AppRouter.getCertificateDetail(),
      arguments: {'certificate': certificate},
    );
  }
  
  /// Download certificate as PDF
  Future<void> downloadCertificate(CertificateModel certificate) async {
    try {
      DialogHelper.showLoading();
      
      // Get download URL from API
      final response = await apiService.getPrivate(
        'wp-json/llms/v1/mobile-app/certificate/${certificate.id}/download',
        lmsService.currentUserToken ?? '',
        null,
      );
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200 && response.body['success'] == true) {
        final downloadUrl = response.body['download_url'];
        
        if (downloadUrl != null) {
          // Open download URL
          if (await canLaunchUrl(Uri.parse(downloadUrl))) {
            await launchUrl(
              Uri.parse(downloadUrl),
              mode: LaunchMode.externalApplication,
            );
            showToast('Certificate download started');
          } else {
            showToast('Could not open download link', isError: true);
          }
        }
      } else {
        showToast('Failed to get download link', isError: true);
      }
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Error downloading certificate', isError: true);
    }
  }
  
  /// Share certificate
  Future<void> shareCertificate(CertificateModel certificate) async {
    try {
      DialogHelper.showLoading();
      
      // Get share data from API
      final response = await apiService.postPrivate(
        'wp-json/llms/v1/mobile-app/certificate/${certificate.id}/share',
        {'method': 'link'},
        lmsService.currentUserToken ?? '',
      );
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200 && response.body['success'] == true) {
        final shareUrl = response.body['share_url'] ?? certificate.previewUrl;
        final message = response.body['message'] ?? 
            'Check out my certificate: ${certificate.title}';
        
        // Share using share_plus
        await Share.share(
          '$message\n\n$shareUrl',
          subject: 'Certificate: ${certificate.title}',
        );
      } else {
        // Fallback to basic share
        await Share.share(
          'I earned a certificate in ${certificate.courseTitle}!',
          subject: 'Certificate Earned',
        );
      }
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Error sharing certificate', isError: true);
    }
  }
  
  /// Verify certificate authenticity
  Future<void> verifyCertificate(CertificateModel certificate) async {
    try {
      DialogHelper.showLoading();
      
      final response = await apiService.postPrivate(
        'wp-json/llms/v1/mobile-app/certificate/verify',
        {
          'certificate_id': certificate.id,
          if (certificate.verificationCode != null) 
            'verification_code': certificate.verificationCode,
        },
        lmsService.currentUserToken ?? '',
      );
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200) {
        final isValid = response.body['valid'] ?? false;
        final message = response.body['message'] ?? 'Verification complete';
        
        Get.dialog(
          AlertDialog(
            title: Text(isValid ? '✓ Verified' : '✗ Not Verified'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Error verifying certificate', isError: true);
    }
  }
  
  /// Get certificates for a specific course
  Future<void> loadCourseCertificates(int courseId) async {
    try {
      isLoading.value = true;
      
      final response = await apiService.getPrivate(
        'wp-json/llms/v1/mobile-app/course/$courseId/certificates',
        lmsService.currentUserToken ?? '',
        null,
      );
      
      if (response.statusCode == 200 && response.body['success'] == true) {
        // Handle both earned and available certificates
        final earned = response.body['earned'] ?? [];
        final available = response.body['available'] ?? [];
        
        // Process earned certificates
        for (var certData in earned) {
          final certificate = CertificateModel.fromJson(certData);
          // Check if not already in list
          if (!_certificates.any((c) => c.id == certificate.id)) {
            _certificates.add(certificate);
          }
        }
        
        // Show available certificates if any
        if (available.isNotEmpty) {
          _showAvailableCertificates(available);
        }
      }
    } catch (e) {
      print('Error loading course certificates: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Show available certificates dialog
  void _showAvailableCertificates(List<dynamic> available) {
    Get.dialog(
      AlertDialog(
        title: Text('Available Certificates'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: available.map((cert) => ListTile(
              leading: Icon(Icons.card_membership, color: Colors.amber),
              title: Text(cert['title'] ?? 'Certificate'),
              subtitle: Text(cert['requirements']?[0]?['description'] ?? 
                  'Complete course requirements'),
            )).toList(),
          ),
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
  
  /// Search certificates
  void searchCertificates(String query) {
    searchQuery.value = query.toLowerCase();
    
    if (query.isEmpty) {
      _filteredCertificates.clear();
      return;
    }
    
    _filteredCertificates.value = _certificates.where((cert) =>
      cert.title.toLowerCase().contains(searchQuery.value) ||
      cert.courseTitle.toLowerCase().contains(searchQuery.value)
    ).toList();
  }
  
  /// Filter by course
  void filterByCourse(int courseId) {
    selectedCourseFilter.value = courseId;
    
    if (courseId == 0) {
      _filteredCertificates.clear();
      return;
    }
    
    _filteredCertificates.value = _certificates
        .where((cert) => cert.courseId == courseId)
        .toList();
  }
  
  /// Clear filters
  void clearFilters() {
    searchQuery.value = '';
    selectedCourseFilter.value = 0;
    _filteredCertificates.clear();
  }
  
  /// Refresh certificates
  Future<void> refreshCertificates() async {
    await loadCertificates(isRefresh: true);
  }
  
  /// Handle errors
  void _handleError(String message) {
    errorMessage.value = message;
    hasError.value = true;
    print(message);
  }
  
  /// Clear error
  void clearError() {
    errorMessage.value = '';
    hasError.value = false;
  }
  
  /// Get certificate count
  int get certificateCount => _certificates.length;
  
  /// Check if has certificates
  bool get hasCertificates => _certificates.isNotEmpty;
  
  /// Get unique courses with certificates
  List<int> get coursesWithCertificates {
    return _certificates.map((c) => c.courseId).toSet().toList();
  }
}

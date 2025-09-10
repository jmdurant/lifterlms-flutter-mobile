import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/api/api.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/helper/dialog_helper.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// Custom InAppBrowser to handle navigation
class MyInAppBrowser extends InAppBrowser {
  @override
  Future onLoadStart(url) async {
    // Close browser when navigating to about:blank
    if (url.toString() == 'about:blank') {
      close();
    }
  }
}

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
      
      print('CertificatesController - Loading certificates, page: ${currentPage.value}');
      
      // Use LMSService wrapper for plugin endpoint
      final response = await lmsService.getCertificates(
        page: currentPage.value,
        perPage: perPage,
      );
      
      print('CertificatesController - Response status: ${response.statusCode}');
      print('CertificatesController - Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = response.body;
        
        if (data['success'] == true && data['certificates'] != null) {
          final List<dynamic> certificatesList = data['certificates'];
          print('CertificatesController - Found ${certificatesList.length} certificates');
          
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
        } else {
          print('CertificatesController - Response success flag: ${data['success']}');
          print('CertificatesController - Certificates data: ${data['certificates']}');
        }
      } else {
        print('CertificatesController - HTTP error: ${response.statusCode} - ${response.statusText}');
        _handleError('Failed to load certificates (${response.statusCode})');
      }
    } catch (e) {
      print('CertificatesController - Exception: $e');
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
      
      print('CertificatesController - Downloading certificate ${certificate.id}');
      
      // Get certificate HTML content from API
      final response = await lmsService.getCertificateDownloadData(certificate.id);
      
      print('CertificatesController - Download response status: ${response.statusCode}');
      print('CertificatesController - Download response body keys: ${response.body.keys}');
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200 && response.body['success'] == true) {
        final htmlContent = response.body['html'];
        print('CertificatesController - HTML content length: ${htmlContent?.length ?? 0}');
        
        if (htmlContent != null && htmlContent.isNotEmpty) {
          // Create a properly formatted HTML with viewport and auto-fit
          final wrappedHtml = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes">
<style>
  * { box-sizing: border-box; }
  html, body { 
    margin: 0; 
    padding: 0; 
    width: 100%; 
    min-height: 100vh;
  }
  body {
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 20px;
    background: #f5f5f5;
  }
  .wrapper {
    width: 100%;
    max-width: 100%;
    display: flex;
    justify-content: center;
    align-items: center;
  }
</style>
</head>
<body>
<div class="wrapper">
$htmlContent
</div>
<script>
  // Auto-fit certificate on load and center it
  window.addEventListener('load', function() {
    var cert = document.querySelector('.certificate-container');
    if (cert) {
      cert.style.maxWidth = '100%';
      cert.style.margin = 'auto';
    }
    // Also update the body from the original HTML if it exists
    var originalBody = document.querySelector('body > body');
    if (originalBody) {
      originalBody.style.margin = '0';
      originalBody.style.padding = '0';
    }
  });
</script>
</body>
</html>
''';
          
          // Add JavaScript for print functionality and close button
          final enhancedHtml = wrappedHtml.replaceFirst(
            '</body>',
            '''
<div style="position: fixed; top: 50px; right: 20px; z-index: 9999;">
  <button onclick="window.location.href='about:blank';" style="
    background: rgba(0,0,0,0.5);
    color: white;
    border: none;
    padding: 0;
    border-radius: 50%;
    width: 44px;
    height: 44px;
    font-size: 24px;
    cursor: pointer;
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
    display: flex;
    align-items: center;
    justify-content: center;
    line-height: 1;
  ">
    ✕
  </button>
</div>
<div style="position: fixed; bottom: 30px; left: 50%; transform: translateX(-50%); z-index: 9999;">
  <button onclick="window.print()" style="
    background: #f59e0b;
    color: white;
    border: none;
    padding: 14px 32px;
    border-radius: 50px;
    font-size: 16px;
    font-weight: bold;
    cursor: pointer;
    box-shadow: 0 4px 8px rgba(0,0,0,0.2);
  ">
    🖨️ Print / Save PDF
  </button>
</div>
</body>
'''
          );
          
          // Open in InAppBrowser where user can print/save
          print('CertificatesController - Opening InAppBrowser with HTML');
          final browser = MyInAppBrowser();
          
          await browser.openData(
            data: enhancedHtml,
            mimeType: 'text/html',
            encoding: 'utf-8',
            baseUrl: WebUri('https://polite-tree.myliftersite.com'),
            settings: InAppBrowserClassSettings(
              browserSettings: InAppBrowserSettings(
                hideUrlBar: true,
                hideToolbarTop: true,
                presentationStyle: ModalPresentationStyle.FULL_SCREEN,
                transitionStyle: ModalTransitionStyle.COVER_VERTICAL,
              ),
              webViewSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                supportZoom: true,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                builtInZoomControls: true,
                displayZoomControls: false,
                horizontalScrollBarEnabled: false,
                verticalScrollBarEnabled: false,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
              ),
            ),
          );
        } else {
          print('CertificatesController - No HTML content available');
          showToast('Certificate content not available', isError: true);
        }
      } else {
        print('CertificatesController - Failed response: ${response.statusCode}');
        print('CertificatesController - Response body: ${response.body}');
        showToast('Failed to load certificate', isError: true);
      }
    } catch (e, stackTrace) {
      DialogHelper.hideLoading();
      print('CertificatesController - Error downloading certificate: $e');
      print('CertificatesController - Stack trace: $stackTrace');
      showToast('Error loading certificate: $e', isError: true);
    }
  }
  
  /// Share certificate
  Future<void> shareCertificate(CertificateModel certificate) async {
    try {
      DialogHelper.showLoading();
      
      // Get certificate HTML content from API
      final response = await lmsService.getCertificateDownloadData(certificate.id);
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200 && response.body['success'] == true) {
        final htmlContent = response.body['html'];
        
        if (htmlContent != null && htmlContent.isNotEmpty) {
          // Create a complete HTML document
          final fullHtml = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${certificate.title}</title>
</head>
<body style="margin: 0; padding: 20px; background: #f5f5f5; display: flex; justify-content: center; align-items: center; min-height: 100vh;">
$htmlContent
</body>
</html>
''';
          
          // Create XFile from HTML string
          final bytes = utf8.encode(fullHtml);
          final dir = await getTemporaryDirectory();
          // Use course title for filename, sanitized for filesystem
          final sanitizedTitle = certificate.courseTitle
              .replaceAll(RegExp(r'[<>:"/\|?*]'), '')
              .replaceAll(RegExp(r'\s+'), '_');
          final fileName = '${sanitizedTitle}_Certificate.html';
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          
          // Share the HTML file
          final xFile = XFile(file.path, mimeType: 'text/html');
          await Share.shareXFiles(
            [xFile],
            subject: 'Certificate: ${certificate.title}',
            text: 'I earned a certificate in ${certificate.courseTitle}!',
          );
          
          // Clean up temp file after a delay
          Future.delayed(Duration(seconds: 10), () {
            file.deleteSync();
          });
        } else {
          // Fallback to text share
          await Share.share(
            'I earned a certificate in ${certificate.courseTitle}!',
            subject: 'Certificate Earned',
          );
        }
      } else {
        // Fallback to basic share
        await Share.share(
          'I earned a certificate in ${certificate.courseTitle}!',
          subject: 'Certificate Earned',
        );
      }
    } catch (e) {
      DialogHelper.hideLoading();
      print('Error sharing certificate: $e');
      showToast('Error sharing certificate', isError: true);
    }
  }
  
  /// Verify certificate authenticity
  Future<void> verifyCertificate(CertificateModel certificate) async {
    try {
      DialogHelper.showLoading();
      
      final response = await lmsService.verifyCertificate(
        certificateId: certificate.id,
        code: certificate.verificationCode,
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
      
      final response = await lmsService.getCourseCertificates(courseId);
      
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

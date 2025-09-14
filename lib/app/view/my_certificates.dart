import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_app/app/controller/lifterlms/certificates_controller.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/theme.dart';
import 'package:get/get.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:indexed/indexed.dart';

class MyCertificatesScreen extends StatefulWidget {
  const MyCertificatesScreen({Key? key}) : super(key: key);

  @override
  State<MyCertificatesScreen> createState() => _MyCertificatesScreenState();
}

class _MyCertificatesScreenState extends State<MyCertificatesScreen> {
  final CertificatesController controller = Get.put(CertificatesController());
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      controller.loadMoreCertificates();
    }
  }

  @override
  Widget build(BuildContext context) {
    var screenWidth = (window.physicalSize.shortestSide / window.devicePixelRatio);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Gradient background
          Indexed(
            index: 1,
            child: Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                width: screenWidth,
                height: (209 / 375) * screenWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.1),
                      Theme.of(context).primaryColor.withOpacity(0.05),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              // Custom header
              Container(
                padding: EdgeInsets.fromLTRB(
                    0, MediaQuery.of(context).viewPadding.top + 10, 0, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    IconButton(
                      onPressed: () {
                        Get.back();
                      },
                      icon: const Icon(Icons.arrow_back),
                      color: Theme.of(context).iconTheme.color,
                      iconSize: 24,
                    ),
                    Text(
                      'My Certificates',
                      style: TextStyle(
                        fontFamily: 'Poppins-Medium',
                        fontWeight: FontWeight.w500,
                        fontSize: 24,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    Obx(() => controller.hasCertificates
                        ? IconButton(
                            icon: Icon(Icons.filter_list, color: Theme.of(context).iconTheme.color),
                            onPressed: _showFilterOptions,
                          )
                        : Container(width: 40)),
                  ],
                ),
              ),
              // Body content
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value && controller.certificates.isEmpty) {
                    return _buildLoadingState();
                  }

                  if (controller.hasError.value) {
                    return _buildErrorState();
                  }

                  if (!controller.hasCertificates) {
                    return _buildEmptyState();
                  }

                  return Column(
                    children: [
                      if (controller.hasCertificates) _buildSearchBar(),
                      _buildCertificateStats(),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: controller.refreshCertificates,
                          child: _buildCertificatesList(),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Theme.of(context).cardColor,
      padding: EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: controller.searchCertificates,
        decoration: InputDecoration(
          hintText: 'Search certificates...',
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          suffixIcon: controller.searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    controller.searchCertificates('');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).dividerColor.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCertificateStats() {
    return Container(
      color: Theme.of(context).cardColor,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${controller.totalCertificates} Certificates Earned',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          if (controller.selectedCourseFilter.value > 0)
            TextButton(
              onPressed: controller.clearFilters,
              child: Text('Clear Filter'),
            ),
        ],
      ),
    );
  }

  Widget _buildCertificatesList() {
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: controller.certificates.length +
          (controller.isLoadingMore.value ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= controller.certificates.length) {
          return _buildLoadingCard();
        }

        final certificate = controller.certificates[index];
        return _buildCertificateCard(certificate);
      },
    );
  }

  Widget _buildCertificateCard(CertificateModel certificate) {
    return GestureDetector(
      onTap: () => controller.viewCertificate(certificate),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Certificate image/icon
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade400, Colors.amber.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      size: 48,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'CERTIFICATE',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Certificate details
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          certificate.courseTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Earned ${_formatDate(certificate.earnedDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.share, size: 20),
                          color: Colors.grey.shade600,
                          onPressed: () => controller.shareCertificate(certificate),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                        IconButton(
                          icon: Icon(Icons.download, size: 20),
                          color: Colors.grey.shade600,
                          onPressed: () => controller.downloadCertificate(certificate),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    // Simple skeleton placeholder without external dependency
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => _buildLoadingCard(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.card_membership_outlined,
            size: 80,
            color: Theme.of(context).dividerColor,
          ),
          SizedBox(height: 16),
          Text(
            'No Certificates Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Complete courses to earn certificates',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Get.offNamed(AppRouter.getCourses()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Browse Courses',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'Error Loading Certificates',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            controller.errorMessage.value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: controller.refreshCertificates,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions() {
    Get.bottomSheet(
      Container(
        color: Theme.of(context).cardColor,
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Course',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Radio<int>(
                value: 0,
                groupValue: controller.selectedCourseFilter.value,
                onChanged: (value) {
                  controller.filterByCourse(value!);
                  Get.back();
                },
              ),
              title: Text('All Courses'),
              onTap: () {
                controller.filterByCourse(0);
                Get.back();
              },
            ),
            ...controller.coursesWithCertificates.map((courseId) {
              final count = controller.certificatesPerCourse[courseId] ?? 0;
              return ListTile(
                leading: Radio<int>(
                  value: courseId,
                  groupValue: controller.selectedCourseFilter.value,
                  onChanged: (value) {
                    controller.filterByCourse(value!);
                    Get.back();
                  },
                ),
                title: Text('Course $courseId'),
                trailing: Text('$count certificates'),
                onTap: () {
                  controller.filterByCourse(courseId);
                  Get.back();
                },
              );
            }).toList(),
          ],
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'today';
      } else if (difference.inDays == 1) {
        return 'yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      } else {
        final years = (difference.inDays / 365).floor();
        return '$years ${years == 1 ? 'year' : 'years'} ago';
      }
    } catch (e) {
      return dateString;
    }
  }
}

import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/controller/lifterlms/learning_controller.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_section_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_lesson_model.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:get/get.dart';
import 'package:indexed/indexed.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:vimeo_video_player/vimeo_video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({Key? key}) : super(key: key);

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  YoutubePlayerController? _youtubeController;
  String? _vimeoVideoId;
  
  var screenWidth = (window.physicalSize.shortestSide / window.devicePixelRatio);
  var screenHeight = (window.physicalSize.longestSide / window.devicePixelRatio);

  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }
  
  String? _extractYoutubeId(String content) {
    // Check for youtube.com/watch?v= format
    final watchRegex = RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]+)');
    final watchMatch = watchRegex.firstMatch(content);
    if (watchMatch != null) {
      return watchMatch.group(1);
    }
    
    // Check for youtu.be/ format
    final shortRegex = RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)');
    final shortMatch = shortRegex.firstMatch(content);
    if (shortMatch != null) {
      return shortMatch.group(1);
    }
    
    // Check for iframe with YouTube embed
    final iframeRegex = RegExp(r'<iframe[^>]*src=["' + "'" + r']https?://(?:www\.)?(?:youtube\.com|youtu\.be)/embed/([a-zA-Z0-9_-]+)');
    final iframeMatch = iframeRegex.firstMatch(content);
    if (iframeMatch != null) {
      return iframeMatch.group(1);
    }
    
    return null;
  }
  
  String? _extractVimeoId(String content) {
    // Check for vimeo.com/video_id format
    final vimeoRegex = RegExp(r'vimeo\.com/(\d+)');
    final vimeoMatch = vimeoRegex.firstMatch(content);
    if (vimeoMatch != null) {
      return vimeoMatch.group(1);
    }
    
    // Check for player.vimeo.com/video/video_id format
    final playerRegex = RegExp(r'player\.vimeo\.com/video/(\d+)');
    final playerMatch = playerRegex.firstMatch(content);
    if (playerMatch != null) {
      return playerMatch.group(1);
    }
    
    // Check for iframe with Vimeo embed
    final iframeRegex = RegExp(r'<iframe[^>]*src=["' + "'" + r']https?://(?:www\.)?(?:player\.)?vimeo\.com/video/(\d+)');
    final iframeMatch = iframeRegex.firstMatch(content);
    if (iframeMatch != null) {
      return iframeMatch.group(1);
    }
    
    return null;
  }
  
  void _initializeVideoPlayer(String? videoEmbed) {
    if (videoEmbed == null || videoEmbed.isEmpty) {
      _youtubeController?.dispose();
      _youtubeController = null;
      _vimeoVideoId = null;
      return;
    }
    
    // Try YouTube first
    final youtubeId = _extractYoutubeId(videoEmbed);
    if (youtubeId != null) {
      _vimeoVideoId = null; // Clear Vimeo
      _youtubeController?.dispose();
      _youtubeController = YoutubePlayerController(
        initialVideoId: youtubeId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          disableDragSeek: false,
          enableCaption: true,
        ),
      );
      return;
    }
    
    // Try Vimeo
    final vimeoId = _extractVimeoId(videoEmbed);
    if (vimeoId != null) {
      _youtubeController?.dispose();
      _youtubeController = null; // Clear YouTube
      _vimeoVideoId = vimeoId;
      return;
    }
    
    // No supported video found
    _youtubeController?.dispose();
    _youtubeController = null;
    _vimeoVideoId = null;
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LearningController>(builder: (controller) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        drawerEnableOpenDragGesture: false,
        drawer: _buildDrawer(controller),
        body: Stack(
          children: <Widget>[
            Indexed(
              index: 1,
              child: Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: (276 / 375) * screenWidth,
                  height: (209 / 375) * screenWidth,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                        image: AssetImage(
                          'assets/images/banner-my-course.png',
                        ),
                        fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Column(
              children: <Widget>[
                _buildHeader(controller),
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    
                    if (controller.hasError.value) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(controller.errorMessage.value),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => controller.loadCourseData(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    if (!controller.isEnrolled.value) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('You are not enrolled in this course'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                Get.back();
                              },
                              child: const Text('Go Back'),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    // Show current lesson content
                    if (controller.currentLesson.value != null) {
                      return _buildLessonContent(controller);
                    }
                    
                    // Show current quiz
                    if (controller.currentQuiz.value != null) {
                      return _buildQuizContent(controller);
                    }
                    
                    // Show current assignment
                    if (controller.currentAssignment.value != null) {
                      return _buildAssignmentContent(controller);
                    }
                    
                    // Default - show course overview
                    return _buildCourseOverview(controller);
                  }),
                ),
                _buildNavigationBar(controller),
              ],
            ),
          ],
        ),
      );
    });
  }
  
  Widget _buildHeader(LearningController controller) {
    return Container(
      height: 80.0,
      width: screenWidth,
      padding: const EdgeInsets.fromLTRB(0, 40, 0, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          IconButton(
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            icon: const Icon(Icons.menu),
            color: Colors.grey[900],
            iconSize: 30,
          ),
          Obx(() => Text(
            controller.currentCourse.value?.title ?? 'Learning',
            style: const TextStyle(
              fontFamily: 'Poppins-Medium',
              fontWeight: FontWeight.w500,
              fontSize: 18,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )),
          IconButton(
            onPressed: () {
              Get.back();
            },
            icon: const Icon(Icons.close),
            color: Colors.grey[900],
            iconSize: 30,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDrawer(LearningController controller) {
    return Drawer(
      child: Container(
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.of(context).viewPadding.top, 0, 0),
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Colors.amber,
              width: 4.0,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Obx(() => Text(
                    controller.currentCourse.value?.title ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'medium',
                      fontSize: 14,
                    ),
                  )),
                ),
                Container(
                  width: screenWidth * 0.13,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8.0),
                      bottomLeft: Radius.circular(8.0),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      _scaffoldKey.currentState?.closeDrawer();
                    },
                    icon: const Icon(
                      Icons.close,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(thickness: 1),
            Expanded(
              child: Obx(() {
                if (controller.sections.isEmpty && controller.isLoading.value) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                if (controller.sections.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No sections available',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: controller.sections.length,
                  itemBuilder: (context, sectionIndex) {
                    final section = controller.sections[sectionIndex];
                    final isLoading = section.lessons.isEmpty;
                    
                    return _SectionTile(
                      key: ValueKey('section_${section.id}'),
                      section: section,
                      sectionIndex: sectionIndex,
                      controller: controller,
                      isLoading: isLoading,
                      onLessonTap: (lessonId) {
                        controller.loadLesson(lessonId);
                        _scaffoldKey.currentState?.closeDrawer();
                      },
                    );
                  },
                );
              }),
            ),
            // Progress indicator
            Obx(() => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: controller.courseProgress.value / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${controller.completedLessons.value} / ${controller.totalLessons.value} lessons completed',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLessonContent(LearningController controller) {
    final lesson = controller.currentLesson.value!;
    
    // Initialize video player when lesson changes
    if (lesson.videoEmbed != null && lesson.videoEmbed!.isNotEmpty) {
      _initializeVideoPlayer(lesson.videoEmbed);
    } else {
      _youtubeController?.dispose();
      _youtubeController = null;
      _vimeoVideoId = null;
    }
    
    return RefreshIndicator(
      onRefresh: () => controller.loadLesson(lesson.id),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_youtubeController != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: YoutubePlayer(
                  controller: _youtubeController!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: Colors.red,
                  progressColors: const ProgressBarColors(
                    playedColor: Colors.red,
                    handleColor: Colors.redAccent,
                  ),
                ),
              )
            else if (_vimeoVideoId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                height: 250,
                child: VimeoVideoPlayer(
                  videoId: _vimeoVideoId!,
                  isAutoPlay: false,
                ),
              )
            else if (lesson.videoEmbed != null && lesson.videoEmbed!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: HtmlWidget(
                  lesson.videoEmbed!,
                  factoryBuilder: () => MyWidgetFactory(),
                ),
              ),
            if (lesson.audioEmbed != null && lesson.audioEmbed!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: HtmlWidget(
                  lesson.audioEmbed!,
                  factoryBuilder: () => MyWidgetFactory(),
                ),
              ),
            Obx(() => HtmlWidget(
              controller.cleanedLessonContent.value.isNotEmpty 
                  ? controller.cleanedLessonContent.value 
                  : lesson.content,
              factoryBuilder: () => MyWidgetFactory(),
              textStyle: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            )),
            const SizedBox(height: 32),
            if (controller.lessonCompletionStatus[lesson.id] != true)
              Center(
                child: ElevatedButton(
                  onPressed: controller.isCompletingLesson.value 
                      ? null 
                      : () => controller.completeLesson(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: controller.isCompletingLesson.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Mark as Complete',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuizContent(LearningController controller) {
    final quiz = controller.currentQuiz.value!;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            quiz.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Quiz functionality coming soon'),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => controller.navigateToNextLesson(),
            child: const Text('Skip Quiz'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAssignmentContent(LearningController controller) {
    final assignment = controller.currentAssignment.value!;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            assignment.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Assignment functionality coming soon'),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => controller.navigateToNextLesson(),
            child: const Text('Skip Assignment'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCourseOverview(LearningController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Course Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            if (controller.currentCourse.value != null) {
              return HtmlWidget(
                controller.currentCourse.value?.content ?? '',
                textStyle: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              );
            }
            return const Text('No course content available');
          }),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton(
              onPressed: () async {
                print('Start Learning button pressed');
                print('Sections count: ${controller.sections.length}');
                
                // If sections are not loaded, load them first
                if (controller.sections.isEmpty) {
                  print('Sections not loaded, loading now...');
                  await controller.loadCourseSectionsOnly();
                  print('After loading - Sections count: ${controller.sections.length}');
                }
                
                // Load first section's lessons if available
                if (controller.sections.isNotEmpty && controller.sections[0].id != null) {
                  await controller.loadSectionOnDemand(controller.sections[0].id!);
                }
                
                // Start with first lesson
                if (controller.sections.isNotEmpty && 
                    controller.sections.first.lessons.isNotEmpty) {
                  print('First section: ${controller.sections.first.title}');
                  print('First section has ${controller.sections.first.lessons.length} lessons');
                  print('Loading lesson ID: ${controller.sections.first.lessons.first.id}');
                  controller.loadLesson(controller.sections.first.lessons.first.id);
                } else {
                  print('No sections or lessons available');
                  if (controller.sections.isEmpty) {
                    print('Sections list is still empty after loading');
                  } else if (controller.sections.first.lessons.isEmpty) {
                    print('First section "${controller.sections.first.title}" has no lessons');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text(
                'Start Learning',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNavigationBar(LearningController controller) {
    return Obx(() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: controller.canNavigatePrevious.value 
                ? () => controller.navigateToPreviousLesson()
                : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous'),
            style: ElevatedButton.styleFrom(
              foregroundColor: controller.canNavigatePrevious.value 
                  ? Colors.white 
                  : Colors.grey,
              backgroundColor: controller.canNavigatePrevious.value 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey[300],
            ),
          ),
          Text(
            '${controller.courseProgress.value.toStringAsFixed(0)}% Complete',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          ElevatedButton.icon(
            onPressed: controller.canNavigateNext.value 
                ? () => controller.navigateToNextLesson()
                : null,
            label: const Text('Next'),
            icon: const Icon(Icons.arrow_forward),
            style: ElevatedButton.styleFrom(
              foregroundColor: controller.canNavigateNext.value 
                  ? Colors.white 
                  : Colors.grey,
              backgroundColor: controller.canNavigateNext.value 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey[300],
            ),
          ),
        ],
      ),
    ));
  }
}

// Optimized section tile that only builds visible lessons
class _SectionTile extends StatefulWidget {
  final LLMSSectionModel section;
  final int sectionIndex;
  final LearningController controller;
  final bool isLoading;
  final Function(int) onLessonTap;
  
  const _SectionTile({
    Key? key,
    required this.section,
    required this.sectionIndex,
    required this.controller,
    required this.isLoading,
    required this.onLessonTap,
  }) : super(key: key);
  
  @override
  _SectionTileState createState() => _SectionTileState();
}

class _SectionTileState extends State<_SectionTile> {
  bool _isExpanded = false;
  
  @override
  void initState() {
    super.initState();
    _isExpanded = widget.sectionIndex == widget.controller.selectedSectionIndex.value;
  }
  
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.section.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (widget.isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (!widget.isLoading && widget.section.lessons.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.section.lessons.length}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) async {
          setState(() {
            _isExpanded = expanded;
          });
          
          // Load lessons on demand if needed
          if (expanded && widget.section.id != null && widget.section.lessons.isEmpty) {
            print('Expanding section ${widget.section.id}: ${widget.section.title} - loading lessons...');
            await widget.controller.loadSectionOnDemand(widget.section.id!);
            // Force rebuild after loading
            if (mounted) {
              setState(() {});
            }
          }
        },
        // Only build children when expanded!
        children: _isExpanded ? _buildLessonsList() : [],
      ),
    );
  }
  
  List<Widget> _buildLessonsList() {
    if (widget.isLoading) {
      return [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Loading lessons...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
      ];
    }
    
    // Use ListView.builder for better performance with many lessons
    if (widget.section.lessons.length > 10) {
      return [
        SizedBox(
          height: widget.section.lessons.length * 56.0, // Approximate height per ListTile
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: widget.section.lessons.length,
            itemBuilder: (context, index) {
              return _buildLessonTile(widget.section.lessons[index]);
            },
          ),
        ),
      ];
    }
    
    // For fewer lessons, build them directly
    return widget.section.lessons.map((lesson) => _buildLessonTile(lesson)).toList();
  }
  
  Widget _buildLessonTile(LLMSLessonModel lesson) {
    return Obx(() {
      final isCompleted = widget.controller.lessonCompletionStatus[lesson.id] ?? false;
      final isCurrent = widget.controller.currentLesson.value?.id == lesson.id;
      
      return ListTile(
        leading: Icon(
          isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isCompleted ? Colors.green : Colors.grey,
          size: 20,
        ),
        title: Text(
          lesson.title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? Theme.of(context).primaryColor : null,
          ),
        ),
        onTap: () => widget.onLessonTap(lesson.id),
      );
    });
  }
}

class MyWidgetFactory extends WidgetFactory {
  @override
  bool get webViewMediaPlaybackAlwaysAllow => true;
  
  @override
  Future<bool> onTapUrl(String url) async {
    // Handle URL taps - launch in browser or in-app webview
    if (await canLaunch(url)) {
      await launch(url, forceSafariVC: true, forceWebView: false);
      return true;
    } else {
      print('Could not launch $url');
      return false;
    }
  }
}
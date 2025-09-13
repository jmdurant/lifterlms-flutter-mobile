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
import 'package:flutter_app/app/view/components/learning/learning-quiz.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_app/app/view/components/accordion-lesson-lifterlms.dart';
import 'package:html/parser.dart' as HtmlParser;

class LearningScreen extends StatefulWidget {
  const LearningScreen({Key? key}) : super(key: key);

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  YoutubePlayerController? _youtubeController;
  String? _vimeoVideoId;
  int? _currentLessonId;
  
  var screenWidth = (window.physicalSize.shortestSide / window.devicePixelRatio);
  var screenHeight = (window.physicalSize.longestSide / window.devicePixelRatio);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ensure controller picks up current route args when screen is created
    try {
      final controller = Get.find<LearningController>();
      controller.initializeFromArguments();
    } catch (_) {}
  }
  
  @override
  void dispose() {
    try { _youtubeController?.pause(); } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    try { _youtubeController?.pause(); } catch (_) {}
    super.deactivate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      try { _youtubeController?.pause(); } catch (_) {}
    }
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
      if (mounted) {
        setState(() {
          _youtubeController?.dispose();
          _youtubeController = null;
          _vimeoVideoId = null;
        });
      }
      return;
    }
    
    // Try YouTube first
    final youtubeId = _extractYoutubeId(videoEmbed);
    if (youtubeId != null) {
      print('Learning - Initializing YouTube player with ID: $youtubeId');
      if (mounted) {
        setState(() {
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
        });
      }
      return;
    }
    
    // Try Vimeo
    final vimeoId = _extractVimeoId(videoEmbed);
    if (vimeoId != null) {
      print('Learning - Initializing Vimeo player with ID: $vimeoId');
      if (mounted) {
        setState(() {
          _youtubeController?.dispose();
          _youtubeController = null; // Clear YouTube
          _vimeoVideoId = vimeoId;
        });
      }
      return;
    }
    
    // No supported video found
    print('Learning - No supported video found in embed');
    if (mounted) {
      setState(() {
        _youtubeController?.dispose();
        _youtubeController = null;
        _vimeoVideoId = null;
      });
    }
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
                    
                    // Show current lesson content (which includes quiz if available)
                    if (controller.currentLesson.value != null) {
                      return _buildLessonContent(controller);
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
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).viewPadding.top + 5,
        left: 8,
        right: 8,
      ),
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
          Expanded(
            child: Obx(() => Text(
              controller.currentCourse.value?.title ?? 'Learning',
              style: const TextStyle(
                fontFamily: 'Poppins-Medium',
                fontWeight: FontWeight.w500,
                fontSize: 18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            )),
          ),
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
            // Auto-advance toggle
            Obx(() => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Auto-advance lessons',
                    style: TextStyle(fontSize: 14),
                  ),
                  Switch(
                    value: controller.autoAdvanceEnabled.value,
                    onChanged: (_) => controller.toggleAutoAdvance(),
                    activeColor: Colors.green,
                  ),
                ],
              ),
            )),
            const Divider(thickness: 1),
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
    if (_currentLessonId != lesson.id) {
      print('Learning - Lesson changed from $_currentLessonId to ${lesson.id}');
      _currentLessonId = lesson.id;
      
      // Immediately clear old video state
      _youtubeController?.dispose();
      _youtubeController = null;
      _vimeoVideoId = null;
      
      // Defer new video initialization to after build
      if (lesson.videoEmbed != null && lesson.videoEmbed!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print('Learning - Initializing video for lesson ${lesson.id}');
            _initializeVideoPlayer(lesson.videoEmbed);
          }
        });
      }
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
            // Check for audio in content field
            if (_hasAudioInContent(lesson.content))
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: _buildAudioPlayer(lesson.content),
              ),
            // Check for PDF in content field
            if (_hasPdfInContent(lesson.content))
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                height: 600,
                child: _buildPdfViewer(lesson.content),
              ),
            // Check for H5P interactive content
            if (_hasH5pContent(lesson.content))
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                height: 650,
                child: _buildH5pViewer(lesson.content),
              ),
            // Check for PowerPoint content
            if (_hasPowerPointContent(lesson.content))
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: _buildPowerPointViewer(lesson.content),
              ),
            // Check for form content
            if (_hasFormContent(lesson.content))
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: _buildFormMessage(lesson.content),
              ),
            // Check for interactive/JavaScript content (tabs, accordions, etc)
            if (_hasInteractiveContent(lesson.content))
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: _buildInteractiveViewer(lesson.content),
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
            
            // Show quiz section if available
            Obx(() {
              final currentLesson = controller.currentLesson.value;
              if (currentLesson == null) return const SizedBox.shrink();
              
              if (currentLesson.hasQuiz && controller.currentQuiz.value != null) {
                final quiz = controller.currentQuiz.value!;
                // Show the quiz interface directly
                return Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  child: LearningQuiz(
                    data: currentLesson,
                    dataQuiz: quiz,
                  ),
                );
              } else if (currentLesson.hasQuiz && currentLesson.quizId != null) {
                // Quiz is loading
                return Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: null,
                      icon: const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: const Text('Loading quiz...'),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            
            Center(
              child: Obx(() {
                final currentLesson = controller.currentLesson.value;
                if (currentLesson == null) return const SizedBox.shrink();
                
                final isCompleted = controller.lessonCompletionStatus[currentLesson.id] ?? false;
                
                return ElevatedButton.icon(
                  onPressed: isCompleted || controller.isCompletingLesson.value
                      ? null 
                      : () => controller.completeLesson(),
                  icon: Icon(
                    isCompleted ? Icons.check_circle : Icons.check,
                    color: Colors.white,
                  ),
                  label: Text(
                    isCompleted ? 'Completed' : 'Mark as Complete',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCompleted ? Colors.grey : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    disabledBackgroundColor: isCompleted ? Colors.grey : Colors.green.shade300,
                  ),
                );
              }),
            ),
          ],
        ),
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
  
  String _cleanCourseDescription(String content) {
    // Remove lesson links and navigation elements from course description
    if (content.isEmpty) return content;
    
    try {
      final document = HtmlParser.parse(content);
      
      // Remove the course syllabus section completely - this contains all the lesson links
      final syllabusElements = document.querySelectorAll('.wp-block-llms-course-syllabus');
      for (var element in syllabusElements) {
        element.remove();
      }
      
      // Remove the continue button section
      final continueButtons = document.querySelectorAll('.wp-block-llms-course-continue-button');
      for (var element in continueButtons) {
        element.remove();
      }
      
      // Remove the meta info sections
      final metaInfo = document.querySelectorAll('.llms-meta-info');
      for (var element in metaInfo) {
        element.remove();
      }
      
      // Remove the tracks section
      final tracks = document.querySelectorAll('.llms-meta.llms-tracks');
      for (var element in tracks) {
        element.remove();
      }
      
      // Remove the instructor info section
      final instructorInfo = document.querySelectorAll('.llms-instructor-info');
      for (var element in instructorInfo) {
        element.remove();
      }
      
      // Remove any remaining lesson links just in case
      final lessonLinks = document.querySelectorAll('a[href*="lesson"], a[href*="topic"]');
      for (var link in lessonLinks) {
        link.remove();
      }
      
      // Remove any ul/ol lists that contain lesson links
      final lists = document.querySelectorAll('ul, ol');
      for (var list in lists) {
        final hasLessonLinks = list.querySelectorAll('a[href*="lesson"], a[href*="topic"]').isNotEmpty;
        if (hasLessonLinks) {
          list.remove();
        }
      }
      
      // Remove "Continue" or navigation paragraphs (keeping this as fallback)
      final paragraphs = document.querySelectorAll('p');
      for (var p in paragraphs) {
        final text = p.text.toLowerCase();
        if (text.contains('continue') || 
            text.contains('click here') || 
            text.contains('next lesson') ||
            text.contains('start here')) {
          p.remove();
        }
      }
      
      // Remove any divs with lesson navigation
      final navDivs = document.querySelectorAll('div[class*="lesson"], div[class*="navigation"]');
      for (var div in navDivs) {
        div.remove();
      }
      
      return document.outerHtml;
    } catch (e) {
      print('Error cleaning course description: $e');
      return content;
    }
  }
  
  Widget _buildCourseOverview(LearningController controller) {
    final screenWidth = MediaQuery.of(context).size.width;
    final course = controller.currentCourse.value;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course Image and Title
          Stack(
            children: [
              Container(
                width: screenWidth,
                constraints: BoxConstraints(
                  maxHeight: (250 / 375) * screenWidth,
                ),
                child: Image.network(
                  (course?.featuredImage?.isNotEmpty ?? false) &&
                          !course!.featuredImage.contains('placeholder')
                      ? course.featuredImage
                      : "assets/images/placeholder-500x300.png",
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset("assets/images/placeholder-500x300.png", fit: BoxFit.contain);
                  },
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Text(
                  course?.title ?? '',
                  maxLines: 2,
                  style: const TextStyle(
                    fontFamily: 'Poppins-Medium',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3.0,
                        color: Color.fromARGB(150, 0, 0, 0),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Course Stats
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Lessons count
                    Row(
                      children: [
                        const Icon(Icons.book_outlined, size: 18, color: Color(0xFFFBC815)),
                        const SizedBox(width: 4),
                        Obx(() => Text(
                          '${controller.totalLessons.value} lessons',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFF939393),
                          ),
                        )),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Progress
                    Row(
                      children: [
                        const Icon(Icons.trending_up, size: 18, color: Color(0xFFFBC815)),
                        const SizedBox(width: 4),
                        Obx(() => Text(
                          '${controller.courseProgress.value.toStringAsFixed(0)}% complete',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFF939393),
                          ),
                        )),
                      ],
                    ),
                  ],
                ),
                // Enrolled students
                if ((course?.enrollmentCount ?? 0) > 0)
                  Row(
                    children: [
                      Image.asset('assets/images/icon/icon-student.png', 
                        color: const Color(0xFFFBC815), height: 16, width: 16),
                      const SizedBox(width: 4),
                      Text(
                        course?.enrollmentCount?.toString() ?? '0',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF939393),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Course Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About this course',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (course != null)
                  HtmlWidget(
                    _cleanCourseDescription(course.content ?? ''),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Curriculum Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Course Curriculum',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Obx(() => controller.sections.isNotEmpty
                  ? AccordionLessonLifterLMS(
                      data: controller.sections,
                      indexLesson: controller.handleGetIndexLesson(),
                      onNavigate: (lessonData) {
                        // Navigate to the lesson
                        controller.loadLesson(lessonData.id);
                      },
                    )
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Start/Resume Button
          Center(
            child: Obx(() => ElevatedButton.icon(
              onPressed: () => controller.startOrResumeLearning(),
              icon: Icon(
                controller.completedLessons.value > 0 
                    ? Icons.play_arrow 
                    : Icons.play_circle_outline,
                size: 24,
              ),
              label: Text(
                controller.completedLessons.value > 0 
                    ? 'Resume Learning' 
                    : 'Start Course',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            )),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  
  Widget _buildNavigationBar(LearningController controller) {
    return Obx(() {
        // Special case: if on overview, show different navigation
        if (controller.currentLesson.value == null) {
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 21),
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
              // Empty space or back button
              const SizedBox(width: 100),
              Text(
                '${controller.courseProgress.value.toStringAsFixed(0)}% Complete',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Start/Resume button
              ElevatedButton.icon(
                onPressed: () => controller.startOrResumeLearning(),
                label: Text(
                  controller.completedLessons.value > 0 
                      ? 'Resume' 
                      : 'Start',
                ),
                icon: Icon(
                  controller.completedLessons.value > 0 
                      ? Icons.play_arrow 
                      : Icons.play_circle_outline,
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        );
      }
      
      // Normal navigation for lessons
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 21),
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
            // Show "Back to Overview" for first lesson, otherwise "Previous"
            controller.isFirstLesson.value
                ? ElevatedButton.icon(
                    onPressed: () => controller.backToOverview(),
                    icon: const Icon(Icons.home),
                    label: const Text('Overview'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                  )
                : ElevatedButton.icon(
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
            // Show "Back to Overview" for last lesson, otherwise "Next"
            controller.isLastLesson.value
                ? ElevatedButton.icon(
                    onPressed: () => controller.backToOverview(),
                    label: const Text('Overview'),
                    icon: const Icon(Icons.home),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                  )
                : ElevatedButton.icon(
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
      );
    });
  }
  
  // Helper methods for content detection and rendering
  bool _hasAudioInContent(String content) {
    final hasAudio = content.contains('<audio') && content.contains('.mp3');
    if (hasAudio) print('DEBUG: Audio detected in content');
    return hasAudio;
  }
  
  bool _hasPdfInContent(String content) {
    final hasPdf = content.contains('type="application/pdf"') || 
           (content.contains('.pdf') && content.contains('<object'));
    if (hasPdf) print('DEBUG: PDF detected in content');
    return hasPdf;
  }
  
  bool _hasH5pContent(String content) {
    final hasH5p = content.contains('h5p.org/h5p/embed');
    if (hasH5p) print('DEBUG: H5P detected in content');
    return hasH5p;
  }
  
  bool _hasPowerPointContent(String content) {
    final hasPpt = content.contains('[embeddoc') && 
                   (content.contains('.pptx') || content.contains('.ppt'));
    if (hasPpt) print('DEBUG: PowerPoint detected in content');
    return hasPpt;
  }
  
  bool _hasFormContent(String content) {
    // Detect common form patterns
    final hasForm = (content.contains('complete the form below') || 
                    content.contains('fill out the form') ||
                    content.contains('submit the form') ||
                    content.contains('[contact-form') ||
                    content.contains('[wpforms') ||
                    content.contains('[ninja_form') ||
                    content.contains('[gravityform')) &&
                    !content.contains('<form') && // No actual form HTML
                    !content.contains('<input'); // No input fields
    if (hasForm) print('DEBUG: Form detected but not rendered in content');
    return hasForm;
  }
  
  bool _hasInteractiveContent(String content) {
    // Detect interactive WordPress blocks that need JavaScript
    final hasInteractive = content.contains('wp-block-kadence-tabs') ||
                          content.contains('wp-block-kadence-accordion') ||
                          content.contains('wp-block-toggle') ||
                          content.contains('wp-block-tabs') ||
                          content.contains('wp-block-accordion') ||
                          content.contains('data-toggle') ||
                          content.contains('onclick=') ||
                          (content.contains('kt-tabs') && content.contains('kt-tab-title'));
    if (hasInteractive) print('DEBUG: Interactive content detected (tabs/accordion/etc)');
    return hasInteractive;
  }
  
  Widget _buildAudioPlayer(String content) {
    // Extract audio URL from content
    final audioPattern = RegExp(r'<audio[^>]*src="([^"]+)"');
    final match = audioPattern.firstMatch(content);
    if (match != null) {
      final audioUrl = match.group(1);
      print('DEBUG: Found audio URL: $audioUrl');
      
      // Create HTML with audio player
      final audioHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { 
      margin: 0; 
      padding: 20px;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100px;
    }
    audio { 
      width: 100%; 
      max-width: 500px;
    }
  </style>
</head>
<body>
  <audio controls>
    <source src="$audioUrl" type="audio/mpeg">
    <source src="$audioUrl" type="audio/mp3">
    Your browser does not support the audio element.
  </audio>
</body>
</html>
''';
      
      return SizedBox(
        height: 100,
        child: InAppWebView(
          initialData: InAppWebViewInitialData(data: audioHtml),
          initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
              useShouldOverrideUrlLoading: false,
              mediaPlaybackRequiresUserGesture: false,
              javaScriptEnabled: true,
            ),
          ),
        ),
      );
    }
    print('DEBUG: No audio URL found in content');
    return const SizedBox.shrink();
  }
  
  Widget _buildPdfViewer(String content) {
    // Extract PDF URL from content
    final pdfPattern = RegExp(r'data="([^"]+\.pdf[^"]*)"');
    final match = pdfPattern.firstMatch(content);
    if (match != null) {
      final pdfUrl = match.group(1);
      print('DEBUG: Found PDF URL: $pdfUrl');
      // Use InAppWebView to display PDF
      return SizedBox(
        height: 600,
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(pdfUrl!)),
          initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
              useShouldOverrideUrlLoading: false,
              mediaPlaybackRequiresUserGesture: false,
              javaScriptEnabled: true,
            ),
          ),
        ),
      );
    }
    print('DEBUG: No PDF URL found in content');
    return const SizedBox.shrink();
  }
  
  Widget _buildH5pViewer(String content) {
    // Extract H5P iframe
    final h5pPattern = RegExp(r'<iframe[^>]*src="(https://h5p\.org/h5p/embed/[^"]+)"[^>]*>');
    final match = h5pPattern.firstMatch(content);
    if (match != null) {
      final h5pUrl = match.group(1);
      print('DEBUG: Found H5P URL: $h5pUrl');
      // Use InAppWebView for better iframe support
      return SizedBox(
        height: 650,
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(h5pUrl!)),
          initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
              useShouldOverrideUrlLoading: false,
              mediaPlaybackRequiresUserGesture: false,
              javaScriptEnabled: true,
            ),
          ),
        ),
      );
    }
    print('DEBUG: No H5P URL found in content');
    return const SizedBox.shrink();
  }
  
  Widget _buildInteractiveViewer(String content) {
    print('DEBUG: Building interactive content viewer');
    
    // Create a full HTML page with the content and necessary styles
    final htmlPage = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { 
      margin: 0; 
      padding: 16px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      font-size: 14px;
      line-height: 1.6;
    }
    /* Hide LifterLMS navigation elements */
    .llms-parent-course-link,
    .llms-favorite-wrapper,
    .llms-lesson-button-wrapper,
    .llms-lesson-navigation,
    .llms-lesson-preview { 
      display: none !important; 
    }
    /* Style tabs if present */
    .kt-tabs-wrap { margin: 20px 0; }
    .kt-tabs-title-list { display: flex; flex-wrap: wrap; }
    .kt-title-item { cursor: pointer; padding: 10px 15px; }
    .kt-title-item.kt-tab-title-active { 
      background: #007cba; 
      color: white; 
    }
  </style>
  <!-- Include any necessary JavaScript libraries -->
  <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
</head>
<body>
  $content
  <script>
    // Basic tab functionality if jQuery is available
    if (typeof jQuery !== 'undefined') {
      jQuery(document).ready(function(\$) {
        // Kadence tabs
        \$('.kt-title-item').on('click', function() {
          var tabId = \$(this).attr('id');
          var contentId = tabId.replace('tab-', '');
          
          // Hide all tab contents
          \$('.kt-tab-inner-content').hide();
          // Show selected tab content
          \$('#' + contentId).show();
          
          // Update active states
          \$('.kt-title-item').removeClass('kt-tab-title-active');
          \$(this).addClass('kt-tab-title-active');
        });
        
        // Trigger first tab
        \$('.kt-title-item:first').trigger('click');
      });
    }
  </script>
</body>
</html>
''';
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.widgets_outlined, color: Colors.purple.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Interactive content detected - rendered with JavaScript support',
                  style: TextStyle(color: Colors.purple.shade700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 500,
          child: InAppWebView(
            initialData: InAppWebViewInitialData(data: htmlPage),
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                useShouldOverrideUrlLoading: false,
                mediaPlaybackRequiresUserGesture: false,
                javaScriptEnabled: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFormMessage(String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.feedback_outlined, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                'Form Submission Required',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This lesson contains a form that needs to be completed on the website. Forms are not currently supported in the mobile app.',
            style: TextStyle(color: Colors.blue.shade700),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              // Open lesson in browser
              final controller = Get.find<LearningController>();
              final lessonId = controller.currentLesson.value?.id;
              final courseId = controller.courseId;
              final lessonUrl = 'https://polite-tree.myliftersite.com/course/lesson/$lessonId';
              
              if (await canLaunch(lessonUrl)) {
                await launch(lessonUrl);
              }
            },
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open in Browser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPowerPointViewer(String content) {
    // Extract PowerPoint URL from embeddoc shortcode
    final pptPattern = RegExp(r'\[embeddoc url[=:]"([^"]+\.(pptx?|ppt))"?\]');
    final match = pptPattern.firstMatch(content);
    if (match != null) {
      final pptUrl = match.group(1);
      print('DEBUG: Found PowerPoint URL: $pptUrl');
      
      // Option 1: Try to use Office Online viewer (works for publicly accessible files)
      final officeViewerUrl = 'https://view.officeapps.live.com/op/view.aspx?src=${Uri.encodeComponent(pptUrl!)}';
      
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PowerPoint presentation detected. Attempting to load...',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 600,
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(officeViewerUrl)),
              initialOptions: InAppWebViewGroupOptions(
                crossPlatform: InAppWebViewOptions(
                  useShouldOverrideUrlLoading: false,
                  mediaPlaybackRequiresUserGesture: false,
                  javaScriptEnabled: true,
                ),
              ),
              onLoadError: (controller, url, code, message) {
                print('Failed to load PowerPoint viewer: $message');
              },
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () async {
              if (await canLaunch(pptUrl)) {
                await launch(pptUrl);
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Download PowerPoint'),
          ),
        ],
      );
    }
    print('DEBUG: No PowerPoint URL found in content');
    return const SizedBox.shrink();
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
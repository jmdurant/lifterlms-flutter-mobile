import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/mobx-store/course_store.dart';
import 'package:flutter_app/app/backend/mobx-store/init_store.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_lesson_model.dart';
import 'package:flutter_app/app/controller/lifterlms/learning_controller.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:fwfh_just_audio/fwfh_just_audio.dart';
import 'package:fwfh_webview/fwfh_webview.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:watch_it/watch_it.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LearningLesson extends StatefulWidget {
  final LLMSLessonModel data;

  LearningLesson({super.key, required this.data});

  @override
  State<LearningLesson> createState() => _LearningLessonState();
}

class _LearningLessonState extends State<LearningLesson> {
  final courseStore = locator<CourseStore>();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  YoutubePlayerController? _youtubeController;

  get webView => true;

  @override
  void initState() {
    super.initState();
    _initializeYoutubePlayer();
  }

  void _initializeYoutubePlayer() {
    // Extract YouTube video ID from videoEmbed if present
    if (widget.data.videoEmbed != null && widget.data.videoEmbed!.isNotEmpty) {
      print('YouTube: Checking videoEmbed: ${widget.data.videoEmbed}');
      final videoId = _extractYoutubeId(widget.data.videoEmbed!);
      if (videoId != null) {
        print('YouTube: Found video ID: $videoId');
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            disableDragSeek: false,
            enableCaption: true,
          ),
        );
      } else {
        print('YouTube: No video ID found in embed content');
      }
    } else {
      print('YouTube: No videoEmbed data available');
    }
  }

  String? _extractYoutubeId(String content) {
    // Try to extract YouTube video ID from various formats
    print('YouTube: Extracting ID from content: $content');
    
    // First check if it's a plain YouTube URL (most common case from the API)
    // Format 1: https://www.youtube.com/watch?v=VIDEO_ID
    // Format 2: https://youtu.be/VIDEO_ID
    
    // Check for youtube.com/watch?v= format
    final watchRegex = RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]+)');
    final watchMatch = watchRegex.firstMatch(content);
    if (watchMatch != null) {
      print('YouTube: Found watch URL match: ${watchMatch.group(1)}');
      return watchMatch.group(1);
    }
    
    // Check for youtu.be/ format
    final shortRegex = RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)');
    final shortMatch = shortRegex.firstMatch(content);
    if (shortMatch != null) {
      print('YouTube: Found short URL match: ${shortMatch.group(1)}');
      return shortMatch.group(1);
    }
    
    // Check for iframe with YouTube embed (less common but still possible)
    final iframeRegex = RegExp(r'<iframe[^>]*src=["' + "'" + r']https?://(?:www\.)?(?:youtube\.com|youtu\.be)/embed/([a-zA-Z0-9_-]+)');
    final iframeMatch = iframeRegex.firstMatch(content);
    if (iframeMatch != null) {
      print('YouTube: Found iframe match: ${iframeMatch.group(1)}');
      return iframeMatch.group(1);
    }
    
    // Check for embed URL directly
    final embedRegex = RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]+)');
    final embedMatch = embedRegex.firstMatch(content);
    if (embedMatch != null) {
      print('YouTube: Found embed URL match: ${embedMatch.group(1)}');
      return embedMatch.group(1);
    }
    
    print('YouTube: No video ID found in content');
    return null;
  }

  String? _extractPdfUrl(String? content) {
    if (content == null) return null;
    // Extract PDF URL from content - look for both direct links and href links
    final pdfRegex = RegExp(r'(?:href=["' + "'" + r'])?https?://[^\s<>"' + "'" + r']+\.pdf');
    final match = pdfRegex.firstMatch(content);
    if (match != null) {
      String url = match.group(0)!;
      // Remove href=" or href=' if present
      url = url.replaceAll(RegExp(r'^href=["' + "'" + r']'), '');
      return url;
    }
    return null;
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? pdfUrl = _extractPdfUrl(widget.data.content);
    return GetBuilder<LearningController>(builder: (value) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: Text(
              widget.data.title,
              style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'medium',
                  color: Colors.black,
                  fontWeight: FontWeight.w600),
            )),
        if (_youtubeController != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
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
        else if (widget.data.videoEmbed != null)
          Container(
              // padding: EdgeInsets.only(left: 10),
              child: HtmlWidget(
            widget.data.videoEmbed!,
            textStyle: TextStyle(
              fontFamily: 'Poppins-ExtraLight',
              fontSize: 13,
              color: Colors.black,
              fontWeight: FontWeight.w300,
            ),
          )),
        if (widget.data.content != null && pdfUrl == null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: HtmlWidget(
              widget.data.content.toString(),
              factoryBuilder: () => MyWidgetFactory(),
              textStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        if (widget.data.content != null && pdfUrl != null)
          Container(
            height: MediaQuery.of(context).size.height * 0.8,
            child: SfPdfViewer.network(pdfUrl,key: _pdfViewerKey,),

          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (value.isEnrolled.value)
              if (value.sections.isNotEmpty &&
                  !value.isLessonCompleted(widget.data.id))
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 0, 0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green[600],
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12), // foreground color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => value.completeLesson(),
                    child:
                        Text(tr(LocaleKeys.learningScreen_lesson_btnComplete)),
                  ),
                ),
            if (value.courseProgress.value >= 100)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12), // foreground color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => value.showCourseCompletionDialog(),
                  child: Text(tr(LocaleKeys.learningScreen_finishCourse)),
                ),
              ),
          ],
        )
      ]);
    });
  }

}

class MyWidgetFactory extends WidgetFactory
    with WebViewFactory, JustAudioFactory {
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

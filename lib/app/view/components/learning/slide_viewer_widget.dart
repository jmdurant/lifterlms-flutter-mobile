import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SlideData {
  final String title;
  final String layout;
  final List<String>? bullets;
  final String? body;
  final String? imageUrl;
  final String? backgroundColor;
  final String? script;

  SlideData({
    required this.title,
    this.layout = 'title_bullets',
    this.bullets,
    this.body,
    this.imageUrl,
    this.backgroundColor,
    this.script,
  });

  factory SlideData.fromJson(Map<String, dynamic> json) {
    return SlideData(
      title: json['title'] ?? '',
      layout: json['layout'] ?? 'title_bullets',
      bullets: json['bullets'] != null
          ? List<String>.from(json['bullets'])
          : null,
      body: json['body'],
      imageUrl: json['image_url'],
      backgroundColor: json['background_color'],
      script: json['script'],
    );
  }

  /// Build readable text from slide content for TTS when no script is provided
  String get readableText {
    if (script != null && script!.isNotEmpty) return script!;
    final parts = <String>[title];
    if (body != null && body!.isNotEmpty) parts.add(body!);
    if (bullets != null && bullets!.isNotEmpty) parts.addAll(bullets!);
    return parts.join('. ');
  }
}

enum TtsState { playing, paused, stopped }

class SlideViewerWidget extends StatefulWidget {
  final List<SlideData> slides;
  final VoidCallback? onComplete;

  const SlideViewerWidget({
    super.key,
    required this.slides,
    this.onComplete,
  });

  @override
  State<SlideViewerWidget> createState() => _SlideViewerWidgetState();
}

class _SlideViewerWidgetState extends State<SlideViewerWidget> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _showScript = false;

  // TTS
  late FlutterTts _tts;
  TtsState _ttsState = TtsState.stopped;
  double _speechRate = 0.5;
  final double _pitch = 1.0;

  // Lecture mode (auto-advance + TTS)
  bool _lectureMode = false;
  bool _autoAdvance = false;
  Timer? _autoAdvanceTimer;
  final int _autoAdvanceDelay = 5; // seconds after TTS finishes before advancing

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initTts();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(_pitch);

    _tts.setCompletionHandler(() {
      setState(() => _ttsState = TtsState.stopped);
      // Auto-advance after TTS completes
      if (_lectureMode || _autoAdvance) {
        _scheduleAutoAdvance();
      }
    });

    _tts.setCancelHandler(() {
      setState(() => _ttsState = TtsState.stopped);
    });

    _tts.setPauseHandler(() {
      setState(() => _ttsState = TtsState.paused);
    });

    _tts.setContinueHandler(() {
      setState(() => _ttsState = TtsState.playing);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ── TTS Controls ──────────────────────────────────────────────────────────

  Future<void> _speak([String? text]) async {
    _autoAdvanceTimer?.cancel();
    final speakText = text ?? widget.slides[_currentPage].readableText;
    if (speakText.isEmpty) return;
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(_pitch);
    await _tts.speak(speakText);
    setState(() => _ttsState = TtsState.playing);
  }

  Future<void> _stop() async {
    _autoAdvanceTimer?.cancel();
    await _tts.stop();
    setState(() => _ttsState = TtsState.stopped);
  }

  Future<void> _pause() async {
    await _tts.pause();
    setState(() => _ttsState = TtsState.paused);
  }

  // ── Auto-Advance ──────────────────────────────────────────────────────────

  void _scheduleAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (_currentPage >= widget.slides.length - 1) {
      // Last slide — end lecture mode
      setState(() {
        _lectureMode = false;
        _autoAdvance = false;
      });
      widget.onComplete?.call();
      return;
    }
    _autoAdvanceTimer = Timer(Duration(seconds: _autoAdvanceDelay), () {
      if (!mounted) return;
      _goToPage(_currentPage + 1);
    });
  }

  void _goToPage(int page) {
    if (page < 0 || page >= widget.slides.length) return;
    _autoAdvanceTimer?.cancel();
    _tts.stop();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    _autoAdvanceTimer?.cancel();
    _tts.stop();
    setState(() {
      _currentPage = index;
      _showScript = false;
      _ttsState = TtsState.stopped;
    });
    // In lecture mode, auto-speak the new slide
    if (_lectureMode) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _lectureMode) _speak();
      });
    }
  }

  // ── Lecture Mode Toggle ───────────────────────────────────────────────────

  void _toggleLectureMode() {
    setState(() {
      _lectureMode = !_lectureMode;
      _autoAdvance = _lectureMode;
    });
    if (_lectureMode) {
      _speak(); // Start narrating current slide
    } else {
      _stop();
    }
  }

  void _toggleAutoAdvance() {
    setState(() => _autoAdvance = !_autoAdvance);
    if (!_autoAdvance) {
      _autoAdvanceTimer?.cancel();
    }
  }

  // ── Color Helpers ─────────────────────────────────────────────────────────

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF1a73e8);
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  bool _isLightColor(Color color) {
    return color.computeLuminance() > 0.5;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();
    final currentSlide = widget.slides[_currentPage];
    final hasScript = currentSlide.script != null && currentSlide.script!.isNotEmpty;

    return Column(
      children: [
        // Slide deck
        Container(
          height: 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.slides.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    return _buildSlide(widget.slides[index]);
                  },
                ),
                // Page indicator dots
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.slides.length, (index) {
                      return Container(
                        width: index == _currentPage ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: index == _currentPage
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      );
                    }),
                  ),
                ),
                // Slide counter + lecture mode indicator
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    children: [
                      if (_lectureMode)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_filled, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('LECTURE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_currentPage + 1} / ${widget.slides.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Navigation arrows
                if (_currentPage > 0)
                  Positioned(
                    left: 4,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _navArrow(Icons.chevron_left, () => _goToPage(_currentPage - 1)),
                    ),
                  ),
                if (_currentPage < widget.slides.length - 1)
                  Positioned(
                    right: 4,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _navArrow(Icons.chevron_right, () => _goToPage(_currentPage + 1)),
                    ),
                  ),
                // TTS speaking indicator
                if (_ttsState == TtsState.playing)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.volume_up, color: Colors.white, size: 18),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Control Bar ──────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // Lecture mode button
              _controlButton(
                icon: _lectureMode ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                label: _lectureMode ? 'Stop' : 'Lecture',
                color: _lectureMode ? Colors.red.shade600 : Colors.green.shade700,
                onTap: _toggleLectureMode,
              ),
              const SizedBox(width: 4),
              // TTS play/pause
              if (!_lectureMode) ...[
                _controlButton(
                  icon: _ttsState == TtsState.playing ? Icons.pause : Icons.volume_up,
                  label: _ttsState == TtsState.playing ? 'Pause' : 'Speak',
                  color: Colors.blue.shade700,
                  onTap: () {
                    if (_ttsState == TtsState.playing) {
                      _pause();
                    } else {
                      _speak();
                    }
                  },
                ),
                const SizedBox(width: 4),
              ],
              // Auto-advance toggle
              _controlButton(
                icon: Icons.skip_next,
                label: 'Auto',
                color: _autoAdvance ? Colors.orange.shade700 : Colors.grey.shade600,
                onTap: _toggleAutoAdvance,
                active: _autoAdvance,
              ),
              const Spacer(),
              // Speed control
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.speed, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 100,
                    child: Slider(
                      value: _speechRate,
                      min: 0.25,
                      max: 1.0,
                      divisions: 6,
                      label: '${(_speechRate * 2).toStringAsFixed(1)}x',
                      onChanged: (val) {
                        setState(() => _speechRate = val);
                        _tts.setSpeechRate(val);
                      },
                    ),
                  ),
                  Text(
                    '${(_speechRate * 2).toStringAsFixed(1)}x',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Narration Script Panel ───────────────────────────────────────
        if (hasScript)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange.shade200),
              borderRadius: BorderRadius.circular(8),
              color: Colors.orange.shade50,
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _showScript = !_showScript),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.record_voice_over, size: 18, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Slide ${_currentPage + 1} Narration',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                        Icon(
                          _showScript ? Icons.expand_less : Icons.expand_more,
                          color: Colors.orange.shade700,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showScript)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SelectableText(
                      currentSlide.script!,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _navArrow(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  // ── Slide Layouts ─────────────────────────────────────────────────────────

  Widget _buildSlide(SlideData slide) {
    final bgColor = _parseColor(slide.backgroundColor);
    final textColor = _isLightColor(bgColor) ? Colors.black87 : Colors.white;
    final subtitleColor = _isLightColor(bgColor)
        ? Colors.black54
        : Colors.white.withValues(alpha: 0.85);

    switch (slide.layout) {
      case 'full_image':
        return _buildFullImageSlide(slide, bgColor, textColor);
      case 'title_image':
        return _buildTitleImageSlide(slide, bgColor, textColor, subtitleColor);
      case 'title_body':
        return _buildTitleBodySlide(slide, bgColor, textColor, subtitleColor);
      case 'title_bullets':
      default:
        return _buildTitleBulletsSlide(slide, bgColor, textColor, subtitleColor);
    }
  }

  Widget _buildTitleBulletsSlide(
      SlideData slide, Color bg, Color titleColor, Color bulletColor) {
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slide.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: titleColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          if (slide.bullets != null)
            ...slide.bullets!.map((bullet) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 7),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: bulletColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          bullet,
                          style: TextStyle(
                            fontSize: 15,
                            color: bulletColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildTitleBodySlide(
      SlideData slide, Color bg, Color titleColor, Color bodyColor) {
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slide.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: titleColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                slide.body ?? '',
                style: TextStyle(
                  fontSize: 15,
                  color: bodyColor,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleImageSlide(
      SlideData slide, Color bg, Color titleColor, Color subtitleColor) {
    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 12),
            child: Text(
              slide.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: titleColor,
                height: 1.3,
              ),
            ),
          ),
          if (slide.imageUrl != null && slide.imageUrl!.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: slide.imageUrl!,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Icon(Icons.broken_image, size: 48, color: subtitleColor),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullImageSlide(SlideData slide, Color bg, Color titleColor) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (slide.imageUrl != null && slide.imageUrl!.isNotEmpty)
          CachedNetworkImage(
            imageUrl: slide.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: bg,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (context, url, error) => Container(
              color: bg,
              child: const Center(child: Icon(Icons.broken_image, size: 48)),
            ),
          )
        else
          Container(color: bg),
        if (slide.title.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Text(
                slide.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

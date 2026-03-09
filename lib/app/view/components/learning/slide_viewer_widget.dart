import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
}

class SlideViewerWidget extends StatefulWidget {
  final List<SlideData> slides;
  const SlideViewerWidget({Key? key, required this.slides}) : super(key: key);

  @override
  State<SlideViewerWidget> createState() => _SlideViewerWidgetState();
}

class _SlideViewerWidgetState extends State<SlideViewerWidget> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _showScript = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF1a73e8);
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  bool _isLightColor(Color color) {
    return color.computeLuminance() > 0.5;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();

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
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                      _showScript = false;
                    });
                  },
                  itemBuilder: (context, index) {
                    return _buildSlide(widget.slides[index]);
                  },
                ),
                // Page indicator
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
                // Slide counter
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
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
                ),
                // Navigation arrows
                if (_currentPage > 0)
                  Positioned(
                    left: 4,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _navArrow(Icons.chevron_left, () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }),
                    ),
                  ),
                if (_currentPage < widget.slides.length - 1)
                  Positioned(
                    right: 4,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _navArrow(Icons.chevron_right, () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Per-slide narration script toggle
        if (widget.slides[_currentPage].script != null &&
            widget.slides[_currentPage].script!.isNotEmpty)
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
                      widget.slides[_currentPage].script!,
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
        // Title overlay at bottom
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

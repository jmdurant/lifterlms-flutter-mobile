import React, {useState, useEffect, useRef, useCallback} from 'react';
import {
  View,
  Text,
  ScrollView,
  Image,
  StyleSheet,
  Dimensions,
  TouchableOpacity,
} from 'react-native';
import Tts from 'react-native-tts';

interface Slide {
  title: string;
  layout?: string;
  bullets?: string[];
  body?: string;
  image_url?: string;
  background_color?: string;
  script?: string;
}

interface SlideViewerProps {
  slides: Slide[];
  onComplete?: () => void;
}

const {height: SCREEN_HEIGHT} = Dimensions.get('window');

function getReadableText(slide: Slide): string {
  if (slide.script) return slide.script;
  const parts: string[] = [slide.title];
  if (slide.body) parts.push(slide.body);
  if (slide.bullets) parts.push(...slide.bullets);
  return parts.join('. ');
}

const SlideViewer: React.FC<SlideViewerProps> = ({slides, onComplete}) => {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [showScript, setShowScript] = useState(false);
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [lectureMode, setLectureMode] = useState(false);
  const [autoAdvance, setAutoAdvance] = useState(false);
  const [speechRate, setSpeechRate] = useState(0.5);

  const autoAdvanceTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lectureModeRef = useRef(lectureMode);
  const autoAdvanceRef = useRef(autoAdvance);
  const currentIndexRef = useRef(currentIndex);
  const AUTO_ADVANCE_DELAY = 3; // seconds after TTS finishes

  // Keep refs in sync
  useEffect(() => {
    lectureModeRef.current = lectureMode;
  }, [lectureMode]);
  useEffect(() => {
    autoAdvanceRef.current = autoAdvance;
  }, [autoAdvance]);
  useEffect(() => {
    currentIndexRef.current = currentIndex;
  }, [currentIndex]);

  // Initialize TTS
  useEffect(() => {
    Tts.setDefaultLanguage('en-US');
    Tts.setDefaultRate(speechRate);

    const finishListener = Tts.addEventListener('tts-finish' as any, () => {
      setIsSpeaking(false);
      if (lectureModeRef.current || autoAdvanceRef.current) {
        scheduleAutoAdvance();
      }
    });

    const cancelListener = Tts.addEventListener('tts-cancel' as any, () => {
      setIsSpeaking(false);
    });

    return () => {
      (finishListener as any)?.remove?.();
      (cancelListener as any)?.remove?.();
      Tts.stop();
      clearTimer();
    };
  }, []);

  // Update TTS rate when changed
  useEffect(() => {
    Tts.setDefaultRate(speechRate);
  }, [speechRate]);

  const clearTimer = () => {
    if (autoAdvanceTimer.current) {
      clearTimeout(autoAdvanceTimer.current);
      autoAdvanceTimer.current = null;
    }
  };

  const scheduleAutoAdvance = useCallback(() => {
    clearTimer();
    if (currentIndexRef.current >= slides.length - 1) {
      setLectureMode(false);
      setAutoAdvance(false);
      onComplete?.();
      return;
    }
    autoAdvanceTimer.current = setTimeout(() => {
      goToSlide(currentIndexRef.current + 1);
    }, AUTO_ADVANCE_DELAY * 1000);
  }, [slides.length, onComplete]);

  const speak = useCallback(
    (text?: string) => {
      clearTimer();
      Tts.stop();
      const speakText = text || getReadableText(slides[currentIndexRef.current]);
      if (!speakText) return;
      Tts.speak(speakText);
      setIsSpeaking(true);
    },
    [slides],
  );

  const stopSpeech = useCallback(() => {
    clearTimer();
    Tts.stop();
    setIsSpeaking(false);
  }, []);

  const goToSlide = useCallback(
    (index: number) => {
      if (index < 0 || index >= slides.length) return;
      clearTimer();
      Tts.stop();
      setIsSpeaking(false);
      setShowScript(false);
      setCurrentIndex(index);
      // In lecture mode, auto-speak the new slide after a brief delay
      if (lectureModeRef.current) {
        setTimeout(() => {
          const text = getReadableText(slides[index]);
          if (text) {
            Tts.speak(text);
            setIsSpeaking(true);
          }
        }, 500);
      }
    },
    [slides],
  );

  const toggleLectureMode = useCallback(() => {
    if (lectureMode) {
      setLectureMode(false);
      setAutoAdvance(false);
      stopSpeech();
    } else {
      setLectureMode(true);
      setAutoAdvance(true);
      speak();
    }
  }, [lectureMode, speak, stopSpeech]);

  const toggleAutoAdvance = useCallback(() => {
    setAutoAdvance(prev => {
      if (prev) clearTimer();
      return !prev;
    });
  }, []);

  const adjustSpeed = useCallback(
    (delta: number) => {
      setSpeechRate(prev => {
        const newRate = Math.max(0.25, Math.min(1.0, prev + delta));
        return newRate;
      });
    },
    [],
  );

  const goNext = () => {
    if (currentIndex < slides.length - 1) {
      goToSlide(currentIndex + 1);
    } else if (onComplete) {
      onComplete();
    }
  };

  const goPrev = () => {
    if (currentIndex > 0) {
      goToSlide(currentIndex - 1);
    }
  };

  const toggleScript = () => {
    if (slide?.script) {
      setShowScript(prev => !prev);
    }
  };

  const slide = slides[currentIndex];
  if (!slide) return null;

  const bgColor = slide.background_color || '#1a73e8';
  const isLight = isLightColor(bgColor);
  const textColor = isLight ? '#212121' : '#FFFFFF';
  const subColor = isLight ? '#616161' : 'rgba(255,255,255,0.85)';

  return (
    <View style={[styles.container, {backgroundColor: bgColor}]}>
      {/* Lecture mode indicator */}
      {lectureMode && (
        <View style={styles.lectureBadge}>
          <Text style={styles.lectureBadgeText}>LECTURE MODE</Text>
        </View>
      )}

      {/* Speaking indicator */}
      {isSpeaking && (
        <View style={styles.speakingIndicator}>
          <Text style={styles.speakingText}>Speaking...</Text>
        </View>
      )}

      {/* Slide content */}
      <View style={styles.slideContent}>
        {renderSlide(slide, textColor, subColor)}
      </View>

      {/* Progress bar */}
      <View style={styles.progressContainer}>
        <View style={styles.progressTrack}>
          <View
            style={[
              styles.progressFill,
              {width: `${((currentIndex + 1) / slides.length) * 100}%`},
            ]}
          />
        </View>
        <Text style={styles.progressText}>
          {currentIndex + 1} / {slides.length}
        </Text>
      </View>

      {/* Control bar */}
      <View style={styles.controlBar}>
        {/* Lecture mode toggle */}
        <TouchableOpacity
          style={[
            styles.controlBtn,
            lectureMode && styles.controlBtnActive,
          ]}
          onPress={toggleLectureMode}>
          <Text
            style={[
              styles.controlBtnText,
              {color: lectureMode ? '#ef5350' : '#66bb6a'},
            ]}>
            {lectureMode ? '⏹ Stop' : '▶ Lecture'}
          </Text>
        </TouchableOpacity>

        {/* TTS speak/stop */}
        {!lectureMode && (
          <TouchableOpacity
            style={styles.controlBtn}
            onPress={() => (isSpeaking ? stopSpeech() : speak())}>
            <Text style={[styles.controlBtnText, {color: '#42a5f5'}]}>
              {isSpeaking ? '⏸ Pause' : '🔊 Speak'}
            </Text>
          </TouchableOpacity>
        )}

        {/* Auto-advance toggle */}
        <TouchableOpacity
          style={[
            styles.controlBtn,
            autoAdvance && styles.controlBtnActive,
          ]}
          onPress={toggleAutoAdvance}>
          <Text
            style={[
              styles.controlBtnText,
              {color: autoAdvance ? '#ffa726' : '#9e9e9e'},
            ]}>
            ⏭ Auto {autoAdvance ? 'ON' : 'OFF'}
          </Text>
        </TouchableOpacity>

        {/* Speed controls */}
        <TouchableOpacity style={styles.controlBtn} onPress={() => adjustSpeed(-0.1)}>
          <Text style={styles.controlBtnText}>🐢</Text>
        </TouchableOpacity>
        <Text style={styles.speedLabel}>{(speechRate * 2).toFixed(1)}x</Text>
        <TouchableOpacity style={styles.controlBtn} onPress={() => adjustSpeed(0.1)}>
          <Text style={styles.controlBtnText}>🐇</Text>
        </TouchableOpacity>
      </View>

      {/* Navigation buttons */}
      <View style={styles.navHints}>
        {currentIndex > 0 ? (
          <TouchableOpacity style={styles.navBtn} onPress={goPrev}>
            <Text style={styles.navBtnText}>◀ Previous</Text>
          </TouchableOpacity>
        ) : (
          <View style={styles.navBtnPlaceholder} />
        )}
        {slide.script ? (
          <TouchableOpacity style={styles.navBtn} onPress={toggleScript}>
            <Text style={styles.navBtnText}>
              {showScript ? '✕ Hide' : '📖 Narration'}
            </Text>
          </TouchableOpacity>
        ) : (
          <View style={styles.navBtnPlaceholder} />
        )}
        <TouchableOpacity style={styles.navBtn} onPress={goNext}>
          <Text style={styles.navBtnText}>
            {currentIndex < slides.length - 1 ? 'Next ▶' : 'Done ✓'}
          </Text>
        </TouchableOpacity>
      </View>

      {/* Narration overlay */}
      {showScript && slide.script && (
        <View style={styles.scriptOverlay}>
          <View style={styles.scriptBox}>
            <Text style={styles.scriptLabel}>Narration</Text>
            <ScrollView style={styles.scriptScroll}>
              <Text style={styles.scriptText}>{slide.script}</Text>
            </ScrollView>
          </View>
        </View>
      )}
    </View>
  );
};

function renderSlide(slide: Slide, textColor: string, subColor: string) {
  switch (slide.layout) {
    case 'full_image':
      return (
        <View style={styles.fullImageSlide}>
          {slide.image_url && (
            <Image
              source={{uri: slide.image_url}}
              style={StyleSheet.absoluteFillObject}
              resizeMode="cover"
            />
          )}
          {slide.title ? (
            <View style={styles.fullImageOverlay}>
              <Text style={styles.fullImageTitle}>{slide.title}</Text>
            </View>
          ) : null}
        </View>
      );

    case 'title_image':
      return (
        <View style={styles.titleImageSlide}>
          <Text style={[styles.slideTitle, {color: textColor}]}>
            {slide.title}
          </Text>
          {slide.image_url && (
            <Image
              source={{uri: slide.image_url}}
              style={styles.slideImage}
              resizeMode="contain"
            />
          )}
        </View>
      );

    case 'title_body':
      return (
        <View style={styles.titleBodySlide}>
          <Text style={[styles.slideTitle, {color: textColor}]}>
            {slide.title}
          </Text>
          <ScrollView style={styles.bodyScroll}>
            <Text style={[styles.bodyText, {color: subColor}]}>
              {slide.body}
            </Text>
          </ScrollView>
        </View>
      );

    case 'title_bullets':
    default:
      return (
        <View style={styles.titleBulletsSlide}>
          <Text style={[styles.slideTitle, {color: textColor}]}>
            {slide.title}
          </Text>
          <View style={styles.bulletList}>
            {slide.bullets?.map((bullet, i) => (
              <View key={i} style={styles.bulletRow}>
                <View style={[styles.bulletDot, {backgroundColor: subColor}]} />
                <Text style={[styles.bulletText, {color: subColor}]}>
                  {bullet}
                </Text>
              </View>
            ))}
          </View>
        </View>
      );
  }
}

function isLightColor(hex: string): boolean {
  const c = hex.replace('#', '');
  const r = parseInt(c.substring(0, 2), 16);
  const g = parseInt(c.substring(2, 4), 16);
  const b = parseInt(c.substring(4, 6), 16);
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.5;
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  slideContent: {
    flex: 1,
    justifyContent: 'center',
  },
  // Lecture mode badge
  lectureBadge: {
    position: 'absolute',
    top: 20,
    left: 80,
    backgroundColor: 'rgba(76, 175, 80, 0.9)',
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: 12,
    zIndex: 10,
  },
  lectureBadgeText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '700',
    letterSpacing: 1,
  },
  // Speaking indicator
  speakingIndicator: {
    position: 'absolute',
    top: 20,
    right: 80,
    backgroundColor: 'rgba(66, 165, 245, 0.9)',
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: 12,
    zIndex: 10,
  },
  speakingText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
  },
  // Title + Bullets
  titleBulletsSlide: {
    paddingHorizontal: 80,
    paddingTop: 60,
  },
  slideTitle: {
    fontSize: 42,
    fontWeight: '700',
    marginBottom: 30,
    lineHeight: 50,
  },
  bulletList: {
    paddingLeft: 10,
  },
  bulletRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 16,
  },
  bulletDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginTop: 10,
    marginRight: 16,
  },
  bulletText: {
    fontSize: 26,
    lineHeight: 36,
    flex: 1,
  },
  // Title + Body
  titleBodySlide: {
    paddingHorizontal: 80,
    paddingTop: 60,
    flex: 1,
  },
  bodyScroll: {
    flex: 1,
  },
  bodyText: {
    fontSize: 24,
    lineHeight: 36,
  },
  // Title + Image
  titleImageSlide: {
    paddingHorizontal: 80,
    paddingTop: 40,
    flex: 1,
  },
  slideImage: {
    flex: 1,
    marginTop: 20,
    marginBottom: 20,
    borderRadius: 12,
  },
  // Full Image
  fullImageSlide: {
    flex: 1,
  },
  fullImageOverlay: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingHorizontal: 80,
    paddingVertical: 40,
    backgroundColor: 'rgba(0,0,0,0.6)',
  },
  fullImageTitle: {
    fontSize: 36,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  // Progress
  progressContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 80,
    paddingBottom: 8,
  },
  progressTrack: {
    flex: 1,
    height: 4,
    backgroundColor: 'rgba(255,255,255,0.2)',
    borderRadius: 2,
  },
  progressFill: {
    height: 4,
    backgroundColor: '#4FC3F7',
    borderRadius: 2,
  },
  progressText: {
    color: 'rgba(255,255,255,0.7)',
    fontSize: 16,
    marginLeft: 16,
  },
  // Control bar
  controlBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 80,
    paddingBottom: 8,
    gap: 8,
  },
  controlBtn: {
    backgroundColor: 'rgba(255,255,255,0.1)',
    paddingHorizontal: 20,
    paddingVertical: 8,
    borderRadius: 8,
  },
  controlBtnActive: {
    backgroundColor: 'rgba(255,255,255,0.2)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.3)',
  },
  controlBtnText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  speedLabel: {
    color: 'rgba(255,255,255,0.7)',
    fontSize: 16,
    fontWeight: '600',
    minWidth: 40,
    textAlign: 'center',
  },
  // Nav buttons
  navHints: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 80,
    paddingBottom: 30,
  },
  navBtn: {
    backgroundColor: 'rgba(255,255,255,0.15)',
    paddingHorizontal: 28,
    paddingVertical: 12,
    borderRadius: 8,
  },
  navBtnText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
  },
  navBtnPlaceholder: {
    width: 130,
  },
  // Script overlay
  scriptOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.85)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 80,
  },
  scriptBox: {
    backgroundColor: '#1e1e1e',
    borderRadius: 16,
    padding: 40,
    maxWidth: 900,
    maxHeight: SCREEN_HEIGHT * 0.7,
  },
  scriptLabel: {
    color: '#4FC3F7',
    fontSize: 20,
    fontWeight: '700',
    marginBottom: 16,
  },
  scriptScroll: {
    flexGrow: 0,
  },
  scriptText: {
    color: '#EEEEEE',
    fontSize: 22,
    lineHeight: 34,
  },
});

export default SlideViewer;

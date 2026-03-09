import React, {useEffect, useState, useCallback} from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
  TouchableOpacity,
} from 'react-native';
import {useNavigation, useRoute} from '@react-navigation/native';
import api from '../api/lifterlms';
import SlideViewer from '../components/SlideViewer';

const LessonScreen: React.FC = () => {
  const navigation = useNavigation<any>();
  const route = useRoute<any>();
  const {lessonId} = route.params;

  const [lesson, setLesson] = useState<any>(null);
  const [slides, setSlides] = useState<any[]>([]);
  const [script, setScript] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [showScript, setShowScript] = useState(false);

  const loadLesson = useCallback(async () => {
    setIsLoading(true);
    try {
      const [lessonData, slidesData, scriptData] = await Promise.all([
        api.getLesson(lessonId),
        api.getLessonSlides(lessonId).catch(() => ({has_slides: false, slides: []})),
        api.getLessonScript(lessonId).catch(() => ({has_script: false, script: ''})),
      ]);

      setLesson(lessonData);

      if (slidesData.has_slides && Array.isArray(slidesData.slides)) {
        setSlides(slidesData.slides);
      }

      if (scriptData.has_script && scriptData.script) {
        setScript(scriptData.script);
      }
    } catch (err) {
      console.log('Failed to load lesson:', err);
    } finally {
      setIsLoading(false);
    }
  }, [lessonId]);

  useEffect(() => {
    loadLesson();
  }, [loadLesson]);

  const handleComplete = async () => {
    try {
      await api.completeLesson(lessonId);
    } catch (_) {}
    navigation.goBack();
  };

  const getTitle = (obj: any) =>
    typeof obj?.title === 'string' ? obj.title : obj?.title?.rendered || '';

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#4FC3F7" />
      </View>
    );
  }

  // If slides exist, show fullscreen slide viewer
  if (slides.length > 0) {
    return (
      <SlideViewer
        slides={slides}
        onComplete={handleComplete}
      />
    );
  }

  // Fallback: text-based lesson content
  const content = lesson?.content?.rendered?.replace(/<[^>]*>/g, '') || '';

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <Text style={styles.title}>{getTitle(lesson)}</Text>

        {content ? (
          <Text style={styles.content}>{content}</Text>
        ) : (
          <Text style={styles.empty}>No content available for this lesson.</Text>
        )}

        {/* Narration script */}
        {script && (
          <View style={styles.scriptSection}>
            <TouchableOpacity
              style={styles.scriptToggle}
              onPress={() => setShowScript(!showScript)}>
              <Text style={styles.scriptToggleText}>
                {showScript ? '▼' : '▶'} Narration Script
              </Text>
            </TouchableOpacity>
            {showScript && (
              <Text style={styles.scriptText}>{script}</Text>
            )}
          </View>
        )}
      </ScrollView>

      {/* Bottom bar */}
      <View style={styles.bottomBar}>
        <TouchableOpacity
          style={styles.backButton}
          onPress={() => navigation.goBack()}>
          <Text style={styles.backButtonText}>◀ Back</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.completeButton}
          onPress={handleComplete}>
          <Text style={styles.completeButtonText}>Mark Complete ✓</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  loadingContainer: {
    flex: 1,
    backgroundColor: '#0a0a0a',
    justifyContent: 'center',
    alignItems: 'center',
  },
  scrollContent: {
    padding: 80,
    paddingBottom: 120,
  },
  title: {
    fontSize: 38,
    fontWeight: '800',
    color: '#FFFFFF',
    marginBottom: 30,
  },
  content: {
    fontSize: 22,
    lineHeight: 34,
    color: '#DDDDDD',
  },
  empty: {
    fontSize: 20,
    color: '#666',
    fontStyle: 'italic',
  },
  scriptSection: {
    marginTop: 40,
    backgroundColor: '#1e1e1e',
    borderRadius: 12,
    overflow: 'hidden',
  },
  scriptToggle: {
    padding: 20,
  },
  scriptToggleText: {
    color: '#4FC3F7',
    fontSize: 20,
    fontWeight: '600',
  },
  scriptText: {
    color: '#CCCCCC',
    fontSize: 18,
    lineHeight: 28,
    padding: 20,
    paddingTop: 0,
  },
  bottomBar: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: 30,
    paddingHorizontal: 60,
    backgroundColor: 'rgba(10,10,10,0.95)',
    borderTopWidth: 1,
    borderTopColor: '#222',
  },
  backButton: {
    backgroundColor: '#333',
    paddingHorizontal: 30,
    paddingVertical: 14,
    borderRadius: 10,
  },
  backButtonText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
  },
  completeButton: {
    backgroundColor: '#2E7D32',
    paddingHorizontal: 30,
    paddingVertical: 14,
    borderRadius: 10,
  },
  completeButtonText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '700',
  },
});

export default LessonScreen;

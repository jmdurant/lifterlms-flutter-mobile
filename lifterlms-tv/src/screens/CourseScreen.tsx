import React, {useEffect, useState, useCallback} from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
  TouchableOpacity,
  Image,
} from 'react-native';
import {useNavigation, useRoute} from '@react-navigation/native';
import api from '../api/lifterlms';

interface Section {
  id: number;
  title: {rendered: string} | string;
  lessons: Lesson[];
}

interface Lesson {
  id: number;
  title: {rendered: string} | string;
  quiz_id?: number;
}

const CourseScreen: React.FC = () => {
  const navigation = useNavigation<any>();
  const route = useRoute<any>();
  const {courseId} = route.params;

  const [course, setCourse] = useState<any>(null);
  const [sections, setSections] = useState<Section[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  const loadCourse = useCallback(async () => {
    setIsLoading(true);
    try {
      const courseData = await api.getCourse(courseId);
      setCourse(courseData);

      const sectionsData = await api.getSections(courseId);
      const secs = Array.isArray(sectionsData) ? sectionsData : [];

      // Load lessons for each section
      const withLessons = await Promise.all(
        secs.map(async (sec: any) => {
          let lessons: any[] = [];
          try {
            const res = await api.getLessons(sec.id);
            lessons = Array.isArray(res) ? res : [];
          } catch (_) {}
          return {...sec, lessons};
        }),
      );

      setSections(withLessons);
    } catch (err) {
      console.log('Failed to load course:', err);
    } finally {
      setIsLoading(false);
    }
  }, [courseId]);

  useEffect(() => {
    loadCourse();
  }, [loadCourse]);

  const getTitle = (obj: any) =>
    typeof obj?.title === 'string' ? obj.title : obj?.title?.rendered || '';

  const handleLessonPress = (lessonId: number) => {
    navigation.navigate('Lesson', {lessonId, courseId});
  };

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#4FC3F7" />
      </View>
    );
  }

  const courseTitle = getTitle(course);
  const description = course?.content?.rendered
    ?.replace(/<[^>]*>/g, '')
    .trim()
    .substring(0, 300);

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        {/* Hero */}
        <View style={styles.hero}>
          {course?.image?.src && (
            <Image
              source={{uri: course.image.src}}
              style={styles.heroImage}
              resizeMode="cover"
            />
          )}
          <View style={styles.heroOverlay}>
            <Text style={styles.courseTitle}>{courseTitle}</Text>
            {description ? (
              <Text style={styles.courseDescription}>{description}</Text>
            ) : null}
            <View style={styles.statsRow}>
              {sections.length > 0 && (
                <Text style={styles.stat}>
                  {sections.reduce((n, s) => n + s.lessons.length, 0)} Lessons
                </Text>
              )}
              {sections.length > 1 && (
                <Text style={styles.stat}>{sections.length} Sections</Text>
              )}
            </View>
          </View>
        </View>

        {/* Start button */}
        {sections.length > 0 && sections[0].lessons.length > 0 && (
          <View style={styles.startRow}>
            <TouchableOpacity
              style={styles.startButton}
              onPress={() =>
                handleLessonPress(sections[0].lessons[0].id)
              }>
              <Text style={styles.startButtonText}>▶  Start Course</Text>
            </TouchableOpacity>
          </View>
        )}

        {/* Curriculum */}
        <View style={styles.curriculum}>
          <Text style={styles.sectionHeader}>Curriculum</Text>
          {sections.map((section, si) => (
            <View key={section.id} style={styles.section}>
              <Text style={styles.sectionTitle}>
                Section {si + 1}: {getTitle(section)}
              </Text>
              {section.lessons.map((lesson, li) => (
                <TouchableOpacity
                  key={lesson.id}
                  style={styles.lessonRow}
                  onPress={() => handleLessonPress(lesson.id)}>
                  <Text style={styles.lessonNumber}>{li + 1}</Text>
                  <Text style={styles.lessonTitle}>{getTitle(lesson)}</Text>
                  {lesson.quiz_id && (
                    <View style={styles.quizBadge}>
                      <Text style={styles.quizBadgeText}>Quiz</Text>
                    </View>
                  )}
                  <Text style={styles.lessonArrow}>▶</Text>
                </TouchableOpacity>
              ))}
            </View>
          ))}
        </View>
      </ScrollView>
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
    paddingBottom: 80,
  },
  hero: {
    height: 350,
    backgroundColor: '#1e1e1e',
  },
  heroImage: {
    ...StyleSheet.absoluteFillObject,
    opacity: 0.4,
  },
  heroOverlay: {
    flex: 1,
    justifyContent: 'flex-end',
    paddingHorizontal: 60,
    paddingBottom: 40,
  },
  courseTitle: {
    fontSize: 42,
    fontWeight: '800',
    color: '#FFFFFF',
    marginBottom: 8,
  },
  courseDescription: {
    fontSize: 18,
    color: '#CCCCCC',
    lineHeight: 26,
    marginBottom: 12,
  },
  statsRow: {
    flexDirection: 'row',
    gap: 24,
  },
  stat: {
    color: '#4FC3F7',
    fontSize: 16,
    fontWeight: '600',
  },
  startRow: {
    paddingHorizontal: 60,
    paddingTop: 30,
  },
  startButton: {
    backgroundColor: '#1976D2',
    paddingHorizontal: 40,
    paddingVertical: 18,
    borderRadius: 12,
    alignSelf: 'flex-start',
  },
  startButtonText: {
    color: '#FFFFFF',
    fontSize: 22,
    fontWeight: '700',
  },
  curriculum: {
    paddingHorizontal: 60,
    paddingTop: 40,
  },
  sectionHeader: {
    color: '#FFFFFF',
    fontSize: 28,
    fontWeight: '700',
    marginBottom: 24,
  },
  section: {
    marginBottom: 30,
  },
  sectionTitle: {
    color: '#4FC3F7',
    fontSize: 20,
    fontWeight: '600',
    marginBottom: 12,
  },
  lessonRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1e1e1e',
    padding: 20,
    borderRadius: 10,
    marginBottom: 8,
  },
  lessonNumber: {
    color: '#666',
    fontSize: 18,
    fontWeight: '700',
    width: 40,
  },
  lessonTitle: {
    color: '#FFFFFF',
    fontSize: 18,
    flex: 1,
  },
  quizBadge: {
    backgroundColor: '#e65100',
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 6,
    marginRight: 12,
  },
  quizBadgeText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '700',
  },
  lessonArrow: {
    color: '#666',
    fontSize: 16,
  },
});

export default CourseScreen;

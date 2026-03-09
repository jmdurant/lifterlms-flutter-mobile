import React, {useEffect, useState, useCallback} from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
  TouchableOpacity,
} from 'react-native';
import {useNavigation} from '@react-navigation/native';
import api from '../api/lifterlms';
import {useAuth} from '../context/AuthContext';
import ContentRow from '../components/ContentRow';

const HomeScreen: React.FC = () => {
  const navigation = useNavigation<any>();
  const {user, logout} = useAuth();
  const [courses, setCourses] = useState<any[]>([]);
  const [enrolled, setEnrolled] = useState<any[]>([]);
  const [categories, setCategories] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  const loadData = useCallback(async () => {
    setIsLoading(true);
    try {
      const [coursesRes, categoriesRes] = await Promise.all([
        api.getCourses({per_page: 20}).catch(() => []),
        api.getCategories().catch(() => []),
      ]);

      // Try to get enrolled courses
      let enrolledRes: any[] = [];
      try {
        enrolledRes = await api.getMyEnrollments();
      } catch (_) {}

      setCourses(Array.isArray(coursesRes) ? coursesRes : []);
      setEnrolled(Array.isArray(enrolledRes) ? enrolledRes : []);
      setCategories(Array.isArray(categoriesRes) ? categoriesRes : []);
    } catch (err) {
      console.log('Failed to load home data:', err);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleCoursePress = (courseId: number) => {
    navigation.navigate('Course', {courseId});
  };

  const formatCourses = (list: any[]) =>
    list.map(c => ({
      id: c.id,
      title: c.title?.rendered || c.title || 'Course',
      subtitle: c.lessons_count ? `${c.lessons_count} lessons` : undefined,
      imageUrl: c.featured_media_url || c.image?.src || undefined,
    }));

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#4FC3F7" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Top bar */}
      <View style={styles.topBar}>
        <Text style={styles.appTitle}>LifterLMS</Text>
        <View style={styles.topBarRight}>
          <TouchableOpacity
            style={styles.navButton}
            onPress={() => navigation.navigate('CME')}>
            <Text style={styles.navButtonText}>CME Credits</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.navButton}
            onPress={() => navigation.navigate('Browse')}>
            <Text style={styles.navButtonText}>Browse All</Text>
          </TouchableOpacity>
          <Text style={styles.userName}>
            {user?.user_display_name || 'User'}
          </Text>
          <TouchableOpacity style={styles.logoutButton} onPress={logout}>
            <Text style={styles.logoutText}>Sign Out</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Content rows */}
      <ScrollView
        style={styles.content}
        contentContainerStyle={styles.contentInner}>
        {enrolled.length > 0 && (
          <ContentRow
            title="Continue Learning"
            items={formatCourses(enrolled)}
            onItemPress={handleCoursePress}
          />
        )}

        <ContentRow
          title="All Courses"
          items={formatCourses(courses)}
          onItemPress={handleCoursePress}
        />

        {categories.length > 0 && (
          <View style={styles.categoriesSection}>
            <Text style={styles.sectionTitle}>Categories</Text>
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.categoriesRow}>
              {categories.map((cat: any) => (
                <TouchableOpacity
                  key={cat.id}
                  style={styles.categoryChip}
                  onPress={() =>
                    navigation.navigate('Browse', {categoryId: cat.id})
                  }>
                  <Text style={styles.categoryText}>
                    {cat.name} ({cat.count || 0})
                  </Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
          </View>
        )}
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
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 60,
    paddingTop: 40,
    paddingBottom: 20,
  },
  appTitle: {
    fontSize: 32,
    fontWeight: '800',
    color: '#4FC3F7',
  },
  topBarRight: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 20,
  },
  navButton: {
    backgroundColor: '#1e1e1e',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  navButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  userName: {
    color: '#999',
    fontSize: 16,
  },
  logoutButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  logoutText: {
    color: '#EF5350',
    fontSize: 14,
  },
  content: {
    flex: 1,
  },
  contentInner: {
    paddingTop: 20,
    paddingBottom: 60,
  },
  categoriesSection: {
    paddingHorizontal: 60,
  },
  sectionTitle: {
    color: '#FFFFFF',
    fontSize: 28,
    fontWeight: '700',
    marginBottom: 16,
  },
  categoriesRow: {
    gap: 12,
  },
  categoryChip: {
    backgroundColor: '#1e1e1e',
    paddingHorizontal: 24,
    paddingVertical: 14,
    borderRadius: 10,
    marginRight: 12,
  },
  categoryText: {
    color: '#FFFFFF',
    fontSize: 18,
  },
});

export default HomeScreen;

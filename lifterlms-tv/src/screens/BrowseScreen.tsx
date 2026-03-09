import React, {useEffect, useState, useCallback} from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
  TextInput,
} from 'react-native';
import {useNavigation, useRoute} from '@react-navigation/native';
import api from '../api/lifterlms';
import FocusableCard from '../components/FocusableCard';

const BrowseScreen: React.FC = () => {
  const navigation = useNavigation<any>();
  const route = useRoute<any>();
  const categoryId = route.params?.categoryId;

  const [courses, setCourses] = useState<any[]>([]);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [page, setPage] = useState(1);

  const loadCourses = useCallback(async () => {
    setIsLoading(true);
    try {
      const params: any = {per_page: 30, page};
      if (search) {
        params.search = search;
      }
      if (categoryId) {
        params.categories = categoryId;
      }
      const res = await api.getCourses(params);
      setCourses(Array.isArray(res) ? res : []);
    } catch (err) {
      console.log('Failed to load courses:', err);
    } finally {
      setIsLoading(false);
    }
  }, [search, page, categoryId]);

  useEffect(() => {
    loadCourses();
  }, [loadCourses]);

  const handleSearch = (text: string) => {
    setSearch(text);
    setPage(1);
  };

  const getTitle = (c: any) =>
    typeof c?.title === 'string' ? c.title : c?.title?.rendered || 'Course';

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>
          {categoryId ? 'Category' : 'Browse Courses'}
        </Text>
        <TextInput
          style={styles.searchInput}
          placeholder="Search courses..."
          placeholderTextColor="#888"
          value={search}
          onChangeText={handleSearch}
          returnKeyType="search"
        />
      </View>

      {isLoading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#4FC3F7" />
        </View>
      ) : (
        <ScrollView contentContainerStyle={styles.grid}>
          {courses.map(course => (
            <FocusableCard
              key={course.id}
              title={getTitle(course)}
              subtitle={
                course.lessons_count
                  ? `${course.lessons_count} lessons`
                  : undefined
              }
              imageUrl={course.featured_media_url || course.image?.src}
              onPress={() =>
                navigation.navigate('Course', {courseId: course.id})
              }
              width={280}
              height={180}
            />
          ))}
          {courses.length === 0 && (
            <Text style={styles.empty}>No courses found</Text>
          )}
        </ScrollView>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 60,
    paddingTop: 40,
    paddingBottom: 20,
  },
  title: {
    fontSize: 32,
    fontWeight: '800',
    color: '#FFFFFF',
  },
  searchInput: {
    backgroundColor: '#1e1e1e',
    borderRadius: 10,
    paddingHorizontal: 24,
    paddingVertical: 14,
    fontSize: 18,
    color: '#FFF',
    width: 400,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    paddingHorizontal: 60,
    paddingTop: 20,
    paddingBottom: 60,
    gap: 10,
  },
  empty: {
    color: '#666',
    fontSize: 20,
    marginTop: 40,
  },
});

export default BrowseScreen;

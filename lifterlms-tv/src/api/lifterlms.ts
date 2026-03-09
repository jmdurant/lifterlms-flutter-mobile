import axios, {AxiosInstance} from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';

const STORAGE_KEY_TOKEN = '@llms_token';
const STORAGE_KEY_USER = '@llms_user';

class LifterLMSApi {
  private client: AxiosInstance;
  private token: string | null = null;

  constructor() {
    this.client = axios.create({
      baseURL: '', // Set via configure()
      timeout: 30000,
      headers: {'Content-Type': 'application/json'},
    });
  }

  configure(siteUrl: string, consumerKey: string, consumerSecret: string) {
    const auth = Buffer.from(`${consumerKey}:${consumerSecret}`).toString(
      'base64',
    );
    this.client = axios.create({
      baseURL: `${siteUrl}/wp-json`,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Basic ${auth}`,
      },
    });
  }

  setToken(token: string | null) {
    this.token = token;
  }

  private get headers() {
    const h: Record<string, string> = {};
    if (this.token) {
      h['X-JWT-Token'] = this.token;
    }
    return h;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  async login(username: string, password: string) {
    const res = await this.client.post(
      '/jwt-auth/v1/token',
      {username, password},
      {headers: this.headers},
    );
    if (res.data?.token) {
      this.token = res.data.token;
      await AsyncStorage.setItem(STORAGE_KEY_TOKEN, res.data.token);
      await AsyncStorage.setItem(STORAGE_KEY_USER, JSON.stringify(res.data));
    }
    return res.data;
  }

  async restoreSession() {
    const token = await AsyncStorage.getItem(STORAGE_KEY_TOKEN);
    const user = await AsyncStorage.getItem(STORAGE_KEY_USER);
    if (token) {
      this.token = token;
      return user ? JSON.parse(user) : null;
    }
    return null;
  }

  async logout() {
    this.token = null;
    await AsyncStorage.removeItem(STORAGE_KEY_TOKEN);
    await AsyncStorage.removeItem(STORAGE_KEY_USER);
  }

  // ── Courses ───────────────────────────────────────────────────────────────
  async getCourses(params?: {page?: number; per_page?: number; search?: string}) {
    const res = await this.client.get('/llms/v1/courses', {
      params: {page: 1, per_page: 20, ...params},
      headers: this.headers,
    });
    return res.data;
  }

  async getCourse(courseId: number) {
    const res = await this.client.get(`/llms/v1/courses/${courseId}`, {
      headers: this.headers,
    });
    return res.data;
  }

  // ── Sections & Lessons ────────────────────────────────────────────────────
  async getSections(courseId: number) {
    const res = await this.client.get('/llms/v1/sections', {
      params: {parent_id: courseId, per_page: 50},
      headers: this.headers,
    });
    return res.data;
  }

  async getLessons(sectionId: number) {
    const res = await this.client.get('/llms/v1/lessons', {
      params: {parent_id: sectionId, per_page: 100},
      headers: this.headers,
    });
    return res.data;
  }

  async getLesson(lessonId: number) {
    const res = await this.client.get(`/llms/v1/lessons/${lessonId}`, {
      headers: this.headers,
    });
    return res.data;
  }

  // ── Slides & Scripts ──────────────────────────────────────────────────────
  async getLessonSlides(lessonId: number) {
    const res = await this.client.get(
      `/llms/v1/mobile-app/lesson/${lessonId}/slides`,
      {headers: this.headers},
    );
    return res.data;
  }

  async getLessonScript(lessonId: number) {
    const res = await this.client.get(
      `/llms/v1/mobile-app/lesson/${lessonId}/script`,
      {headers: this.headers},
    );
    return res.data;
  }

  // ── Quizzes ───────────────────────────────────────────────────────────────
  async getQuiz(quizId: number) {
    const res = await this.client.get(`/llms/v1/quizzes/${quizId}`, {
      headers: this.headers,
    });
    return res.data;
  }

  async getQuizQuestions(quizId: number) {
    const res = await this.client.get(
      `/llms/v1/quizzes/${quizId}/questions`,
      {params: {per_page: 50}, headers: this.headers},
    );
    return res.data;
  }

  // ── Enrollments & Progress ────────────────────────────────────────────────
  async getMyEnrollments() {
    const res = await this.client.get('/llms/v1/my-courses', {
      headers: this.headers,
    });
    return res.data;
  }

  async completeLesson(lessonId: number) {
    const res = await this.client.post(
      `/llms/v1/lessons/${lessonId}/complete`,
      {},
      {headers: this.headers},
    );
    return res.data;
  }

  // ── CME ───────────────────────────────────────────────────────────────────
  async getCmeCredits() {
    const res = await this.client.get('/llms/v1/cme/credits', {
      headers: this.headers,
    });
    return res.data;
  }

  async getCmeSummary() {
    const res = await this.client.get('/llms/v1/cme/summary', {
      headers: this.headers,
    });
    return res.data;
  }

  // ── App Config ────────────────────────────────────────────────────────────
  async getAppConfig() {
    const res = await this.client.get('/llms/v1/mobile-app/config');
    return res.data;
  }

  // ── Media ─────────────────────────────────────────────────────────────────
  async getMedia(mediaId: number) {
    const res = await this.client.get(`/wp/v2/media/${mediaId}`, {
      headers: this.headers,
    });
    return res.data;
  }

  // ── Categories ────────────────────────────────────────────────────────────
  async getCategories() {
    const res = await this.client.get('/wp/v2/course_cat', {
      params: {per_page: 50},
      headers: this.headers,
    });
    return res.data;
  }
}

export const api = new LifterLMSApi();
export default api;

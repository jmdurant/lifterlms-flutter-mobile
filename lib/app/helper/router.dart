import 'package:flutter_app/app/backend/binding/course_detail_binding.dart';
import 'package:flutter_app/app/backend/binding/courses_binding.dart';
import 'package:flutter_app/app/backend/binding/finish_learning_binding.dart';
import 'package:flutter_app/app/backend/binding/home_binding.dart';
import 'package:flutter_app/app/backend/binding/learning_binding.dart';
import 'package:flutter_app/app/backend/binding/login_binding.dart';
import 'package:flutter_app/app/backend/binding/my_courses_binding.dart';
import 'package:flutter_app/app/backend/binding/notification_binding.dart';
import 'package:flutter_app/app/backend/binding/register_binding.dart';
import 'package:flutter_app/app/backend/binding/review_binding.dart';
import 'package:flutter_app/app/backend/binding/search_course_binding.dart';
import 'package:flutter_app/app/backend/binding/splash_binding.dart';
import 'package:flutter_app/app/backend/binding/tabs_binding.dart';
import 'package:flutter_app/app/backend/binding/wishlist_binding.dart';
import 'package:flutter_app/app/view/course_detail.dart';
import 'package:flutter_app/app/view/courses.dart';
import 'package:flutter_app/app/view/finish_learning.dart';
import 'package:flutter_app/app/view/forgot_password.dart';
import 'package:flutter_app/app/view/home.dart';
import 'package:flutter_app/app/view/instructor_detail.dart';
import 'package:flutter_app/app/view/learning.dart';
import 'package:flutter_app/app/view/login.dart';
import 'package:flutter_app/app/view/my_courses.dart';
import 'package:flutter_app/app/view/my_profile.dart';
import 'package:flutter_app/app/view/notification.dart';
import 'package:flutter_app/app/view/payment.dart';
import 'package:flutter_app/app/view/register.dart';
import 'package:flutter_app/app/view/review.dart';
import 'package:flutter_app/app/view/search-course.dart';
import 'package:flutter_app/app/view/splash.dart';
import 'package:flutter_app/app/view/tabs.dart';
import 'package:flutter_app/app/view/wishlist.dart';
import 'package:flutter_app/app/view/components/profile/profile-screen.dart';
// import 'package:flutter_app/app/view/splash.dart';
// import 'package:flutter_app/app/view/welcome.dart';
import 'package:get/get.dart';

import '../backend/binding/forgot_password_binding.dart';
import '../backend/binding/intructor_detail_binding.dart';
import '../backend/binding/language_binding.dart';
import '../backend/binding/profile_binding.dart';
import '../backend/binding/my_profile_binding.dart';
import '../backend/binding/payment_binding.dart';
import '../backend/binding/wishlist_binding.dart';
import '../backend/binding/my_courses_binding.dart';
import '../backend/binding/courses_binding.dart';
import '../view/components/profile/settings/delete-account.dart';
import '../view/components/profile/settings/general.dart';
import '../view/components/profile/settings/language.dart';
import '../view/components/profile/settings/password.dart';

class AppRouter {
  static const String initial = '/';
  static const String splash = '/splash';
  static const String tabsBarRoutes = '/tabs';
  static const String tabs = '/tabs'; // Add alias for backward compatibility
  static const String home = '/home';
  static const String login = '/login';
  static const String forgotPassword = '/forgotPassword';
  static const String register = '/register';
  static const String coursesByCategory = '/coursesByCategory';
  
  static String getCoursesByCategory() => coursesByCategory;
  static const String courseDetail = '/course_detail';
  static const String courseDetail1 = '/course_detail1';
  static const String learning = '/learning';
  static const String finishLearning = '/finishLearning';
  static const String searchCourse = '/searchCourse';
  static const String intructorDetail = '/intructorDetail';
  static const String notification = '/notification';
  static const String review = '/review';
  static const String language = '/language';
  static const String general = '/general';
  static const String password = '/password';
  static const String delete = '/delete';
  static const String profile = '/profile';
  static const String myProfile = '/myProfile';
  static const String payment = '/payment';
  static const String wishlist = '/wishlist';
  static const String myCourses = '/myCourses';
  static const String courses = '/courses';
  static const String writeReview = '/writeReview';
  static const String terms = '/terms';
  static const String privacy = '/privacy';
  static const String myCertificates = '/myCertificates';
  static const String certificateDetail = '/certificateDetail';

  static String getInitialRoute() => initial;
  static String getSplashRoute() => splash;
  static String getTabsBarRoute() => tabsBarRoutes;
  static String getHomeRoute() => home;
  // static String getWelcomeRoute() => welcome;
  static String getLoginRoute() => login;
  static String getRegisterRoute() => register;
  static String getCourseDetailRoute() => courseDetail;
  static String getCourseDetailRoute1() => courseDetail1;
  static String getLearningRoute() => learning;
  static String getFinishLearningRoute() => finishLearning;
  static String getSearchCourseRoute() => searchCourse;
  static String getIntructorDetailRoute() => intructorDetail;
  static String getNotificationRoute() => notification;
  static String getReview() => review;
  static String getForgotPassword() => forgotPassword;
  static String getLanguage() => language;
  static String getGeneral() => general;
  static String getPassword() => password;
  static String getDelete() => delete;
  static String getProfile() => profile;
  static String getMyProfile() => myProfile;
  static String getPayment() => payment;
  static String getWishlist() => wishlist;
  static String getMyCourses() => myCourses;
  static String getCourses() => courses;
  static String getWriteReview() => writeReview;
  static String getTerms() => terms;
  static String getPrivacy() => privacy;
  static String getCourseDetail() => courseDetail;
  static String getLearning() => learning;
  static String getInstructorDetail() => intructorDetail;
  static String getMyCertificates() => myCertificates;
  static String getCertificateDetail() => certificateDetail;

  static List<GetPage> routes = [
    // GetPage(
    //     name: initial,
    //     page: () => const IntroScreen(),
    //     binding: IntroBinding()),
    GetPage(name: splash, page: () => SplashScreen(), binding: SplashBinding()),
    GetPage(name: tabsBarRoutes, page: () => TabScreen(), binding: TabsBinding()),
    GetPage(name: home, page: () => HomeScreen(), binding: HomeBinding()),
    GetPage(name: login, page: () => LoginScreen(), binding: LoginBinding()),
    GetPage(name: forgotPassword, page: () => ForgotPasswordScreen(), binding: ForgotPasswordBinding()),
    GetPage(
        name: courseDetail,
        page: () => CourseDetailScreen(),
        binding: CourseDetailBinding(),
        preventDuplicates: false
    ),
    GetPage(
        name: language,
        page: () => MultiLanguage(),
        binding: LanguageBinding(),
        preventDuplicates: false
    ),
    GetPage(
        name: general,
        page: () => GeneralAccount(),
        preventDuplicates: false
    ),
    GetPage(
        name: password,
        page: () => Password(),
        preventDuplicates: false
    ),
    GetPage(
        name: delete,
        page: () => DeleteAccount(),
        preventDuplicates: false
    ),
    GetPage(
        name: register,
        page: () => const RegisterScreen(),
        binding: RegisterBinding()),
    GetPage(
        name: learning,
        page: () => LearningScreen(),
        binding: LearningBinding()),
    GetPage(
        name: searchCourse,
        page: () => SearchCourseScreen(),
        binding: SearchCourseBinding()),
    GetPage(
        name: finishLearning,
        page: () => FinishLearningScreen(),
        binding: FinishLearningBinding()),
    GetPage(
        name: intructorDetail,
        page: () => InstructorDetailScreen(),
        binding: InstructorDetailBinding(),
        preventDuplicates: false
    ),
    GetPage(
        name: notification,
        page: () => NotificationScreen(),
        binding: NotificationBinding()),
    GetPage(name: review, page: () => ReviewScreen(), binding: ReviewBinding()),
    GetPage(name: profile, page: () => MyProfileScreen(), binding: ProfileBinding()),
    GetPage(name: myProfile, page: () => MyProfileScreen(), binding: MyProfileBinding()),
    GetPage(name: payment, page: () => PaymentScreen(), binding: PaymentBinding()),
    GetPage(name: wishlist, page: () => WishlistScreen(), binding: WishlistBinding()),
    GetPage(name: myCourses, page: () => MyCoursesScreen(), binding: MyCoursesBinding()),
    GetPage(name: courses, page: () => CoursesScreen(), binding: CoursesBinding()),
  ];
}

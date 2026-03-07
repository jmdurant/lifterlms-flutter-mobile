import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/app/controller/session_controller.dart';
import 'package:flutter_app/app/controller/course_store_controller.dart';
import 'package:flutter_app/app/controller/quiz_state_controller.dart';
import 'package:flutter_app/app/controller/language_controller.dart';
import 'package:flutter_app/app/controller/theme_controller.dart';
import 'package:flutter_app/app/util/theme.dart';
// LifterLMS Controllers
import 'package:flutter_app/app/controller/lifterlms/home_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/login_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/courses_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/course_detail_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/learning_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/wishlist_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/my_courses_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/profile_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/my_profile_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/payment_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/register_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/search_course_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/instructor_detail_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/notification_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/review_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/finish_learning_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/forgot_password_controller.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/backend/services/media_cache_service.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/controller/firebase_api_controller.dart';
import 'package:flutter_app/app/util/constant.dart';
import 'package:flutter_app/app/util/init.dart';
import 'package:get/get.dart';
import 'package:loader_overlay/loader_overlay.dart';


void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await MainBinding().dependencies();
  Get.put(SessionController(), permanent: true);
  Get.put(CourseStoreController(), permanent: true);
  Get.put(QuizStateController(), permanent: true);
  
  // Initialize Theme Controller
  Get.put(ThemeController());
  
  // Initialize LMS Service
  await Get.putAsync(() => LMSService().init());
  
  // Initialize Media Cache Service
  await Get.putAsync(() => MediaCacheService().init());
  
  // Initialize LifterLMS Controllers
  Get.lazyPut(() => HomeController());
  Get.lazyPut(() => LoginController());
  Get.lazyPut(() => CoursesController());
  Get.lazyPut(() => CourseDetailController());
  Get.lazyPut(() => LearningController());
  Get.lazyPut(() => WishlistController());
  Get.put(MyCoursesController(), permanent: true);
  Get.lazyPut(() => ProfileController());
  Get.lazyPut(() => MyProfileController());
  Get.lazyPut(() => PaymentController());
  Get.lazyPut(() => RegisterController());
  Get.lazyPut(() => SearchCourseController());
  Get.lazyPut(() => InstructorDetailController());
  Get.lazyPut(() => NotificationController());
  Get.lazyPut(() => ReviewController());
  Get.lazyPut(() => FinishLearningController());
  Get.lazyPut(() => ForgotPasswordController());
  //firebase - skip on Linux and macOS desktop
  if (!Platform.isLinux && !Platform.isMacOS) {
    await Firebase.initializeApp();
    await FirebaseApiController().initNotifications();
  }
  runApp(EasyLocalization(
    child: MyApp(),
    supportedLocales: [
      Locale('en', 'US'),
      Locale('es', 'ES'),
      Locale('ko', 'KR'),
      Locale('pt', 'PT'),
      Locale('fa', 'IR'),
      Locale('bn', 'BN'),
    ],
    fallbackLocale: Locale('en', 'US'),
    path: 'assets/translations',
  ));
}

class MyApp extends StatelessWidget {

  MyApp({super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    LanguageController languageController = Get.find();
    ThemeController themeController = Get.find();
    String key = languageController.sharedPreferencesManager.getString("language")??'en';
    var currentLanguage = languageController.handleChoiceLanguage(key);
    var currentLocale = Locale(currentLanguage['key'], currentLanguage['countryCode']);
    context.setLocale(currentLocale);
    return
      GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
          },
          child: GlobalLoaderOverlay(
            child: GetMaterialApp(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              navigatorKey: Get.key,
              initialRoute: AppRouter.splash,
              getPages: AppRouter.routes,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeController.themeMode,
            ),
          ));

  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/mobx-store/session_store.dart';
import 'package:flutter_app/app/controller/lifterlms/login_controller.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/config/branding_config.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:get/get.dart';
import 'dart:ui';

import 'package:watch_it/watch_it.dart';
import 'package:provider/provider.dart';
import 'package:auth_buttons/auth_buttons.dart';

import '../controller/social_login_controller.dart';

class LoginScreen extends WatchingStatefulWidget {
  LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginScreen> {
  bool _isVisible = false;
  //feature login social
  // Controllers are now in the LoginController
  //SocialLoginController socialLoginController = Get.find();

  void onRegister() {
    Future.delayed(Duration.zero, () {
      Get.toNamed(AppRouter.getRegisterRoute());
    });
  }

  void onForgotPassword() {
    Future.delayed(Duration.zero, () {
      Get.toNamed(AppRouter.forgotPassword);
    });
  }

  @override
  Size size = WidgetsBinding.instance.window.physicalSize;
  var screenWidth =
      (window.physicalSize.shortestSide / window.devicePixelRatio);
  var screenHeight =
      (window.physicalSize.longestSide / window.devicePixelRatio);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final sessionStore = Provider.of<SessionStore>(context);

    // Get the LifterLMS LoginController
    final LoginController loginController = Get.find<LoginController>();


    return GetBuilder<SocialLoginController>(builder: (socialLoginController) {
      return  Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Stack(children: <Widget>[
            Positioned(
              left: 16,
              top: 60,
              child: IconButton(
                onPressed: () {
                  // Try to go back first, if that fails go to tabs
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Get.offAllNamed(AppRouter.getTabsBarRoute());
                  }
                },
                icon: const Icon(Icons.arrow_back),
                color: Colors.grey[500],
                iconSize: 24,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: (1120 / 1500) * screenWidth,
                height: (1272 / 1500) * screenWidth,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                      image: AssetImage(
                        'assets/images/banner-login2.png',
                      ),
                      fit: BoxFit.contain),
                ),
              ),
            ),
            // padding: const EdgeInsets.all(16.0),
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 120, 40, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BrandingConfig.getAuthLogo(screenWidth: screenWidth),
                  Center(
                    child: Text(
                      tr(LocaleKeys.loginScreen_title),
                      style: TextStyle(fontFamily: "Sniglet", fontSize: 28),
                    ),
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: loginController.usernameController,
                    // obscureText: true,
                    decoration: InputDecoration(
                      hintText: tr(LocaleKeys.loginScreen_usernamePlaceholder),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Password text field
                  TextField(
                    obscureText: !_isVisible,
                    controller: loginController.passwordController,
                    decoration: InputDecoration(
                      labelText: tr(LocaleKeys.loginScreen_passwordPlaceholder),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _isVisible ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() {
                          _isVisible = !_isVisible;
                        }),
                      ),
                    ),
                  ),
                  if (socialLoginController.isEnableSocialLogin)
                    Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: FacebookAuthButton(
                          onPressed: () {
                            socialLoginController.signInFacebook();
                          },
                          style: AuthButtonStyle(
                            buttonType: AuthButtonType.secondary,
                          ),
                        )),
                  if (socialLoginController.isEnableSocialLogin)
                    Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: GoogleAuthButton(
                          onPressed: () {
                            socialLoginController.signInGoogle();
                          },
                          style: AuthButtonStyle(
                            buttonType: AuthButtonType.secondary,
                          ),
                        )),
                  if (socialLoginController.isEnableSocialLogin)
                    Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: AppleAuthButton(
                          onPressed: () {
                            // Apple sign-in logic here
                          },
                          style: AuthButtonStyle(
                            buttonType: AuthButtonType.secondary,
                          ),
                        )),
                  const SizedBox(height: 16),
                  // Login button
                  ElevatedButton(
                    onPressed: () => {
                      loginController.login(),
                      sessionStore.getUser()
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 12)),
                    child: Text(
                      tr(LocaleKeys.loginScreen_btnLogin),
                      style: TextStyle(
                          color: Colors.black,
                          fontFamily: "Sniglet",
                          fontSize: 16),
                    ),
                  ),
                  TextButton(
                      onPressed: onForgotPassword,
                      child: Text(tr(LocaleKeys.loginScreen_forgotPassword))),
                  const SizedBox(height: 32),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(LocaleKeys.loginScreen_registerText),
                          style: TextStyle(
                              color: Colors.black,
                              fontFamily: "Sniglet",
                              fontSize: 14),
                        ),
                        Container(
                            padding: const EdgeInsets.fromLTRB(2, 0, 0, 4),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  width: 1.0,
                                ),
                              ),
                            ),
                            child: GestureDetector(
                                onTap: onRegister,
                                child: Text(
                                  tr(LocaleKeys.loginScreen_register),
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontFamily: "Sniglet",
                                      fontSize: 14),
                                ))),
                      ],
                    ),
                  ),
                ],
              ),
            )
          ]),
        ),
      );
    });
  }

  @override
  void dispose() {
    // Controllers are disposed in LoginController
    super.dispose();
  }
}

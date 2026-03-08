import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/helper/shared_pref.dart';
import 'package:flutter_app/app/view/components/login_required_widget.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../../../controller/lifterlms/profile_controller.dart';
import '../../../env.dart';

typedef OnNavigateCallback = void Function(int page);

class Profile extends StatefulWidget {
  final SharedPreferencesManager sharedPreferencesManager;
  final ProfileController profileController;
  final OnNavigateCallback goToPage;
  final OnNavigateCallback goBack;

  @override
  State<Profile> createState() => _Profile();

  Profile(
      {required this.sharedPreferencesManager,
      super.key,
      required this.goToPage,
      required this.goBack,
      required this.profileController});
}

class _Profile extends State<Profile> {
  @override
  void initState() {
    super.initState();
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;
    var screenHeight = MediaQuery.of(context).size.height;
    final value = widget.profileController;
    return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawerEnableOpenDragGesture: false,
        body: Column(
            children: [
              Container(
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).viewPadding.top),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    tr(LocaleKeys.profile_title),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              (widget.sharedPreferencesManager.getString('token') ?? "") == ''
                  ? Container(
                      width: screenWidth,
                      height: screenHeight * 0.7,
                      child: const LoginRequiredWidget(
                        message: 'Sign in to view your profile',
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Stack(children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Row(
                                  children: [
                                    value.avatarUrl.value.isNotEmpty
                                        ? Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(23),
                                                image: DecorationImage(
                                                  fit: BoxFit.cover,
                                                  image: NetworkImage(
                                                      value.avatarUrl.value),
                                                )))
                                        : CircleAvatar(
                                            radius: 23,
                                            backgroundImage: Image.asset(
                                              'assets/images/default-user-avatar.jpg',
                                            ).image,
                                          ),
                                    SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            value.displayName.value,
                                            style: TextStyle(
                                                fontFamily: "Poppins-Medium",
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500),
                                          ),
                                          SizedBox(
                                            height: 4,
                                          ),
                                          if (value.bio.value.isNotEmpty)
                                            Text(
                                                value.bio.value,
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    color:
                                                        Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey)),
                                          SizedBox(
                                            height: 4,
                                          ),
                                          if (value.email.value.isNotEmpty)
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.email_outlined,
                                                  color: Colors.amber,
                                                  size: 18,
                                                ),
                                                SizedBox(
                                                  width: 8,
                                                ),
                                                Text(value.email.value,
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey)),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                height: 20,
                                thickness: 0.7,
                                indent: 35,
                                endIndent: 35,
                                color: Theme.of(context).dividerColor,
                              ),
                              Align(
                                alignment: Alignment.center,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 50),
                                  child: Column(
                                    children: [
                                      SizedBox(height: 30),
                                      GestureDetector(
                                        onTap: () => {widget.goToPage(1)},
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                color: Color(0xFF36CE61),
                                              ),
                                              child: Icon(Feather.settings,
                                                  size: 20,
                                                  color: Theme.of(context).colorScheme.onPrimary),
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              tr(
                                                LocaleKeys.settings_title,
                                              ),
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w500),
                                            )
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 15),
                                      GestureDetector(
                                        onTap: () => {widget.goToPage(2)},
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                color: Colors.amber,
                                              ),
                                              child: Icon(Icons.card_membership,
                                                  size: 20,
                                                  color: Theme.of(context).colorScheme.onPrimary),
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'My Certificates',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w500),
                                            )
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 15),
                                      GestureDetector(
                                        onTap: () => {widget.goToPage(3)},
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                color: Color(0xFFF8C719),
                                              ),
                                              child: Icon(Feather.shopping_bag,
                                                  size: 20,
                                                  color: Theme.of(context).colorScheme.onPrimary),
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              tr(LocaleKeys.myOrders_title),
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w500),
                                            )
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 15),
                                      SizedBox(height: 40),
                                      Divider(
                                        height: 20,
                                        thickness: 0.7,
                                        indent: 0,
                                        endIndent: 0,
                                        color: Theme.of(context).dividerColor,
                                      ),
                                      SizedBox(height: 50),
                                      GestureDetector(
                                        onTap: value.logout,
                                        child: Row(
                                          children: [
                                            Icon(Icons.logout_outlined,
                                                size: 20,
                                                color: Color(0xFFFF3535)),
                                            SizedBox(width: 14),
                                            Text(
                                              tr(LocaleKeys.logout),
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w500),
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      ]),
                    ),
              SizedBox(
                height: (widget.sharedPreferencesManager.getString('token') ?? "") != '' ? 200 : 50,
              ),
              Text(
                LocaleKeys.profile_version,
                style: TextStyle(fontFamily: 'poppins', fontSize: 12),
              ).tr(args: [Environments.appVersion, Environments.appBuild])
            ],
          ));
  }
}

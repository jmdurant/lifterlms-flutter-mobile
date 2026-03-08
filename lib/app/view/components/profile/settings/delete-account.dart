import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/controller/settings_controller.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:get/get.dart';

class DeleteAccount extends StatefulWidget {
  @override
  State<DeleteAccount> createState() => _DeleteAccountState();
  DeleteAccount({super.key});
}

class _DeleteAccountState extends State<DeleteAccount> {
  bool _isVisible = false;
  final SettingsController settingController = Get.find<SettingsController>();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        drawerEnableOpenDragGesture: false,
        body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: screenWidth,
                  // color: Colors.blue,
                  padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top + 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.arrow_back),
                          color: Colors.grey[900],
                          iconSize: 26,
                        ),
                     Expanded(child:  Text(
                       tr( LocaleKeys.settings_deleteAccount),
                       style: const TextStyle(
                         fontFamily: 'medium',
                         fontWeight: FontWeight.w500,
                         fontSize: 24,
                       ),
                       textAlign: TextAlign.center,
                     )),
                     SizedBox(width: 20,)
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(LocaleKeys.settings_deleteAccountTitle),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(
                        height: 12,
                      ),
                      Text(
                        tr(LocaleKeys.settings_deleteAccountTitle2),
                        style: TextStyle(
                            fontFamily: 'medium',
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.w600),
                      ),
                      SizedBox(
                        height: 12,
                      ),
                      Text(
                        tr(LocaleKeys.settings_deleteAccountContent),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(
                        height: 12,
                      ),
                      Text(
                        tr(LocaleKeys.settings_deleteAccountContent2),
                        style: TextStyle(
                            fontFamily: 'medium',
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.w600),
                      ),
                      SizedBox(
                        height: 12,
                      ),
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        margin: EdgeInsets.only(bottom: 24),
                        child: TextField(
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          obscureText: !_isVisible,
                          controller: settingController.deletePasswordController,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.only(left: 20, right: 20, top: 5, bottom: 0),
                            border: InputBorder.none,
                            suffixIcon: IconButton(
                              icon: Icon(_isVisible ? Icons.visibility_off : Icons.visibility),
                              onPressed: () =>setState(() {
                                _isVisible = !_isVisible;
                              }),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: screenWidth - 32, // Set the width you want
                        child: ElevatedButton(
                          onPressed: () => {settingController.deleteAccount()},
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Color(0xffdc2626),
                            backgroundColor: Colors.grey[200],
                            minimumSize: Size(double.infinity, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey),
                            ),
                          ),
                          child: Text(
                            tr(LocaleKeys.settings_deleteAccountBtn),
                            style: TextStyle(
                              fontFamily: 'medium',
                              fontSize: 14,
                              color: Color(0xffdc2626),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ]));
  }
}

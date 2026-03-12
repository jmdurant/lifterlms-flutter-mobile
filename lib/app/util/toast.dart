import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

void _showSnackBar(String message, Color backgroundColor) {
  final context = Get.context;
  if (context != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.tr, style: const TextStyle(color: Colors.white)),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

void showToast(String message, {bool isError = true}) {
  if (!kIsWeb) HapticFeedback.lightImpact();
  _showSnackBar(message, isError ? Colors.red : Colors.black);
}

void successToast(String message) {
  if (!kIsWeb) HapticFeedback.lightImpact();
  _showSnackBar(message, Colors.green);
}

Future<bool> clearCartAlert() async {
  HapticFeedback.lightImpact();
  bool clean = false;
  await Get.generalDialog(
      pageBuilder: (context, __, ___) => AlertDialog(
            title: const Text('Warning'),
            content: const Text(
                "You already have item's in cart with different grocery store"),
            actions: [
              TextButton(
                onPressed: () {
                  // Navigator.pop(context);
                  clean = false;
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                      color: Colors.black, fontFamily: 'medium'),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigator.pop(context);
                  clean = true;
                },
                child: const Text(
                  'Clear Cart',
                  style: TextStyle(
                      color: Colors.blue, fontFamily: 'bold'),
                ),
              )
            ],
          ));
  return clean;
}

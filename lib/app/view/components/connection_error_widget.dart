import 'package:flutter/material.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:get/get.dart';

class ConnectionErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ConnectionErrorWidget({
    Key? key,
    this.message,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to connect to server',
              style: TextStyle(
                fontFamily: 'medium',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Please check your site connection settings and try again.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Get.toNamed(AppRouter.siteConnection);
              },
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Site Connection Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFBC815),
                foregroundColor: Colors.black,
                minimumSize: const Size(200, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(200, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

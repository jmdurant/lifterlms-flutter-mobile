import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_app/app/util/toast.dart';

class CertificateViewerScreen extends StatefulWidget {
  const CertificateViewerScreen({Key? key}) : super(key: key);
  
  @override
  State<CertificateViewerScreen> createState() => _CertificateViewerScreenState();
}

class _CertificateViewerScreenState extends State<CertificateViewerScreen> {
  late final WebViewController controller;
  bool isLoading = true;
  String? htmlContent;
  String? certificateTitle;
  
  @override
  void initState() {
    super.initState();
    
    // Get the HTML content passed as argument
    final args = Get.arguments;
    htmlContent = args['html'] ?? '';
    certificateTitle = args['title'] ?? 'Certificate';
    
    // Initialize WebView controller
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
        ),
      )
      ..loadHtmlString(htmlContent!);
  }
  
  Future<void> _printCertificate() async {
    // Add JavaScript to trigger print dialog
    await controller.runJavaScript('window.print();');
    showToast('Opening print dialog...');
  }
  
  Future<void> _shareCertificate() async {
    // Share the certificate title and a message
    await Share.share(
      'I earned a certificate: $certificateTitle',
      subject: 'Certificate Earned',
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(certificateTitle ?? 'Certificate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareCertificate,
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printCertificate,
            tooltip: 'Print',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _printCertificate,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Save as PDF'),
        tooltip: 'Print or save as PDF',
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_app/app/controller/lifterlms/certificates_controller.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

class CertificateDetailScreen extends StatefulWidget {
  const CertificateDetailScreen({Key? key}) : super(key: key);

  @override
  State<CertificateDetailScreen> createState() => _CertificateDetailScreenState();
}

class _CertificateDetailScreenState extends State<CertificateDetailScreen> {
  final CertificatesController controller = Get.find<CertificatesController>();
  late WebViewController _webViewController;
  bool isLoading = true;
  CertificateModel? certificate;

  @override
  void initState() {
    super.initState();
    
    // Get certificate from arguments
    final args = Get.arguments;
    if (args != null && args['certificate'] != null) {
      certificate = args['certificate'] as CertificateModel;
      _loadCertificate();
    }
  }

  void _loadCertificate() {
    if (certificate == null) return;
    
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
        ),
      );
    
    // Load certificate HTML or preview URL
    if (certificate!.previewUrl != null) {
      _webViewController.loadRequest(Uri.parse(certificate!.previewUrl!));
    } else {
      _loadCertificateHTML();
    }
  }

  void _loadCertificateHTML() async {
    // Load certificate HTML content
    final html = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body {
          margin: 0;
          padding: 20px;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
        }
        .certificate {
          background: white;
          border-radius: 20px;
          padding: 40px;
          box-shadow: 0 20px 40px rgba(0,0,0,0.1);
          max-width: 600px;
          width: 100%;
          text-align: center;
        }
        .certificate-header {
          border-bottom: 3px solid #fbbf24;
          padding-bottom: 20px;
          margin-bottom: 30px;
        }
        .certificate-title {
          font-size: 36px;
          font-weight: bold;
          color: #1f2937;
          margin: 0;
          letter-spacing: 2px;
        }
        .certificate-subtitle {
          font-size: 18px;
          color: #6b7280;
          margin-top: 10px;
        }
        .certificate-body {
          margin: 30px 0;
        }
        .recipient-name {
          font-size: 32px;
          font-weight: bold;
          color: #1f2937;
          margin: 20px 0;
        }
        .course-name {
          font-size: 24px;
          color: #4b5563;
          margin: 20px 0;
        }
        .earned-date {
          font-size: 16px;
          color: #9ca3af;
          margin-top: 30px;
        }
        .certificate-seal {
          width: 100px;
          height: 100px;
          background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%);
          border-radius: 50%;
          margin: 30px auto;
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .seal-icon {
          font-size: 48px;
          color: white;
        }
        .verification {
          margin-top: 30px;
          padding-top: 20px;
          border-top: 1px solid #e5e7eb;
          font-size: 12px;
          color: #9ca3af;
        }
      </style>
    </head>
    <body>
      <div class="certificate">
        <div class="certificate-header">
          <h1 class="certificate-title">CERTIFICATE</h1>
          <p class="certificate-subtitle">OF ACHIEVEMENT</p>
        </div>
        <div class="certificate-body">
          <p style="font-size: 18px; color: #6b7280;">This is to certify that</p>
          <h2 class="recipient-name">Student Name</h2>
          <p style="font-size: 18px; color: #6b7280;">has successfully completed</p>
          <h3 class="course-name">${certificate!.courseTitle}</h3>
        </div>
        <div class="certificate-seal">
          <span class="seal-icon">★</span>
        </div>
        <p class="earned-date">Earned on ${certificate!.earnedDate}</p>
        <div class="verification">
          <p>Certificate ID: ${certificate!.id}</p>
          ${certificate!.verificationCode != null ? '<p>Verification Code: ${certificate!.verificationCode}</p>' : ''}
        </div>
      </div>
    </body>
    </html>
    ''';
    
    _webViewController.loadHtmlString(html);
  }

  @override
  Widget build(BuildContext context) {
    if (certificate == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Certificate'),
        ),
        body: Center(
          child: Text('Certificate not found'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Certificate',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) {
              switch (value) {
                case 'share':
                  controller.shareCertificate(certificate!);
                  break;
                case 'download':
                  controller.downloadCertificate(certificate!);
                  break;
                case 'verify':
                  controller.verifyCertificate(certificate!);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20, color: Colors.black87),
                    SizedBox(width: 12),
                    Text('Share'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20, color: Colors.black87),
                    SizedBox(width: 12),
                    Text('Download PDF'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'verify',
                child: Row(
                  children: [
                    Icon(Icons.verified_user, size: 20, color: Colors.black87),
                    SizedBox(width: 12),
                    Text('Verify'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Certificate info header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.amber.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        certificate!.courseTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Earned on ${certificate!.earnedDate}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // WebView for certificate
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _webViewController),
                if (isLoading)
                  Center(
                    child: CircularProgressIndicator(
                      color: Colors.amber,
                    ),
                  ),
              ],
            ),
          ),
          
          // Action buttons
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.shareCertificate(certificate!),
                    icon: Icon(Icons.share),
                    label: Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => controller.downloadCertificate(certificate!),
                    icon: Icon(Icons.download),
                    label: Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
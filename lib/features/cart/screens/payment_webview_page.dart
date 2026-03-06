import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:techsc/core/theme/app_colors.dart';

/// Pantalla que contiene el WebView para procesar el pago seguro con Payphone.
class PaymentWebViewPage extends StatefulWidget {
  final String url;
  final String successUrl;
  final String cancelUrl;

  const PaymentWebViewPage({
    super.key,
    required this.url,
    required this.successUrl,
    required this.cancelUrl,
  });

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
            final lowerUrl = url.toLowerCase();
            debugPrint('Navigating to: $url');

            // Detección agresiva de éxito o cancelación
            final bool isSuccess =
                lowerUrl.contains(widget.successUrl.toLowerCase()) ||
                lowerUrl.contains('/result') ||
                lowerUrl.contains('/confirm');

            final bool isCancelled =
                lowerUrl.contains(widget.cancelUrl.toLowerCase()) ||
                lowerUrl.contains('/cancel');

            if (isSuccess) {
              debugPrint('Success pattern detected in URL: $url');
              Navigator.pop(context, 'success');
            } else if (isCancelled) {
              debugPrint('Cancel pattern detected in URL: $url');
              Navigator.pop(context, 'cancelled');
            }
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            final lowerUrl = url.toLowerCase();

            final bool isSuccess =
                lowerUrl.contains(widget.successUrl.toLowerCase()) ||
                lowerUrl.contains('/result') ||
                lowerUrl.contains('/confirm');

            final bool isCancelled =
                lowerUrl.contains(widget.cancelUrl.toLowerCase()) ||
                lowerUrl.contains('/cancel');

            if (isSuccess) {
              debugPrint('Success pattern detected in navigation: $url');
              Navigator.pop(context, 'success');
              return NavigationDecision.prevent;
            } else if (isCancelled) {
              debugPrint('Cancel pattern detected in navigation: $url');
              Navigator.pop(context, 'cancelled');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Pago Seguro Payphone',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context, 'cancelled'),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            ),
        ],
      ),
    );
  }
}

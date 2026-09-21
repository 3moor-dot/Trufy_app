import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

const String kAppUrl = 'https://turfy-play.vercel.app/';
const String kAppHost = 'turfy-play.vercel.app';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const TurfyPlayApp());
}

class TurfyPlayApp extends StatelessWidget {
  const TurfyPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turfy Play',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const WebShell(),
    );
  }
}

class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    // iOS-specific: allow inline video/audio and autoplay without a tap.
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _loading = true;
            _hasError = false;
          }),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              setState(() {
                _loading = false;
                _hasError = true;
              });
            }
          },
          onNavigationRequest: (request) {
            // Only intercept top-level navigations; let iframes/embeds load.
            if (!request.isMainFrame) return NavigationDecision.navigate;

            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;

            final isInternal =
                uri.host == kAppHost || uri.scheme == 'about' || uri.scheme == 'blob';
            if (isInternal) return NavigationDecision.navigate;

            // External links open in Safari.
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(kAppUrl));

    // Swipe-back / swipe-forward gestures like Safari.
    final platform = controller.platform;
    if (platform is WebKitWebViewController) {
      platform.setAllowsBackForwardNavigationGestures(true);
    }

    _controller = controller;
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _loading = true;
    });
    _controller.loadRequest(Uri.parse(kAppUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading && !_hasError)
              const Center(child: CircularProgressIndicator()),
            if (_hasError)
              Container(
                color: Colors.black,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      "Can't reach Turfy Play.\nCheck your connection and try again.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _retry, child: const Text('Retry')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

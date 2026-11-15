import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/panoptes_theme.dart';

class WebViewReconSheet extends StatefulWidget {
  final String initialUrl;
  final String title;
  final void Function(String imageUrl)? onVerifyCandidateImage;

  const WebViewReconSheet({
    super.key,
    required this.initialUrl,
    required this.title,
    this.onVerifyCandidateImage,
  });

  static Future<void> open(
    BuildContext context, {
    required String url,
    required String title,
    void Function(String imageUrl)? onVerifyCandidateImage,
  }) async {
    final isMobileWebViewSupported =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (!isMobileWebViewSupported) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: PanoptesColors.obsidian,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        side: BorderSide(color: PanoptesColors.borderCrimson, width: 1),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: WebViewReconSheet(
          initialUrl: url,
          title: title,
          onVerifyCandidateImage: onVerifyCandidateImage,
        ),
      ),
    );
  }

  @override
  State<WebViewReconSheet> createState() => _WebViewReconSheetState();
}

class _WebViewReconSheetState extends State<WebViewReconSheet> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = '';
  List<String> _capturedImages = const [];
  List<String> _capturedLinks = const [];
  bool _showCapturedDrawer = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(PanoptesColors.obsidian)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _currentUrl = url;
              });
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _currentUrl = url;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<void> _extractDomIntelligence() async {
    try {
      const jsScript = '''
      (function() {
        var imgs = Array.from(document.querySelectorAll('img'))
          .map(function(i) { return i.src || ''; })
          .filter(function(s) { return s.startsWith('http') && s.length < 400; })
          .slice(0, 18);
        var links = Array.from(document.querySelectorAll('a'))
          .map(function(a) { return a.href || ''; })
          .filter(function(h) { return h.startsWith('http') && !h.includes('google.com/preferences'); })
          .slice(0, 25);
        return JSON.stringify({images: imgs, links: links});
      })();
      ''';
      final rawResult = await _controller.runJavaScriptReturningResult(jsScript);
      String jsonStr = rawResult.toString();
      if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
        jsonStr = jsonDecode(jsonStr) as String;
      }
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final imgs = List<String>.from((map['images'] as List?) ?? const []).toSet().toList();
      final lnks = List<String>.from((map['links'] as List?) ?? const []).toSet().toList();

      if (mounted) {
        setState(() {
          _capturedImages = imgs;
          _capturedLinks = lnks;
          _showCapturedDrawer = true;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DOM verisi ayrıştırılamadı.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tactical Header Bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: const BoxDecoration(
            color: PanoptesColors.surfaceCard,
            border: Border(
              bottom: BorderSide(color: PanoptesColors.borderSubtle, width: 1),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.radar, color: PanoptesColors.crimson, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PanoptesColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _currentUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PanoptesColors.textMuted,
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'DOM Görsel & Link Yakala',
                onPressed: _extractDomIntelligence,
                icon: const Icon(Icons.auto_awesome_mosaic_outlined, size: 20, color: PanoptesColors.crimson),
              ),
              IconButton(
                tooltip: 'Dış Tarayıcıda Aç',
                onPressed: () async {
                  final uri = Uri.tryParse(_currentUrl);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 19, color: PanoptesColors.textSecondary),
              ),
              IconButton(
                tooltip: 'Kapat',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20, color: PanoptesColors.textPrimary),
              ),
            ],
          ),
        ),
        if (_isLoading)
          const LinearProgressIndicator(
            minHeight: 2,
            color: PanoptesColors.crimson,
            backgroundColor: PanoptesColors.surfaceBase,
          ),

        // Quick Engine Switcher Bar (Yandex / Google Lens / Bing / TinEye)
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: PanoptesColors.surfaceBase,
            border: Border(bottom: BorderSide(color: PanoptesColors.borderSubtle, width: 1)),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _QuickEngineChip(
                label: 'DOM Yakala (${_capturedImages.length + _capturedLinks.length})',
                active: _showCapturedDrawer,
                onTap: _extractDomIntelligence,
              ),
              _QuickEngineChip(
                label: 'Yandex Görsel',
                active: _currentUrl.contains('yandex'),
                onTap: () => _controller.loadRequest(Uri.parse('https://yandex.com.tr/images/')),
              ),
              _QuickEngineChip(
                label: 'Google Görsel',
                active: _currentUrl.contains('google'),
                onTap: () => _controller.loadRequest(Uri.parse('https://images.google.com/')),
              ),
              _QuickEngineChip(
                label: 'Bing Visual',
                active: _currentUrl.contains('bing.com'),
                onTap: () => _controller.loadRequest(Uri.parse('https://www.bing.com/visualsearch')),
              ),
              _QuickEngineChip(
                label: 'TinEye',
                active: _currentUrl.contains('tineye.com'),
                onTap: () => _controller.loadRequest(Uri.parse('https://tineye.com/')),
              ),
            ],
          ),
        ),

        // Captured DOM Drawer (Images to send to 192-D Face Verification + Extracted Links)
        if (_showCapturedDrawer)
          Container(
            constraints: const BoxConstraints(maxHeight: 190),
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: PanoptesColors.surfaceCard,
              border: Border(bottom: BorderSide(color: PanoptesColors.borderCrimson, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'YAKALANAN GÖRSELLER (${_capturedImages.length}) — Yüz Doğrulaması İçin Dokun',
                      style: const TextStyle(
                        color: PanoptesColors.crimsonBright,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _showCapturedDrawer = false),
                      child: const Text(
                        'Gizle',
                        style: TextStyle(color: PanoptesColors.textSecondary, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_capturedImages.isNotEmpty)
                  SizedBox(
                    height: 68,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _capturedImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final imgUrl = _capturedImages[idx];
                        return InkWell(
                          onTap: () {
                            widget.onVerifyCandidateImage?.call(imgUrl);
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: PanoptesColors.crimson, width: 1),
                              color: PanoptesColors.obsidian,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              imgUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                size: 20,
                                color: PanoptesColors.textMuted,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  const Text(
                    'Bu sayfada doğrudan <img> kaynağı bulunamadı.',
                    style: TextStyle(color: PanoptesColors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),

        // WebView Viewport
        Expanded(
          child: WebViewWidget(controller: _controller),
        ),
      ],
    );
  }
}

class _QuickEngineChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _QuickEngineChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? PanoptesColors.burgundyDeep : PanoptesColors.surfaceCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? PanoptesColors.crimson : PanoptesColors.borderSubtle,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : PanoptesColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

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
  final Uint8List? targetImageBytes;
  final void Function(String imageUrl)? onVerifyCandidateImage;

  const WebViewReconSheet({
    super.key,
    required this.initialUrl,
    required this.title,
    this.targetImageBytes,
    this.onVerifyCandidateImage,
  });

  static Future<void> open(
    BuildContext context, {
    required String url,
    required String title,
    Uint8List? targetImageBytes,
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

    final p = PanoptesPalette.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: p.obsidian,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        side: BorderSide(color: p.borderCrimson, width: 1),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: WebViewReconSheet(
          initialUrl: url,
          title: title,
          targetImageBytes: targetImageBytes,
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
  String? _lastInjectedUrl;

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
            if (widget.targetImageBytes != null &&
                _lastInjectedUrl != url &&
                !url.contains('cbir_id=')) {
              _injectTargetImageToWebView(silent: true);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<void> _injectTargetImageToWebView({bool silent = false}) async {
    final bytes = widget.targetImageBytes;
    if (bytes == null || bytes.isEmpty) return;
    _lastInjectedUrl = _currentUrl;
    try {
      final b64 = base64Encode(bytes);
      final js = '''
      (function() {
        try {
          var b64 = '$b64';
          var bin = atob(b64);
          var arr = new Uint8Array(bin.length);
          for (var i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
          var file = new File([arr], 'target_photo.jpg', {type: 'image/jpeg'});
          var dt = new DataTransfer();
          dt.items.add(file);
          var inputs = Array.from(document.querySelectorAll('input[type="file"]'));
          if (inputs.length > 0) {
            var inp = inputs[0];
            inp.files = dt.files;
            inp.dispatchEvent(new Event('change', {bubbles: true}));
            return 'injected';
          }
          return 'no_input';
        } catch (e) {
          return 'err:' + e.message;
        }
      })();
      ''';
      final res = await _controller.runJavaScriptReturningResult(js);
      if (!silent && mounted) {
        final msg = res.toString().contains('injected')
            ? 'Hedef fotoğraf arama motoruna gönderildi.'
            : 'Bu sayfada otomatik yükleme alanı bulunamadı; kamera/dosya ikonunu kullanın.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (_) {}
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
    final p = PanoptesPalette.of(context);
    return Column(
      children: [
        // Tactical Header Bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: p.surfaceCard,
            border: Border(
              bottom: BorderSide(color: p.borderSubtle, width: 1),
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
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _currentUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'DOM Görsel & Link Yakala',
                visualDensity: VisualDensity.compact,
                onPressed: _extractDomIntelligence,
                icon: const Icon(
                  Icons.auto_awesome_mosaic_outlined,
                  size: 19,
                  color: PanoptesColors.crimson,
                ),
              ),
              IconButton(
                tooltip: 'Dış Tarayıcıda Aç',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  final uri = Uri.tryParse(_currentUrl);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: Icon(Icons.open_in_new, size: 18, color: p.textSecondary),
              ),
              IconButton(
                tooltip: 'Kapat',
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, size: 19, color: p.textPrimary),
              ),
            ],
          ),
        ),
        if (_isLoading)
          LinearProgressIndicator(
            minHeight: 2,
            color: PanoptesColors.crimson,
            backgroundColor: p.surfaceBase,
          ),

        // Quick Engine Switcher Bar (Yandex / Google Lens / Bing / TinEye)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: p.surfaceBase,
            border: Border(bottom: BorderSide(color: p.borderSubtle, width: 1)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (widget.targetImageBytes != null)
                  _QuickEngineChip(
                    label: 'Fotoğrafı Yükle',
                    active: false,
                    onTap: () => _injectTargetImageToWebView(silent: false),
                  ),
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
                  onTap: () =>
                      _controller.loadRequest(Uri.parse('https://www.bing.com/visualsearch')),
                ),
                _QuickEngineChip(
                  label: 'TinEye',
                  active: _currentUrl.contains('tineye.com'),
                  onTap: () => _controller.loadRequest(Uri.parse('https://tineye.com/')),
                ),
              ],
            ),
          ),
        ),

        // Captured DOM Drawer
        if (_showCapturedDrawer)
          Container(
            constraints: const BoxConstraints(maxHeight: 185),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.surfaceCard,
              border: Border(bottom: BorderSide(color: p.borderCrimson, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'YAKALANAN GÖRSELLER (${_capturedImages.length}) — Yüz Doğrulaması İçin Dokun',
                        style: TextStyle(
                          color: p.isDark
                              ? PanoptesColors.crimsonBright
                              : PanoptesColors.crimsonDeep,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() => _showCapturedDrawer = false),
                      child: Text(
                        'Gizle',
                        style: TextStyle(color: p.textSecondary, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_capturedImages.isNotEmpty)
                  SizedBox(
                    height: 64,
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
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: PanoptesColors.crimson, width: 1),
                              color: p.surfaceBase,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              imgUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.broken_image_outlined,
                                size: 20,
                                color: p.textMuted,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Text(
                    'Bu sayfada doğrudan <img> kaynağı bulunamadı.',
                    style: TextStyle(color: p.textMuted, fontSize: 11),
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
    final p = PanoptesPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? PanoptesColors.crimson : p.surfaceCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? PanoptesColors.crimsonBright : p.borderSubtle,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : p.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

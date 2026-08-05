import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:qui/constants.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/plugins/substack/substack_client.dart';
import 'package:qui/plugins/substack/substack_html.dart';
import 'package:qui/plugins/substack/substack_html_parser.dart';
import 'package:qui/plugins/substack/substack_html_view.dart';
import 'package:qui/plugins/substack/substack_models.dart';
import 'package:qui/plugins/substack/substack_store.dart';
import 'package:qui/ui/dates.dart';
import 'package:qui/ui/errors.dart';
import 'package:qui/utils/desktop_files.dart';
import 'package:qui/utils/urls.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SubstackReaderScreen extends StatefulWidget {
  final SubstackPost post;

  const SubstackReaderScreen({super.key, required this.post});

  @override
  State<SubstackReaderScreen> createState() => _SubstackReaderScreenState();
}

class _SubstackReaderScreenState extends State<SubstackReaderScreen> {
  /// Mobile only. webview_flutter has no Linux/Windows implementation, so on
  /// desktop the body is parsed and rendered natively instead ([_blocks]).
  WebViewController? _controller;
  late final FlutterTts _tts;
  late SubstackPost _post;
  Object? _error;
  var _loading = true;
  var _empty = false;
  var _paywalled = false;
  var _speaking = false;
  var _ttsReady = false;
  String? _speakText;

  /// Desktop: the parsed article body, rendered without a WebView.
  List<SubstackBlock>? _blocks;

  /// Desktop: the post has no readable body here (fetch failed or body
  /// missing) but does have a web URL — offer that instead of a WebView.
  var _webOnly = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    if (!isDesktop) {
      _controller = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
    }
    _tts = FlutterTts();
    // flutter_tts has no Linux implementation; skip it there so its channel
    // calls cannot throw. The listen button stays hidden while [_ttsReady] is
    // false.
    if (!Platform.isLinux) {
      _initTts();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubstackReadStore>().markRead(_post.id);
      _load();
    });
  }

  Future<void> _initTts() async {
    await _tts.awaitSpeakCompletion(true);
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _speaking = false);
    });

    final locale = Intl.shortLocale(Intl.getCurrentLocale());
    final language = switch (locale) {
      'zh' => 'zh-CN',
      'nb' => 'nb-NO',
      'pt' => 'pt-BR',
      _ => locale.contains('_') ? locale.replaceAll('_', '-') : '$locale-${locale.toUpperCase()}',
    };
    try {
      await _tts.setLanguage(language);
    } catch (_) {
      await _tts.setLanguage('en-US');
    }
    await _tts.setSpeechRate(0.45);
    if (mounted) setState(() => _ttsReady = true);
  }

  @override
  void dispose() {
    if (!Platform.isLinux) {
      _tts.stop();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final client = context.read<SubstackClient>();
      final full = await client.fetchPost(_post.publication, _post.slug);
      if (!mounted) return;
      _post = full;
      _error = null;
      await _showContent(full);
    } catch (e) {
      if (!mounted) return;
      if (_post.canonicalUrl != null) {
        if (isDesktop) {
          setState(() {
            _error = null;
            _paywalled = false;
            _empty = false;
            _speakText = null;
            _blocks = null;
            _webOnly = true;
            _loading = false;
          });
          return;
        }
        _error = null;
        _paywalled = false;
        _empty = false;
        _speakText = null;
        _controller!.setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ));
        await _controller!.loadRequest(Uri.parse(_post.canonicalUrl!));
      } else {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _showContent(SubstackPost post) async {
    if (post.isPaywalled) {
      setState(() {
        _paywalled = true;
        _empty = false;
        _loading = false;
        _speakText = null;
        _blocks = null;
        _webOnly = false;
      });
      return;
    }

    final html = post.bodyHtml;
    if (html != null && html.trim().isNotEmpty) {
      _paywalled = false;
      _empty = false;
      _speakText = buildSubstackSpeakText(
        title: post.title,
        subtitle: post.excerpt,
        authorName: post.authorName,
        publicationName: post.publicationName,
        bodyHtml: html,
      );
      if (isDesktop) {
        setState(() {
          _blocks = parseSubstackHtml(sanitizeSubstackBodyHtml(html));
          _webOnly = false;
          _loading = false;
        });
        return;
      }
      _controller!.setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ));
      final scheme = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      await _controller!.loadHtmlString(
        wrapSubstackHtml(
          title: post.title,
          body: html,
          subtitle: post.excerpt,
          authorName: post.authorName,
          publicationName: post.publicationName,
          background: _cssColor(scheme.surface),
          foreground: _cssColor(scheme.onSurface),
          muted: _cssColor(scheme.onSurfaceVariant),
          link: _cssColor(scheme.primary),
          isDark: isDark,
        ),
      );
      return;
    }

    if (post.canonicalUrl != null) {
      if (isDesktop) {
        setState(() {
          _paywalled = false;
          _empty = false;
          _speakText = null;
          _blocks = null;
          _webOnly = true;
          _loading = false;
        });
        return;
      }
      _paywalled = false;
      _empty = false;
      _speakText = null;
      _controller!.setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ));
      await _controller!.loadRequest(Uri.parse(post.canonicalUrl!));
      return;
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _empty = true;
        _paywalled = false;
        _speakText = null;
        _blocks = null;
        _webOnly = false;
      });
    }
  }

  Future<void> _toggleTts() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }

    final text = _speakText?.trim();
    if (text == null || text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).plugin_substack_tts_unavailable)),
      );
      return;
    }

    // Android engines can choke on very long utterances; speak in chunks.
    final chunks = _chunkForTts(text);
    setState(() => _speaking = true);
    for (final chunk in chunks) {
      if (!mounted || !_speaking) break;
      await _tts.speak(chunk);
    }
    if (mounted) setState(() => _speaking = false);
  }

  void _share() {
    final url = _post.canonicalUrl;
    if (url == null || url.isEmpty) return;
    SharePlus.instance.share(ShareParams(text: '${_post.title}\n$url'));
  }

  Widget _buildNativeArticle(BuildContext context, List<SubstackBlock> blocks) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final post = _post;
    final absoluteTimestamp = PrefService.of(context).get<bool>(optionUseAbsoluteTimestamp) ?? false;

    final meta = [
      if (post.publicationName.trim().isNotEmpty) post.publicationName.trim(),
      if (post.authorName != null && post.authorName!.trim().isNotEmpty) post.authorName!.trim(),
    ].join(' · ');
    final host = Uri.tryParse(post.publicationBaseUrl)?.host ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (post.coverImage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ExtendedImage.network(post.coverImage!, fit: BoxFit.fitWidth),
                    ),
                  ),
                Text(post.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                if (post.excerpt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(post.excerpt!,
                        style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: DefaultTextStyle.merge(
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    child: Row(
                      children: [
                        Flexible(child: Text(meta.isEmpty ? host : meta, overflow: TextOverflow.ellipsis)),
                        if (post.publishedAt != null) ...[
                          const Text(' · '),
                          Timestamp(timestamp: post.publishedAt, absoluteTimestamp: absoluteTimestamp),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                SubstackHtmlView(blocks: blocks),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSpeak = _ttsReady && !_paywalled && !_empty && (_speakText?.trim().isNotEmpty ?? false);
    final blocks = _blocks;

    return Scaffold(
      appBar: AppBar(
        title: Text(_post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (canSpeak || _speaking)
            IconButton(
              tooltip: _speaking
                  ? L10n.of(context).plugin_substack_tts_stop
                  : L10n.of(context).plugin_substack_tts_listen,
              icon: Icon(_speaking ? Icons.stop_circle_outlined : Icons.record_voice_over_outlined),
              onPressed: _toggleTts,
            ),
          if (_post.canonicalUrl != null) ...[
            IconButton(
              tooltip: L10n.of(context).share_link,
              icon: const Icon(Icons.share_outlined),
              onPressed: _share,
            ),
            IconButton(
              tooltip: L10n.of(context).open_in_browser,
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openUri(context, _post.canonicalUrl!),
            ),
          ],
        ],
      ),
      body: _error != null
          ? FullPageErrorWidget(
              error: _error,
              stackTrace: null,
              prefix: L10n.of(context).plugin_substack_load_error,
              onRetry: () {
                setState(() {
                  _error = null;
                  _empty = false;
                  _paywalled = false;
                  _blocks = null;
                  _webOnly = false;
                  _loading = true;
                });
                _load();
              },
            )
          : _paywalled
              ? _PaywallPane(
                  post: _post,
                  onOpenWeb: _post.canonicalUrl == null ? null : () => openUri(context, _post.canonicalUrl!),
                )
              : _empty
                  ? Center(child: Text(L10n.of(context).plugin_substack_no_content))
                  : _webOnly
                      ? _WebOnlyPane(
                          post: _post,
                          onOpenWeb:
                              _post.canonicalUrl == null ? null : () => openUri(context, _post.canonicalUrl!),
                        )
                      : blocks != null
                          ? _buildNativeArticle(context, blocks)
                          : _controller == null
                              // Desktop, still fetching: nothing to show yet.
                              ? const Center(child: CircularProgressIndicator())
                              : Stack(
                                  children: [
                                    WebViewWidget(controller: _controller!),
                                    if (_loading) const Center(child: CircularProgressIndicator()),
                                  ],
                                ),
    );
  }
}

class _PaywallPane extends StatelessWidget {
  final SubstackPost post;
  final VoidCallback? onOpenWeb;

  const _PaywallPane({required this.post, this.onOpenWeb});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          L10n.of(context).plugin_substack_paywalled_title,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          L10n.of(context).plugin_substack_paywalled_description,
          textAlign: TextAlign.center,
        ),
        if (post.excerpt != null) ...[
          const SizedBox(height: 24),
          Text(post.excerpt!, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
        ],
        if (onOpenWeb != null) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onOpenWeb,
            icon: const Icon(Icons.open_in_new),
            label: Text(L10n.of(context).open_in_browser),
          ),
        ],
      ],
    );
  }
}

/// Desktop stand-in for the WebView fallbacks: the post body is not readable
/// in-app, so lead the reader to the website instead.
class _WebOnlyPane extends StatelessWidget {
  final SubstackPost post;
  final VoidCallback? onOpenWeb;

  const _WebOnlyPane({required this.post, this.onOpenWeb});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.newspaper_outlined, size: 48, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          post.title,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        if (post.excerpt != null) ...[
          const SizedBox(height: 16),
          Text(post.excerpt!, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
        ],
        if (onOpenWeb != null) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onOpenWeb,
            icon: const Icon(Icons.open_in_new),
            label: Text(L10n.of(context).substack_read_on_substack),
          ),
        ],
      ],
    );
  }
}

String _cssColor(Color color) {
  final hex = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${hex.substring(2)}';
}

List<String> _chunkForTts(String text, {int maxChars = 3500}) {
  if (text.length <= maxChars) return [text];

  final chunks = <String>[];
  var remaining = text;
  while (remaining.length > maxChars) {
    var splitAt = remaining.lastIndexOf('\n\n', maxChars);
    if (splitAt < maxChars ~/ 2) {
      splitAt = remaining.lastIndexOf('. ', maxChars);
      if (splitAt < maxChars ~/ 2) splitAt = maxChars;
    }
    chunks.add(remaining.substring(0, splitAt).trim());
    remaining = remaining.substring(splitAt).trimLeft();
  }
  if (remaining.isNotEmpty) chunks.add(remaining);
  return chunks;
}

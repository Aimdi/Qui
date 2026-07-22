import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:qui/constants.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/substack/substack_client.dart';
import 'package:qui/substack/substack_html.dart';
import 'package:qui/substack/substack_html_parser.dart';
import 'package:qui/substack/substack_model.dart';
import 'package:qui/ui/dates.dart';
import 'package:qui/ui/errors.dart';
import 'package:qui/utils/urls.dart';
import 'package:share_plus/share_plus.dart';

class SubstackArticleScreenArguments {
  final String host;
  final String slug;

  /// The archive listing of the post, when we navigated from the feed. Lets
  /// the header render while the full body loads.
  final SubstackPost? post;

  SubstackArticleScreenArguments({required this.host, required this.slug, this.post});
}

class SubstackArticleScreen extends StatefulWidget {
  const SubstackArticleScreen({super.key});

  @override
  State<SubstackArticleScreen> createState() => _SubstackArticleScreenState();
}

class _SubstackArticleScreenState extends State<SubstackArticleScreen> {
  SubstackArticleScreenArguments? _arguments;
  Future<SubstackPost>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_future == null) {
      final arguments = ModalRoute.of(context)!.settings.arguments as SubstackArticleScreenArguments;
      _arguments = arguments;
      _future = fetchSubstackPost(arguments.host, arguments.slug);
    }
  }

  void _retry() {
    setState(() {
      _future = fetchSubstackPost(_arguments!.host, _arguments!.slug);
    });
  }

  Widget _buildArticle(BuildContext context, SubstackPost post) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final absoluteTimestamp = PrefService.of(context).get<bool>(optionUseAbsoluteTimestamp) ?? false;

    final publication = context
        .read<SubstackModel>()
        .state
        .where((e) => e.host == post.host)
        .firstOrNull;

    final bodyHtml = post.bodyHtml;
    final blocks = bodyHtml == null || bodyHtml.isEmpty ? <SubstackBlock>[] : parseSubstackHtml(bodyHtml);

    return ListView(
      padding: const EdgeInsets.all(16),
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
        if (post.subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(post.subtitle!,
                style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: DefaultTextStyle.merge(
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            child: Row(
              children: [
                if (publication?.logoUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CircleAvatar(radius: 10, backgroundImage: ExtendedNetworkImageProvider(publication!.logoUrl!)),
                  ),
                Flexible(child: Text(publication?.name ?? post.host, overflow: TextOverflow.ellipsis)),
                if (post.postDate != null) ...[
                  const Text(' · '),
                  Timestamp(timestamp: post.postDate, absoluteTimestamp: absoluteTimestamp),
                ],
              ],
            ),
          ),
        ),
        Divider(height: 1, color: colorScheme.surfaceBright.withAlpha(150)),
        const SizedBox(height: 8),
        if (blocks.isNotEmpty)
          SubstackHtmlView(blocks: blocks)
        else if (post.description != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(post.description!, style: theme.textTheme.bodyMedium),
          ),
        if (post.isPaid) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(L10n.of(context).substack_paid_post_preview, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => openUri(post.url),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(L10n.of(context).substack_read_on_substack),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _arguments?.post;

    return FutureBuilder<SubstackPost>(
      future: _future,
      builder: (context, snapshot) {
        final post = snapshot.data;
        final shareUrl = post?.url ?? fallback?.url;

        return Scaffold(
          appBar: AppBar(
            actions: [
              if (shareUrl != null) ...[
                IconButton(
                  icon: const Icon(Icons.share_rounded),
                  tooltip: L10n.of(context).share_article_link,
                  onPressed: () => Share.share(cleanUrl(shareUrl)),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_browser_rounded),
                  tooltip: L10n.of(context).open_in_browser,
                  onPressed: () => openInDefaultBrowser(shareUrl),
                ),
              ],
            ],
          ),
          body: switch (snapshot.connectionState) {
            ConnectionState.done when snapshot.hasError => EmojiErrorWidget(
                emoji: '📰',
                message: L10n.of(context).substack_unable_to_load_posts,
                errorMessage: snapshot.error.toString(),
                onRetry: _retry,
                retryText: L10n.of(context).retry,
                showBackButton: false,
              ),
            ConnectionState.done when post != null => _buildArticle(context, post),
            _ => const Center(child: CircularProgressIndicator()),
          },
        );
      },
    );
  }
}

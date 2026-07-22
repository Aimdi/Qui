import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:qui/constants.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/substack/substack_article_screen.dart';
import 'package:qui/substack/substack_client.dart';
import 'package:qui/substack/substack_model.dart';
import 'package:qui/ui/dates.dart';
import 'package:qui/ui/errors.dart';

const _pageSize = 12;

class SubstackScreen extends StatefulWidget {
  final ScrollController scrollController;

  const SubstackScreen({super.key, required this.scrollController});

  @override
  State<SubstackScreen> createState() => _SubstackScreenState();
}

class _SubstackScreenState extends State<SubstackScreen> with AutomaticKeepAliveClientMixin<SubstackScreen> {
  late final SubstackModel _model;
  Disposer? _modelDisposer;

  /// null means all publications.
  String? _filterHost;

  final List<SubstackPost> _posts = [];
  final Map<String, int> _offsets = {};
  final Set<String> _exhausted = {};
  bool _loading = false;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _model = context.read<SubstackModel>();
    _modelDisposer = _model.observer(onState: (_) => _onSubscriptionsChanged());

    widget.scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) => _resetAndLoad());
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _modelDisposer?.call();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) {
      return;
    }

    final position = widget.scrollController.position;
    if (position.extentAfter < 600) {
      _loadMore();
    }
  }

  void _onSubscriptionsChanged() {
    if (!mounted) {
      return;
    }

    // The filtered publication may just have been unfollowed.
    if (_filterHost != null && !_model.state.any((e) => e.host == _filterHost)) {
      _filterHost = null;
    }

    _resetAndLoad();
  }

  List<String> _hostsInScope() {
    final filterHost = _filterHost;
    if (filterHost != null) {
      return [filterHost];
    }

    return _model.state.map((e) => e.host).toList();
  }

  Future<void> _resetAndLoad() async {
    setState(() {
      _posts.clear();
      _offsets.clear();
      _exhausted.clear();
      _error = null;
      _loading = false;
    });

    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !mounted) {
      return;
    }

    final hosts = _hostsInScope().where((e) => !_exhausted.contains(e)).toList();
    if (hosts.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    Object? firstError;
    final fresh = <SubstackPost>[];

    await Future.wait(hosts.map((host) async {
      try {
        final posts = await fetchSubstackArchive(host, offset: _offsets[host] ?? 0, limit: _pageSize);

        fresh.addAll(posts);
        _offsets[host] = (_offsets[host] ?? 0) + posts.length;
        if (posts.length < _pageSize) {
          _exhausted.add(host);
        }
      } catch (e) {
        // One broken publication shouldn't take the whole feed down; surface
        // the error only if nothing at all could be loaded.
        firstError ??= e;
        _exhausted.add(host);
      }
    }));

    if (!mounted) {
      return;
    }

    setState(() {
      final seen = _posts.map((e) => '${e.host}/${e.id}').toSet();
      _posts.addAll(fresh.where((e) => seen.add('${e.host}/${e.id}')));
      _posts.sort((a, b) {
        if (a.postDate == null || b.postDate == null) {
          return a.postDate == null ? 1 : -1;
        }
        return b.postDate!.compareTo(a.postDate!);
      });

      _error = _posts.isEmpty ? firstError : null;
      _loading = false;
    });
  }

  Future<void> _showAddDialog() async {
    final controller = TextEditingController();
    var busy = false;
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(L10n.of(context).substack_add_publication),
          content: TextField(
            controller: controller,
            autofocus: true,
            enabled: !busy,
            decoration: InputDecoration(
              hintText: L10n.of(context).substack_publication_hint,
              errorText: errorText,
            ),
            onSubmitted: busy ? null : (_) => _subscribe(context, controller.text, setDialogState, (v) => busy = v,
                (v) => errorText = v),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: Text(L10n.of(context).cancel),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () =>
                      _subscribe(context, controller.text, setDialogState, (v) => busy = v, (v) => errorText = v),
              child: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(L10n.of(context).subscribe),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _subscribe(BuildContext dialogContext, String input, StateSetter setDialogState,
      void Function(bool) setBusy, void Function(String?) setError) async {
    if (input.trim().isEmpty) {
      return;
    }

    setDialogState(() {
      setBusy(true);
      setError(null);
    });

    try {
      await _model.subscribe(input);
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
    } catch (_) {
      if (dialogContext.mounted) {
        setDialogState(() {
          setBusy(false);
          setError(L10n.of(dialogContext).substack_unable_to_add);
        });
      }
    }
  }

  Future<void> _confirmUnsubscribe(SubstackPublication publication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).substack_stop_following(publication.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(L10n.of(context).cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(L10n.of(context).unsubscribe)),
        ],
      ),
    );

    if (confirmed == true) {
      await _model.unsubscribe(publication.host);
    }
  }

  Widget _buildChips(BuildContext context, List<SubstackPublication> publications) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(L10n.of(context).all),
              selected: _filterHost == null,
              onSelected: (_) {
                setState(() => _filterHost = null);
                _resetAndLoad();
              },
            ),
          ),
          for (final publication in publications)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onLongPress: () => _confirmUnsubscribe(publication),
                child: ChoiceChip(
                  avatar: publication.logoUrl == null
                      ? null
                      : CircleAvatar(backgroundImage: ExtendedNetworkImageProvider(publication.logoUrl!)),
                  label: Text(publication.name),
                  selected: _filterHost == publication.host,
                  onSelected: (_) {
                    setState(() => _filterHost = publication.host);
                    _resetAndLoad();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.newspaper_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(L10n.of(context).substack_no_subscriptions,
                style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(L10n.of(context).substack_no_subscriptions_description,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add_rounded),
              label: Text(L10n.of(context).substack_add_publication),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final error = _error;
    if (error != null && _posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: EmojiErrorWidget(
          emoji: '📰',
          message: L10n.of(context).substack_unable_to_load_posts,
          errorMessage: error.toString(),
          onRetry: _resetAndLoad,
          retryText: L10n.of(context).retry,
          showBackButton: false,
        ),
      );
    }

    return const SizedBox(height: 24);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ScopedBuilder<SubstackModel, List<SubstackPublication>>.transition(
      store: _model,
      onError: (_, error) => Scaffold(
        appBar: AppBar(title: Text(L10n.of(context).substack)),
        body: EmojiErrorWidget(
          emoji: '📰',
          message: L10n.of(context).substack_unable_to_load_posts,
          errorMessage: error.toString(),
          onRetry: () async => await _model.reload(),
          retryText: L10n.of(context).retry,
          showBackButton: false,
        ),
      ),
      onLoading: (_) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      onState: (context, publications) => Scaffold(
        appBar: AppBar(
          title: Text(L10n.of(context).substack),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: L10n.of(context).substack_add_publication,
              onPressed: _showAddDialog,
            ),
          ],
        ),
        body: publications.isEmpty
            ? _buildEmptyState(context)
            : RefreshIndicator(
                onRefresh: _resetAndLoad,
                child: ListView.builder(
                  controller: widget.scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _posts.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildChips(context, publications);
                    }
                    if (index == _posts.length + 1) {
                      return _buildFooter(context);
                    }

                    return _SubstackPostCard(post: _posts[index - 1], model: _model);
                  },
                ),
              ),
      ),
    );
  }
}

class _SubstackPostCard extends StatelessWidget {
  final SubstackPost post;
  final SubstackModel model;

  const _SubstackPostCard({required this.post, required this.model});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final absoluteTimestamp = PrefService.of(context).get<bool>(optionUseAbsoluteTimestamp) ?? false;

    final publication = model.state.where((e) => e.host == post.host).firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          routeSubstackArticle,
          arguments: SubstackArticleScreenArguments(host: post.host, slug: post.slug, post: post),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.coverImage != null) ExtendedImage.network(post.coverImage!, fit: BoxFit.fitWidth),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (post.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        post.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    DefaultTextStyle.merge(
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      child: Row(
                        children: [
                          Flexible(child: Text(publication?.name ?? post.host, overflow: TextOverflow.ellipsis)),
                          if (post.postDate != null) ...[
                            const Text(' · '),
                            Timestamp(timestamp: post.postDate, absoluteTimestamp: absoluteTimestamp),
                          ],
                          if (post.isPaid) ...[
                            const Spacer(),
                            Icon(Icons.lock_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

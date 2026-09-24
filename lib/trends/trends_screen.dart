import 'package:flutter/material.dart';
import 'package:qui/constants.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/search/recent_searches_bar.dart';
import 'package:qui/search/search.dart';
import 'package:qui/search/search_history.dart';
import 'package:qui/trends/_list.dart';
import 'package:qui/trends/_settings.dart';
import 'package:qui/trends/_tabs.dart';
import 'package:qui/ui/adaptive_sheet.dart';
import 'package:qui/ui/layout.dart';
import 'package:qui/ui/tab_app_bar.dart';

class TrendsScreen extends StatefulWidget {
  final ScrollController scrollController;
  final FocusNode focusNode;

  const TrendsScreen({
    super.key,
    required this.scrollController,
    required this.focusNode,
  });

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen>
    with AutomaticKeepAliveClientMixin<TrendsScreen> {
  @override
  bool get wantKeepAlive => true;
  final TextEditingController _queryController = TextEditingController();
  final SearchHistory _history = SearchHistory()..load();

  Future<void> _submit(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      widget.focusNode.requestFocus();
      return;
    }

    _queryController.text = query;
    await _history.remember(query);
    if (!mounted) return;

    await Navigator.pushNamed(
      context,
      routeSearch,
      arguments: SearchArguments(
        0,
        focusInputOnOpen: false,
        query: query,
      ),
    );
  }

  void _clearQuery() {
    _queryController.clear();
    widget.focusNode.requestFocus();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _history.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final desktop = useDesktopShell(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      appBar: tabAppBar(
        context: context,
        hideTitleOnDesktop: false,
        toolbarHeight: desktop ? 72 : kToolbarHeight,
        flexibleSpace: Padding(
          padding: EdgeInsets.fromLTRB(8, 8 + (desktop ? 0 : topInset), 8, 8),
          child: SearchBar(
            controller: _queryController,
            focusNode: widget.focusNode,
            hintText: L10n.of(context).search,
            textInputAction: TextInputAction.search,
            leading: IconButton(
              icon: const Icon(Icons.search),
              tooltip: L10n.of(context).search,
              onPressed: () => _submit(_queryController.text),
            ),
            trailing: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _queryController,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        key: const ValueKey('discover-search-clear'),
                        tooltip: L10n.of(context).reader_clear_search,
                        onPressed: _clearQuery,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ],
            onSubmitted: _submit,
          ),
        ),
        bottom: TrendsTabBar(),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async => showAdaptiveSheet(
          context: context,
          builder: (context) => const TrendsSettings(),
        ),
      ),
      body: Column(
        children: [
          RecentSearchesBar(store: _history, onSelected: _submit),
          Expanded(child: TrendsList(scrollController: widget.scrollController)),
        ],
      ),
    );
  }
}

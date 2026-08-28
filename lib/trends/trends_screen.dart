import 'package:flutter/material.dart';
import 'package:qui/constants.dart';
import 'package:qui/search/search.dart';
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
            textInputAction: TextInputAction.search,
            leading: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => {},
            ),
            onSubmitted: (query) {
              Navigator.pushNamed(
                context,
                routeSearch,
                arguments: SearchArguments(
                  0,
                  focusInputOnOpen: false,
                  query: query,
                ),
              );
            },
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
      body: TrendsList(scrollController: widget.scrollController),
    );
  }
}

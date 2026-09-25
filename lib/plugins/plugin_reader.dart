import 'package:flutter/material.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/plugins/plugin.dart';
import 'package:qui/ui/layout.dart';

/// Opens a reader even when its optional navigation tab is hidden.
class PluginReader extends StatefulWidget {
  final QuaxPlugin plugin;
  const PluginReader({super.key, required this.plugin});

  @override
  State<PluginReader> createState() => _PluginReaderState();
}

class _PluginReaderState extends State<PluginReader> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.plugin.title(context)),
      actions: [
        if (widget.plugin.settingsScreen(context) != null)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: L10n.of(context).settings,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => widget.plugin.settingsScreen(context)!),
            ),
          ),
      ],
    ),
    body: ContentFrame(child: widget.plugin.homeScreen(scrollController: _scroll) ?? const SizedBox.shrink()),
  );
}

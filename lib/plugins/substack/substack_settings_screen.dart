import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/plugins/substack/substack_add_screen.dart';
import 'package:qui/plugins/substack/substack_models.dart';
import 'package:qui/plugins/substack/substack_store.dart';
import 'package:qui/ui/errors.dart';

/// Manage followed Substack publications from the plugin store's Settings row.
///
/// Without this the only place to follow/unfollow publications is the Substack
/// home tab; when that tab is turned off there was no way to configure the
/// plugin on desktop. Reuses [SubstackAddScreen] and the global stores.
class SubstackSettingsScreen extends StatefulWidget {
  const SubstackSettingsScreen({super.key});

  @override
  State<SubstackSettingsScreen> createState() => _SubstackSettingsScreenState();
}

class _SubstackSettingsScreenState extends State<SubstackSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SubstackPublicationsStore>().load();
    });
  }

  Future<void> _add() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SubstackAddScreen()),
    );
    // Reload regardless of the result: the add screen may have followed a
    // publication and popped without a positive result (e.g. the post-preview
    // confirm path), and re-reading is cheap.
    if (!mounted) return;
    await context.read<SubstackPublicationsStore>().load();
    if (mounted) await context.read<SubstackFeedStore>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final pubs = context.read<SubstackPublicationsStore>();

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).plugin_substack_title),
        actions: [
          IconButton(
            tooltip: L10n.of(context).plugin_substack_add,
            icon: const Icon(Icons.add),
            onPressed: _add,
          ),
        ],
      ),
      body: ScopedBuilder<SubstackPublicationsStore, List<SubstackPublication>>(
        store: pubs,
        onError: (_, error) => FullPageErrorWidget(
          error: error,
          stackTrace: null,
          prefix: L10n.of(context).plugin_substack_load_error,
          onRetry: pubs.load,
        ),
        onLoading: (_) => const Center(child: CircularProgressIndicator()),
        onState: (context, publications) {
          if (publications.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Icon(Icons.newspaper_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    L10n.of(context).plugin_substack_empty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    L10n.of(context).plugin_substack_empty_description,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    label: Text(L10n.of(context).plugin_substack_add),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            itemCount: publications.length,
            itemBuilder: (context, index) {
              final pub = publications[index];
              return ListTile(
                leading: pub.logoUrl == null
                    ? const Icon(Icons.newspaper)
                    : ClipOval(
                        child: ExtendedImage.network(pub.logoUrl!, width: 40, height: 40, fit: BoxFit.cover),
                      ),
                title: Text(pub.name),
                trailing: IconButton(
                  tooltip: L10n.of(context).plugin_substack_unfollow,
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    await pubs.remove(pub.id);
                    if (context.mounted) await context.read<SubstackFeedStore>().refresh();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

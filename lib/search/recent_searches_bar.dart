import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/search/search_history.dart';

class RecentSearchesBar extends StatelessWidget {
  final SearchHistory store;
  final ValueChanged<String> onSelected;

  const RecentSearchesBar({super.key, required this.store, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ScopedBuilder<SearchHistory, List<String>>(
      store: store,
      onState: (context, queries) {
        if (queries.isEmpty) return const SizedBox.shrink();
        final l10n = L10n.of(context);

        return SizedBox(
          height: MediaQuery.textScalerOf(context).scale(14) + 44,
          child: Row(
            children: [
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
                  itemCount: queries.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => Center(
                    child: InputChip(
                      avatar: const Icon(Icons.history, size: 18),
                      label: Text(queries[index], maxLines: 1),
                      tooltip: l10n.reader_recent_searches,
                      onPressed: () => onSelected(queries[index]),
                      onDeleted: () => store.remove(queries[index]),
                      deleteButtonTooltipMessage: l10n.delete,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('recent-searches-clear'),
                tooltip: l10n.reader_clear_searches,
                onPressed: store.clear,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
              const SizedBox(width: 4),
            ],
          ),
        );
      },
    );
  }
}

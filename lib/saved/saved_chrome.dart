import 'package:flutter/material.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/saved/saved_view_store.dart';

enum SavedLibraryAction { sortNewest, sortOldest, select }

class SavedLibraryActionButton extends StatelessWidget {
  final SavedSort sort;
  final bool canSelect;
  final ValueChanged<SavedLibraryAction> onSelected;

  const SavedLibraryActionButton({
    super.key,
    required this.sort,
    required this.canSelect,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return PopupMenuButton<SavedLibraryAction>(
      key: const ValueKey('saved-library-actions'),
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      icon: const Icon(Icons.tune),
      onSelected: onSelected,
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: SavedLibraryAction.sortNewest,
          checked: sort == SavedSort.newest,
          child: Text(l10n.library_sort_newest),
        ),
        CheckedPopupMenuItem(
          value: SavedLibraryAction.sortOldest,
          checked: sort == SavedSort.oldest,
          child: Text(l10n.library_sort_oldest),
        ),
        if (canSelect) const PopupMenuDivider(),
        if (canSelect)
          PopupMenuItem(
            value: SavedLibraryAction.select,
            child: Row(
              children: [
                const Icon(Icons.checklist_outlined, size: 20),
                const SizedBox(width: 10),
                Text(l10n.select),
              ],
            ),
          ),
      ],
    );
  }
}

class SavedSelectableTile extends StatelessWidget {
  final String id;
  final bool selected;
  final VoidCallback onToggle;
  final Widget child;

  const SavedSelectableTile({
    super.key,
    required this.id,
    required this.selected,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        key: ValueKey('saved-select-$id'),
        onTap: onToggle,
        child: Stack(
          children: [
            IgnorePointer(child: child),
            PositionedDirectional(
              top: 8,
              end: 12,
              child: Semantics(
                checked: selected,
                child: Checkbox(
                  value: selected,
                  onChanged: (_) => onToggle(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

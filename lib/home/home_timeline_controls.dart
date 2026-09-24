import 'package:flutter/material.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/ui/layout.dart';

@immutable
class HomeSourceOption<T> {
  final T value;
  final String label;
  final IconData icon;

  const HomeSourceOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

/// Compact Home source selector.
///
/// On desktop this is deliberately a menu button instead of a phone-sized
/// dropdown field: it leaves room for feed actions and works naturally with a
/// mouse. Compact layouts keep the same control, so keyboard/focus behaviour is
/// consistent across window sizes.
class HomeSourceSwitcher<T> extends StatelessWidget {
  final T selected;
  final List<HomeSourceOption<T>> options;
  final ValueChanged<T> onSelected;

  const HomeSourceSwitcher({
    super.key,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedOption = options.firstWhere(
      (option) => option.value == selected,
      orElse: () => options.first,
    );
    final desktop = useDesktopShell(context);

    return PopupMenuButton<T>(
      initialValue: selected,
      tooltip: L10n.of(context).home,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<T>(
            value: option.value,
            child: Row(
              children: [
                Icon(option.icon, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(option.label)),
                if (option.value == selected)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 12),
                    child: Icon(Icons.check, size: 18),
                  ),
              ],
            ),
          ),
      ],
      child: Semantics(
        button: true,
        label: selectedOption.label,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: desktop ? 260 : 210),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: desktop ? 4 : 0,
              end: 4,
              top: 6,
              bottom: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selectedOption.icon, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    selectedOption.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// XTA-style Posts / Media reading control for the Following feed.
///
/// Keeping this below the title makes Home feel like a reader workspace while
/// preserving Qui's desktop rail/deck shell and its separate action buttons.
class HomeReadingControls extends StatelessWidget {
  final bool mediaOnly;
  final VoidCallback onMediaToggle;

  const HomeReadingControls({
    super.key,
    required this.mediaOnly,
    required this.onMediaToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final divider = theme.dividerColor.withValues(alpha: 0.55);

    Widget mode({
      required bool media,
      required String label,
      required IconData icon,
      required Key key,
    }) {
      final selected = mediaOnly == media;
      return Semantics(
        selected: selected,
        button: true,
        child: TextButton.icon(
          key: key,
          onPressed: selected ? null : onMediaToggle,
          icon: Icon(icon, size: 19),
          label: Text(label),
          style: TextButton.styleFrom(
            foregroundColor:
                selected ? theme.colorScheme.onSurface : theme.hintColor,
            disabledForegroundColor: theme.colorScheme.onSurface,
            minimumSize: const Size(96, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            shape: const RoundedRectangleBorder(),
          ).copyWith(
            side: WidgetStatePropertyAll(
              BorderSide(
                color: selected ? accent : Colors.transparent,
                width: selected ? 0 : 0,
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.96),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: divider)),
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  mode(
                    media: false,
                    label: L10n.of(context).tweets,
                    icon: Icons.view_stream_outlined,
                    key: const ValueKey('home-posts-tab'),
                  ),
                  mode(
                    media: true,
                    label: L10n.of(context).media,
                    icon: Icons.photo_library_outlined,
                    key: const ValueKey('home-media-toggle'),
                  ),
                ],
              ),
            ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment:
                  mediaOnly ? AlignmentDirectional.bottomCenter : AlignmentDirectional.bottomStart,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(height: 2.5, color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

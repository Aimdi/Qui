import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:qui/article/entities/entity_value.dart';
import 'package:qui/substack/substack_html_parser.dart';
import 'package:qui/utils/urls.dart';

/// Renders a parsed Substack article body, styled to match the X long-form
/// article view in `lib/article/article.dart`.
class SubstackHtmlView extends StatelessWidget {
  final List<SubstackBlock> blocks;

  const SubstackHtmlView({super.key, required this.blocks});

  TextStyle? _headingStyle(ThemeData theme, int level) {
    switch (level) {
      case 1:
        return theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold);
      case 2:
        return theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);
      case 3:
        return theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
      default:
        return theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);
    }
  }

  TextSpan _inlineSpan(BuildContext context, SubstackInline inline) {
    final theme = Theme.of(context);
    final linkUrl = inline.linkUrl;

    var style = TextStyle(
      fontWeight: inline.bold ? FontWeight.bold : null,
      fontStyle: inline.italic ? FontStyle.italic : null,
      fontFamily: inline.code ? 'monospace' : null,
      backgroundColor: inline.code ? theme.colorScheme.surfaceContainer : null,
      decoration: TextDecoration.combine([
        if (inline.strikethrough) TextDecoration.lineThrough,
        if (linkUrl != null) TextDecoration.underline,
      ]),
    );

    if (linkUrl != null) {
      style = style.copyWith(
        color: theme.colorScheme.primary,
        decorationColor: theme.colorScheme.primary,
      );
    }

    return TextSpan(
      text: inline.text,
      style: style,
      recognizer: linkUrl == null ? null : (TapGestureRecognizer()..onTap = () => openUri(linkUrl)),
    );
  }

  TextSpan _spans(BuildContext context, List<SubstackInline> spans) {
    return TextSpan(children: spans.map((e) => _inlineSpan(context, e)).toList());
  }

  Widget _listItem(BuildContext context, Widget prefix, List<SubstackInline> spans) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 0, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          prefix,
          Expanded(child: SelectableText.rich(_spans(context, spans))),
        ],
      ),
    );
  }

  Widget _buildBlock(BuildContext context, SubstackBlock block) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (block) {
      case SubstackParagraph():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SelectableText.rich(_spans(context, block.spans)),
        );

      case SubstackHeading():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SelectableText.rich(
            TextSpan(children: [_spans(context, block.spans)], style: _headingStyle(theme, block.level)),
          ),
        );

      case SubstackListBlock():
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < block.items.length; i++)
              _listItem(context, Text(block.ordered ? '${i + 1}. ' : '• '), block.items[i]),
          ],
        );

      case SubstackQuote():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Color.alphaBlend(colorScheme.onSurface.withValues(alpha: 0.08), colorScheme.surfaceContainer),
                  width: 4,
                ),
              ),
              color: colorScheme.surfaceContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: block.children.map((e) => _buildBlock(context, e)).toList(),
            ),
          ),
        );

      case SubstackImage():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ImageEntity(imageUrl: block.src).toWidget(context),
              if (block.caption != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    block.caption!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        );

      case SubstackDivider():
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1),
        );

      case SubstackCode():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              block.text,
              style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((e) => _buildBlock(context, e)).toList(),
    );
  }
}

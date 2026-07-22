import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// A structured, renderer-independent representation of a Substack article
/// body. Substack serves sanitized HTML with a small, stable set of block
/// patterns; everything unknown degrades to plain paragraphs so a new embed
/// type never blanks an article.
sealed class SubstackBlock {
  const SubstackBlock();
}

class SubstackParagraph extends SubstackBlock {
  final List<SubstackInline> spans;

  const SubstackParagraph(this.spans);
}

class SubstackHeading extends SubstackBlock {
  final int level;
  final List<SubstackInline> spans;

  const SubstackHeading(this.level, this.spans);
}

class SubstackListBlock extends SubstackBlock {
  final bool ordered;
  final List<List<SubstackInline>> items;

  const SubstackListBlock({required this.ordered, required this.items});
}

class SubstackQuote extends SubstackBlock {
  final List<SubstackBlock> children;

  const SubstackQuote(this.children);
}

class SubstackImage extends SubstackBlock {
  final String src;
  final String? caption;

  const SubstackImage(this.src, {this.caption});
}

class SubstackDivider extends SubstackBlock {
  const SubstackDivider();
}

class SubstackCode extends SubstackBlock {
  final String text;

  const SubstackCode(this.text);
}

/// A run of text with uniform styling.
class SubstackInline {
  final String text;
  final bool bold;
  final bool italic;
  final bool code;
  final bool strikethrough;
  final String? linkUrl;

  const SubstackInline(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.strikethrough = false,
    this.linkUrl,
  });
}

// Containers whose content is interactive chrome, not article text.
const _skippedElements = {'script', 'style', 'form', 'input', 'button', 'svg', 'audio', 'video', 'source', 'iframe'};
const _skippedClasses = ['subscription-widget', 'poll-embed', 'install-substack-app', 'digest-post-embed'];

List<SubstackBlock> parseSubstackHtml(String html) {
  final fragment = html_parser.parseFragment(html);
  final blocks = <SubstackBlock>[];

  for (final node in fragment.nodes) {
    _walkBlock(node, blocks);
  }

  return blocks;
}

bool _isSkipped(dom.Element element) {
  if (_skippedElements.contains(element.localName)) {
    return true;
  }

  final classes = element.attributes['class'] ?? '';
  return _skippedClasses.any(classes.contains);
}

void _walkBlock(dom.Node node, List<SubstackBlock> out) {
  if (node is dom.Text) {
    if (node.text.trim().isNotEmpty) {
      out.add(SubstackParagraph([SubstackInline(node.text.trim())]));
    }
    return;
  }

  if (node is! dom.Element || _isSkipped(node)) {
    return;
  }

  switch (node.localName) {
    case 'p':
    case 'a':
      _emitParagraph(node, out);
      break;

    case 'h1':
    case 'h2':
    case 'h3':
    case 'h4':
    case 'h5':
    case 'h6':
      final level = int.parse(node.localName!.substring(1));
      final (spans, images) = _collectInline(node);
      if (spans.isNotEmpty) {
        out.add(SubstackHeading(level, spans));
      }
      out.addAll(images);
      break;

    case 'ul':
    case 'ol':
      final items = <List<SubstackInline>>[];
      for (final li in node.children.where((e) => e.localName == 'li')) {
        // Nested lists inside an item are flattened onto the same item; deep
        // nesting is rare enough on Substack that this reads fine.
        final (spans, images) = _collectInline(li);
        if (spans.isNotEmpty) {
          items.add(spans);
        }
        out.addAll(images);
      }
      if (items.isNotEmpty) {
        out.add(SubstackListBlock(ordered: node.localName == 'ol', items: items));
      }
      break;

    case 'blockquote':
      final children = <SubstackBlock>[];
      for (final child in node.nodes) {
        _walkBlock(child, children);
      }
      if (children.isNotEmpty) {
        out.add(SubstackQuote(children));
      }
      break;

    case 'hr':
      out.add(const SubstackDivider());
      break;

    case 'pre':
      final text = node.text;
      if (text.trim().isNotEmpty) {
        out.add(SubstackCode(text));
      }
      break;

    case 'img':
      final image = _parseImage(node);
      if (image != null) {
        out.add(image);
      }
      break;

    case 'figure':
      _emitFigure(node, out);
      break;

    default:
      // div, section, span at block level, captioned-image-container, and any
      // future wrapper: recurse and let the children sort themselves out.
      for (final child in node.nodes) {
        _walkBlock(child, out);
      }
  }
}

void _emitParagraph(dom.Element element, List<SubstackBlock> out) {
  final (spans, images) = _collectInline(element);
  if (spans.isNotEmpty) {
    out.add(SubstackParagraph(spans));
  }
  out.addAll(images);
}

void _emitFigure(dom.Element figure, List<SubstackBlock> out) {
  final img = figure.querySelector('img');
  final caption = figure.querySelector('figcaption')?.text.trim();

  if (img != null) {
    final image = _parseImage(img, caption: caption == null || caption.isEmpty ? null : caption);
    if (image != null) {
      out.add(image);
      return;
    }
  }

  // A figure without a usable image (e.g. an embed): fall back to its text.
  for (final child in figure.nodes) {
    _walkBlock(child, out);
  }
}

SubstackImage? _parseImage(dom.Element img, {String? caption}) {
  final src = img.attributes['src'];
  if (src == null || !src.startsWith('http')) {
    return null;
  }

  return SubstackImage(src, caption: caption);
}

class _InlineStyle {
  final bool bold;
  final bool italic;
  final bool code;
  final bool strikethrough;
  final String? linkUrl;

  const _InlineStyle({
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.strikethrough = false,
    this.linkUrl,
  });

  _InlineStyle apply(dom.Element element) {
    final tag = element.localName;
    return _InlineStyle(
      bold: bold || tag == 'strong' || tag == 'b',
      italic: italic || tag == 'em' || tag == 'i',
      code: code || tag == 'code',
      strikethrough: strikethrough || tag == 's' || tag == 'del' || tag == 'strike',
      linkUrl: tag == 'a' ? (element.attributes['href'] ?? linkUrl) : linkUrl,
    );
  }
}

/// Flattens an element's contents into styled runs. Images found inline are
/// returned separately so they can be emitted as their own blocks.
(List<SubstackInline>, List<SubstackImage>) _collectInline(dom.Element element) {
  final spans = <SubstackInline>[];
  final images = <SubstackImage>[];

  void walk(dom.Node node, _InlineStyle style) {
    if (node is dom.Text) {
      // Collapse the whitespace runs HTML treats as a single space.
      final text = node.text.replaceAll(RegExp(r'\s+'), ' ');
      if (text.isNotEmpty) {
        spans.add(SubstackInline(
          text,
          bold: style.bold,
          italic: style.italic,
          code: style.code,
          strikethrough: style.strikethrough,
          linkUrl: style.linkUrl,
        ));
      }
      return;
    }

    if (node is! dom.Element || _isSkipped(node)) {
      return;
    }

    if (node.localName == 'br') {
      spans.add(const SubstackInline('\n'));
      return;
    }

    if (node.localName == 'img') {
      final image = _parseImage(node);
      if (image != null) {
        images.add(image);
      }
      return;
    }

    final childStyle = style.apply(node);
    for (final child in node.nodes) {
      walk(child, childStyle);
    }
  }

  for (final child in element.nodes) {
    walk(child, element.localName == 'a' ? const _InlineStyle().apply(element) : const _InlineStyle());
  }

  // Trim the leading/trailing space of the paragraph as a whole.
  while (spans.isNotEmpty && spans.first.text.trim().isEmpty) {
    spans.removeAt(0);
  }
  while (spans.isNotEmpty && spans.last.text.trim().isEmpty) {
    spans.removeLast();
  }

  return (spans, images);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:qui/substack/substack_html_parser.dart';

void main() {
  test('parses paragraphs with inline styling and links', () {
    final blocks = parseSubstackHtml(
        '<p>Hello <strong>bold</strong> and <em>italic</em> and <a href="https://example.com">a link</a>.</p>');

    expect(blocks, hasLength(1));
    final paragraph = blocks.first as SubstackParagraph;
    expect(paragraph.spans.map((e) => e.text).join(), 'Hello bold and italic and a link.');
    expect(paragraph.spans.singleWhere((e) => e.text == 'bold').bold, true);
    expect(paragraph.spans.singleWhere((e) => e.text == 'italic').italic, true);
    expect(paragraph.spans.singleWhere((e) => e.text == 'a link').linkUrl, 'https://example.com');
  });

  test('parses headings with their level', () {
    final blocks = parseSubstackHtml('<h2>Section</h2><p>Body</p>');

    expect(blocks, hasLength(2));
    final heading = blocks.first as SubstackHeading;
    expect(heading.level, 2);
    expect(heading.spans.single.text, 'Section');
  });

  test('parses Substack captioned image containers', () {
    final blocks = parseSubstackHtml('<div class="captioned-image-container"><figure>'
        '<a href="https://substackcdn.com/image/full.jpg"><img src="https://substackcdn.com/image/img.jpg"></a>'
        '<figcaption>The caption</figcaption></figure></div>');

    expect(blocks, hasLength(1));
    final image = blocks.first as SubstackImage;
    expect(image.src, 'https://substackcdn.com/image/img.jpg');
    expect(image.caption, 'The caption');
  });

  test('parses ordered and unordered lists', () {
    final blocks = parseSubstackHtml('<ul><li>One</li><li>Two</li></ul><ol><li>First</li></ol>');

    expect(blocks, hasLength(2));
    final unordered = blocks[0] as SubstackListBlock;
    expect(unordered.ordered, false);
    expect(unordered.items.map((e) => e.map((s) => s.text).join()), ['One', 'Two']);
    expect((blocks[1] as SubstackListBlock).ordered, true);
  });

  test('parses blockquotes containing paragraphs', () {
    final blocks = parseSubstackHtml('<blockquote><p>Quoted text</p></blockquote>');

    final quote = blocks.single as SubstackQuote;
    final inner = quote.children.single as SubstackParagraph;
    expect(inner.spans.single.text, 'Quoted text');
  });

  test('parses dividers and preformatted code', () {
    final blocks = parseSubstackHtml('<hr><pre>final x = 1;</pre>');

    expect(blocks[0], isA<SubstackDivider>());
    expect((blocks[1] as SubstackCode).text, 'final x = 1;');
  });

  test('skips subscription widgets and scripts', () {
    final blocks = parseSubstackHtml('<div class="subscription-widget-wrap"><p>Subscribe now!</p></div>'
        '<script>alert(1)</script><p>Real content</p>');

    final paragraph = blocks.single as SubstackParagraph;
    expect(paragraph.spans.single.text, 'Real content');
  });

  test('collapses whitespace like HTML rendering does', () {
    final blocks = parseSubstackHtml('<p>Multiple\n   spaces\n\tcollapse</p>');

    final paragraph = blocks.single as SubstackParagraph;
    expect(paragraph.spans.map((e) => e.text).join(), 'Multiple spaces collapse');
  });

  test('turns <br> into a newline', () {
    final blocks = parseSubstackHtml('<p>Line one<br>Line two</p>');

    final paragraph = blocks.single as SubstackParagraph;
    expect(paragraph.spans.map((e) => e.text).join(), contains('\n'));
  });

  test('degrades unknown wrappers to their content', () {
    final blocks = parseSubstackHtml('<div class="future-embed"><div><p>Inner text</p></div></div>');

    final paragraph = blocks.single as SubstackParagraph;
    expect(paragraph.spans.single.text, 'Inner text');
  });

  test('ignores images without an absolute URL', () {
    final blocks = parseSubstackHtml('<p><img src="data:image/png;base64,xyz">Text</p>');

    final paragraph = blocks.single as SubstackParagraph;
    expect(paragraph.spans.single.text, 'Text');
  });
}

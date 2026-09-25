import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:qui/saved/saved_post_content.dart';

void main() {
  test('damaged and non-object bookmarks are isolated', () {
    for (final input in [null, '{broken', '[]', 'null', '42']) {
      expect(decodeSavedPost(input), isNull);
      expect(savedPostMatches(input, 'science'), isFalse);
    }
  });
  test('saved search matches separate terms across names, links and quotes', () {
    final content = jsonEncode({
      'id_str': '1',
      'full_text': 'Read this article',
      'user': {'id_str': '2', 'name': 'Maya', 'screen_name': 'mayac'},
      'entities': {
        'urls': [
          {'url': 'https://t.co/a', 'expanded_url': 'https://example.org/science'},
        ],
      },
      'quotedStatusWithCard': {'id_str': '3', 'full_text': 'Climate research'},
    });
    expect(savedPostMatches(content, 'MAYA science'), isTrue);
    expect(savedPostMatches(content, 'climate research'), isTrue);
    expect(savedPostMatches(content, '  '), isTrue);
    expect(savedPostMatches(content, 'absent'), isFalse);
  });
}

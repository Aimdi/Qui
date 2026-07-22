import 'package:flutter_test/flutter_test.dart';
import 'package:qui/substack/substack_client.dart';

void main() {
  group('normalizeSubstackHost', () {
    test('expands a bare name to a substack.com subdomain', () {
      expect(normalizeSubstackHost('example'), 'example.substack.com');
    });

    test('accepts a bare host', () {
      expect(normalizeSubstackHost('example.substack.com'), 'example.substack.com');
    });

    test('accepts a full URL and strips the path', () {
      expect(normalizeSubstackHost('https://example.substack.com/p/some-post?utm_source=x'), 'example.substack.com');
    });

    test('accepts a custom domain', () {
      expect(normalizeSubstackHost('https://www.astralcodexten.com'), 'www.astralcodexten.com');
    });

    test('lowercases and trims the input', () {
      expect(normalizeSubstackHost('  Example.Substack.Com  '), 'example.substack.com');
    });

    test('rejects empty input and inner whitespace', () {
      expect(normalizeSubstackHost(''), null);
      expect(normalizeSubstackHost('   '), null);
      expect(normalizeSubstackHost('not a domain'), null);
    });
  });

  group('SubstackPost.fromJson', () {
    test('parses an archive item', () {
      final post = SubstackPost.fromJson('example.substack.com', {
        'id': 123456,
        'title': 'A post title',
        'subtitle': 'A subtitle',
        'slug': 'a-post-title',
        'post_date': '2026-07-01T12:00:00.000Z',
        'canonical_url': 'https://example.substack.com/p/a-post-title',
        'cover_image': 'https://substackcdn.com/image/123.png',
        'audience': 'everyone',
        'type': 'newsletter',
        'description': 'A description',
      });

      expect(post, isNotNull);
      expect(post!.id, '123456');
      expect(post.title, 'A post title');
      expect(post.subtitle, 'A subtitle');
      expect(post.slug, 'a-post-title');
      expect(post.postDate, DateTime.utc(2026, 7, 1, 12).toLocal());
      expect(post.url, 'https://example.substack.com/p/a-post-title');
      expect(post.isPaid, false);
    });

    test('flags paid posts and falls back to a constructed URL', () {
      final post = SubstackPost.fromJson('example.substack.com', {
        'id': 1,
        'title': 'Paid post',
        'slug': 'paid-post',
        'audience': 'only_paid',
      });

      expect(post!.isPaid, true);
      expect(post.url, 'https://example.substack.com/p/paid-post');
    });

    test('tolerates missing and malformed optional fields', () {
      final post = SubstackPost.fromJson('example.substack.com', {
        'id': null,
        'title': 'Title',
        'slug': 'slug',
        'subtitle': '',
        'post_date': 'not-a-date',
        'cover_image': 42,
      });

      expect(post, isNotNull);
      expect(post!.subtitle, null);
      expect(post.postDate, null);
      expect(post.coverImage, null);
    });

    test('rejects items without a slug or title', () {
      expect(SubstackPost.fromJson('example.substack.com', {'title': 'No slug'}), null);
      expect(SubstackPost.fromJson('example.substack.com', {'slug': 'no-title'}), null);
      expect(SubstackPost.fromJson('example.substack.com', 'not-a-map'), null);
    });
  });

  group('SubstackPublication', () {
    test('round-trips through its database map', () {
      final publication = SubstackPublication(
        host: 'example.substack.com',
        name: 'Example',
        logoUrl: 'https://substackcdn.com/logo.png',
      );

      final restored = SubstackPublication.fromMap(publication.toMap());
      expect(restored.host, publication.host);
      expect(restored.name, publication.name);
      expect(restored.logoUrl, publication.logoUrl);
    });
  });
}

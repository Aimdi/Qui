import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('SubstackClient');

class SubstackException implements Exception {
  final String message;

  SubstackException(this.message);

  @override
  String toString() => 'SubstackException: $message';
}

/// A Substack publication the user follows, identified by its host (either
/// `name.substack.com` or a custom domain serving the same public API).
class SubstackPublication {
  final String host;
  final String name;
  final String? logoUrl;

  SubstackPublication({required this.host, required this.name, this.logoUrl});

  String get url => 'https://$host';

  Map<String, Object?> toMap() => {'host': host, 'name': name, 'logo_url': logoUrl};

  factory SubstackPublication.fromMap(Map<String, Object?> map) => SubstackPublication(
        host: map['host'] as String,
        name: map['name'] as String? ?? map['host'] as String,
        logoUrl: map['logo_url'] as String?,
      );
}

class SubstackPost {
  final String id;
  final String host;
  final String title;
  final String? subtitle;
  final String slug;
  final DateTime? postDate;
  final String? canonicalUrl;
  final String? coverImage;
  final String audience;
  final String type;
  final String? description;
  final String? bodyHtml;

  SubstackPost({
    required this.id,
    required this.host,
    required this.title,
    required this.slug,
    this.subtitle,
    this.postDate,
    this.canonicalUrl,
    this.coverImage,
    this.audience = 'everyone',
    this.type = 'newsletter',
    this.description,
    this.bodyHtml,
  });

  bool get isPaid => audience == 'only_paid';

  String get url => canonicalUrl ?? 'https://$host/p/$slug';

  /// Parses one post object from the public API, returning null when the
  /// fields we cannot render without are missing.
  static SubstackPost? fromJson(String host, dynamic json) {
    if (json is! Map) {
      return null;
    }

    var slug = json['slug'];
    var title = json['title'];
    if (slug is! String || slug.isEmpty || title is! String) {
      return null;
    }

    DateTime? postDate;
    var rawDate = json['post_date'];
    if (rawDate is String) {
      postDate = DateTime.tryParse(rawDate)?.toLocal();
    }

    return SubstackPost(
      id: '${json['id'] ?? slug}',
      host: host,
      title: title,
      subtitle: json['subtitle'] is String && (json['subtitle'] as String).isNotEmpty ? json['subtitle'] as String : null,
      slug: slug,
      postDate: postDate,
      canonicalUrl: json['canonical_url'] is String ? json['canonical_url'] as String : null,
      coverImage: json['cover_image'] is String ? json['cover_image'] as String : null,
      audience: json['audience'] is String ? json['audience'] as String : 'everyone',
      type: json['type'] is String ? json['type'] as String : 'newsletter',
      description: json['description'] is String ? json['description'] as String : null,
      bodyHtml: json['body_html'] is String ? json['body_html'] as String : null,
    );
  }
}

/// Turns whatever the user pasted (a subdomain, a full URL, a custom domain)
/// into the host the public API lives on. Returns null for unusable input.
String? normalizeSubstackHost(String input) {
  var value = input.trim().toLowerCase();
  if (value.isEmpty || value.contains(RegExp(r'\s'))) {
    return null;
  }

  if (!value.contains('://')) {
    value = 'https://$value';
  }

  var host = Uri.tryParse(value)?.host ?? '';
  if (host.isEmpty) {
    return null;
  }

  // A bare word like "example" means the example.substack.com subdomain.
  if (!host.contains('.')) {
    host = '$host.substack.com';
  }

  return host;
}

const _headers = {'accept': 'application/json'};

/// Fetches a page of a publication's archive, newest first.
Future<List<SubstackPost>> fetchSubstackArchive(String host, {int offset = 0, int limit = 12}) async {
  final uri = Uri.https(host, '/api/v1/archive', {'sort': 'new', 'offset': '$offset', 'limit': '$limit'});

  final response = await http.get(uri, headers: _headers);
  if (response.statusCode != 200) {
    throw SubstackException('Unable to load the archive for $host (HTTP ${response.statusCode})');
  }

  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
  if (decoded is! List) {
    throw SubstackException('Unexpected archive response from $host');
  }

  return decoded.map((e) => SubstackPost.fromJson(host, e)).whereType<SubstackPost>().toList();
}

/// Fetches a single post, including its body HTML (truncated to a preview by
/// Substack when the post is for paid subscribers only).
Future<SubstackPost> fetchSubstackPost(String host, String slug) async {
  final uri = Uri.https(host, '/api/v1/posts/$slug');

  final response = await http.get(uri, headers: _headers);
  if (response.statusCode != 200) {
    throw SubstackException('Unable to load the post $slug from $host (HTTP ${response.statusCode})');
  }

  final post = SubstackPost.fromJson(host, jsonDecode(utf8.decode(response.bodyBytes)));
  if (post == null) {
    throw SubstackException('Unexpected post response from $host');
  }

  return post;
}

/// Validates that [input] points at a Substack publication and resolves its
/// display name and logo. The archive probe is what actually gates adding a
/// subscription; the homepage scrape for name/logo is best-effort.
Future<SubstackPublication> resolveSubstackPublication(String input) async {
  final host = normalizeSubstackHost(input);
  if (host == null) {
    throw SubstackException('Not a valid publication address: $input');
  }

  await fetchSubstackArchive(host, limit: 1);

  var name = host;
  String? logoUrl;
  try {
    final response = await http.get(Uri.https(host, '/'));
    if (response.statusCode == 200) {
      final document = html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));

      String? meta(String property) =>
          document.querySelector('meta[property="$property"]')?.attributes['content']?.trim();

      final title = document.querySelector('title')?.text.trim();
      name = meta('og:site_name') ?? meta('og:title') ?? (title == null || title.isEmpty ? host : title);

      logoUrl = document.querySelector('link[rel="apple-touch-icon"]')?.attributes['href'] ?? meta('og:image');
    }
  } catch (e) {
    _log.warning('Unable to resolve publication details for $host', e);
  }

  return SubstackPublication(host: host, name: name, logoUrl: logoUrl);
}

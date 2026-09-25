import 'dart:convert';
import 'package:qui/client/client.dart';
import 'package:qui/search/loaded_feed_search.dart';

/// A damaged bookmark must not hide the rest of the archive.
TweetWithCard? decodeSavedPost(String? content) {
  if (content == null) return null;
  try {
    final json = jsonDecode(content);
    if (json is! Map<String, dynamic>) return null;
    return TweetWithCard.fromJson(json);
  } catch (_) {
    return null;
  }
}

bool savedPostMatches(String? content, String query) {
  if (query.trim().isEmpty) return true;
  final tweet = decodeSavedPost(content);
  if (tweet == null) return false;
  final text = loadedTweetText(tweet).toLowerCase();
  return query.toLowerCase().trim().split(RegExp(r'\s+')).every(text.contains);
}

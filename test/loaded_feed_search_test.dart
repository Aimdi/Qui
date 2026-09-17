import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qui/client/client.dart';
import 'package:qui/search/loaded_feed_search.dart';

void main() {
  test('loaded text includes names, handles, expanded URLs and quoted posts', () {
    final tweet = TweetWithCard()
      ..fullText = 'Reading a long article'
      ..noteText = 'Extended observations'
      ..user = (User()
        ..name = 'Maya'
        ..screenName = 'mayac')
      ..entities = Entities.fromJson({
        'urls': [
          {
            'expanded_url': 'https://example.org/climate',
            'display_url': 'example.org/climate',
            'url': 'https://t.co/abc',
          },
        ],
      })
      ..quotedStatusWithCard = (TweetWithCard()..fullText = 'Quoted science');
    final entries = loadedFeedEntries([
      TweetChain(id: '1', isPinned: false, tweets: [tweet]),
    ], null);
    expect(entries.single.matches('MAYA climate'), isTrue);
    expect(entries.single.matches('extended observations'), isTrue);
    expect(entries.single.matches('quoted SCIENCE'), isTrue);
    expect(entries.single.matches('not-present'), isFalse);
  });
}

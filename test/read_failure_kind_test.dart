import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:qui/catcher/exceptions.dart';
import 'package:qui/client/errors.dart';
import 'package:qui/ui/read_failure_kind.dart';

void main() {
  group('readFailureKind', () {
    test('classifies transient connectivity failures', () {
      expect(
        readFailureKind(const TimeoutException('slow')),
        ReadFailureKind.timedOut,
      );
      expect(
        readFailureKind(http.ClientException('offline')),
        ReadFailureKind.connection,
      );
    });

    test('classifies account and rate-limit failures', () {
      expect(
        readFailureKind(NoAccountAvailableException()),
        ReadFailureKind.session,
      );
      expect(
        readFailureKind(NoWorkingAccountException()),
        ReadFailureKind.session,
      );
      expect(
        readFailureKind(RateLimitedException()),
        ReadFailureKind.rateLimited,
      );
      expect(
        readFailureKind(
          TwitterError(uri: 'https://x.com', code: 89, message: 'expired'),
        ),
        ReadFailureKind.session,
      );
    });

    test('distinguishes endpoint and transaction failures', () {
      expect(
        readFailureKind(EndpointRefusedException('UserTweets')),
        ReadFailureKind.endpointRefused,
      );
      expect(
        readFailureKind(TransactionIdUnavailableException(Exception('shape'))),
        ReadFailureKind.transactionUnavailable,
      );
    });

    test('classifies HTTP failures without exposing response bodies', () {
      expect(
        readFailureKind(HttpException(http.Response('private body', 503))),
        ReadFailureKind.serviceUnavailable,
      );
      expect(
        readFailureKind(HttpException(http.Response('private body', 404))),
        ReadFailureKind.unavailable,
      );
      expect(
        readFailureKind(HttpException(http.Response('private body', 429))),
        ReadFailureKind.rateLimited,
      );
    });

    test('automatic recovery is limited to transient failures', () {
      final service = HttpException(http.Response('', 503));
      final unavailable = HttpException(http.Response('', 404));

      expect(recoverableReadFailure(const TimeoutException('slow')), isNotNull);
      expect(recoverableReadFailure(service), same(service));
      expect(recoverableReadFailure(unavailable), isNull);
      expect(recoverableReadFailure(RateLimitedException()), isNull);
    });
  });
}

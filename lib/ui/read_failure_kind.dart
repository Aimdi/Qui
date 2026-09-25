import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;
import 'package:qui/catcher/exceptions.dart';
import 'package:qui/client/errors.dart';

/// Shared taxonomy for reader failures.
///
/// Full-page errors and cached-feed notices should describe the same problem in
/// the same way. This stays UI-free so feed/cache code can depend on it.
enum ReadFailureKind {
  connection,
  timedOut,
  session,
  rateLimited,
  endpointRefused,
  transactionUnavailable,
  unavailable,
  serviceUnavailable,
  unknown,
}

ReadFailureKind readFailureKind(Object? error) {
  if (error is TimeoutException) {
    return ReadFailureKind.timedOut;
  }
  if (error is SocketException || error is http.ClientException) {
    return ReadFailureKind.connection;
  }
  if (error is RateLimitedException || (error is HttpException && error.statusCode == 429)) {
    return ReadFailureKind.rateLimited;
  }
  if (error is NoAccountAvailableException ||
      error is NoWorkingAccountException ||
      (error is HttpException && error.statusCode == 401) ||
      (error is TwitterError && const [32, 89, 215].contains(error.code))) {
    return ReadFailureKind.session;
  }
  if (error is EndpointRefusedException) {
    return ReadFailureKind.endpointRefused;
  }
  if (error is TransactionIdUnavailableException) {
    return ReadFailureKind.transactionUnavailable;
  }
  if (error is HttpException && const [500, 502, 503, 504].contains(error.statusCode)) {
    return ReadFailureKind.serviceUnavailable;
  }
  if (error is HttpException && const [403, 404].contains(error.statusCode)) {
    return ReadFailureKind.unavailable;
  }
  return ReadFailureKind.unknown;
}

/// Failures where a later automatic retry is reasonable and does not risk
/// hammering a rate-limited endpoint or a broken session.
Object? recoverableReadFailure(Object? error) {
  return switch (readFailureKind(error)) {
    ReadFailureKind.connection || ReadFailureKind.timedOut || ReadFailureKind.serviceUnavailable => error,
    _ => null,
  };
}

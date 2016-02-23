library bacchus_diary.retry_routin;

import 'dart:async';

import 'package:logging/logging.dart';

final _logger = new Logger('Retry');

class Retry<T> {
  final int limitRetry;
  final Duration durRetry;
  final String name;

  const Retry(this.name, this.limitRetry, this.durRetry);

  loop(Completer<T> result, Future<T> proc(), [bool isRetryable()]) {
    doit(int count) async {
      try {
        _logger.fine(() => "(${count}/${limitRetry}) ${name}");
        result.complete(await proc());
      } catch (ex) {
        if ((isRetryable == null || isRetryable()) && count < limitRetry) {
          new Future.delayed(durRetry, () => doit(count + 1));
        } else {
          result.completeError(ex);
        }
      }
    }
    new Future(() => doit(1));
    return result.future;
  }
}

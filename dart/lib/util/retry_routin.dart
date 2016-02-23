library bacchus_diary.retry_routin;

import 'dart:async';

import 'package:logging/logging.dart';

final _logger = new Logger('Retry');

class Retry<T> {
  final int limitRetry;
  final Duration durRetry;
  final String name;

  const Retry(this.name, this.limitRetry, this.durRetry);

  loop(Future<T> proc(int count), [bool isRetryable()]) {
    Future<T> doit(int count) async {
      try {
        _logger.fine(() => "(${count}/${limitRetry}) ${name}");
        return await proc(count);
      } catch (ex) {
        if ((isRetryable == null || isRetryable()) && count < limitRetry) {
          return new Future.delayed(durRetry, () => doit(count + 1));
        } else {
          throw ex;
        }
      }
    }
    return doit(1);
  }
}

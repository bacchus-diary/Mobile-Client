library bacchus_diary.retry_routin;

import 'dart:async';

import 'package:logging/logging.dart';

final _logger = new Logger('Retry');

class Retry<T> {
  final int limitRetry;
  final Duration durRetry;
  final String name;

  const Retry(this.name, this.limitRetry, this.durRetry);

  loop(Completer<T> result, Future<T> proc()) {
    doit(int count) async {
      try {
        _logger.fine(() => "(${count}/${limitRetry}) ${name}");
        result.complete(await proc());
      } catch (ex) {
        if (count < limitRetry) {
          new Future.delayed(durRetry, () => doit(count + 1));
        } else {
          result.completeError(ex);
        }
      }
    }
    doit(1);
  }
}

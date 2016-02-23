library bacchus_diary.service.aws.lambda;

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/settings.dart';
import 'package:bacchus_diary/util/retry_routin.dart';

final _logger = new Logger('ApiGateway');

typedef T _LoadResult<T>(Map map);

class ApiGateway<R> {
  final ApiInfo info;
  final _LoadResult<R> _loader;
  final Retry<R> retryer;

  ApiGateway(ApiInfo api, this._loader)
      : this.info = api,
        this.retryer = new Retry<R>(api.url, api.retryLimit, api.retryDur);

  Future<R> call(Map<String, String> dataMap) async {
    final url = info.url;
    final apiKey = info.key;
    final name = url.split('/').last;

    var req;
    return retryer.loop(new Completer<R>(), () {
      final result = new Completer<R>();
      req = new HttpRequest()
        ..open('POST', url)
        ..setRequestHeader('x-api-key', apiKey)
        ..setRequestHeader('Content-Type', 'application/json')
        ..send(JSON.encode(dataMap));

      req.onLoadEnd.listen((event) {
        final text = req.responseText;
        _logger.fine(() => "Response of ${name}(${url}): (Status:${req.status}) ${text}");
        if (req.status == 200) {
          try {
            final map = JSON.decode(text);
            final r = _loader(map);
            result.complete(r);
          } catch (ex) {
            result.completeError(ex);
          }
        } else
          result.completeError(req.responseText);
      });
      req.onError.listen((event) {
        result.completeError(req.responseText);
      });
      req.onTimeout.listen((event) {
        result.completeError(event);
      });
      return result.future;
    }, () => (req.status / 100).floor() == 5);
  }
}

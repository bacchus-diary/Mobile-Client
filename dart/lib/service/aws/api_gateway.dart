library triton_note.service.aws.api_gateway;

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/util/retry_routin.dart';
import 'package:bacchus_diary/settings.dart';

final _logger = new Logger('ApiGateway');

typedef T _LoadResult<T>(String responseText);

class ApiGateway<R> {
  static const RETRYER = const Retry<String>("ApiGateway", 3, const Duration(seconds: 3));

  final ApiInfo info;
  final _LoadResult<R> _loader;

  ApiGateway(this.info, this._loader);

  Future<R> call(Map<String, String> dataMap) async {
    final url = info.url;
    final apiKey = info.key;
    final params = JSON.encode(dataMap);

    final text = await RETRYER.loop((count) {
      final result = new Completer<String>();

      _logger.finest(() => "Posting to ${url}");
      final req = new HttpRequest()
        ..open('POST', url)
        ..setRequestHeader('x-api-key', apiKey)
        ..setRequestHeader('Content-Type', 'application/json')
        ..send(params);

      req.onLoadEnd.listen((event) {
        final text = JSON.decode(req.responseText);
        _logger.fine(() => "Response of ${url}: (Status:${req.status}) ${text}");
        result.complete(req.responseText);
      });
      req.onError.listen((event) {
        result.complete(req.responseText);
      });
      req.onTimeout.listen((event) {
        result.completeError("Timeout");
      });

      return result.future;
    });
    return _loader(text);
  }
}

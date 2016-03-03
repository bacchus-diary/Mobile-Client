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
  final ApiInfo info;
  final _LoadResult<R> _loader;
  final Retry<R> _RETRYER;

  ApiGateway(ApiInfo info, this._loader)
      : this.info = info,
        this._RETRYER = new Retry('ApiGateway', info.retryLimit, info.retryDur);

  Future<R> call(Map<String, dynamic> dataMap) async {
    final url = info.url;
    final apiKey = info.key;
    final params = JSON.encode(dataMap);

    return _RETRYER.loop((count) async {
      _logger.finest(() => "Posting to ${url}: ${params}");
      final req = await HttpRequest.request(url,
          method: 'POST', requestHeaders: {'X-Api-Key': apiKey, 'Content-Type': 'application/json'}, sendData: params);

      _logger.fine(() => "Response of ${url}: (Status:${req.status})");
      try {
        return _loader(req.responseText);
      } catch (ex) {
        _logger.warning(() => "Failed to process response: ${req.responseText}");
        throw ex;
      }
    });
  }
}

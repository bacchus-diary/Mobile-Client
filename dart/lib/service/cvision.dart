library bacchus_diary.service.cvision;

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/settings.dart';
import 'package:bacchus_diary/util/file_reader.dart';

final Logger _logger = new Logger('CVision');

class CVision {
  static const urlGCV = "https://vision.googleapis.com/v1/images:annotate";

  static Future<Map> request(String base64data, Map<String, int> featuresMap) async {
    final result = new Completer<Map>();

    final settings = await Settings;
    final url = "${urlGCV}?key=${settings.googleKey}";

    try {
      final features = [];
      featuresMap.forEach((name, max) => features.add({'type': name, 'maxResults': max}));

      final dataMap = {
        'requests': [
          {
            'image': {'content': base64data},
            'features': features
          }
        ]
      };

      _logger.info(() => "Requesting: ${featuresMap}");
      final req = new HttpRequest()
        ..open('POST', url)
        ..setRequestHeader('Content-Type', 'application/json')
        ..send(JSON.encode(dataMap));

      req.onLoadEnd.listen((event) {
        final text = req.responseText;
        _logger.fine(() => "Response: (Status:${req.status}) ${text}");
        if (req.status == 200) {
          try {
            final map = JSON.decode(text);
            final resList = map['responses'] as List;
            if (resList.isNotEmpty) {
              result.complete(resList.first);
            } else {
              result.completeError("Result is empty");
            }
          } catch (ex) {
            _logger.warning(() => "Could not parse as json: ${text}");
            result.completeError(ex);
          }
        } else {
          _logger.warning(() => "Response status ${req.status}: ${text}");
          result.completeError(text);
        }
      });
      req.onError.listen((event) {
        _logger.warning(() => "Response status ${req.status}: ${event}");
        result.completeError(event);
      });
      req.onTimeout.listen((event) {
        _logger.warning(() => "Timeout to request: ${event}");
        result.completeError(event);
      });
    } catch (ex) {
      _logger.warning(() => "Failed to request: ${ex}");
      result.completeError(ex);
    }

    return result.future;
  }

  static const FEATURES = const {
    'FACE_DETECTION': 10,
    'LANDMARK_DETECTION': 10,
    'LOGO_DETECTION': 10,
    'LABEL_DETECTION': 10,
    'TEXT_DETECTION': 10,
    'SAFE_SEARCH_DETECTION': 10,
    'IMAGE_PROPERTIES': 10
  };

  final String srcData;
  Map<String, int> featuresMap;
  Future<Map> resutsMap;

  CVision(this.srcData, {List<String> list, Map<String, int> map}) {
    if (map != null) {
      featuresMap = map;
    } else if (list != null) {
      map = {};
      list.forEach((name) => map[name] = FEATURES[name]);
      featuresMap = map;
    } else {
      featuresMap = FEATURES;
    }
    resutsMap = request(srcData, featuresMap);
  }

  _singleRequest(String featureName, String annotationName, proc(List<Map> list)) async {
    final map = await resutsMap;
    final list = map[annotationName] as List;
    if (list != null && list.isNotEmpty) {
      return proc(list);
    } else {
      _logger.warning(() => "No result for ${featureName}(${annotationName})");
      return null;
    }
  }

  Future<String> readText() async =>
      _singleRequest('TEXT_DETECTION', 'textAnnotations', (list) => list.first['description']);

  Future<String> findLogo() async =>
      _singleRequest('LOGO_DETECTION', 'logoAnnotations', (list) => list.first['description']);
}

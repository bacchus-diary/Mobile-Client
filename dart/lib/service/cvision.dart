library bacchus_diary.service.cvision;

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/settings.dart';
import 'package:bacchus_diary/util/retry_routin.dart';

final Logger _logger = new Logger('CVision');

class CVision {
  static const urlGCV = "https://vision.googleapis.com/v1/images:annotate";
  static const RETRYER = const Retry<String>("CVision Requesting", 3, const Duration(seconds: 3));

  static Future<Map> request(String base64data, Map<String, int> featuresMap) async {
    final settings = await Settings;
    final url = "${urlGCV}?key=${settings.googleKey}";

    final features = [];
    featuresMap.forEach((name, max) => features.add({'type': name, 'maxResults': max}));

    final requestData = JSON.encode({
      'requests': [
        {
          'image': {'content': base64data},
          'features': features
        }
      ]
    });

    final text = await RETRYER.loop((count) {
      final result = new Completer<String>();
      final req = new HttpRequest()
        ..open('POST', url)
        ..setRequestHeader('Content-Type', 'application/json')
        ..send(requestData);

      req.onLoadEnd.listen((event) {
        final text = req.responseText;
        _logger.fine(() => "Response: (Status:${req.status}) ${text}");
        if (req.status == 200) {
          result.complete(text);
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
      return result.future;
    });

    final map = JSON.decode(text);
    final resList = map['responses'] as List;
    if (resList.isNotEmpty) {
      return resList.first;
    } else {
      throw "Result is empty";
    }
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

  Future<SafeSearch> safeLevel() async {
    final result = (await resutsMap)['safeSearchAnnotation'];
    return new SafeSearch(result);
  }
}

class SafeSearch {
  static const LIKELIHOOD = const {
    'UNKNOWN': 0,
    'VERY_UNLIKELY': 1,
    'UNLIKELY': 2,
    'POSSIBLE': 3,
    'LIKELY': 4,
    'VERY_LIKELY': 5
  };

  final Map<String, String> _map;

  SafeSearch(this._map);

  int get adult => LIKELIHOOD[_map['adult']];
  int get spoof => LIKELIHOOD[_map['spoof']];
  int get medical => LIKELIHOOD[_map['medical']];
  int get violence => LIKELIHOOD[_map['violence']];

  bool isAllUnder(int level) => adult < level && spoof < level && medical < level && violence < level;
}

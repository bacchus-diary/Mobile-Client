library bacchus_diary.service.aws.paa;

import 'dart:async';
import 'dart:js';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/util/retry_routin.dart';

final _logger = new Logger('ProductAdvertisingAPI');

class PAA {
  static const RETRYER = const Retry<Map>("ProductAdvertisingAPI", 3, const Duration(seconds: 3));
}

class Country {
  static Future<String> get code {
    final result = new Completer();
    final plugin = context['plugins']['country'];
    if (plugin != null) {
      plugin.callMethod('get', [
        (code) {
          result.complete(code);
        },
        (error) {
          result.completeError(error);
        }
      ]);
    } else {
      result.completeError("No country plugin");
    }
    return result.future;
  }

  static Future<String> get locale {
    final result = new Completer();
    final plugin = context['navigator']['globalization'];
    if (plugin != null) {
      plugin.callMethod('getLocaleName', [
        (code) {
          result.complete(code);
        },
        (error) {
          result.completeError(error);
        }
      ]);
    } else {
      result.completeError("No globalization plugin");
    }
    return result.future;
  }
}

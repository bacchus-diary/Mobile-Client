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
  static const ENDPOINT = const {
    "BR": "https://webservices.amazon.br/onca/soap",
    "CA": "https://webservices.amazon.ca/onca/soap",
    "CN": "https://webservices.amazon.cn/onca/soap",
    "DE": "https://webservices.amazon.de/onca/soap",
    "ES": "https://webservices.amazon.es/onca/soap",
    "FR": "https://webservices.amazon.fr/onca/soap",
    "IN": "https://webservices.amazon.in/onca/soap",
    "IT": "https://webservices.amazon.it/onca/soap",
    "JP": "https://webservices.amazon.co.jp/onca/soap",
    "MX": "https://webservices.amazon.com.mx/onca/soap",
    "UK": "https://webservices.amazon.co.uk/onca/soap",
    "US": "https://webservices.amazon.com/onca/soap"
  };

  static String _endpoint;
  static Future<String> get endpoint async {
    if (_endpoint == null) {
      try {
        final code = await getCode();
        _endpoint = ENDPOINT[code];
        _logger.info(() => "Getting endpoint of ${code}: ${_endpoint}");

        if (_endpoint == null) {
          _endpoint = ENDPOINT['US'];
          _logger.warning(() => "No match endpoint found. use 'US': ${_endpoint}");
        }
      } catch (ex) {
        _logger.warning(() => "Failed to get locale: ${ex}");
      }
    }
    return _endpoint;
  }

  static Future<String> getCode() async {
    try {
      return await _code;
    } catch (ex) {
      final locale = await _locale;
      final regex = new RegExp(r"[A-Z]{2}");
      final parts = locale.split('-').where((x) => x.length == 2 && regex.stringMatch(x) != null);
      if (parts.isEmpty) return null;
      return parts.first;
    }
  }

  static Future<String> get _code {
    final result = new Completer();
    final plugin = context['plugins']['country'];
    if (plugin != null) {
      plugin.callMethod('get', [
        (code) {
          _logger.finest(() => "Get country code: ${code}");
          result.complete(code);
        },
        (error) {
          _logger.warning(() => "Failed to get country code: ${error}");
          result.completeError(error);
        }
      ]);
    } else {
      result.completeError("No country plugin");
    }
    return result.future;
  }

  static Future<String> get _locale {
    final result = new Completer();
    final plugin = context['navigator']['globalization'];
    if (plugin != null) {
      plugin.callMethod('getLocaleName', [
        (code) {
          _logger.finest(() => "Get locale: ${code}");
          result.complete(code);
        },
        (error) {
          _logger.warning(() => "Failed to get locale: ${error}");
          result.completeError(error);
        }
      ]);
    } else {
      result.completeError("No globalization plugin");
    }
    return result.future;
  }
}

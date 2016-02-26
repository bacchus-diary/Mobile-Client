library bacchus_diary.service.aws.paa;

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:html';
import 'dart:js';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

import 'package:bacchus_diary/util/pager.dart';
import 'package:bacchus_diary/util/retry_routin.dart';
import 'package:bacchus_diary/settings.dart';

final _logger = new Logger('ProductAdvertisingAPI');

class PAA {
  static const RETRYER = const Retry<Map>("ProductAdvertisingAPI", 3, const Duration(seconds: 3));

  static Future<Pager<Item>> findByWords(String text) {
    final words = text.split("\n").where((x) => x.length > 2);
    final pagers = words.map((word) => new _SearchPager(word));
  }

  static String query(Map<String, dynamic> params) {
    params.forEach((key, value) {
      params[key] = Uri.encodeQueryComponent(value);
    });
    return params.keys.map((key) => "${key}=${params[key]}").join('&');
  }

  static String signature(String secret, Uri endpoint, String queryString) {
    final tosign = ['GET', endpoint.host, endpoint.path, queryString].join('\n');

    final hmac = new HMAC(new SHA256(), convert.UTF8.encode(secret));
    hmac.add(convert.UTF8.encode(tosign));

    final sig = BASE64.encode(hmac.close());
    return Uri.encodeQueryComponent(sig);
  }
}

class Item {
  String image;
  String title;
  String description;
  String price;
}

class _SearchPager extends Pager<Item> {
  final String word;

  _SearchPager(this.word);

  int pageIndex;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  void reset() {
    pageIndex = null;
  }

  Future<List<Item>> more(int pageSize) async {
    final settings = (await Settings).amazon;
    final endpoint = await Country.endpoint;
    final params = {
      'Service': 'AWSECommerceService',
      'Operation': 'ItemSearch',
      'AWSAccessKeyId': settings.accessKey,
      'AssociateTag': settings.associateTag,
      'SearchIndex': 'All',
      'ResponseGroup': 'Images,ItemAttributes',
      'Keywords': word,
      'Timestamp': new DateTime.now().toIso8601String()
    };
    if (pageIndex != null) params['ItemPage'] = pageIndex;

    final query = PAA.query(params);
    final sig = PAA.signature(settings.secretKey, endpoint, query);
    final url = "endpoint?${query}&Signature=${sig}";

    final req = await HttpRequest.request(url);
  }
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
  static Future<Uri> get endpoint async {
    if (_endpoint == null) {
      try {
        final code = await getCode();
        _endpoint = ENDPOINT[code];
        _logger.info(() => "Getting endpoint of ${code}: ${_endpoint}");

        if (_endpoint == null) {
          _endpoint = ENDPOINT['US'];
          _logger.warning(() => "No match endpoint found. Use 'US': ${_endpoint}");
        }
      } catch (ex) {
        _logger.warning(() => "Failed to get locale: ${ex}");
      }
    }
    return Uri.parse(_endpoint);
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

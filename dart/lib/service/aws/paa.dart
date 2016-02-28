library bacchus_diary.service.aws.paa;

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:js';

import 'package:crypto/crypto.dart' as Crypto;
import 'package:logging/logging.dart';
import 'package:xml/xml.dart' as XML;

import 'package:bacchus_diary/util/pager.dart';
import 'package:bacchus_diary/util/retry_routin.dart';
import 'package:bacchus_diary/settings.dart';

final _logger = new Logger('ProductAdvertisingAPI');

class PAA {
  static const RETRYER = const Retry<List<Item>>("ProductAdvertisingAPI", 3, const Duration(seconds: 3));

  static Pager<Item> findByWords(String text) {
    final words = text.split("\n").where((x) => x.length > 2);
    final pagers = words.map((word) => new _SearchPager(word));
    return new MergedPager(pagers);
  }

  static String _query(Map<String, dynamic> params) {
    params.forEach((key, value) {
      params[key] = Uri.encodeQueryComponent(value);
    });
    return params.keys.map((key) => "${key}=${params[key]}").join('&');
  }

  static String _signature(String secret, Uri endpoint, String queryString) {
    final tosign = ['GET', endpoint.host, endpoint.path, queryString].join('\n');

    final hmac = new Crypto.HMAC(new Crypto.SHA256(), UTF8.encode(secret));
    hmac.add(UTF8.encode(tosign));

    final sig = BASE64.encode(hmac.close());
    return Uri.encodeQueryComponent(sig);
  }

  static Future<XML.XmlDocument> request(Uri endpoint, Map<String, String> params) async {
    final settings = (await Settings).amazon;

    params['AWSAccessKeyId'] = settings.accessKey;
    params['AssociateTag'] = settings.associateTag;

    final query = _query(params);
    final sig = _signature(settings.secretKey, endpoint, query);
    final url = "endpoint?${query}&Signature=${sig}";

    final req = await HttpRequest.request(url);
    return XML.parse(req.responseText);
  }
}

class Item {
  final XML.XmlElement _src;
  Item(this._src);

  Map<String, String> _cache = {};
  String _fromCache(String path) {
    if (!_cache.containsKey(path)) {
      String getElm(List<String> keys, XML.XmlElement parent) {
        if (keys.isEmpty) return parent.text;
        final el = parent.findAllElements(keys.first);
        return el.isEmpty ? null : getElm(keys.sublist(1), el.first);
      }
      _cache[path] = getElm(path.split('/'), _src);
    }
    return _cache[path];
  }

  String get image => _fromCache('SmallImage/URL');
  String get title => _fromCache('ItemAttributes/Title');
  String get price => _fromCache('OfferSummary/LowestNewPrice/FormattedPrice');
  String get url => _fromCache('DetailPageURL');
}

class _SearchPager extends Pager<Item> {
  final String word;

  _SearchPager(this.word);

  int _pageIndex = 0;
  int _pageTotal = 1;
  List<Item> _stock = [];

  bool get hasMore => _pageIndex < _pageTotal || _stock.isNotEmpty;

  void reset() {
    _pageIndex = 0;
  }

  Future<List<Item>> more(int pageSize) async {
    Future<List<Item>> load(List<Item> result) async {
      if (pageSize <= result.length || !hasMore) return result;

      if (_stock.isEmpty) _stock = await _getNextPage();

      result.addAll(_stock.take(pageSize - result.length));
      _stock = _stock.length <= pageSize ? [] : _stock.sublist(pageSize);

      return load(result);
    }
    return load([]);
  }

  Future<List<Item>> _getNextPage() async {
    final nextPageIndex = _pageIndex + 1;

    final endpoint = await Country.endpoint;
    final params = {
      'Service': 'AWSECommerceService',
      'Version': '2013-08-01',
      'Operation': 'ItemSearch',
      'SearchIndex': 'All',
      'ResponseGroup': 'Images,ItemAttributes,OfferSummary',
      'Keywords': word,
      'ItemPage': nextPageIndex,
      'Timestamp': new DateTime.now().toUtc().toIso8601String()
    };

    return PAA.RETRYER.loop((count) async {
      final xml = await PAA.request(endpoint, params);
      final items = xml.findElements('Items');
      if (items.isEmpty) return [];

      final totalPages = xml.findElements('TotalPages').first;
      _pageTotal = int.parse(totalPages.text);
      _pageIndex = nextPageIndex;

      return items.first.findElements('Item').map((x) => new Item(x));
    });
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
      final regex = new RegExp(r"^[A-Z]{2}$");
      final parts = locale.split('-').map(regex.stringMatch).where((x) => x != null);
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

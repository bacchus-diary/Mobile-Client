library bacchus_diary.service.aws.paa;

import 'dart:async';
import 'dart:convert';
import 'dart:js';

import 'package:logging/logging.dart';
import 'package:xml/xml.dart' as XML;

import 'package:bacchus_diary/service/aws/api_gateway.dart';
import 'package:bacchus_diary/settings.dart';

final _logger = new Logger('ProductAdvertisingAPI');

class PAA {
  static final _api =
      Settings.then((x) => new ApiGateway<XML.XmlDocument>(x.server.paa, (text) => XML.parse(JSON.decode(text))));

  static const durThrottled = const Duration(seconds: 1);
  static Completer _throttled;
  static Future throttled(Future proc()) async {
    while (!(_throttled?.isCompleted ?? true)) await _throttled.future;
    _throttled = new Completer();
    try {
      return await proc();
    } finally {
      new Future.delayed(durThrottled, () => _throttled.complete());
    }
  }

  static Map<String, List<XML.XmlElement>> _cacheItemSearch = {};

  static XML.XmlElement _getFromCache(String word, int nextPageIndex) {
    if (nextPageIndex <= (_cacheItemSearch[word]?.length ?? 0)) {
      return _cacheItemSearch[word][nextPageIndex - 1];
    }
    return null;
  }

  static XML.XmlElement _setToCache(String word, int nextPageIndex, XML.XmlElement value) {
    final List cache = _cacheItemSearch[word] ?? [];
    if (cache.length < nextPageIndex) {
      cache.addAll(new List(nextPageIndex - cache.length));
    }
    cache[nextPageIndex - 1] = value;
    _cacheItemSearch[word] = cache;
    return value;
  }

  static Future<XML.XmlElement> itemSearch(String word, int nextPageIndex) async {
    _logger.finest(() => "Getting ItemSearch (page: ${nextPageIndex}): ${word}");

    final result = _getFromCache(word, nextPageIndex);
    if (result != null) return result;

    return throttled(() async {
      final result = _getFromCache(word, nextPageIndex);
      if (result != null) return result;

      final settings = await Settings;
      final api = await _api;
      final endpoint = await Country.endpoint;

      final params = {
        'Operation': 'ItemSearch',
        'SearchIndex': 'All',
        'ResponseGroup': 'Images,ItemAttributes,OfferSummary',
        'Keywords': word,
        'ItemPage': "${nextPageIndex}"
      };

      try {
        final xml =
            await api.call({'params': params, 'endpoint': endpoint.toString(), 'bucketName': settings.s3Bucket});
        final roots = xml.findElements('ItemSearchResponse');
        if (roots.isEmpty) {
          _logger.warning(() => "Illegal response: ${xml}");
          return null;
        }
        return _setToCache(word, nextPageIndex, roots.first);
      } catch (ex) {
        _logger.warning(() => "Failed to ItemSearch: ${params}");
        return null;
      }
    });
  }
}

class XmlItem {
  final XML.XmlElement _src;
  XmlItem(this._src);

  @override
  String toString() => _src.toXmlString(pretty: true);

  Map<String, String> _cache = {};

  String getProperty(String path) {
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
}

class ItemSearch {
  final String word;

  ItemSearch(this.word);

  int _pageTotal = 5;
  int _pageIndex = 0;

  bool get hasMore => _pageIndex < _pageTotal;

  Completer _seeking;
  Future _seek(proc()) async {
    try {
      if (_seeking != null) await _seeking.future;
      _seeking = new Completer();
      return proc();
    } finally {
      _seeking.complete();
    }
  }

  void reset() {
    _seek(() {
      _pageIndex = 0;
    });
  }

  Future<List<XmlItem>> nextPage() async {
    if (_pageTotal <= _pageIndex) return [];
    final nextPageIndex = _pageIndex + 1;

    final xml = await PAA.itemSearch(word, nextPageIndex);
    if (xml == null) return [];

    final itemsRc = xml.findElements('Items');
    if (itemsRc.isEmpty) return [];
    final items = itemsRc.first;

    final totalPages = items.findElements('TotalPages');
    if (totalPages.isNotEmpty) {
      final total = int.parse(totalPages.first.text);
      if (total < _pageTotal) {
        _logger.info(() => "Reducing totalPages: ${total}");
        _pageTotal = total;
      }
    }
    _pageIndex = nextPageIndex;

    return items.findElements('Item').map((x) => new XmlItem(x)).toList();
  }
}

class Country {
  static const ENDPOINT = const {
    "BR": "https://webservices.amazon.br/onca/xml",
    "CA": "https://webservices.amazon.ca/onca/xml",
    "CN": "https://webservices.amazon.cn/onca/xml",
    "DE": "https://webservices.amazon.de/onca/xml",
    "ES": "https://webservices.amazon.es/onca/xml",
    "FR": "https://webservices.amazon.fr/onca/xml",
    "IN": "https://webservices.amazon.in/onca/xml",
    "IT": "https://webservices.amazon.it/onca/xml",
    "JP": "https://webservices.amazon.co.jp/onca/xml",
    "MX": "https://webservices.amazon.com.mx/onca/xml",
    "UK": "https://webservices.amazon.co.uk/onca/xml",
    "US": "https://webservices.amazon.com/onca/xml"
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
      try {
        final locale = await _locale;
        final regex = new RegExp(r"^[A-Z]{2}$");
        final parts = locale.split('-').map(regex.stringMatch).where((x) => x != null);
        if (parts.isEmpty) return null;
        return parts.first;
      } catch (ex) {
        return null;
      }
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

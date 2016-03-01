library bacchus_diary.service.aws.paa;

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:js';

import 'package:logging/logging.dart';
import 'package:xml/xml.dart' as XML;

import 'package:bacchus_diary/service/aws/api_gateway.dart';
import 'package:bacchus_diary/util/pager.dart';
import 'package:bacchus_diary/util/retry_routin.dart';
import 'package:bacchus_diary/settings.dart';

final _logger = new Logger('ProductAdvertisingAPI');

class PAA {
  static const RETRYER = const Retry<List<Item>>("ProductAdvertisingAPI", 3, const Duration(seconds: 3));
  static final _api =
      Settings.then((x) => new ApiGateway<XML.XmlDocument>(x.server.paa, (text) => XML.parse(JSON.decode(text))));

  static Pager<Item> findByWords(String text) {
    final words = text.split("\n").where((x) => x.length > 2);
    final pagers = words.map((word) => new _SearchPager(word));
    return new MergedPager(pagers);
  }

  static Future<XML.XmlElement> itemSearch(String word, int nextPageIndex) async {
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

    return PAA.RETRYER.loop((count) async {
      final xml = await api.call({'params': params, 'endpoint': endpoint.toString(), 'bucketName': settings.s3Bucket});
      final roots = xml.findElements('ItemSearchResponse');
      if (roots.isEmpty) {
        _logger.warning(() => "Illegal response: ${xml}");
        return null;
      }
      return roots.first;
    });
  }

  static open(Item item) {
    _logger.info(() => "Opening amazon: ${item}");
    if (context['cordova'] != null && context['cordova']['InAppBrowser'] != null) {
      context['cordova']['InAppBrowser'].callMethod('open', [item.url, '_system']);
    } else {
      window.open(item.url, '_blank');
    }
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

  @override
  String toString() => _src.toXmlString(pretty: true);

  String get image => _fromCache('SmallImage/URL');
  String get title => _fromCache('ItemAttributes/Title');
  String get price => _fromCache('OfferSummary/LowestNewPrice/FormattedPrice');
  String get url => _fromCache('DetailPageURL');
}

class _SearchPager extends Pager<Item> {
  final String word;

  _SearchPager(this.word);

  final int _pageTotal = 5;
  int _pageIndex = 0;
  List<Item> _stock = [];

  bool get hasMore => _pageIndex < _pageTotal || _stock.isNotEmpty;

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
      _stock = [];
    });
  }

  Future<List<Item>> more(int pageSize) async {
    Future<List<Item>> load(List<Item> result) async {
      if (pageSize <= result.length || !hasMore) return result;

      if (_stock.isEmpty) _stock = await _getNextPage();

      final need = pageSize - result.length;
      result.addAll(_stock.take(need));
      _stock = _stock.length <= need ? [] : _stock.sublist(need);

      return load(result);
    }
    return _seek(() => load([]));
  }

  Future<List<Item>> _getNextPage() async {
    if (_pageTotal <= _pageIndex) return [];
    final nextPageIndex = _pageIndex + 1;

    final xml = await PAA.itemSearch(word, nextPageIndex);
    if (xml == null) return [];

    final itemsRc = xml.findElements('Items');
    if (itemsRc.isEmpty) return [];
    final items = itemsRc.first;

    _pageIndex = nextPageIndex;

    return items.findElements('Item').map((x) => new Item(x)).toList();
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

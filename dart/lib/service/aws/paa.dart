library bacchus_diary.service.aws.paa;

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:indexed_db';
import 'dart:js';

import 'package:logging/logging.dart';
import 'package:xml/xml.dart' as XML;

import 'package:bacchus_diary/service/aws/api_gateway.dart';
import 'package:bacchus_diary/util/withjs.dart';
import 'package:bacchus_diary/settings.dart';

final _logger = new Logger('ProductAdvertisingAPI');

class PAA {
  static void initialize() {
    _CachedItemSearch.removeOlds();
  }

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

  static Future<XML.XmlElement> itemSearch(String word, int nextPageIndex) async {
    _logger.finest(() => "Getting ItemSearch (page: ${nextPageIndex}): ${word}");

    final result = await _CachedItemSearch.get(word, nextPageIndex);
    if (result != null) return result;

    return throttled(() async {
      final result = await _CachedItemSearch.get(word, nextPageIndex);
      if (result != null) return result;

      final settings = await Settings;
      final api = await _api;
      final endpoint = await Country.endpoint;

      final params = {
        'Operation': 'ItemSearch',
        'SearchIndex': 'All',
        'ResponseGroup': 'Images,ItemAttributes,OfferSummary',
        'Keywords': word,
        'Availability': 'Available',
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
        return await _CachedItemSearch.set(word, nextPageIndex, roots.first);
      } catch (ex) {
        _logger.warning(() => "Failed to ItemSearch: ${params}");
        return null;
      }
    });
  }
}

class _CachedItemSearch {
  static final _logger = new Logger('PAA_Cache');

  static const DB_NAME = 'paaa_cache';
  static const STORE_NAME = 'itemSearch';
  static const VERSION = 1;

  static Future<ObjectStore> _getStore() async {
    if (window.indexedDB == null) return null;

    final db = await window.indexedDB.open(DB_NAME, version: VERSION, onUpgradeNeeded: (VersionChangeEvent event) {
      final db = (event.target as OpenDBRequest).result as Database;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, keyPath: 'word');
      }
    });
    final trans = db.transaction(STORE_NAME, 'readwrite');
    return trans.objectStore(STORE_NAME);
  }

  static Future<XML.XmlElement> get(String word, int nextPageIndex) async {
    final store = await _getStore();
    if (store == null) return null;

    final Map<String, String> record = await store.getObject(word);
    _logger.finest(() => "Cached Values for '${word}': ${record == null ? null : record['timestamp']}");
    if (record == null || isOld(record)) return null;

    final Map<String, String> data = JSON.decode(record['data']);

    final xml = data[nextPageIndex.toString()];
    return xml == null ? null : XML.parse(xml).firstChild;
  }

  static Future<XML.XmlElement> set(String word, int nextPageIndex, XML.XmlElement value) async {
    final store = await _getStore();
    if (store == null) return value;

    final Map<String, String> record = await store.getObject(word) ?? {'word': word};

    final Map<String, String> data = JSON.decode(record['data'] ?? '{}');
    data[nextPageIndex.toString()] = value.toXmlString();

    record['data'] = JSON.encode(data);
    record['timestamp'] = new DateTime.now().millisecondsSinceEpoch.toString();
    await store.put(record);

    return value;
  }

  static const maxAge = const Duration(days: 1);
  static bool isOld(Map<String, String> record) {
    final timestamp = new DateTime.fromMillisecondsSinceEpoch(int.parse(record['timestamp']));
    final diff = new DateTime.now().difference(timestamp);
    return maxAge < diff;
  }

  static Future removeOlds() async {
    final store = await _getStore();
    if (store == null) return;

    store.openCursor(autoAdvance: true).listen((cursor) {
      final Map<String, String> record = cursor.value;
      if (isOld(record)) {
        _logger.finest(() => "Deleting cache: ${record['word']}");
        cursor.delete();
      }
    });
  }
}

class ItemSearch {
  final String word;

  ItemSearch(this.word);

  @override
  String toString() => "ItemSearch[${word}](${_pageIndex}/${_pageTotal})";

  int _pageTotal = 5;
  int _pageIndex = 0;

  bool get hasMore => _pageIndex < _pageTotal;

  Completer _seeking;
  Future _seek(Future proc()) async {
    while (!(_seeking?.isCompleted ?? true)) await _seeking.future;
    _seeking = new Completer();
    try {
      return await proc();
    } finally {
      _seeking.complete();
    }
  }

  void reset() {
    _seek(() async {
      _pageIndex = 0;
    });
  }

  Future<List<XML.XmlElement>> nextPage() => _seek(() async {
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

        return items.findElements('Item').toList();
      });
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
    final plugin = context['Country'];
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
          _logger.finest(() => "Get locale: ${stringify(code)}");
          result.complete(code['value']);
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

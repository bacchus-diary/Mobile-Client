library bacchus_diary.service.search;

import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'package:logging/logging.dart';
import 'package:xml/xml.dart' as XML;

import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/service/aws/paa.dart';
import 'package:bacchus_diary/util/pager.dart';

final _logger = new Logger('Suggestions');

class Suggestions implements PagingList<Item> {
  final Report _report;
  final List<Item> list = [];

  List<ScoreKeeper> _scores;
  List<ItemSearch> _searchers;

  Suggestions(this._report) {
    final labels = new ScoreKeeper.fromLabels(_report);
    final words = new ScoreKeeper.fromDescriptions(_report);

    _logger.info(() => "Using search labels: ${labels}");
    _logger.info(() => "Using search words: ${words}");

    final keywords = words.all.isEmpty
        ? labels.heads
        : words.all.map((word) {
            final list = labels.heads.map((x) => "${x} ${word}").toList();
            list.add(word);
            return list;
          }).expand((x) => x);
    _logger.fine(() => "Search keywords:\n${keywords.join('\n')}");

    _scores = new List.unmodifiable([labels, words]);
    _searchers = new List.unmodifiable(keywords.map((x) => new ItemSearch(x)));
  }

  int score(Item item) => _scores.map((x) => x.score(item)).fold(0, (a, b) => a + b);

  sort(List<Item> items) {
    items.sort((a, b) => b.priceValue - a.priceValue);
    items.sort((a, b) => score(b) - score(a));
    return items;
  }

  bool get hasMore => _searchers.any((x) => x.hasMore);

  void reset() => _searchers.forEach((x) => x.reset());

  Completer _more;
  Future<List<Item>> more(int pageSize) async {
    if (!(_more?.isCompleted ?? true)) return [];
    _more = new Completer();

    Future.wait(_searchers.map(_addNext)).whenComplete(_more.complete);
    return [];
  }

  Future _addNext(ItemSearch search) async {
    final items = (await search.nextPage()).map((x) => new Item.fromXml(x));
    if (items.isNotEmpty) {
      items.forEach((item) {
        if (list.every((x) => x.id != item.id)) list.add(item);
      });
      sort(list);
    }
  }
}

class ScoreKeeper {
  static final _regexNum = new RegExp(r"[0-9]+");
  static final _regexSpace = new RegExp(r"\s+");

  static List<String> expand(Iterable<Iterable<String>> lists) => new List.unmodifiable(lists.expand((x) => x));

  static List<String> pickHeads(Iterable<Iterable<String>> lists) =>
      new List.unmodifiable(lists.where((x) => x.isNotEmpty).map((x) => x.first));

  int score(Item item) =>
      [all, heads, headWords].map((x) => x.where(item.title.contains).length).fold(0, (a, b) => a + b);

  List<String> all;
  List<String> heads;
  List<String> headWords;

  ScoreKeeper(Iterable<Iterable<String>> lists) {
    all = expand(lists);
    heads = pickHeads(lists);
    headWords = expand(heads.map((x) => x.split(_regexSpace)));
  }

  @override
  String toString() => {'all': all, 'heads': heads, 'headWords': headWords}.toString();

  factory ScoreKeeper.fromLabels(Report report) {
    final lists = report.leaves.map((x) => x.labels ?? []);

    return new ScoreKeeper(lists);
  }

  factory ScoreKeeper.fromDescriptions(Report report) {
    final lists = report.leaves.map((x) => (x.description ?? '')
        .split('\n')
        .map((x) => x.trim())
        .where((String x) => x.replaceAll(_regexNum, '').trim().length > 2)
        .take(5));

    return new ScoreKeeper(lists);
  }
}

class Item {
  factory Item.fromXml(XML.XmlElement _src) {
    String text(String path) {
      String getElm(List<String> keys, XML.XmlElement parent) {
        if (keys.isEmpty) return parent.text;
        final el = parent.findAllElements(keys.first);
        return el.isEmpty ? null : getElm(keys.sublist(1), el.first);
      }
      return getElm(path.split('/'), _src);
    }

    return new Item(
        text('ASIN'),
        text('SmallImage/URL'),
        int.parse(text('SmallImage/Width') ?? '0'),
        int.parse(text('SmallImage/Height') ?? '0'),
        text('ItemAttributes/Title'),
        text('OfferSummary/LowestNewPrice/FormattedPrice'),
        int.parse(text('OfferSummary/LowestNewPrice/Amount') ?? '0'),
        text('DetailPageURL'));
  }

  final String id;
  final String imageUrl;
  final int imageWidth;
  final int imageHeight;
  final String title;
  final String price;
  final int priceValue;
  final String url;

  Item(this.id, this.imageUrl, this.imageWidth, this.imageHeight, this.title, this.price, this.priceValue, this.url);

  @override
  String toString() => {'id': id, 'title': title, 'price': price}.toString();

  open() {
    _logger.info(() => "Opening amazon: ${url}");
    if (context['cordova'] != null && context['cordova']['InAppBrowser'] != null) {
      context['cordova']['InAppBrowser'].callMethod('open', [url, '_system']);
    } else {
      window.open(url, '_blank');
    }
  }
}

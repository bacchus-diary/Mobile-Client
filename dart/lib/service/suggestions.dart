library bacchus_diary.service.search;

import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'package:logging/logging.dart';

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

    final keywords = words.all.map((word) {
      final list = labels.heads.map((x) => "${x} ${word}").toList();
      list.add(word);
      return list;
    }).expand((x) => x);
    _logger.fine(() => "Search keywords:\n${keywords.join('\n')}");

    _scores = new List.unmodifiable([labels, words]);
    _searchers = new List.unmodifiable(keywords.map((x) => new ItemSearch(x)));

    _more();
  }

  int score(Item item) => _scores.map((x) => x.score(item)).fold(0, (a, b) => a + b);

  sort(List<Item> items) {
    items.sort((a, b) => b.priceValue - a.priceValue);
    items.sort((a, b) => score(b) - score(a));
    return items;
  }

  bool get hasMore => _searchers.any((x) => x.hasMore);

  void reset() => _searchers.forEach((x) => x.reset());

  Future<List<Item>> more(int pageSize) async => [];

  static const interval = const Duration(seconds: 3);
  _more() async {
    while (!_isCanceled && hasMore) {
      _logger.finest(() => "Getting more...");
      await Future.wait(_searchers.map(_addNext));
      await new Future.delayed(interval);
    }
  }

  Future _addNext(ItemSearch search) async {
    final items = (await search.nextPage()).map((x) => new Item(x));
    if (items.isNotEmpty) {
      items.forEach((item) {
        if (list.every((x) => x.id != item.id)) list.add(item);
      });
      sort(list);
    }
  }

  bool _isCanceled = false;

  cancel() async {
    _logger.finest(() => "Cancel getting more");
    _isCanceled = true;
  }
}

class ScoreKeeper {
  static List<String> expand(List<List<String>> lists) => new List.unmodifiable(lists.expand((x) => x));

  static List<String> pickHeads(List<List<String>> lists) =>
      new List.unmodifiable(lists.where((x) => x.isNotEmpty).map((x) => x.first));

  int score(Item item) =>
      [all, heads, headWords].map((x) => x.where(item.title.contains).length).fold(0, (a, b) => a + b);

  final List<String> all;
  final List<String> heads;
  final List<String> headWords;

  ScoreKeeper(List<List<String>> lists)
      : all = expand(lists),
        heads = pickHeads(lists),
        headWords = expand(pickHeads(lists).map((x) => x.split(new RegExp(r'\s+'))));

  @override
  String toString() => {'all': all, 'heads': heads, 'headWords': headWords}.toString();

  factory ScoreKeeper.fromLabels(Report report) {
    final lists = report.leaves.map((x) => x.labels ?? []);

    return new ScoreKeeper(lists);
  }

  factory ScoreKeeper.fromDescriptions(Report report) {
    final lists = report.leaves.map((x) => (x.description ?? '').split('\n').map((x) => x.trim()).where((String x) {
          return x.length > 2 && !new RegExp(r"^[0-9]+$").hasMatch(x);
        }));

    return new ScoreKeeper(lists);
  }
}

class Item {
  final XmlItem _src;
  Item(this._src);

  @override
  String toString() => _src.toString();

  String get id => _src.getProperty('ASIN');
  String get image => _src.getProperty('SmallImage/URL');
  String get title => _src.getProperty('ItemAttributes/Title');
  String get price => _src.getProperty('OfferSummary/LowestNewPrice/FormattedPrice');
  int get priceValue => int.parse(_src.getProperty('OfferSummary/LowestNewPrice/Amount') ?? '0');
  String get url => _src.getProperty('DetailPageURL');

  open() {
    _logger.info(() => "Opening amazon: ${url}");
    if (context['cordova'] != null && context['cordova']['InAppBrowser'] != null) {
      context['cordova']['InAppBrowser'].callMethod('open', [url, '_system']);
    } else {
      window.open(url, '_blank');
    }
  }
}
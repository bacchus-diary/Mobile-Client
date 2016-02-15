library bacchus_diary.service.search;

import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/service/aws/cognito.dart';
import 'package:bacchus_diary/service/aws/dynamodb.dart';
import 'package:bacchus_diary/service/reports.dart';
import 'package:bacchus_diary/util/pager.dart';

final _logger = new Logger('Search');

class Search implements Pager<Report> {
  static Future<Pager<Leaf>> leavesByDescription(List<String> words) async {
    final map = new ExpressionMap();

    final nameContent = map.putName(DynamoDB.CONTENT);
    final nameDesc = map.putName('description');

    final list = ["${map.putName(DynamoDB.COGNITO_ID)} = ${map.putValue(await cognitoId)}"];
    list.addAll(words.map((word) => "contains (${nameContent}.${nameDesc}, ${map.putValue(word)})"));
    final exp = list.join(' AND ');

    return Reports.TABLE_LEAF.scanPager(exp, map.names, map.values);
  }

  static Future<Pager<Report>> reportsByComment(List<String> words) async {
    final map = new ExpressionMap();

    final nameContent = map.putName(DynamoDB.CONTENT);
    final nameDesc = map.putName('comment');

    final list = ["${map.putName(DynamoDB.COGNITO_ID)} = ${map.putValue(await cognitoId)}"];
    list.addAll(words.map((word) => "contains (${nameContent}.${nameDesc}, ${map.putValue(word)})"));
    final exp = list.join(' AND ');

    return Reports.TABLE_REPORT.scanPager(exp, map.names, map.values);
  }

  static Future<Pager<Report>> byWords(List<String> words) async {
    final descs = await leavesByDescription(words);
    final comments = await reportsByComment(words);
    return new Search(comments, descs);
  }

  final Pager<Report> _pagerReports;
  final Pager<Leaf> _pagerLeaves;

  Search(this._pagerReports, this._pagerLeaves);

  bool get hasMore => _pagerReports.hasMore || _pagerLeaves.hasMore;

  void reset() {
    _pagerReports.reset();
    _pagerLeaves.reset();
  }

  Future<List<Report>> _moreLeaves(int pageSize) async {
    final result = [];
    add(int more) async {
      final list = (await _pagerLeaves.more(pageSize));
      final reports = list.map((x) => x.reportId).toSet().map(Reports.get).toList();
      result.addAll(reports);
    }
    while (result.length < pageSize && _pagerLeaves.hasMore) {
      add(pageSize - result.length);
    }
    return result;
  }

  Future<List<Report>> more(int pageSize) async {
    final reports = await _pagerReports.more((pageSize / 2).floor());
    reports.addAll(await _moreLeaves(pageSize - reports.length));
    reports.addAll(await _pagerReports.more(pageSize - reports.length));
    reports.sort((a, b) {
      final byRating = b.rating.compareTo(a.rating);
      if (byRating != 0) {
        return byRating;
      } else {
        return b.dateAt.compareTo(a.dateAt);
      }
    });
    return reports;
  }
}

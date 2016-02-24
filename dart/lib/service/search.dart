library bacchus_diary.service.search;

import 'dart:async';

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
    final nameDesc = map.putName(Leaf.DESCRIPTION_UPPER);

    final list = ["${map.putName(DynamoDB.COGNITO_ID)} = ${map.putValue(await cognitoId)}"];
    list.addAll(words.map((word) => "contains (${nameContent}.${nameDesc}, ${map.putValue(word.toUpperCase())})"));
    final exp = list.join(' AND ');

    return Reports.TABLE_LEAF.scanPager(exp, map.names, map.values);
  }

  static Future<Pager<Report>> reportsByComment(List<String> words) async {
    final map = new ExpressionMap();

    final nameContent = map.putName(DynamoDB.CONTENT);
    final nameDesc = map.putName(Report.COMMENT_UPPER);

    final list = ["${map.putName(DynamoDB.COGNITO_ID)} = ${map.putValue(await cognitoId)}"];
    list.addAll(words.map((word) => "contains (${nameContent}.${nameDesc}, ${map.putValue(word.toUpperCase())})"));
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

  Future<List<Report>> more(final int pageSize) async {
    final Map<String, Report> result = {};

    while (result.length < pageSize && hasMore) {
      final leaves = await _pagerLeaves.more(((pageSize - result.length) / 2).ceil());
      await Future.wait(leaves.map((leaf) async {
        if (!result.containsKey(leaf.reportId)) {
          try {
            final report = await Reports.get(leaf.reportId);
            if (report != null) result[leaf.reportId] = report;
          } catch (ex) {
            _logger.warning(() => "Failed to get report: ${leaf.reportId}");
          }
        }
      }));
      final reports = await _pagerReports.more(pageSize - result.length);
      await Future.wait(reports.map((report) async {
        if (!result.containsKey(report.id)) {
          try {
            await Reports.loadLeaves(report);
            if (report.leaves?.isNotEmpty ?? false) result[report.id] = report;
          } catch (ex) {
            _logger.warning(() => "Failed to get leaves: ${report.id}");
          }
        }
      }));
    }

    return result.values.toList()
      ..sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        if (byRating != 0) {
          return byRating;
        } else {
          return b.dateAt.compareTo(a.dateAt);
        }
      });
  }
}

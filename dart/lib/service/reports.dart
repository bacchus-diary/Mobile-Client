library bacchus_diary.service.reports;

import 'dart:async';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/model/photo.dart';
import 'package:bacchus_diary/service/aws/cognito.dart';
import 'package:bacchus_diary/service/aws/dynamodb.dart';
import 'package:bacchus_diary/util/pager.dart';

final _logger = new Logger('Reports');

class Reports {
  static const DATE_AT = "DATE_AT";
  static const LEAF_INDEXES = 'LEAF_INDEXES';

  static final DynamoDB_Table<Leaf> TABLE_LEAF = new DynamoDB_Table("LEAF", "LEAF_ID", (Map map) {
    return new Leaf.fromData(map[DynamoDB.CONTENT], map['LEAF_ID'], map['REPORT_ID']);
  }, (Leaf obj) {
    return {DynamoDB.CONTENT: obj.toMap(), 'REPORT_ID': obj.reportId};
  });

  static final DynamoDB_Table<Report> TABLE_REPORT = new DynamoDB_Table("REPORT", "REPORT_ID", (Map map) {
    return new Report.fromData(map[DynamoDB.CONTENT], map['REPORT_ID'],
        new DateTime.fromMillisecondsSinceEpoch(map['DATE_AT'], isUtc: true).toLocal());
  }, (Report obj) {
    final content = obj.toMap();
    content[LEAF_INDEXES] = obj.leaves.map((x) => x.id).toList();
    return {DynamoDB.CONTENT: content, 'REPORT_ID': obj.id, 'DATE_AT': obj.dateAt};
  });

  static final PagingList<Report> paging = new PagingList(new _PagerReports());
  static List<Report> get _cachedList => paging.list;

  static List<Report> _addToCache(Report adding) => _cachedList
    ..removeWhere((x) => x.id == adding.id)
    ..add(adding)
    ..sort((a, b) => b.dateAt.compareTo(a.dateAt));

  static Report _onCache(String id) => _cachedList.firstWhere((r) => r.id == id, orElse: () => null);

  static Future<Null> loadLeaves(Report report) async {
    final found = _onCache(report.id);
    if (found != null) {
      report.leaves
        ..clear()
        ..addAll(found.leaves);
      return;
    }
    final indexes = report.toMap()[LEAF_INDEXES] as List<String>;
    if (indexes != null &&
        indexes.isNotEmpty &&
        indexes.every((leafId) => report.leaves.any((leaf) => leaf.id == leafId))) {
      return;
    }

    final list = await TABLE_LEAF
        .query("COGNITO_ID-REPORT_ID-index", {DynamoDB.COGNITO_ID: await cognitoId, TABLE_REPORT.ID_COLUMN: report.id});

    final List<Leaf> leaves = [];
    indexes?.forEach((leafId) {
      final leaf = list.firstWhere((x) => x.id == leafId, orElse: () => null);
      if (leaf != null) {
        leaves.add(leaf);
        list.removeWhere((x) => x.id == leaf.id);
      }
    });
    leaves.addAll(list);

    report.leaves
      ..clear()
      ..addAll(leaves);
  }

  static Future<Report> get(String id) async {
    final found = _cachedList.firstWhere((r) => r.id == id, orElse: () => null);
    if (found != null) {
      return found.clone();
    } else {
      final report = await TABLE_REPORT.get(id);
      final loading = loadLeaves(report);
      _addToCache(report);
      await loading;
      return report.clone();
    }
  }

  static Future<Null> remove(String id) async {
    _logger.fine("Removing report.id: ${id}");
    final report = await get(id);
    _cachedList.removeWhere((r) => r.id == id);
    await TABLE_REPORT.delete(id);
    await Future.wait(report.leaves.map((x) => TABLE_LEAF.delete(x.id)));
  }

  static Future<Null> update(Report newReport) async {
    final oldReport = await get(newReport.id);
    assert(oldReport != null);

    _logger.finest("Updating report:\n old=${oldReport}\n new=${newReport}");

    if (newReport.leaves.isEmpty) throw "Updating report's leaves is Empty.";

    newReport.leaves.forEach((x) => x.reportId = newReport.id);

    List<Leaf> distinct(List<Leaf> src, List<Leaf> dst) => src.where((a) => dst.every((b) => b.id != a.id));

    // No old, On new
    Future adding() => Future.wait(distinct(newReport.leaves, oldReport.leaves).map(TABLE_LEAF.put));

    // On old, No new
    Future deleting() => Future.wait(distinct(oldReport.leaves, newReport.leaves).map((o) => TABLE_LEAF.delete(o.id)));

    // On old, On new
    Future marging() => Future.wait(newReport.leaves.where((newOne) {
          final oldOne = oldReport.leaves.firstWhere((oldOne) => oldOne.id == newOne.id, orElse: () => null);
          return oldOne != null && oldOne.isNeedUpdate(newOne);
        }).map(TABLE_LEAF.update));

    Future updating() async {
      if (oldReport.isNeedUpdate(newReport)) TABLE_REPORT.update(newReport);
    }

    Future replaceCache() async {
      _cachedList.removeWhere((x) => x.id == newReport.id);
      _addToCache(newReport.clone());
    }

    await Future.wait([adding(), marging(), deleting(), updating(), replaceCache()]);
    _logger.finest("Count of cached list: ${_cachedList.length}");
  }

  static Future<Null> add(Report reportSrc) async {
    final report = reportSrc.clone();
    _logger.finest("Adding report: ${report}");

    if (report.leaves.isEmpty) throw "Adding report's leaves is Empty.";

    final putting = Future.wait(
        [TABLE_REPORT.put(report), Future.wait(report.leaves.map((x) => TABLE_LEAF.put(x..reportId = report.id)))]);

    _addToCache(report);
    await putting;

    _logger.finest(() => "Added report: ${report}");
  }
}

class _PagerReports implements Pager<Report> {
  static const changedEx = "CognitoId Changed";

  Pager<Report> _db;
  Completer<Null> _ready;

  _PagerReports() {
    _refreshDb();

    CognitoIdentity.addChaningHook(_refreshDb);
  }

  toString() => "PagerReports(ready=${_ready?.isCompleted ?? false})";

  _refreshDb([String oldId, String newId]) async {
    if (_ready != null && !_ready.isCompleted) _ready.completeError(changedEx);
    _ready = new Completer();
    _db = null;
    Reports.paging.reset();

    if (oldId != null && newId != null) await Photo.moveCognitoId(oldId, newId);
    cognitoId.then((currentId) {
      assert(currentId == newId || newId == null);

      _logger.info(() => "Refresh pager: cognito id is changed to ${currentId}");
      _db = Reports.TABLE_REPORT.queryPager("COGNITO_ID-DATE_AT-index", DynamoDB.COGNITO_ID, currentId, false);

      _ready.complete();
    });
  }

  bool get hasMore => _db?.hasMore ?? true;

  void reset() => _db?.reset();

  Future<List<Report>> more(int pageSize) async {
    try {
      await _ready.future;
      final cached = Reports._cachedList;
      final list = (await _db.more(pageSize)).where((r) => cached.every((c) => c.id != r.id));
      await Future.wait(list.map(Reports.loadLeaves));
      _logger.finer(() => "Loaded reports: ${list}");
      return list;
    } catch (ex) {
      if (ex != changedEx) throw ex;
      return [];
    }
  }
}

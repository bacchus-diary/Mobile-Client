library bacchus_diary.page.reports_list;

import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:core_elements/core_animation.dart';

import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/service/search.dart';
import 'package:bacchus_diary/service/reports.dart';
import 'package:bacchus_diary/util/cordova.dart';
import 'package:bacchus_diary/util/fabric.dart';
import 'package:bacchus_diary/util/main_frame.dart';
import 'package:bacchus_diary/util/pager.dart';

final _logger = new Logger('ReportsListPage');

@Component(
    selector: 'reports-list',
    templateUrl: 'packages/bacchus_diary/page/reports_list.html',
    cssUrl: 'packages/bacchus_diary/page/reports_list.css',
    useShadowDom: true)
class ReportsListPage extends MainPage {
  final pageSize = 20;

  final _Search search = new _Search();

  final PagingList<Report> _reports = Reports.paging;
  PagingList<Report> get reports => search.results ?? _reports;

  bool get noReports => search.results == null && reports.list.isEmpty && !reports.hasMore;
  bool get noMatches => search.results != null && search.isEmpty;

  int get imageSize => (window.innerWidth * sqrt(2) / (2 + sqrt(2))).round();

  ReportsListPage(Router router) : super(router);

  void onShadowRoot(ShadowRoot sr) {
    super.onShadowRoot(sr);
    FabricAnswers.eventContentView(contentName: "ReportsListPage");

    hideSplashScreen();

    reports.more(pageSize).then((_) {
      FabricAnswers.eventCustom(name: "ReportsListPage.Loaded");

      new Future.delayed(const Duration(seconds: 2), () {
        if (noReports) {
          final target = root.querySelector('.list-reports .no-reports');
          final dy = (window.innerHeight / 4).round();

          _logger.finest(() => "Show add_first_report button: ${target}: +${dy}");
          new CoreAnimation()
            ..target = target
            ..duration = 180
            ..easing = 'ease-in'
            ..fill = "both"
            ..keyframes = [
              {'transform': "none", 'opacity': '0'},
              {'transform': "translate(0px, ${dy}px)", 'opacity': '1'}
            ]
            ..play();
        }
      });
    });
  }

  goReport(Event event, Report report) {
    event.target as Element..style.opacity = '1';
    afterRippling(() {
      router.go('report-detail', {'reportId': report.id});
    });
  }

  goLeaf(Event event, Leaf leaf) {
    event.target as Element..style.opacity = '1';
    afterRippling(() {
      router.go('report-detail', {'reportId': leaf.reportId});
    });
  }

  addReport() {
    router.go('add', {});
  }
}

class _Search {
  static const durChange = const Duration(seconds: 2);

  static String _text;
  static PagingList<Report> _results;

  final pageSize = 20;

  String get text => _text;
  set text(String v) => _text = v;

  PagingList<Report> get results => _results;
  bool get isEmpty => results == null || results.list.isEmpty && !results.hasMore;

  Timer _changeTimer;

  onChange() async {
    _logger.finest("Changed: Start timer to search.");
    if (_changeTimer != null && _changeTimer.isActive) _changeTimer.cancel();
    _changeTimer = new Timer(durChange, start);
  }

  start() async {
    if (_changeTimer != null && _changeTimer.isActive) _changeTimer.cancel();

    final words = (text ?? "").split(' ').where((x) => x.isNotEmpty);
    if (words.isEmpty) {
      _results = null;
    } else {
      _results = new PagingList(await Search.byWords(words));
    }
  }
}

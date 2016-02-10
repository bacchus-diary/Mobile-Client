library bacchus_diary.page.reports_list;

import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:core_elements/core_animation.dart';

import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/service/leaves.dart';
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

  final PagingList<Report> reports = Reports.paging;

  bool get noReports => reports.list.isEmpty && !reports.hasMore;

  int get imageSize => (window.innerWidth / 3).round();

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

  goReport(Event event, String id) {
    event.target as Element..style.opacity = '1';
    afterRippling(() {
      router.go('report-detail', {'reportId': id});
    });
  }

  addReport() {
    router.go('add', {});
  }
}

class _Search {
  String text;

  PagingList<Leaf> results;
  bool get isEmpty => results == null || results.list.isEmpty && !results.hasMore;

  start() async {
    final words = (text ?? "").split(' ').where((x) => x.isNotEmpty);
    if (words.isEmpty) {
      results = null;
    } else {
      results = new PagingList(await Leaves.byWords(words));
    }
  }
}

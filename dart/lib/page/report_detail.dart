library bacchus_diary.page.report_detail;

import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:core_elements/core_dropdown.dart';
import 'package:paper_elements/paper_toast.dart';

import 'package:bacchus_diary/element/showcase.dart';
import 'package:bacchus_diary/dialog/confirm.dart';
import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/service/reports.dart';
import 'package:bacchus_diary/service/facebook.dart';
import 'package:bacchus_diary/util/fabric.dart';
import 'package:bacchus_diary/util/getter_setter.dart';
import 'package:bacchus_diary/util/main_frame.dart';

final Logger _logger = new Logger('ReportDetailPage');

const String editFlip = "create";
const String editFlop = "done";

const Duration blinkDuration = const Duration(seconds: 2);
const Duration blinkDownDuration = const Duration(milliseconds: 300);
const frameBackground = const [
  const {'background': "#fffcfc"},
  const {'background': "#fee"}
];
const frameBackgroundDown = const [
  const {'background': "#fee"},
  const {'background': "white"}
];

const submitDuration = const Duration(minutes: 1);

@Component(
    selector: 'report-detail',
    templateUrl: 'packages/bacchus_diary/page/report_detail.html',
    cssUrl: 'packages/bacchus_diary/page/report_detail.css',
    useShadowDom: true)
class ReportDetailPage extends SubPage {
  final Future<Report> _report;

  ReportDetailPage(RouteProvider rp) : this._report = Reports.get(rp.parameters['reportId']);

  Report report;
  _MoreMenu moreMenu;

  Timer _submitTimer;

  int get starSize => (window.innerWidth / 8).round();

  @override
  void onShadowRoot(ShadowRoot sr) {
    super.onShadowRoot(sr);
    FabricAnswers.eventContentView(contentName: "ReportDetailPage");

    _report.then((v) async {
      report = v;
      moreMenu = new _MoreMenu(root, report, onChanged, back);
    });
  }

  void detach() {
    super.detach();

    if (_submitTimer != null && _submitTimer.isActive) {
      _submitTimer.cancel();
      _update();
    }
  }

  DateTime get timestamp => report?.dateAt;

  void onChanged() {
    _logger.finest("Changed: Start timer to submit.");
    if (_submitTimer != null && _submitTimer.isActive) _submitTimer.cancel();
    _submitTimer = new Timer(submitDuration, _update);
  }

  void _update() {
    Reports.update(report).then((_) {
      FabricAnswers.eventCustom(name: 'ModifyReport');
    }).catchError((ex) {
      _logger.warning(() => "Failed to update report: ${ex}");
    });
  }
}

class _MoreMenu {
  final ShadowRoot _root;
  final Report _report;
  final OnChanged _onChanged;
  bool published = false;
  final _back;

  Getter<ConfirmDialog> confirmDialog = new PipeValue();
  final PipeValue<bool> dialogResult = new PipeValue();

  _MoreMenu(this._root, this._report, this._onChanged, void back()) : this._back = back {
    setPublished(_report?.published?.facebook);
  }

  setPublished(String id) async {
    if (id == null) {
      published = false;
    } else {
      try {
        final obj = await FBPublish.getAction(id);
        if (obj != null) {
          published = true;
        } else {
          published = false;
          _onChanged();
        }
      } catch (ex) {
        _logger.warning(() => "Error on getting published action: ${ex}");
        published = false;
      }
    }
  }

  CoreDropdown get dropdown => _root.querySelector('#more-menu core-dropdown');

  confirm(String message, whenOk()) {
    dropdown.close();
    confirmDialog.value
      ..message = message
      ..onClossing(() {
        if (confirmDialog.value.result) whenOk();
      })
      ..open();
  }

  toast(String msg, [Duration dur = const Duration(seconds: 8)]) =>
      _root.querySelector('#more-menu paper-toast') as PaperToast
        ..classes.remove('fit-bottom')
        ..duration = dur.inMilliseconds
        ..text = msg
        ..show();

  publish() {
    final msg =
        published ? "This report is already published. Are you sure to publish again ?" : "Publish to Facebook ?";
    confirm(msg, () async {
      try {
        await FBPublish.publish(_report);
        _onChanged();
        toast("Completed on publishing to Facebook");
      } catch (ex) {
        _logger.warning(() => "Error on publishing to Facebook: ${ex}");
        toast("Failed on publishing to Facebook");
      }
    });
  }

  delete() => confirm("Delete this report ?", () async {
        await Reports.remove(_report.id);
        _back();
      });
}

library bacchus_diary.page.report_detail;

import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:core_elements/core_dropdown.dart';
import 'package:paper_elements/paper_autogrow_textarea.dart';
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

@Component(
    selector: 'report-detail',
    templateUrl: 'packages/bacchus_diary/page/report_detail.html',
    cssUrl: 'packages/bacchus_diary/page/report_detail.css',
    useShadowDom: true)
class ReportDetailPage extends SubPage {
  static const submitDuration = const Duration(minutes: 1);

  final Future<Report> _report;

  ReportDetailPage(RouteProvider rp) : this._report = Reports.get(rp.parameters['reportId']);

  final Getter<ShowcaseElement> showcase = new PipeValue();
  Report report;
  _MoreMenu moreMenu;

  Timer _submitTimer;

  int get stars => report?.rating;
  set stars(int v) {
    _logger.info(() => "Setting rating: ${report.rating} -> ${v}");
    if (report != null && report?.rating != v) {
      report.rating = v;
      onChanged();
    }
  }

  @override
  void onShadowRoot(ShadowRoot sr) {
    super.onShadowRoot(sr);
    FabricAnswers.eventContentView(contentName: "ReportDetailPage");

    _report.then((v) {
      report = v;
      moreMenu = new _MoreMenu(root, report, onChanged, _remove);

      new Future.delayed(_durUpdateTextarea, () {
        root.querySelectorAll('paper-autogrow-textarea').forEach((PaperAutogrowTextarea e) {
          e.querySelectorAll('textarea').forEach((t) {
            _logger.finer(() => "Updating comment area: ${e} <= ${t}");
            e.update(t);
          });
        });
      });
    });
  }

  static const _durUpdateTextarea = const Duration(milliseconds: 200);

  back() async {
    if (showcase.value?.isProcessing ?? true) return;

    if (report.leaves.isEmpty) {
      if (await moreMenu.confirm("No photo on this report. Delete this report ?")) {
        _remove();
      }
    } else {
      super.back();
    }
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

  _update() async {
    if ((showcase.value?.isProcessing ?? true) || report.leaves.isEmpty) return;
    try {
      await Reports.update(report);
      FabricAnswers.eventCustom(name: 'ModifyReport');
    } catch (ex) {
      _logger.warning(() => "Failed to update report: ${ex}");
    }
  }

  _remove() async {
    if (_submitTimer != null && _submitTimer.isActive) _submitTimer.cancel();
    await Reports.remove(report);
    super.back();
  }
}

class _MoreMenu {
  final ShadowRoot _root;
  final Report _report;
  final OnChanged _onChanged;
  bool published = false;
  final _remove;

  Getter<ConfirmDialog> confirmDialog = new PipeValue();
  final PipeValue<bool> dialogResult = new PipeValue();

  _MoreMenu(this._root, this._report, this._onChanged, this._remove) {
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

  Future<bool> confirm(String message) async {
    final result = new Completer();

    dropdown.close();
    confirmDialog.value
      ..message = message
      ..onClossing(() {
        result.complete(confirmDialog.value.result);
      })
      ..open();

    return result.future;
  }

  toast(String msg, [Duration dur = const Duration(seconds: 8)]) =>
      _root.querySelector('#more-menu paper-toast') as PaperToast
        ..classes.remove('fit-bottom')
        ..duration = dur.inMilliseconds
        ..text = msg
        ..show();

  publish() async {
    final msg =
        published ? "This report is already published. Are you sure to publish again ?" : "Publish to Facebook ?";
    if (await confirm(msg)) {
      try {
        await FBPublish.publish(_report);
        _onChanged();
        toast("Completed on publishing to Facebook");
      } catch (ex) {
        _logger.warning(() => "Error on publishing to Facebook: ${ex}");
        toast("Failed on publishing to Facebook");
      }
    }
  }

  delete() async {
    if (await confirm("Delete this report ?")) _remove();
  }
}

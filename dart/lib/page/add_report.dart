library bacchus_diary.page.reports_add;

import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:core_elements/core_dropdown.dart';
import 'package:paper_elements/paper_toast.dart';

import 'package:bacchus_diary/element/showcase.dart';
import 'package:bacchus_diary/dialog/alert.dart';
import 'package:bacchus_diary/dialog/confirm.dart';
import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/service/facebook.dart';
import 'package:bacchus_diary/service/reports.dart';
import 'package:bacchus_diary/util/fabric.dart';
import 'package:bacchus_diary/util/main_frame.dart';
import 'package:bacchus_diary/util/getter_setter.dart';

final Logger _logger = new Logger('AddReportPage');

@Component(
    selector: 'add-report',
    templateUrl: 'packages/bacchus_diary/page/add_report.html',
    cssUrl: 'packages/bacchus_diary/page/add_report.css',
    useShadowDom: true)
class AddReportPage extends SubPage {
  Report report;

  final FuturedValue<ShowcaseElement> showcase = new FuturedValue();
  final Getter<ConfirmDialog> confirmDialog = new PipeValue();
  final Getter<AlertDialog> alertDialog = new PipeValue();

  @override
  void onShadowRoot(ShadowRoot sr) {
    super.onShadowRoot(sr);
    FabricAnswers.eventContentView(contentName: "AddReportPage");

    report = new Report.fromMap({});
  }

  int get stars => report?.rating;
  set stars(int v) => report?.rating = v;

  //********************************
  // Submit

  back() {
    if (!isSubmitting) {
      if (!_isSubmitted && report != null) {
        FabricAnswers.eventCustom(name: 'AddReportPage.CancelReport');
        report.leaves.forEach((x) => x.photo.delete());
      }
      super.back();
    }
  }

  bool get isSubmittable => report?.rating != null && (report?.leaves?.isNotEmpty ?? false);
  bool _isSubmitted = false;
  bool isSubmitting = false;
  DivElement get divSubmit => root.querySelector('core-toolbar div#submit');
  CoreDropdown get dropdownSubmit => divSubmit.querySelector('core-dropdown');

  toast(String msg, [Duration dur = const Duration(seconds: 8)]) =>
      root.querySelector('#submit paper-toast') as PaperToast
        ..classes.remove('fit-bottom')
        ..duration = dur.inMilliseconds
        ..text = msg
        ..show();

  submit(bool publish) => rippling(() async {
        _logger.finest("Submitting report: ${report}");
        dropdownSubmit.close();
        isSubmitting = true;

        doit(String name, Future proc()) async {
          try {
            await proc();
            return true;
          } catch (ex) {
            _logger.warning(() => "Failed to ${name}: ${ex}");
            alertDialog.value
              ..message = "Failed to ${name} your report. Please try again later."
              ..open();
            return false;
          }
        }

        try {
          _isSubmitted = await doit('add', () => Reports.add(report));
          if (_isSubmitted) {
            FabricAnswers.eventCustom(name: 'AddReportPage.Submit');
          }
          if (_isSubmitted && publish) {
            confirmDialog.value
              ..message = "Publish to Facebook ?"
              ..onClossing(() async {
                if (confirmDialog.value.result) {
                  final published = await doit('publish', () => FBPublish.publish(report));
                  if (published) {
                    try {
                      toast("Completed on publishing to Facebook");
                      await Reports.update(report);
                    } catch (ex) {
                      _logger.warning(() => "Failed to update published id: ${ex}");
                    }
                  }
                }
              })
              ..open();
          }
        } catch (ex) {
          _logger.warning(() => "Error on submitting: ${ex}");
        } finally {
          isSubmitting = false;
          if (_isSubmitted) back();
        }
      });
}

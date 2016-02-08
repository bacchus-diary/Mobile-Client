library bacchus_diary.page.reports_add;

import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:core_elements/core_header_panel.dart';
import 'package:core_elements/core_animation.dart';
import 'package:core_elements/core_dropdown.dart';
import 'package:paper_elements/paper_toast.dart';

import 'package:bacchus_diary/element/expandable_gmap.dart';
import 'package:bacchus_diary/element/showcase.dart';
import 'package:bacchus_diary/dialog/alert.dart';
import 'package:bacchus_diary/dialog/photo_way.dart';
import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/model/location.dart';
import 'package:bacchus_diary/service/facebook.dart';
import 'package:bacchus_diary/service/preferences.dart';
import 'package:bacchus_diary/service/reports.dart';
import 'package:bacchus_diary/service/googlemaps_browser.dart';
import 'package:bacchus_diary/service/aws/s3file.dart';
import 'package:bacchus_diary/util/blinker.dart';
import 'package:bacchus_diary/util/enums.dart';
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
  final Getter<AlertDialog> alertDialog = new PipeValue();

  @override
  void onShadowRoot(ShadowRoot sr) {
    super.onShadowRoot(sr);
    FabricAnswers.eventContentView(contentName: "AddReportPage");

    report = new Report.fromMap({
      'location': {},
      'condition': {'moon': {}, 'weather': {}}
    });
  }

  List<Leaf> get leaves => report.leaves;

  //********************************
  // Photo View Size

  int _photoWidth;
  int get photoWidth {
    if (_photoWidth == null) {
      final div = root.querySelector('#photo');
      if (div != null) _photoWidth = div.clientWidth;
    }
    return _photoWidth;
  }

  int get photoHeight => photoWidth == null ? null : (photoWidth * 2 / 3).round();

  //********************************
  // Edit Catches

  String addingFishName;

  _fishNameBlinkArea() => [root.querySelector('#catches .control .fish-name input')];
  static const fishNameBlinkDuration = const Duration(milliseconds: 350);
  static const fishNameBlinkUpDuration = const Duration(milliseconds: 100);
  static const fishNameBlinkDownDuration = const Duration(milliseconds: 100);
  static const fishNameBlinkFrames = const [
    const {'background': "transparent"},
    const {'background': "#fee"}
  ];

  addFish() {
    if (addingFishName != null && addingFishName.isNotEmpty) {
      final fish = new Fishes.fromMap({'name': addingFishName, 'count': 1});
      addingFishName = null;
      report.fishes.add(fish);
      FabricAnswers.eventCustom(name: 'AddReportPage.AddFish');
    } else {
      final blinker = new Blinker(fishNameBlinkUpDuration, fishNameBlinkDownDuration,
          [new BlinkTarget(new Getter(_fishNameBlinkArea), fishNameBlinkFrames)]);
      blinker.start();
      new Future.delayed(fishNameBlinkDuration, () {
        blinker.stop();
      });
    }
  }

  editFish(int index) {
    if (0 <= index && index < report.fishes.length) {
      fishDialog.value.openWith(new GetterSetter(() => report.fishes[index], (v) {
        if (v == null) {
          report.fishes..removeAt(index);
        } else {
          report.fishes..[index] = v;
        }
      }));
    }
  }

  //********************************
  // Submit

  back() {
    if (!isSubmitting) {
      if (!_isSubmitted && report != null) {
        FabricAnswers.eventCustom(name: 'AddReportPage.CancelReport');
        delete(path) async {
          try {
            await S3File.delete(path);
          } catch (ex) {
            _logger.warning(() => "Failed to delete on S3(${path}): ${ex}");
          }
        }
        report.photo.original.storagePath.then(delete);
        new Future.delayed(new Duration(minutes: 1), () {
          report.photo.reduced..mainview.storagePath.then(delete)..thumbnail.storagePath.then(delete);
        });
      }
      super.back();
    }
  }

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

  void _submitable() {
    FabricAnswers.eventCustom(name: 'AddReportPage.Submitable');
    _logger.fine("Appearing submit button");
    final x = document.body.clientWidth;
    final y = (x / 5).round();
    new CoreAnimation()
      ..target = (divSubmit.querySelector('.action')..style.display = 'block')
      ..duration = 300
      ..fill = "both"
      ..keyframes = [
        {'transform': "translate(-${x}px, ${y}px)", 'opacity': '0'},
        {'transform': "none", 'opacity': '1'}
      ]
      ..play();
  }

  submit(bool publish) => rippling(() async {
        _logger.finest("Submitting report: ${report}");
        dropdownSubmit.close();
        if (report.location.name == null || report.location.name.isEmpty) report.location.name = "My Spot";
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
            final published = await doit('publish', () => FBPublish.publish(report));
            if (published)
              try {
              toast("Completed on publishing to Facebook");
              await Reports.update(report);
            } catch (ex) {
              _logger.warning(() => "Failed to update published id: ${ex}");
            }
          }
        } catch (ex) {
          _logger.warning(() => "Error on submitting: ${ex}");
        } finally {
          isSubmitting = false;
          if (_isSubmitted) back();
        }
      });
}

class _GMap {
  final ShadowRoot _root;
  final GetterSetter<String> spotName;
  final GetterSetter<GeoInfo> _geoinfo;
  GeoInfo get geoinfo => _geoinfo.value;
  Getter<Element> getScroller;
  Getter<Element> getBase;
  final FuturedValue<ExpandableGMapElement> gmapElement = new FuturedValue();
  final FuturedValue<GoogleMap> setGMap = new FuturedValue();

  _GMap(this._root, this.spotName, this._geoinfo) {
    getBase = new Getter<Element>(() => _root.querySelector('#input'));
    getScroller = new Getter<Element>(() {
      final panel = _root.querySelector('core-header-panel[main]') as CoreHeaderPanel;
      return (panel == null) ? null : panel.scroller;
    });

    gmapElement.future.then((elem) {
      elem
        ..onExpanding = (gmap) {
          gmap
            ..showMyLocationButton = true
            ..options.draggable = true
            ..options.disableDoubleClickZoom = false;
        }
        ..onShrinking = (gmap) {
          gmap
            ..showMyLocationButton = false
            ..options.draggable = false
            ..options.disableDoubleClickZoom = true;
        };
    });

    setGMap.future.then((gmap) {
      gmap
        ..putMarker(_geoinfo.value)
        ..options.draggable = false
        ..onClick = (pos) {
          _logger.fine("Point map: ${pos}");
          _geoinfo.value = pos;
          gmap.clearMarkers();
          gmap.putMarker(pos);
        };
    });
  }
}

class _Conditions {
  final ShadowRoot _root;
  final Getter<Condition> _condition;
  final Getter<EditWeatherDialog> weatherDialog = new PipeValue();
  final Getter<EditTideDialog> tideDialog = new PipeValue();

  _Conditions(this._root, this._condition);

  Condition get value => _condition.value;

  dialogTide() => tideDialog.value.open();
  dialogWeather() => weatherDialog.value.open();

  String get weatherName => value.weather?.nominal;
  String get weatherImage => value.weather?.iconUrl;
  String get tideName => value.tide == null ? null : nameOfEnum(value.tide);
  String get tideImage => tideName == null ? null : Tides.iconBy(tideName);
  String get moonImage => _condition.value?.moon?.image;
}

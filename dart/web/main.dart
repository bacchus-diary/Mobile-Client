library bacchus_diary;

import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'package:bacchus_diary/router.dart';
import 'package:bacchus_diary/formatter/fish_formatter.dart';
import 'package:bacchus_diary/formatter/temperature_formatter.dart';
import 'package:bacchus_diary/formatter/tide_formatter.dart';
import 'package:bacchus_diary/dialog/alert.dart';
import 'package:bacchus_diary/dialog/confirm.dart';
import 'package:bacchus_diary/dialog/distributions_filter.dart';
import 'package:bacchus_diary/dialog/edit_fish.dart';
import 'package:bacchus_diary/dialog/edit_timestamp.dart';
import 'package:bacchus_diary/dialog/edit_tide.dart';
import 'package:bacchus_diary/dialog/edit_weather.dart';
import 'package:bacchus_diary/dialog/geolocation.dart';
import 'package:bacchus_diary/dialog/photo_way.dart';
import 'package:bacchus_diary/element/distributions_filter.dart';
import 'package:bacchus_diary/element/fit_image.dart';
import 'package:bacchus_diary/element/float_buttons.dart';
import 'package:bacchus_diary/element/calendar.dart';
import 'package:bacchus_diary/element/choose_list.dart';
import 'package:bacchus_diary/element/collapser.dart';
import 'package:bacchus_diary/element/expandable_gmap.dart';
import 'package:bacchus_diary/element/expandable_text.dart';
import 'package:bacchus_diary/element/num_input.dart';
import 'package:bacchus_diary/element/infinite_scroll.dart';
import 'package:bacchus_diary/page/acceptance.dart';
import 'package:bacchus_diary/page/add_report.dart';
import 'package:bacchus_diary/page/reports_list.dart';
import 'package:bacchus_diary/page/report_detail.dart';
import 'package:bacchus_diary/page/preferences.dart';
import 'package:bacchus_diary/page/distributions.dart';
import 'package:bacchus_diary/util/fabric.dart';
import 'package:bacchus_diary/util/cordova.dart';
import 'package:bacchus_diary/util/resource_url_resolver_cordova.dart';

import 'package:angular/angular.dart';
import 'package:angular/application_factory.dart';
import 'package:angular/core_dom/static_keys.dart';
import 'package:logging/logging.dart';
import 'package:polymer/polymer.dart';

class AppExceptionHandler extends ExceptionHandler {
  call(dynamic error, dynamic stack, [String reason = '']) async {
    recordEvent(error);
    await dialog(error);
    final msg = ["$error", reason, stack].join("\n");
    FabricCrashlytics.crash(msg);
  }

  recordEvent(error) {
    final prefix = "Fatal Exception: ";
    var text = "$error";
    if (text.startsWith(prefix)) {
      text = text.substring(prefix.length);
    }
    final parts = text.split(":").map((x) => x.trim()).toList();
    final titles = parts.takeWhile((x) => !x.contains(" "));
    final descs = titles.isEmpty ? parts : parts.sublist(titles.length - 1);
    final desc = descs.join(": ");
    FabricAnswers.eventCustom(name: "Crash", attributes: {'desc': desc});
  }

  Future<Null> dialog(error) async {
    final result = new Completer();

    final text = "$error";
    getMessage() {
      if (text.contains("Network Failure")) {
        return "Network Failure";
      } else {
        return "Unrecoverable Error";
      }
    }

    context['navigator']['notification']?.callMethod('alert', [
      getMessage(),
      (_) {
        result.complete();
      },
      "Application Stop",
      "STOP"
    ]);
    return result.future;
  }
}

class AppModule extends Module {
  AppModule() {
    bind(FishFormatter);
    bind(TemperatureFormatter);
    bind(TideFormatter);

    bind(AlertDialog);
    bind(ConfirmDialog);
    bind(DistributionsFilterDialog);
    bind(EditFishDialog);
    bind(EditTimestampDialog);
    bind(EditTideDialog);
    bind(EditWeatherDialog);
    bind(GeolocationDialog);
    bind(PhotoWayDialog);

    bind(DistributionsFilterElement);
    bind(FitImageElement);
    bind(FloatButtonsElement);
    bind(CalendarElement);
    bind(ChooseListElement);
    bind(CollapserElement);
    bind(ExpandableGMapElement);
    bind(ExpandableTextElement);
    bind(NumInputElement);
    bind(InfiniteScrollElement);

    bind(AcceptancePage);
    bind(AddReportPage);
    bind(ReportsListPage);
    bind(ReportDetailPage);
    bind(PreferencesPage);
    bind(DistributionsPage);

    bind(RouteInitializerFn, toValue: getRouteInitializer);
    bind(NgRoutingUsePushState, toValue: new NgRoutingUsePushState.value(false));
    bind(ResourceResolverConfig, toValue: new ResourceResolverConfig.resolveRelativeUrls(false));
    bind(ResourceUrlResolver, toImplementation: ResourceUrlResolverCordova);

    bindByKey(EXCEPTION_HANDLER_KEY, toValue: new AppExceptionHandler());
  }
}

void main() {
  Logger.root
    ..level = Level.FINEST
    ..onRecord.listen((record) {
      if (isCordova) {
        FabricCrashlytics.log("${record}");
      } else {
        window.console.log("${record.time} ${record}");
      }
    });

  try {
    onDeviceReady((event) {
      try {
        initPolymer().then((zone) {
          zone.run(() {
            Polymer.onReady.then((_) {
              applicationFactory().addModule(new AppModule()).run();
              document.querySelector('#app-loading').style.display = 'none';
            });
          });
        });
      } catch (ex) {
        FabricCrashlytics.crash("Error on initPolymer: $ex");
      }
    });
  } catch (ex) {
    window.alert("Error ${ex}");
    FabricCrashlytics.crash("Error onDeviceReady: $ex");
  }
}

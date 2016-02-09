library tiroton_note.formatter.temperature;

import 'package:angular/angular.dart';

import 'package:bacchus_diary/model/value_unit.dart';
import 'package:bacchus_diary/service/preferences.dart';
import 'package:bacchus_diary/util/enums.dart';

@Formatter(name: 'temperatureFilter')
class TemperatureFormatter {
  static Measures _measures;

  TemperatureFormatter() {
    if (_measures == null) UserPreferences.current.then((c) => _measures = c.measures);
  }

  String call(Temperature src, [int digits = 0]) {
    if (_measures == null) return null;

    final dst = src.convertTo(_measures.temperature);
    return "${round(dst.value, digits)} °${nameOfEnum(dst.unit)[0]}";
  }
}

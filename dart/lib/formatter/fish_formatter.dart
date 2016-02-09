library tiroton_note.formatter.fish;

import 'package:angular/angular.dart';

import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/model/value_unit.dart';
import 'package:bacchus_diary/service/preferences.dart';
import 'package:bacchus_diary/util/enums.dart';

@Formatter(name: 'fishFilter')
class FishFormatter {
  static Measures _measures;

  FishFormatter() {
    if (_measures == null) UserPreferences.current.then((c) => _measures = c.measures);
  }

  String call(Fishes fish, [int digits = 0]) {
    if (_measures == null) return null;

    final length = fish.length == null ? null : fish.length.convertTo(_measures.length);
    final weight = fish.weight == null ? null : fish.weight.convertTo(_measures.weight);

    String rounded(ValueUnit vu) => "${round(vu.value, digits)} ${nameOfEnum(vu.unit)}";

    final sizesList = [weight, length].where((a) => a != null && a.value != null && a.value > 0).map(rounded);
    final sizes = sizesList.isEmpty ? '' : " (${sizesList.join(', ')})";
    return "${fish.name}${sizes} x ${fish.count}";
  }
}

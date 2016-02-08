library tiroton_note.formatter.tide;

import 'package:angular/angular.dart';

import 'package:bacchus_diary/model/location.dart';
import 'package:bacchus_diary/util/enums.dart';

@Formatter(name: 'tideFilter')
class TideFormatter {
  String call(Tide src) {
    return nameOfEnum(src);
  }
}

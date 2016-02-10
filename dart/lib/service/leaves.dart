library bacchus_diary.service.leaves;

import 'package:logging/logging.dart';

import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/service/aws/dynamodb.dart';
import 'package:bacchus_diary/service/reports.dart';
import 'package:bacchus_diary/util/pager.dart';

final _logger = new Logger('Leaves');

class Leaves {
  static Pager<Leaf> byWords(List<String> words) {
    final map = new ExpressionMap();

    final nameContent = map.putName('CONTENT');
    final nameDesc = map.putName('description');

    final exp = words.map((word) => "${nameContent}.${nameDesc} CONTAINS ${map.putValue(word)}").join(' AND ');

    return Reports.TABLE_LEAF.scanPager(exp, map.names, map.values);
  }

  static Pager<Leaf> byDescription(String desc) {
    final map = new ExpressionMap();

    final nameContent = map.putName('CONTENT');
    final nameDesc = map.putName('description');
    final valueDesc = map.putValue(desc);

    final exp1 = "${nameContent}.${nameDesc} CONTAINS ${valueDesc}";
    final exp2 = "${valueDesc} CONTAINS ${nameContent}.${nameDesc}";
    final exp = [exp1, exp2].join(' OR ');

    return Reports.TABLE_LEAF.scanPager(exp, map.names, map.values);
  }
}

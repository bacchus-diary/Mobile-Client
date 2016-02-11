library bacchus_diary.service.leaves;

import 'dart:async';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/service/aws/cognito.dart';
import 'package:bacchus_diary/service/aws/dynamodb.dart';
import 'package:bacchus_diary/service/reports.dart';
import 'package:bacchus_diary/util/pager.dart';

final _logger = new Logger('Leaves');

class Leaves {
  static Future<Pager<Leaf>> byWords(List<String> words) async {
    final map = new ExpressionMap();

    final nameContent = map.putName(DynamoDB.CONTENT);
    final nameDesc = map.putName('description');

    final list = ["${map.putName(DynamoDB.COGNITO_ID)} = ${map.putValue(await cognitoId)}"];
    list.addAll(words.map((word) => "contains (${nameContent}.${nameDesc}, ${map.putValue(word)})"));
    final exp = list.join(' AND ');

    return Reports.TABLE_LEAF.scanPager(exp, map.names, map.values);
  }

  static Pager<Leaf> byDescription(String desc) {
    final map = new ExpressionMap();

    final nameContent = map.putName(DynamoDB.CONTENT);
    final nameDesc = map.putName('description');
    final valueDesc = map.putValue(desc);

    final exp = "contains (${nameContent}.${nameDesc}, ${valueDesc})";

    return Reports.TABLE_LEAF.scanPager(exp, map.names, map.values);
  }
}

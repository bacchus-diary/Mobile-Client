library bacchus_diary.model.report;

import 'dart:convert';

import 'package:bacchus_diary/model/_json_support.dart';
import 'package:bacchus_diary/model/value_unit.dart';
import 'package:bacchus_diary/model/photo.dart';
import 'package:bacchus_diary/model/location.dart';
import 'package:bacchus_diary/service/aws/dynamodb.dart';

abstract class Report implements DBRecord<Report> {
  String comment;
  DateTime dateAt;
  Published published;
  Location location;
  Condition condition;
  final List<Leaf> leaves;

  factory Report.fromMap(Map data) => new _ReportImpl(data, DynamoDB.createRandomKey(), new DateTime.now(), []);

  factory Report.fromData(Map data, String id, DateTime dateAt) => new _ReportImpl(data, id, dateAt, []);
}

class _ReportImpl implements Report {
  final Map _data;
  final CachedProp<Published> _published;
  final CachedProp<Location> _location;
  final CachedProp<Condition> _condition;

  _ReportImpl(Map data, String id, this.dateAt, this.leaves)
      : _data = data,
        this.id = id,
        _published = new CachedProp<Published>.forMap(data, 'published', (map) => new Published.fromMap(map)),
        _location = new CachedProp<Location>.forMap(data, 'location', (map) => new Location.fromMap(map)),
        _condition = new CachedProp<Condition>.forMap(data, 'condition', (map) => new Condition.fromMap(map));

  String get _mapString => JSON.encode(_data);
  Map toMap() => JSON.decode(_mapString);

  final String id;
  DateTime dateAt;

  String get comment => _data['comment'];
  set comment(String v) => _data['comment'] = v;

  Published get published => _published.value;
  set published(Published v) => _published.value = v;

  Location get location => _location.value;
  set location(Location v) => _location.value = v;

  Condition get condition => _condition.value;
  set condition(Condition v) => _condition.value = v;

  final List<Leaf> leaves;

  @override
  String toString() => "${_data}, id=${id}, dateAt=${dateAt},  leaves=${leaves}";

  bool isNeedUpdate(Report other) {
    if (other is _ReportImpl) {
      return this._mapString != other._mapString || this.dateAt != other.dateAt;
    } else {
      throw "Unrecognized obj: ${other}";
    }
  }

  Report clone() => new _ReportImpl(toMap(), id, dateAt, fishes.map((o) => o.clone()).toList());
}

abstract class Published implements JsonSupport {
  String facebook;

  factory Published.fromMap(Map data) => new _PublishedImpl(data);
}

class _PublishedImpl extends JsonSupport implements Published {
  final Map _data;

  _PublishedImpl(Map data) : _data = data;

  Map get asMap => _data;

  String get facebook => _data['facebook'];
  set facebook(String v) => _data['facebook'] = v;
}

abstract class Leaf implements DBRecord<Leaf> {
  String reportId;
  final Photo photo;
  final String id;
  String description;

  factory Leaf.fromMap(String reportId, Map data) => new _LeafImpl(data, DynamoDB.createRandomKey(), reportId);

  factory Leaf.fromData(Map data, String id, String reportId) => new _LeafImpl(data, id, reportId);
}

class _LeafImpl implements Leaf {
  final Map _data;

  _LeafImpl(Map data, String id, String reportId)
      : _data = data,
        this.id = id,
        this.reportId = reportId,
        photo = new Photo(reportId, id);

  String get _mapString => JSON.encode(_data);
  Map toMap() => JSON.decode(_mapString);

  String reportId;
  final String id;
  final Photo photo;

  String get description => _data['description'];
  set description(String v) => _data['description'] = v;

  @override
  String toString() => "${_data}, id=${id}, reportId=${reportId}";

  bool isNeedUpdate(Leaf other) {
    if (other is _LeafImpl) {
      return this._mapString != other._mapString || this.reportId != other.reportId;
    } else {
      throw "Unrecognized obj: ${other}";
    }
  }

  Leaf clone() => new _LeafImpl(toMap(), id, reportId);
}

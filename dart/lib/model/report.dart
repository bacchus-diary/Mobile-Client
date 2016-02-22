library bacchus_diary.model.report;

import 'dart:convert';

import 'package:bacchus_diary/model/_json_support.dart';
import 'package:bacchus_diary/model/photo.dart';
import 'package:bacchus_diary/service/aws/dynamodb.dart';

abstract class Report implements DBRecord<Report> {
  static const COMMENT_UPPER = 'comment_upper';

  int rating;
  String comment;
  DateTime dateAt;
  Published published;
  final List<Leaf> leaves;

  factory Report.fromMap(Map data) => new _ReportImpl(data, DynamoDB.createRandomKey(), new DateTime.now(), []);

  factory Report.fromData(Map data, String id, DateTime dateAt) => new _ReportImpl(data, id, dateAt, []);
}

class _ReportImpl implements Report {
  final Map _data;
  final CachedProp<Published> _published;

  _ReportImpl(Map data, String id, this.dateAt, this.leaves)
      : _data = data,
        this.id = id,
        _published = new CachedProp<Published>.forMap(data, 'published', (map) => new Published.fromMap(map));

  String get _mapString => JSON.encode(_data);
  Map toMap() => JSON.decode(_mapString);

  final String id;
  DateTime dateAt;

  int get rating => _data['rating'];
  set rating(int v) => _data['rating'] = v;

  String get comment => _data['comment'];
  set comment(String v) {
    _data[Report.COMMENT_UPPER] = v.toUpperCase();
    _data['comment'] = v;
  }

  Published get published => _published.value;
  set published(Published v) => _published.value = v;

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

  Report clone() => new _ReportImpl(toMap(), id, dateAt, leaves.map((o) => o.clone()).toList());
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
  static const DESCRIPTION_UPPER = 'description_upper';

  String reportId;
  final Photo photo;
  final String id;
  String description;

  factory Leaf.fromMap(String reportId, Map data) => new _LeafImpl(data, DynamoDB.createRandomKey(), reportId);

  factory Leaf.fromData(Map data, String id, String reportId) => new _LeafImpl(data, id, reportId);
}

class _LeafImpl implements Leaf {
  final Map _data;

  _LeafImpl(Map data, String id, String reportId, [Photo photo])
      : _data = data,
        this.id = id,
        this.reportId = reportId,
        this.photo = photo ?? new Photo(reportId, id);

  String get _mapString => JSON.encode(_data);
  Map toMap() => JSON.decode(_mapString);

  String reportId;
  final String id;
  final Photo photo;

  String get description => _data['description'];
  set description(String v) {
    _data[Leaf.DESCRIPTION_UPPER] = v.toUpperCase();
    _data['description'] = v;
  }

  @override
  String toString() => "${_data}, id=${id}, reportId=${reportId}";

  bool isNeedUpdate(Leaf other) {
    if (other is _LeafImpl) {
      return this._mapString != other._mapString || this.reportId != other.reportId;
    } else {
      throw "Unrecognized obj: ${other}";
    }
  }

  Leaf clone() => new _LeafImpl(toMap(), id, reportId, photo);
}

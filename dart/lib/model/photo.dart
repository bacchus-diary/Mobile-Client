library bacchus_diary.model.photo;

import 'dart:async';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/service/aws/cognito.dart';
import 'package:bacchus_diary/service/aws/s3file.dart';
import 'package:bacchus_diary/settings.dart';

final _logger = new Logger('Photo');

class Photo {
  static Future<Null> moveCognitoId(String previous, String current) async {
    final waiters = [ReducedImages.PATH_ORIGINAL, ReducedImages.PATH_MAINVIEW, ReducedImages.PATH_THUMBNAIL]
        .map((relativePath) async {
      final prefix = "photo/${relativePath}/${previous}/";
      final next = "photo/${relativePath}/${current}/";
      _logger.finest(() => "Moving cognito id: ${prefix} -> ${next}");

      final srcList = await S3File.list(prefix);
      final dones = srcList.map((src) => S3File.move(src, "${next}${src.substring(prefix.length)}"));
      return Future.wait(dones);
    });
    await Future.wait(waiters);
  }

  final Image original;
  final ReducedImages reduced;

  Photo(String reportId, String id)
      : original = new Image(reportId, id, ReducedImages.PATH_ORIGINAL),
        reduced = new ReducedImages(reportId, id);

  delete() async {
    del(Image image) async {
      final path = await image.storagePath;
      try {
        await S3File.delete(path);
      } catch (ex) {
        _logger.warning(() => "Failed to delete on S3(${path}): ${ex}");
      }
    }
    del(original);
    new Future.delayed(new Duration(seconds: 10), () {
      del(reduced.mainview);
      del(reduced.thumbnail);
    });
  }
}

class ReducedImages {
  static const _PATH_REDUCED = 'reduced';

  static const PATH_ORIGINAL = 'original';
  static const PATH_MAINVIEW = "${_PATH_REDUCED}/mainview";
  static const PATH_THUMBNAIL = "${_PATH_REDUCED}/thumbnail";

  final Image mainview;
  final Image thumbnail;

  ReducedImages(String reportId, String id)
      : mainview = new Image(reportId, id, PATH_MAINVIEW),
        thumbnail = new Image(reportId, id, PATH_THUMBNAIL);
}

class Image {
  static const _localTimeout = const Duration(minutes: 10);
  static const _refreshInterval = const Duration(minutes: 1);

  final _IntervalKeeper _refresher = new _IntervalKeeper(_refreshInterval);
  final String _reportId;
  final String _name;
  final String relativePath;
  String _url;

  Image(this._reportId, this._name, this.relativePath);

  Future<String> get storagePath async => "photo/${relativePath}/${await cognitoId}/${_reportId}/${_name}.jpg";

  Future<String> makeUrl() async => S3File.url(await storagePath);

  String get url {
    _refreshUrl();
    return _url;
  }

  set url(String v) {
    _url = v;
    if (v.startsWith('http')) {
      Settings.then((s) {
        final v = s.photo.urlTimeout.inSeconds * 0.9;
        _clearUrl(new Duration(seconds: v.round()));
      });
    } else {
      _clearUrl(_localTimeout);
    }
  }

  _clearUrl(Duration dur) => new Future.delayed(dur, () {
        _url = null;
      });

  _refreshUrl() {
    if (_url == null)
      _refresher.go(() async {
      try {
        url = await makeUrl();
      } catch (ex) {
        _logger.info("Failed to get url of s3file: ${ex}");
      }
    });
  }
}

class _IntervalKeeper {
  final Duration interval;
  DateTime _limit;
  bool _isGoing = false;

  _IntervalKeeper(this.interval);

  bool get canGo => !_isGoing && (_limit == null || _limit.isBefore(new DateTime.now()));

  go(Future something()) async {
    if (canGo) {
      _isGoing = true;
      try {
        await something();
      } finally {
        _isGoing = false;
        _limit = new DateTime.now().add(interval);
      }
    }
  }
}

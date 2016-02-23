library bacchus_diary.service.aws.s3file;

import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/settings.dart';
import 'package:bacchus_diary/util/retry_routin.dart';

final _logger = new Logger('S3File');

class S3File {
  static const RETRYER = const Retry("Invoke S3File", 2, const Duration(seconds: 3));
  static final _s3 = new JsObject(context['AWS']['S3'], []);

  static Future _call(String methodName, Map params, [List opts = null]) async {
    final arging = opts ?? [];
    if (params['Bucket'] == null) {
      params['Bucket'] = (await Settings).s3Bucket;
    }
    _logger.fine(() => "Invoking S3.${methodName}: ${arging}, ${params}");
    arging.add(new JsObject.jsify(params));
    final args = new List.unmodifiable(arging);

    return RETRYER.loop(() {
      final result = new Completer();
      try {
        _s3.callMethod(
            methodName,
            new List.from(args)
              ..add((error, data) {
                if (error == null) {
                  _logger.fine(() => "Success on S3.${methodName}");
                  result.complete(data);
                } else {
                  _logger.warning(() => "Error on S3.${methodName}: ${error}");
                  result.completeError(error);
                }
              }));
      } catch (ex) {
        _logger.warning(() => "Failed to call ${methodName}: ${ex}");
        result.completeError(ex);
      }
      return result.future;
    });
  }

  static Future<String> url(String path) async {
    final params = {"Key": path, 'Expires': (await Settings).photo.urlTimeout.inSeconds};
    return _call('getSignedUrl', params, ["getObject"]);
  }

  static Future<String> read(String path, [String bucket = null]) async {
    final data = await _call('getObject', {'Bucket': bucket, 'Key': path});
    final body = data['Body'];
    return new String.fromCharCodes(body);
  }

  static Future<Null> putObject(String path, Blob data) async {
    final params = {'Key': path, 'Body': data};
    if (data.type != null) {
      params['ContentType'] = data.type;
    }
    await _call('putObject', params);
  }

  static Future<List<String>> list(String path) async {
    final data = await _call('listObjects', {'Prefix': path});
    return data['Contents'].map((obj) => obj['Key']);
  }

  static Future<Null> copy(String src, String dst) async {
    await _call('copyObject', {'CopySource': "${(await Settings).s3Bucket}/${src}", 'Key': dst});
  }

  static Future<Null> delete(String path) async {
    await _call('deleteObject', {'Key': path});
  }

  static Future<Null> move(String src, dst) async {
    await copy(src, dst);
    await delete(src);
  }
}

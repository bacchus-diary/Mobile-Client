library bacchus_diary.util.file_reader;

import 'dart:async';
import 'dart:html';
import 'dart:js';
import 'dart:typed_data';

import 'package:logging/logging.dart';

final _logger = new Logger('FileReader');

Future<Blob> readAsBlob(String uri, [String type]) {
  _logger.finest(() => "Reading URI into Blob: ${uri}");
  final result = new Completer();

  context.callMethod('resolveLocalFileSystemURL', [
    uri,
    (entry) {
      _logger.finest(() => "Reading entry of uri: ${entry}");
      entry.callMethod('file', [
        (file) async {
          final list = await readAsList(file);
          final blob = new Blob([new Uint8List.fromList(list)], type);
          _logger.finest(() => "Read uri as blob: ${blob}(${blob.size})");
          result.complete(blob);
        },
        (error) {
          result.completeError("Failed to get file of uri: ${error}");
        }
      ]);
    },
    (error) {
      result.completeError("Failed to read uri: ${error}");
    }
  ]);

  return result.future;
}

Future<List<int>> readAsList(Blob blob) async {
  _logger.finest(() => "Reading Blob into List: ${blob}");

  final arrayBuffer = await fileReader_readAsArrayBuffer(blob);
  final uint8 = new JsObject(context['Uint8Array'], [arrayBuffer]);
  _logger.finest(() => "Converting to List<int>: ${uint8}");
  final list = new List<int>.generate(uint8['length'], (index) => uint8[index]);
  _logger.finest(() => "Read blob data: ${list.length}");
  return list;
}

Future<Object> fileReader_readAsArrayBuffer(blob) {
  _logger.finest(() =>
      "Reading data from: ${blob}, JsObject?${blob is JsObject}, Blob?${(blob is JsObject)? blob.instanceof(context['Blob']):(blob is Blob)}");
  final result = new Completer();

  final reader = new FileReader();

  reader.onLoadEnd.listen((_) {
    result.complete(reader.result);
  });
  reader.onError.listen((event) {
    result.completeError(event);
  });

  reader.readAsArrayBuffer(blob);

  return result.future;
}

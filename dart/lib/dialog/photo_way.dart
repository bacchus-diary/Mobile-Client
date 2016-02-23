library bacchus_diary.dialog.photo_way;

import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:paper_elements/paper_dialog.dart';

import 'package:bacchus_diary/util/cordova.dart';
import 'package:bacchus_diary/util/getter_setter.dart';
import 'package:bacchus_diary/util/main_frame.dart';

final _logger = new Logger('PhotoWayDialog');

@Component(
    selector: 'photo-way-dialog', templateUrl: 'packages/bacchus_diary/dialog/photo_way.html', useShadowDom: true)
class PhotoWayDialog extends AbstractDialog implements ShadowRootAware {
  @NgOneWayOneTime('setter') set setter(Setter<PhotoWayDialog> v) => v?.value = this; // Optional

  ShadowRoot _root;
  CachedValue<PaperDialog> _dialog;
  PaperDialog get realDialog => _dialog.value;

  bool get isBrawser => !isCordova;

  File file = null;
  bool take = null;

  void onShadowRoot(ShadowRoot sr) {
    _root = sr;
    _dialog = new CachedValue(() => _root.querySelector('paper-dialog'));
  }

  done(bool v) {
    if (v != null) {
      take = v;
    } else {
      final fileInput = realDialog.querySelector("#fileInput") as InputElement;
      final files = fileInput.files;
      if (files.isNotEmpty) {
        file = files.first;
      }
    }
    close();
  }

  Future<File> chooseFile() {
    final result = new Completer<File>();
    try {
      final fileChooser = document.querySelector("div#options #fileChooser") as PaperDialog;
      _logger.fine("Toggle dialog: ${fileChooser}");
      fileChooser.toggle();
    } catch (ex) {
      result.completeError(ex);
    }
    return result.future;
  }

  start(proc(bool takeValue, Blob fileValue)) async {
    onClossing(() {
      proc(take, file);
    });
    open();
  }
}

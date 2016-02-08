library bacchus_diary.dialog.photo_way;

import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:paper_elements/paper_dialog.dart';

import 'package:bacchus_diary/util/getter_setter.dart';
import 'package:bacchus_diary/util/main_frame.dart';

final _logger = new Logger('PhotoWayDialog');

@Component(selector: 'photo-way-dialog', templateUrl: 'packages/bacchus_diary/dialog/photo_way.html', useShadowDom: true)
class PhotoWayDialog extends AbstractDialog implements ShadowRootAware {
  @NgOneWayOneTime('setter') Setter<PhotoWayDialog> setter;

  ShadowRoot _root;
  CachedValue<PaperDialog> _dialog;
  PaperDialog get realDialog => _dialog.value;

  String message;
  bool take = null;

  void onShadowRoot(ShadowRoot sr) {
    _root = sr;
    _dialog = new CachedValue(() => _root.querySelector('paper-dialog'));
    setter.value = this;
  }

  done(bool v) {
    take = v;
    close();
  }
}

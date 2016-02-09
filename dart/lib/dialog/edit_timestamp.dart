library bacchus_diary.dialog.edit_timestamp;

import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:paper_elements/paper_dialog.dart';

import 'package:bacchus_diary/element/calendar.dart';
import 'package:bacchus_diary/util/getter_setter.dart';
import 'package:bacchus_diary/util/main_frame.dart';

final _logger = new Logger('EditTimestampDialog');

@Component(
    selector: 'edit-timestamp-dialog',
    templateUrl: 'packages/bacchus_diary/dialog/edit_timestamp.html',
    useShadowDom: true)
class EditTimestampDialog extends AbstractDialog implements ShadowRootAware {
  @NgOneWayOneTime('setter') set setter(Setter<EditTimestampDialog> v) => v?.value = this; // Optional
  @NgTwoWay('value') DateTime value;
  @NgAttr('without-oclock') String withoutOclock;

  ShadowRoot _root;
  bool get withOclock => withoutOclock == null || withoutOclock.toLowerCase() == "false";
  int tmpOclock = 0;
  DateTime tmpDate = new DateTime.now();
  CachedValue<Element> _calendar;
  CachedValue<PaperDialog> _dialog;
  PaperDialog get realDialog => _dialog.value;

  void onShadowRoot(ShadowRoot sr) {
    _root = sr;
    _dialog = new CachedValue(() => _root.querySelector('paper-dialog#timestamp-dialog'));
    _calendar = new CachedValue(() => _root.querySelector('calendar'));

    onOpening(() {
      tmpOclock = value.hour;
      tmpDate = new DateTime(value.year, value.month, value.day);
      _calendar.value.dispatchEvent(new CustomEvent(CalendarElement.REFRESH));
    });
  }

  commit() {
    close();
    value = new DateTime(tmpDate.year, tmpDate.month, tmpDate.day, tmpOclock);
  }

  cancel() {
    close();
  }
}

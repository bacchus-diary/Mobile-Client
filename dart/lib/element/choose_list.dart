library bacchus_diary.element.choose_list;

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';

import 'package:bacchus_diary/util/getter_setter.dart';

final _logger = new Logger('ChooseListElement');

@Component(
    selector: 'choose-list',
    templateUrl: 'packages/bacchus_diary/element/choose_list.html',
    cssUrl: 'packages/bacchus_diary/element/choose_list.css',
    useShadowDom: true)
class ChooseListElement {
  @NgOneWayOneTime('setter') set setter(Setter<ChooseListElement> v) => v?.value = this; // Optional
  @NgTwoWay('value') String value;
  @NgOneWay('list') List<String> list;
}

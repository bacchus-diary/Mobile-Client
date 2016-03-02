library bacchus_diary.element.suggestions;

import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';

import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/service/suggestions.dart';
import 'package:bacchus_diary/util/getter_setter.dart';
import 'package:bacchus_diary/util/main_frame.dart';

final _logger = new Logger('SuggestionsElement');

@Component(
    selector: 'suggestions',
    templateUrl: 'packages/bacchus_diary/element/suggestions.html',
    cssUrl: 'packages/bacchus_diary/element/suggestions.css',
    useShadowDom: true)
class SuggestionsElement implements ShadowRootAware, DetachAware {
  @NgOneWayOneTime('setter') set setter(Setter<SuggestionsElement> v) => v?.value = this; // Optional
  @NgOneWay('pageSize') int pageSize;
  @NgOneWay('report') Report report;

  void onShadowRoot(ShadowRoot sr) {
    refresh();
  }

  void detach() {
    pager?.cancel();
  }

  refresh() {
    pager?.cancel();
    pager = new Suggestions(report);
  }

  int get itemWidth => (window.innerWidth * 0.7).floor();
  Suggestions pager;

  openItem(Event event, Item item) {
    final e = event.target as Element;
    e.style.opacity = '1';
    afterRippling(() {
      e.style.opacity = '0';
      item.open();
    });
  }
}

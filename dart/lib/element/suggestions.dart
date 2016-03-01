library bacchus_diary.element.suggestions;

import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';

import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/service/aws/paa.dart';
import 'package:bacchus_diary/util/getter_setter.dart';
import 'package:bacchus_diary/util/pager.dart';
import 'package:bacchus_diary/util/main_frame.dart';

final _logger = new Logger('SuggestionsElement');

@Component(
    selector: 'suggestions',
    templateUrl: 'packages/bacchus_diary/element/suggestions.html',
    cssUrl: 'packages/bacchus_diary/element/suggestions.css',
    useShadowDom: true)
class SuggestionsElement implements ShadowRootAware {
  @NgOneWayOneTime('setter') set setter(Setter<SuggestionsElement> v) => v?.value = this; // Optional
  @NgOneWay('pageSize') int pageSize;
  @NgOneWay('report') Report report;

  String _keywords;

  void onShadowRoot(ShadowRoot sr) {
    refresh();
  }

  refresh() {
    final keywords = report.leaves.map((x) => x.description ?? '').join("\n");
    if (_keywords != keywords) {
      _keywords = keywords;
      final p = PAA.findByWords(_keywords);
      pager = p == null ? null : new PagingList(p);
    }
  }

  int get itemWidth => (window.innerWidth * 0.7).floor();
  PagingList<Item> pager;

  openItem(Event event, Item item) {
    final e = event.target as Element;
    e.style.opacity = '1';
    afterRippling(() {
      e.style.opacity = '0';
      PAA.open(item);
    });
  }
}

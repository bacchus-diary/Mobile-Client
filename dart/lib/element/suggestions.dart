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

  void onShadowRoot(ShadowRoot sr) {
    pager = new PagingList(PAA.findByWords(report.leaves.map((x) => x.description).join("\n")));
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

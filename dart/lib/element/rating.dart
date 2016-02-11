library bacchus_diary.element.rating;

import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';

import 'package:bacchus_diary/util/getter_setter.dart';

final _logger = new Logger('RatingElement');

@Component(
    selector: 'rating',
    templateUrl: 'packages/bacchus_diary/element/rating.html',
    cssUrl: 'packages/bacchus_diary/element/rating.css',
    useShadowDom: true)
class RatingElement implements ShadowRootAware {
  @NgOneWayOneTime('setter') set setter(Setter<RatingElement> v) => v?.value = this; // Optional
  @NgTwoWay('stars') int stars;
  @NgOneWay('readonly') bool readonly = false;
  @NgOneWay('divide') int divide = 5;
  @NgOneWay('space') double space = 0.0;

  List<int> get grades => new List.generate(divide, (x) => x + 1);

  int _starSize;
  int get starSize {
    if (_starSize == null) {
      final e = _root?.querySelector('div#root');
      if (e != null && 0 < e.clientWidth) {
        _starSize = (e.clientWidth / (divide + divide * space)).round();
      }
    }
    return _starSize;
  }

  ShadowRoot _root;
  void onShadowRoot(ShadowRoot sr) {
    _root = sr;
  }
}

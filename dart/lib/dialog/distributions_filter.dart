library bacchus_diary.dialog.distributions_filter;

import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:paper_elements/paper_dialog.dart';

import 'package:bacchus_diary/util/distributions_filters.dart';
import 'package:bacchus_diary/util/getter_setter.dart';
import 'package:bacchus_diary/util/main_frame.dart';

final _logger = new Logger('DistributionsFilterDialog');

@Component(
    selector: 'distributions-filter-dialog',
    templateUrl: 'packages/bacchus_diary/dialog/distributions_filter.html',
    useShadowDom: true)
class DistributionsFilterDialog extends AbstractDialog implements ShadowRootAware {
  @NgOneWayOneTime('setter') set setter(Setter<DistributionsFilterDialog> v) => v?.value = this; // Optional
  @NgOneWayOneTime('filter') Setter<DistributionsFilter> filter;

  ShadowRoot _root;
  CachedValue<PaperDialog> _dialog;
  PaperDialog get realDialog => _dialog.value;

  void onShadowRoot(ShadowRoot sr) {
    _root = sr;
    _dialog = new CachedValue(() => _root.querySelector('paper-dialog'));
  }
}

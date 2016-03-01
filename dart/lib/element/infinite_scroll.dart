library bacchus_diary.element.infinite_scroll;

import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';

import 'package:bacchus_diary/util/getter_setter.dart';
import 'package:bacchus_diary/util/pager.dart';

final _logger = new Logger('InfiniteScrollElement');

@Component(
    selector: 'infinite-scroll',
    templateUrl: 'packages/bacchus_diary/element/infinite_scroll.html',
    cssUrl: 'packages/bacchus_diary/element/infinite_scroll.css',
    useShadowDom: true)
class InfiniteScrollElement extends ShadowRootAware {
  static const moreDur = const Duration(milliseconds: 800);

  @NgOneWayOneTime('setter') set setter(Setter<InfiniteScrollElement> v) => v?.value = this; // Optional
  @NgAttr('page-size') String pageSize;
  Pager _pager;
  Pager get pager => _pager;
  @NgOneWay('pager') set pager(Pager v) {
    _pager = v;
    _logger.finest(() => "Set pager: ${v}");
    _onReady.future.then((_) => _checkMore());
  }

  @NgAttr('direction') String direction;

  Completer<Null> _onReady = new Completer();

  int get pageSizeValue => (pageSize == null || pageSize.isEmpty) ? 10 : int.parse(pageSize);

  ShadowRoot _root;
  Element _scroller, _spinnerDiv;
  Timer _moreTimer;

  @override
  void onShadowRoot(ShadowRoot sr) {
    _root = sr;
    _scroller = _root.querySelector('div#scroller');
    _scroller.style.height = _root.host.style.height;
    _scroller.style.flexDirection = direction ?? 'column';

    final content = _root.host.querySelector('div#content');
    assert(content != null);
    _scroller.querySelector('div#content').replaceWith(content);

    _spinnerDiv = _scroller.querySelector('div#spinner');
    _scroller.onScroll.listen((event) => _checkMore());

    _onReady.complete();
  }

  void _checkMore() {
    if (pager == null || !pager.hasMore) return;

    final bottom = direction != 'row'
        ? _scroller.scrollTop + _scroller.clientHeight
        : _scroller.scrollLeft + _scroller.clientWidth;
    final spinnerPos = direction != 'row'
        ? _spinnerDiv.offsetTop - _scroller.offsetTop
        : _spinnerDiv.offsetLeft - _scroller.offsetLeft;

    _logger.finer(() => "Check more: bottom=${bottom}, spinner pos=${spinnerPos}");
    if (spinnerPos <= bottom) {
      if (_moreTimer != null && _moreTimer.isActive) _moreTimer.cancel();
      _moreTimer = new Timer(moreDur, () async {
        await pager.more(pageSizeValue);
        // spinner がスクロールの外に見えなくなるまで続ける
        _checkMore();
      });
    }
  }
}

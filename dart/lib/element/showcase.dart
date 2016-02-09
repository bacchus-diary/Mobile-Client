library bacchus_diary.element.showcase;

import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';

import 'package:core_elements/core_animated_pages.dart';
import 'package:core_elements/core_animation.dart';

import 'package:bacchus_diary/dialog/photo_way.dart';
import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/service/aws/s3file.dart';
import 'package:bacchus_diary/service/photo_shop.dart';
import 'package:bacchus_diary/util/fabric.dart';
import 'package:bacchus_diary/util/getter_setter.dart';

final _logger = new Logger('ShowcaseElement');

typedef _AfterSlide();

@Component(
    selector: 'showcase',
    templateUrl: 'packages/bacchus_diary/element/showcase.html',
    cssUrl: 'packages/bacchus_diary/element/showcase.css',
    useShadowDom: true)
class ShowcaseElement implements ShadowRootAware, ScopeAware {
  @NgOneWayOneTime('setter') set setter(Setter<ShowcaseElement> v) => v?.value = this; // Optional
  @NgOneWay('list') List<Leaf> list;
  @NgOneWay('reportId') String reportId;

  final FuturedValue<PhotoWayDialog> photoWayDialog = new FuturedValue();

  final GetterSetter<int> _indexA = new PipeValue();
  final GetterSetter<int> _indexB = new PipeValue();
  Leaf get leafA => _indexA.value == null ? null : list[_indexA.value];
  Leaf get leafB => _indexB.value == null ? null : list[_indexB.value];

  CoreAnimatedPages _pages;

  int get height => width;
  int _width;
  int get width {
    if (_width == null) {
      final e = _root?.querySelector('section');
      if (e != null && 0 < e.clientWidth) {
        _width = e.clientWidth;
      }
    }
    return _width;
  }

  ShadowRoot _root;
  void onShadowRoot(ShadowRoot sr) {
    _root = sr;
    _pages = _root.querySelector('core-animated-pages') as CoreAnimatedPages
      ..selected = 0
      ..addEventListener('core-animated-pages-transition-end', (event) => _afterSlide());
    _logger.finest(() => "Opening Showcase");
  }

  Scope _scope;
  void set scope(Scope scope) {
    _scope = scope;
  }

  _scopeApply() {
    try {
      _scope.apply();
    } catch (ex) {
      _logger.warning(() => "${ex}");
    }
  }

  _AfterSlide _afterSlide;

  _slide(proc(List<Element> sections, int pageNo, GetterSetter<int> current, GetterSetter<int> other),
      [int nextSelected = null, post]) {
    if (_pages == null) return null;

    final pageNo = _pages.selected;
    final sections = _pages.querySelectorAll('section');

    GetterSetter<int> current, other;
    if (sections[pageNo].id == "pageA") {
      current = _indexA;
      other = _indexB;
    } else {
      current = _indexB;
      other = _indexA;
    }

    final result = proc(sections, pageNo, current, other);
    if (nextSelected != null) {
      _afterSlide = () {
        if (post != null) post(current, other);
        current.value = null;
        _scopeApply();
      };
      _pages.selected = nextSelected;
    }
    return result;
  }

  bool get isLeftEnabled =>
      _slide((sections, pageNo, current, other) => list.isNotEmpty && (current.value == null || current.value > 0));

  bool get isRightEnabled => _slide((sections, pageNo, current, other) => current.value != null);

  slideLeft([post]) async {
    _slide((sections, pageNo, current, other) {
      other.value = (current.value ?? list.length) - 1;

      if (pageNo == 0) {
        final pre = sections[1];
        pre.remove();
        _pages.insertBefore(pre, sections[0]);
      }
    }, 0, post);
  }

  slideRight([post]) async {
    _slide((sections, pageNo, current, other) {
      final nextIndex = current.value + 1;
      other.value = (list.length <= nextIndex) ? null : nextIndex;

      if (pageNo == 1) {
        final next = sections[0];
        next.remove();
        _pages.append(next);
      }
    }, 1, post);
  }

  delete() async {
    _slide((sections, pageNo, current, other) async {
      new CoreAnimation()
        ..target = sections[pageNo]
        ..keyframes = [
          {'opacity': 1, 'transform': "none"},
          {'opacity': 0, 'transform': "translateY(${height}px)"}
        ]
        ..duration = 200
        ..easing = 'ease-in'
        ..play();

      slideRight((current, other) {
        list.removeAt(current.value);
        if (other.value != null) {
          other.value = other.value - 1;
        }
      });
    });
  }

  add() async {
    final dialog = await photoWayDialog.future;
    dialog.onClosed(() {
      _pickPhoto(dialog.take);
    });
    dialog.open();
  }

  /**
   * Picking photo and upload
   */
  _pickPhoto(bool take) async {
    if (take == null) return;

    try {
      final shop = new PhotoShop(take);
      Future.wait([shop.timestamp, shop.geoinfo]).catchError((ex) => _logger.warning(() => "Error: ${ex}"));

      final leaf = new Leaf.fromMap(reportId, {});

      leaf.photo.reduced.mainview.url = await shop.photoUrl;
      list.add(leaf);
      _slide((sections, index, current, other) {
        current.value = list.length - 1;
        new Future.delayed(const Duration(milliseconds: 300), _scopeApply);
      });

      final path = await leaf.photo.original.storagePath;
      await S3File.putObject(path, await shop.photo);
      FabricAnswers.eventCustom(name: 'UploadPhoto', attributes: {'type': 'NEW_LEAF'});
    } catch (ex) {
      _logger.warning(() => "Failed to pick photo: ${ex}");
    }
  }
}

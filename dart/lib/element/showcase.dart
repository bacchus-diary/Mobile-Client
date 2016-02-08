library bacchus_diary.element.showcase;

import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';

import 'package:core_elements/core_animated_pages.dart';

import 'package:bacchus_diary/dialog/photo_way.dart';
import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/service/aws/s3file.dart';
import 'package:bacchus_diary/service/photo_shop.dart';
import 'package:bacchus_diary/util/fabric.dart';
import 'package:bacchus_diary/util/getter_setter.dart';

final _logger = new Logger('ShowcaseElement');

@Component(
    selector: 'showcase',
    templateUrl: 'packages/bacchus_diary/element/showcase.html',
    cssUrl: 'packages/bacchus_diary/element/showcase.css',
    useShadowDom: true)
class ShowcaseElement extends ShadowRootAware {
  @NgOneWayOneTime('setter') set setter(Setter<ShowcaseElement> v) => v?.value = this; // Optional
  @NgOneWay('list') List<Leaf> list;
  @NgOneWay('reportId') String reportId;

  final FuturedValue<PhotoWayDialog> photoWayDialog = new FuturedValue();

  final GetterSetter<int> _indexA = new PipeValue();
  final GetterSetter<int> _indexB = new PipeValue();
  int get indexA => _indexA.value;
  int get indexB => _indexB.value;

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
  @override
  void onShadowRoot(ShadowRoot sr) {
    _root = sr;
    _pages = _root.querySelector('core-animated-pages') as CoreAnimatedPages..selected = 0;
    _logger.finest(() => "Opening Showcase");
  }

  currentIndex(proc(GetterSetter<int> current, GetterSetter<int> other)) =>
      slide((sections, pageNo, current, other) => proc(current, other));
  slide(proc(List<Element> sections, int pageNo, GetterSetter<int> current, GetterSetter<int> other)) {
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

    return proc(sections, pageNo, current, other);
  }

  bool get isLeftEnabled =>
      currentIndex((current, other) => (current.value != null || other.value != null) && current.value != 0);

  bool get isRightEnabled => currentIndex((current, other) => current.value != null);

  slideLeft() async {
    slide((sections, pageNo, current, other) {
      other.value = (current.value ?? list.length) - 1;

      if (pageNo == 0) {
        final pre = sections[1];
        pre.remove();
        _pages.insertBefore(pre, sections[0]);
      }
      _pages.selected = 0;
    });
  }

  slideRight() async {
    slide((sections, pageNo, current, other) {
      final nextIndex = current.value + 1;
      other.value = (list.length <= nextIndex) ? null : nextIndex;

      if (pageNo == 1) {
        final next = sections[0];
        next.remove();
        _pages.append(next);
      }
      _pages.selected = 1;
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

      final path = await leaf.photo.original.storagePath;
      await S3File.putObject(path, await shop.photo);
      FabricAnswers.eventCustom(name: 'UploadPhoto', attributes: {'type': 'NEW_LEAF'});

      list.add(leaf);
      slide((sections, index, current, other) {
        current.value = list.length - 1;
      });
    } catch (ex) {
      _logger.warning(() => "Failed to pick photo: ${ex}");
    }
  }
}

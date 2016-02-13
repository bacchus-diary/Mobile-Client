library bacchus_diary.element.showcase;

import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';

import 'package:core_elements/core_animated_pages.dart';
import 'package:core_elements/core_animation.dart';
import 'package:paper_elements/paper_autogrow_textarea.dart';
import 'package:rikulo_ui/gesture.dart';

import 'package:bacchus_diary/dialog/photo_way.dart';
import 'package:bacchus_diary/model/report.dart';
import 'package:bacchus_diary/model/photo.dart';
import 'package:bacchus_diary/service/aws/s3file.dart';
import 'package:bacchus_diary/service/photo_shop.dart';
import 'package:bacchus_diary/util/fabric.dart';
import 'package:bacchus_diary/util/getter_setter.dart';

final _logger = new Logger('ShowcaseElement');

typedef _AfterSlide();
typedef OnChanged();

@Component(
    selector: 'showcase',
    templateUrl: 'packages/bacchus_diary/element/showcase.html',
    cssUrl: 'packages/bacchus_diary/element/showcase.css',
    useShadowDom: true)
class ShowcaseElement implements ShadowRootAware, ScopeAware {
  @NgOneWayOneTime('setter') set setter(Setter<ShowcaseElement> v) => v?.value = this; // Optional
  @NgOneWay('list') List<Leaf> list;
  @NgOneWay('reportId') String reportId;
  @NgOneWay('on-changed') OnChanged onChanged;

  onChange() => onChanged == null ? null : onChanged();

  final FuturedValue<PhotoWayDialog> photoWayDialog = new FuturedValue();

  final GetterSetter<int> _indexA = new PipeValue();
  final GetterSetter<int> _indexB = new PipeValue();
  Leaf get leafA => _indexA.value == null ? null : list[_indexA.value];
  Leaf get leafB => _indexB.value == null ? null : list[_indexB.value];

  CoreAnimatedPages _pages;

  int _width;
  int get width {
    if (_width == null) {
      final e = _pages?.querySelector('section');
      if (e != null && 0 < e.clientWidth) {
        _width = e.clientWidth;
      }
    }
    return _width;
  }

  int get heightA => _height('A');
  int get heightB => _height('B');
  int _height(String key) {
    final height = _pages?.querySelector("section#page${key}")?.querySelector('.leaf .photo')?.clientHeight ?? width;
    return height < (width / 10) ? width : height;
  }

  bool _isAdding = false;
  bool get isPhotoLoading =>
      _isAdding ||
      _slide((sections, pageNo, current, other) {
        if (current.value == null) return false;
        final height = sections[pageNo].querySelector('.leaf .photo')?.clientHeight ?? 0;
        return height == 0;
      });

  bool _isGestureSetup = false;
  _setupGesture() async {
    if (_isGestureSetup) return;

    ['A', 'B'].forEach((key) {
      final owner = _pages.querySelector("section#page${key} .leaf-view .gesture");
      _logger.fine(() => "Setting gester on ${owner}");
      new SwipeGesture(owner, (SwipeGestureState state) {
        _logger.info(() => "Swiped: ${state}");
        state.gesture.disable();
        try {
          final int hdiff = state.transition.x;
          if (hdiff < -50 && isRightEnabled) {
            slideRight();
          } else if (hdiff > 50 && isLeftEnabled) {
            slideLeft();
          }
        } finally {
          state.gesture.enable();
        }
      });
    });
    _isGestureSetup = true;
  }

  ShadowRoot _root;
  void onShadowRoot(ShadowRoot sr) {
    _root = sr;
    _pages = _root.querySelector('core-animated-pages') as CoreAnimatedPages
      ..selected = 0
      ..addEventListener('core-animated-pages-transition-end', (event) => _afterSlide());
    _logger.finest(() => "Opening Showcase");

    if (list.isNotEmpty) _indexA.value = 0;
    _updateDescription();
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

  static const _durUpdateTextarea = const Duration(milliseconds: 200);
  _updateDescription() async {
    await new Future.delayed(_durUpdateTextarea, () {
      _slide((sections, pageNo, current, other) {
        sections[pageNo].querySelectorAll('paper-autogrow-textarea').forEach((PaperAutogrowTextarea e) {
          e.querySelectorAll('textarea').forEach((t) {
            _logger.finer(() => "Updating: ${e} <= ${t}");
            e.update(t);
          });
        });
      });
    });
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
        current.value = null;
        if (post != null) post(current, other);
        _updateDescription();
      };
      _pages.selected = nextSelected;
    }
    return result;
  }

  bool get isLeftEnabled =>
      _slide((sections, pageNo, current, other) => list.isNotEmpty && (current.value == null || current.value > 0));

  bool get isRightEnabled => _slide((sections, pageNo, current, other) => current.value != null);

  slideLeft([post]) {
    _slide((sections, pageNo, current, other) {
      other.value = (current.value ?? list.length) - 1;

      if (pageNo == 0) {
        final pre = sections[1];
        pre.remove();
        _pages.insertBefore(pre, sections[0]);
      }
    }, 0, post);
  }

  slideRight([post]) {
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

  delete() {
    _slide((sections, pageNo, current, other) {
      if (current.value == null) return null;

      new CoreAnimation()
        ..target = sections[pageNo]
        ..keyframes = [
          {'opacity': 1, 'transform': "none"},
          {'opacity': 0, 'transform': "translateY(${width}px)"}
        ]
        ..duration = 200
        ..easing = 'ease-in'
        ..play();

      final currentIndex = current.value;
      slideRight((current, other) {
        list.removeAt(currentIndex).photo.delete();
        onChange();
        if (other.value != null) {
          other.value = other.value - 1;
        }
        _scopeApply();
      });
    });
  }

  add() async {
    _setupGesture();

    _isAdding = true;
    try {
      final data = await _pickPhoto();
      final leaf = new Leaf.fromMap(reportId, {})..photo.reduced.mainview.url = PhotoShop.makeUrl(data);

      list.add(leaf);
      onChange();

      _uploadPhoto(data, leaf.photo);

      _slide((sections, index, current, other) {
        current.value = list.length - 1;
        _isAdding = false;
      });
    } catch (ex) {
      _isAdding = false;
    }
  }

  Future<Blob> _pickPhoto() async {
    final result = new Completer<Blob>();

    final dialog = await photoWayDialog.future;
    dialog.onClosed(() async {
      final take = dialog.take;
      if (take != null) {
        try {
          result.complete(await PhotoShop.photo(take));
        } catch (ex) {
          _logger.warning(() => "Could not pick photo: ${ex}");
        }
      } else if (dialog.file != null) {
        result.complete(dialog.file);
      }
    });
    dialog.open();

    return result.future;
  }

  _uploadPhoto(Blob data, Photo photo) async {
    final path = await photo.original.storagePath;
    await S3File.putObject(path, data);
    FabricAnswers.eventCustom(name: 'UploadPhoto', attributes: {'type': 'NEW_LEAF'});
  }
}

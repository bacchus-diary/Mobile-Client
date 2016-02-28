library bacchus_diary.util.pager;

import 'dart:async';

import 'package:logging/logging.dart';

final _logger = new Logger('Pager');

abstract class Pager<T> {
  bool get hasMore;
  Future<List<T>> more(int pageSize);
  void reset();
}

class PagingList<T> implements Pager<T> {
  final Pager<T> _pager;
  final List<T> list = [];

  PagingList(this._pager);

  bool get hasMore => _pager.hasMore;

  void reset() {
    _pager.reset();
    list.clear();
  }

  Future<List<T>> more(int pageSize) async {
    final a = await _pager.more(pageSize);
    list.addAll(a);
    return a;
  }
}

class MergedPager<T> implements Pager<T> {
  final List<Pager<T>> _pagers;

  MergedPager(Iterable<Pager<T>> list) : this._pagers = new List.unmodifiable(list);

  bool get hasMore => _pagers.any((x) => x.hasMore);

  void reset() => _pagers.forEach((x) => x.reset());

  Future<List<T>> more(int pageSize) {
    Future<List<T>> pick(List<Pager<T>> list, List<T> result) async {
      if (pageSize <= result.length || !hasMore) return result;

      final pagers = list.where((x) => x.hasMore);
      final left = pageSize - result.length;
      final each = (left / pagers.length).ceil();
      final adding = pagers.map((x) async {
        result.addAll(await x.more(each));
      });
      await Future.wait(adding);
      return pick(pagers, result);
    }
    return pick(_pagers, []);
  }
}

part of 'dependency_loader.dart';

abstract class _Fixup {
  void fix(Combiner combiner, Map<WrapDocRef, dynamic> cache);
}

class _LoadFixup extends _Fixup {
  WrapDocRef ref;

  _LoadFixup(this.ref);

  @override
  void fix(Combiner combiner, Map<WrapDocRef, dynamic> cache) {
    if (cache[ref] is Document) {
      cache[ref] = combiner._combine(ref.ref, ref.ref);
    }
  }

  @override
  String toString() {
    return '_LoadFixup{ref: $ref}';
  }
}

class _ListFixup extends _Fixup {
  List list;
  WrapDocRef source;
  int index;

  _ListFixup(this.list, this.source, this.index);

  @override
  void fix(Combiner combiner, Map<WrapDocRef, dynamic> cache) {
    list.insert(index, cache[source]);
  }

  @override
  String toString() {
    return '_ListFixup{source: $source}';
  }
}

class _AfterFixUp extends _Fixup {
  AfterFixUp fixup;

  _AfterFixUp(this.fixup);

  @override
  void fix(Combiner combiner, Map<WrapDocRef, dynamic> cache) {
    fixup.afterFixUp();
  }

  @override
  String toString() {
    return '_AfterFixup{source: $fixup}';
  }
}

class Combiner {
  final FirestoreNeo firestoreNeo;
  final Map<WrapDocRef, dynamic> cache;
  final List<dynamic> stack = [];

  final ListQueue<_Fixup> _fixups = ListQueue<_Fixup>();

  Combiner(this.firestoreNeo, this.cache);

  List<T> combine<T extends JsonObject>(
      Iterable<DocumentSnapshot<Document>> data) {
    var res = data.map((e) {
      return _combine(e, e.reference) as T;
    }).toList();

    while (_fixups.isNotEmpty) {
      _fixups.removeFirst().fix(this, cache);
    }

    return res;
  }

  dynamic _combine(dynamic data, DocRef doc) {
    var idx = stack.indexOf(data);
    if (idx != -1) {
      for (var v in stack.skip(idx)) {
        debugPrint(v);
      }
      stack.clear();
      throw Exception("cycle detected");
    }

    stack.add(data);
    dynamic res;
    if (data is DocumentSnapshot<Document>) {
      res = _combine(data.reference, data.reference);
    } else if (data is List) {
      var ref = data
          .whereType<DocRef>()
          .firstOrNull;
      if (ref == null) {
        res = [for (var e in data) _combine(e, doc)];
      } else {
        res = DependencyLoader
            ._getCollection(
            firestoreNeo, WrapColRef(ref.parent))
            .newList;

        for (var i = data.length - 1; i >= 0; i--) {
          var e = data[i];
          if (e is DocRef) {
            e = WrapDocRef(e);
            _fixups.addFirst(_ListFixup(res, e, i));
            _fixups.addFirst(_LoadFixup(e));
          } else {
            res.add(_combine(e, doc));
          }
        }
      }
    } else if (data is Map<WrapDocRef, dynamic>) {
      res = {for (var i in data.entries) i.key: _combine(i.value, doc)};
    } else if (data is Map<String, dynamic>) {
      res = {for (var i in data.entries) i.key: _combine(i.value, doc)};
    } else if (data is DocRef) {
      data = WrapDocRef(data);
      res = cache[data];
      if (res is Document) {
        var combined = _combine(res, data.ref as DocRef);
        res = DependencyLoader._getCollection(firestoreNeo, data.parent)
            .fromJson(combined)
          ..reference = data;
        cache[data] = res;

        if (res is AfterFixUp) _fixups.addLast(_AfterFixUp(res));
      }
    } else {
      res = data;
    }
    stack.removeLast();
    return res;
  }
}

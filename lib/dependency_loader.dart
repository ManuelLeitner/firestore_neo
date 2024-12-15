import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';

import 'firestore_neo.dart';

class DependencyLoader {
  static Document toJson(dynamic data) {
    return _toJson(data) as Document;
  }

  static _toJson(dynamic data) {
    if (data is Map<String, dynamic>) {
      return {for (var e in data.entries) e.key: _toJson(e.value)};
    }
    if (data is Map) {
      return {for (var e in data.entries) e.key: _toJson(e.value)};
    }
    if (data is List) {
      return data.map(_toJson).toList();
    }
    if (data is JsonObject) return _toJson(data.toJson());
    return data;
  }

  static Set<DocRef> summarize(dynamic data, Set<DocRef> references) {
    Iterable? iterable;
    if (data is Iterable) {
      iterable = data;
    } else if (data is Map) {
      iterable = data.entries
          .where((e) => e.key != "reference")
          .map((e) => e.value)
          .toList();
    } else if (data is DocRef) {
      references.add(data);
    } else if (data is num ||
        data is String ||
        data is DateTime ||
        data is bool ||
        data is Timestamp ||
        data == null) {
    } else {
      throw "unsupported type ${data.runtimeType}";
    }
    if (iterable != null) {
      for (var item in iterable) {
        summarize(item, references);
      }
    }
    return references;
  }

  static Future<T> loadObject<T extends JsonObject>(
      FirestoreNeo firestoreNeo, Map<String, dynamic> data,
      [FirestoreSource? source]) async {
    var required = summarize(data, {});

    Map<DocRef, dynamic> loaded = await load(required, source);

    Map<DocRef, dynamic> cache = {};

    if (loaded.isNotEmpty) {
      loaded = await _loadObjectList(firestoreNeo, loaded, cache, source);
    }
    fromJson(loaded, firestoreNeo);
    cache.addAll(loaded);

    return loaded.values.single;
  }

  static Future<List<T>> loadObjectList<T extends JsonObject>(
      FirestoreNeo firestoreNeo, List<DocumentSnapshot<Document>> data,
      [FirestoreSource? source]) async {
    try {
      Map<DocRef, dynamic> cache = {};
      Map<DocRef, dynamic> docs = data.groupFoldBy(
        (e) => e.reference,
        (previous, element) => element.data(),
      );
      var res = await _loadObjectList(firestoreNeo, docs, cache, source);
      fromJson(res, firestoreNeo);
      assert(!res.values.any((element) => element.reference == null));

      return res.values.map((e) => e as T).toList();
    } catch (e, stack) {
      debugPrint(e.toString());
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  static void fromJson(Map<DocRef, dynamic> res, FirestoreNeo firestoreNeo) {
    for (var k in res.keys) {
      var col = firestoreNeo.collections
          .where((c) => c.path.path == k.parent.path)
          .firstOrNull;
      if (col == null) {
        throw Exception("no FirestoreCollection found for ${k.path}");
      }
      try {
        res[k] = col.fromJson(res[k])..reference = k;
      } catch (e, stack) {
        debugPrint("Parsing failed for ${k.path}: $e\n${res[k]}");
        debugPrintStack(stackTrace: stack);
      }
    }
  }

  static Future<Map<DocRef, dynamic>> _loadObjectList(
      FirestoreNeo firestoreNeo,
      Map<DocRef, dynamic> data,
      Map<DocRef, dynamic> cache,
      FirestoreSource? source) async {
    Set<DocRef> required = summarize(data, {});
    required.removeAll(cache.keys);
    Map<DocRef, dynamic> loaded = await load(required, source);

    if (loaded.isNotEmpty) {
      loaded = await _loadObjectList(firestoreNeo, loaded, cache, source);
    }
    fromJson(loaded, firestoreNeo);
    cache.addAll(loaded);

    return _combine(data, cache) as Map<DocRef, dynamic>;
  }

  static dynamic _combine(dynamic data, Map<DocRef, dynamic> cache) {
    if (data is Iterable) {
      return [for (var i in data) _combine(i, cache)];
    }
    if (data is Map<DocRef, dynamic>) {
      return {for (var i in data.entries) i.key: _combine(i.value, cache)};
    }
    if (data is Map<String, dynamic>) {
      return {for (var i in data.entries) i.key: _combine(i.value, cache)};
    }
    if (data is DocRef) {
      return cache[data];
    }
    return data;
  }

  static Future<Map<DocRef, dynamic>> load(Set<DocRef> references,
      [FirestoreSource? source]) async {
    var collections = references.groupSetsBy((dr) => dr.parent);

    for (var col in collections.entries) {
      debugPrint("load ${col.key.path}: ${col.value.map(
            (e) => e.id,
          ).join(", ")}");
    }

    Map<DocRef, dynamic> res = {};
    for (var col in collections.entries) {
      for (var slice in col.value.slices(30)) {
        var query = await col.key
            .where(FieldPath.documentId, whereIn: slice.map((e) => e.id))
            .getFromSource(source);
        for (var doc in query.docs) {
          var d = doc.data();
          res[doc.reference] = d;
        }
      }
    }
    return res;
  }
}

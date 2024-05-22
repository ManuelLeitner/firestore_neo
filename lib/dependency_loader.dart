import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';

import 'firestore_neo.dart';
import 'firestore_extensions.dart';
import 'json_object.dart';

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
    }
    if (iterable != null) {
      for (var item in iterable) {
        summarize(item, references);
      }
    }
    return references;
  }

  static Future loadObjectList<T extends JsonObject>(
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
      res[k] = col.fromJson(res[k])..reference = k;
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
      var query = await col.key
          .where(FieldPath.documentId, whereIn: col.value.map((e) => e.id))
          .getFromSource(source);
      for (var doc in query.docs) {
        var d = doc.data();
        // d["reference"] = doc.reference;
        res[doc.reference] = d;
      }
    }
    return res;
  }
}

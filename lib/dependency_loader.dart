import 'dart:collection' show ListQueue;
import 'package:firestore_neo/conversion_exception.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firestore_neo/firestore_neo.dart';
import 'package:flutter/cupertino.dart';

part 'combiner.dart';

class DependencyLoader {
  static Document toJson(dynamic data) {
    return _toJson(data) as Document;
  }

  static dynamic _toJson(dynamic data) {
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

  static Set<WrapDocRef> summarize(dynamic data, Set<WrapDocRef> references) {
    Iterable? iterable;
    if (data is Iterable) {
      iterable = data;
    } else if (data is Map) {
      iterable = data.entries
          .where((e) => e.key != "reference")
          .map((e) => e.value)
          .toList();
    } else if (data is DocRef) {
      references.add(WrapDocRef(data));
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

  static Future<void> summarizeAndLoad(String base, FirestoreNeo firestoreNeo,
      Map<WrapDocRef, dynamic> cache) async {
    var data = cache;
    while (true) {
      var required = summarize(data, {});
      required.removeAll(cache.keys);
      if (required.isEmpty) return;
      data = await load(firestoreNeo, required, base);
      cache.addAll(data);
    }
  }

  static Future<T> loadObject<T extends JsonObject>(
      FirestoreNeo firestoreNeo, WrapDocRef ref) async {
    var res = await loadObjectList<T>(firestoreNeo, [await ref.getDoc()]);

    return res.first;
  }

  static Future<List<T>> loadObjectList<T extends JsonObject>(
      FirestoreNeo firestoreNeo,
      Iterable<DocumentSnapshot<Document>> data) async {
    try {
      Map<WrapDocRef, dynamic> docs = data.groupFoldBy(
        (e) => WrapDocRef(e.reference),
        (previous, element) => element.data(),
      );
      debugPrint("start loading $T");
      await summarizeAndLoad(T.toString(), firestoreNeo, docs);

      var combiner = Combiner(firestoreNeo, docs);

      return combiner.combine(data);
    } catch (e, stack) {
      debugPrint(e.toString());
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  static FirestoreCollectionBase<JsonObject> _getCollection(
      FirestoreNeo firestoreNeo, WrapColRef k) {
    var col =
        firestoreNeo.collections.where((c) => c.isApplicable(k)).firstOrNull;
    if (col == null) {
      throw Exception("no FirestoreCollection found for $k");
    }
    return col;
  }

  static void fromJson(
      Map<WrapDocRef, dynamic> res, FirestoreNeo firestoreNeo) {
    for (var k in res.keys) {
      var col = _getCollection(firestoreNeo, k.parent);
      try {
        res[k] = col.fromJson(res[k])
          ..reference = k
          ..properties = res[k];
      } catch (e, stack) {
        debugPrint("Parsing failed for $k: $e\n${res[k]}");
        debugPrintStack(stackTrace: stack);
      }
    }
  }

  static Future<Map<WrapDocRef, Document>> load(FirestoreNeo firestoreNeo,
      Set<WrapDocRef> references, String base) async {
    var collections = references.groupSetsBy((dr) => dr.parent);

    Map<WrapDocRef, Document> res = {};
    for (var col in collections.entries) {
      var firestoreCollection = _getCollection(firestoreNeo, col.key);

      if (firestoreCollection.loadAll) {
        await _loadAll(col.key, res, firestoreNeo, base);
      } else {
        await _loadByIds(col.value, res);
      }
    }
    return res;
  }

  static Future<void> _loadAll(WrapColRef col, Map<WrapDocRef, Document> res,
      FirestoreNeo firestoreNeo, String base) async {
    var docCache = firestoreNeo.cache.putIfAbsent(col, () => {});
    var lastLoadedUpdate = firestoreNeo.lastLoadedUpdate[col];
    var lastLoadFilter = lastLoadedUpdate == null
        ? null
        : Filter.or(
            Filter(updatedAt, isGreaterThan: lastLoadedUpdate),
            Filter(updatedAt, isNull: true),
          );

    var docs = await col.where(lastLoadFilter).getDocs();
    for (var doc in docs) {
      var d = doc.data();
      docCache[WrapDocRef(doc.reference)] = d;
      var docUpdate = d[updatedAt];
      if (docUpdate == null || docUpdate is! Timestamp) continue;
      if (lastLoadedUpdate == null ||
          lastLoadedUpdate.millisecondsSinceEpoch <
              docUpdate.millisecondsSinceEpoch) {
        lastLoadedUpdate = docUpdate;
      }
    }

    if (lastLoadedUpdate != null) {
      firestoreNeo.lastLoadedUpdate[col] = lastLoadedUpdate;
    }
    res.addAll(docCache);
  }

  static Future<void> _loadByIds(
      Set<WrapDocRef> value, Map<WrapDocRef, Document> res) async {
    var col = value.first.parent;
    //  debugPrint("load id-based $col: ${value.map((e) => e.id).join(", ")}");
    var slices = value.slices(30);
    for (var slice in slices) {
      var docFilter =
          Filter(FieldPath.documentId, whereIn: slice.map((e) => e.id));
      var docs = await col.where(docFilter).getDocs();
      for (var doc in docs) {
        res[WrapDocRef(doc.reference)] = doc.data();
      }
      //TODO: load statistics
    }
  }
}

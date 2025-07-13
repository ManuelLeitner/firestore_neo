import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_neo/dependency_loader.dart';
import 'package:firestore_neo/firestore_neo.dart';
import 'package:flutter/widgets.dart';

const updatedAt = "updatedAt";

abstract class FirestoreCollectionBase<T extends JsonObject> {
  T Function(Document d) fromJson;
  FirestoreNeo firestoreNeo;
  final type = T;

  List<T> get newList => <T>[];

  /// load all optimizes to load in a way that only recently updated objects are loaded
  /// However document id cannot be filtered
  bool loadAll;

  FirestoreCollectionBase({required this.fromJson, required this.firestoreNeo, required this.loadAll}) {
    assert(T != JsonObject, "pass real type (not JsonObject) as generic argument");
  }

  bool isApplicable(WrapColRef ref);

  bool matchesType(dynamic obj) {
    return obj is T;
  }
}

class FirestoreDeserializer<T extends JsonObject> extends FirestoreCollectionBase<T> {
  FirestoreDeserializer({required super.fromJson, required super.firestoreNeo, required super.loadAll});

  @override
  bool isApplicable(WrapColRef ref) {
    return true;
  }
}

abstract class FirestoreQuery<T extends JsonObject> extends FirestoreCollectionBase<T> {
  Query<Document> query;

  Stream<List<T>> get filteredStream async* {
    debugPrint("stream $query");
    await for (var snap in query.snapshots()) {
      var raw = await DependencyLoader.loadObjectList<T>(firestoreNeo, snap.docs);
      raw.sort();
      yield raw;
    }
  }

  FirestoreQuery({required this.query, required super.fromJson, required super.firestoreNeo, required super.loadAll});
}

class FirestoreCollection<T extends JsonObject> extends FirestoreQuery<T> {
  WrapColRef path;

  Stream<List<T>> get unfilteredStream async* {
    debugPrint("stream $query");
    await for (var snap in path.ref.snapshots()) {
      var raw = await DependencyLoader.loadObjectList<T>(firestoreNeo, snap.docs);
      raw.sort();
      yield raw;
    }
  }

  FirestoreCollection(FirestoreNeo firestoreNeo, this.path, T Function(Document d) fromJson, bool loadAll,
      {Query<Document> Function(Query<Document> query)? configureQuery})
      : super(
            firestoreNeo: firestoreNeo,
            query: configureQuery != null ? configureQuery(path.ref) : path.ref,
            fromJson: fromJson,
            loadAll: loadAll);

  Future<void> delete(T t) async => await t.reference?.delete();

  dynamic _removeObjects(dynamic data, Set<JsonObject> res) {
    if (data is Map<String, dynamic>) {
      return {for (var e in data.entries) e.key: _removeObjects(e.value, res)};
    }
    if (data is Map) {
      return {for (var e in data.entries) e.key: _removeObjects(e.value, res)};
    }
    if (data is Iterable) {
      return data.map((o) => _removeObjects(o, res)).toList();
    }
    if (data is JsonObject) {
      res.add(data);
      return null;
    }
    return data;
  }

  Future<T> save(T t, {String? id}) async {
    if (t.reference == null && id != null) {
      t.reference = path.doc(id);
    }

    var dep = <JsonObject>{};
    var json = _removeObjects(t.toJson(), dep);
    dep.remove(t);

    if (t.reference != null) {
      await path.doc(t.reference!.id).set(json);
    } else {
      t.reference = await path.add(json);
    }

    if (dep.isEmpty) return t;

    for (var d in dep) {
      await firestoreNeo.save(d);
    }

    dep = {};
    json = _removeObjects(t.toJson(), dep);
    dep.remove(t);

    await t.reference!.set(json);

    return t;
  }

  Future<List<T>> getList() async {
    var res = await DependencyLoader.loadObjectList<T>(firestoreNeo, await query.getDocs());

    if (res.firstOrNull is Comparable<T>) {
      res.sort();
    }

    return res;
  }

  Future<T> getById(String id) async {
    var list = await path.doc(id).getWithDependencies<T>(firestoreNeo);
    return list;
  }

  Future<void> deleteAll([bool ignoreFilter = false]) async {
    List<QueryDocumentSnapshot<Document>> objs;
    if (ignoreFilter) {
      objs = await path.getDocs();
    } else {
      objs = await query.getDocs();
    }
    for (var obj in objs) {
      await obj.reference.delete();
    }
  }

  @override
  bool isApplicable(WrapColRef ref) {
    return path == ref;
  }
}

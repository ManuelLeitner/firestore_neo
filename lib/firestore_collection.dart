import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import 'dependency_loader.dart';
import 'firestore_neo.dart';

const updatedAt = "updatedAt";

abstract class FirestoreCollectionBase<T extends JsonObject> {
  T Function(Document d) fromJson;
  FirestoreNeo firestoreNeo;

  /// load all optimizes to load in a way that only recently updated objects are loaded
  /// However document id cannot be filtered
  bool loadAll;

  FirestoreCollectionBase(
      {required this.fromJson,
      required this.firestoreNeo,
      required this.loadAll});

  bool isApplicable(WrapColRef ref);
}

class FirestoreDeserializer<T extends JsonObject>
    extends FirestoreCollectionBase<T> {
  FirestoreDeserializer(
      {required super.fromJson,
      required super.firestoreNeo,
      required super.loadAll});

  @override
  bool isApplicable(WrapColRef ref) {
    return true;
  }
}

abstract class FirestoreQuery<T extends JsonObject>
    extends FirestoreCollectionBase<T> {
  Query<Document> query;

  Stream<List<T>> get stream async* {
    try {
      await for (var snap in query.snapshots()) {
        var raw =
            await DependencyLoader.loadObjectList<T>(firestoreNeo, snap.docs);
        raw.sort();
        yield raw;
      }
    } catch (e, stack) {
      debugPrint(e.toString());
      debugPrintStack(stackTrace: stack);
    }
  }

  FirestoreQuery(
      {required this.query,
      required super.fromJson,
      required super.firestoreNeo,
      required super.loadAll});
}

class FirestoreCollection<T extends JsonObject> extends FirestoreQuery<T> {
  WrapColRef path;

  FirestoreCollection(FirestoreNeo firestoreNeo, this.path,
      T Function(Document d) fromJson, bool loadAll,
      {Query<Document> Function(Query<Document> query)? configureQuery})
      : super(
            firestoreNeo: firestoreNeo,
            query: configureQuery != null ? configureQuery(path.ref) : path.ref,
            fromJson: fromJson,
            loadAll: loadAll);

  Future<void> delete(T t) async => await t.reference?.delete();

  Future<void> save(T t) async {
    var json = DependencyLoader.toJson(t);
    if (t.reference != null) {
      await path.doc(t.reference!.id).set(json);
    } else {
      t.reference = await path.add(json);
    }
  }

  Future<List<T>> getList() async {
    return await DependencyLoader.loadObjectList<T>(
        firestoreNeo, await query.getDocs())
      ..sort();
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

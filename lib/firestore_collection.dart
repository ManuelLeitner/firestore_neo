import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import 'dependency_loader.dart';
import 'firestore_neo.dart';

class FirestoreQuery<T extends JsonObject> {
  Query<Document> query;
  T Function(Document d) fromJson;
  FirestoreNeo firestoreNeo;

  Stream<List<T>> get stream async* {
    try {
      await for (var snap in query.snapshots()) {
        var raw = await DependencyLoader.loadObjectList<T>(
            firestoreNeo, snap.docs, FirestoreSource.server);
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
      required this.fromJson,
      required this.firestoreNeo});
}

class FirestoreCollection<T extends JsonObject> extends FirestoreQuery<T> {
  CollectionReference<Document> path;

  FirestoreCollection(
      FirestoreNeo firestoreNeo, this.path, T Function(Document d) fromJson,
      {Query<Document> Function(Query<Document> query)? configureQuery})
      : super(
            firestoreNeo: firestoreNeo,
            query: configureQuery != null ? configureQuery(path) : path,
            fromJson: fromJson);

  Future<void> delete(T t) async => await t.reference?.delete();

  Future<void> save(T t) async {
    var json = DependencyLoader.toJson(t);
    if (t.reference != null) {
      await path.doc(t.reference!.id).set(json);
    } else {
      t.reference = await path.add(json);
    }
  }

  Future<List<T>> get(FirestoreSource source) async {
    return await DependencyLoader.loadObjectList<T>(
        firestoreNeo, (await query.getFromSource(source)).docs, source);
  }

  Future<T> getById(String id, [FirestoreSource? source]) async {
    var list = await path.doc(id).getWithDependencies<T>(firestoreNeo, source);
    return list;
  }

  Future<void> deleteAll() async {
    var objs = await get(FirestoreSource.server);
    for (var obj in objs) {
      await delete(obj);
    }
  }
}

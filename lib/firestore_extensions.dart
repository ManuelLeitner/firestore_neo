import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_neo/dependency_loader.dart';
import 'package:firestore_neo/firestore_neo.dart';

class FirestoreStat {
  int totalLoads = 0, cachedLoads = 0;

  @override
  String toString() {
    return 'totalLoads: $totalLoads, cachedLoads: $cachedLoads';
  }
}

FirestoreStat _firestoreStat = FirestoreStat();

StreamController<FirestoreStat> _firestoreStatController = StreamController();
Stream<FirestoreStat> firestoreStat = _firestoreStatController.stream;

QuerySnapshot<T> addStatistics<T>(QuerySnapshot<T> snap) {
  _firestoreStat.totalLoads += snap.docs.length;
  _firestoreStat.cachedLoads +=
      snap.docs.where((element) => element.metadata.isFromCache).length;

  _firestoreStatController.add(_firestoreStat);
  return snap;
}

extension FirestoreDocumentExtension<T> on DocumentReference<T> {
  Future<T> getObject() async {
    var q = await get();
    return q.data()!;
  }
}

extension FirestoreQueryExtension<T> on Query<T> {
  Future<List<T>> getList() async {
    var q = await get();
    return q.docs.map((e) => e.data()).toList();
  }
}

extension FirestoreQueryExtensionWithDependencies
    on Query<Map<String, dynamic>> {
  Future<List<QueryDocumentSnapshot<Document>>> getDocs() async {
    var res = await get();
    return res.docs;
  }

  Future<List<T>> getWithDependencies<T extends JsonObject>(
      FirestoreNeo firestore) async {
    var q = await get();
    return await DependencyLoader.loadObjectList<T>(firestore, q.docs);
  }
}

extension FirestoreCollectionExtension<T> on CollectionReference<T> {
  Future<List<T>> getList() async {
    var q = await get();
    return q.docs.map((e) => e.data()).toList();
  }
}

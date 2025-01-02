import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_neo/firestore_neo.dart';
import 'package:flutter/widgets.dart';

import 'dependency_loader.dart';

class FirestoreSource {
  static FirestoreSource cache = FirestoreSource._(Source.cache);
  static FirestoreSource server = FirestoreSource._(Source.server);
  static FirestoreSource serverAndCache =
      FirestoreSource._(Source.serverAndCache);
  static FirestoreSource cacheOrServer = FirestoreSource._(null);
  Source? source;

  FirestoreSource._(this.source);
}

extension FirestoreDocumentExtension<T> on DocumentReference<T> {
  Future<DocumentSnapshot<T>> getFromSource([FirestoreSource? source]) async {
    source = source ?? FirestoreSource.server;
    try {
      if (source == FirestoreSource.cacheOrServer) {
        var ds = await get(const GetOptions(source: Source.cache));
        return ds;
      }
      return get(GetOptions(source: source.source!));
    } catch (_) {
      if (source == FirestoreSource.cacheOrServer) {
        return get(const GetOptions(source: Source.server));
      }
      rethrow;
    }
  }

  Future<T> getFromSourceAsObject(FirestoreSource? source) async {
    var q = await getFromSource(source);
    return q.data()!;
  }
}

extension FirestoreQueryExtension<T> on Query<T> {
  Future<QuerySnapshot<T>> getFromSource([FirestoreSource? source]) async {
    try {
      source ??= FirestoreSource.serverAndCache;
      if (source == FirestoreSource.cacheOrServer) {
        var ds = await get(const GetOptions(source: Source.cache));
        return ds;
      }
      print(parameters);
      return await get(GetOptions(source: source.source!));
    } catch (e, stack) {
      debugPrint(e.toString());
      debugPrintStack(stackTrace: stack);
      if (source == FirestoreSource.cacheOrServer) {
        return await get(const GetOptions(source: Source.server));
      }
      rethrow;
    }
  }

  Future<List<T>> getFromSourceAsList([FirestoreSource? source]) async {
    var q = await getFromSource(source);
    return q.docs.map((e) => e.data()).toList();
  }
}

extension FirestoreQueryExtensionWithDependencies
    on Query<Map<String, dynamic>> {
  Future<List<T>> getWithDependencies<T extends JsonObject>(
      FirestoreNeo firestore,
      [FirestoreSource? source]) async {
    var q = await getFromSource(source);
    return await DependencyLoader.loadObjectList<T>(firestore, q.docs);
  }
}

extension FirestoreDocumentExtensionWithDependencies
    on DocumentReference<Map<String, dynamic>> {
  Future<T> getWithDependencies<T extends JsonObject>(FirestoreNeo firestore,
      [FirestoreSource? source]) async {
    return await DependencyLoader.loadObject<T>(firestore, this, source);
  }
}

extension FirestoreCollectExtension<T> on CollectionReference<T> {
  Future<QuerySnapshot<T>> getFromSource(FirestoreSource source) async {
    try {
      if (source == FirestoreSource.cacheOrServer) {
        var ds = await get(const GetOptions(source: Source.cache));
        return ds;
      }
      return get(GetOptions(source: source.source!));
    } catch (_) {
      if (source == FirestoreSource.cacheOrServer) {
        return get(const GetOptions(source: Source.server));
      }
      rethrow;
    }
  }

  Future<List<T>> getFromSourceAsList(FirestoreSource source) async {
    var q = await getFromSource(source);
    return q.docs.map((e) => e.data()).toList();
  }
}

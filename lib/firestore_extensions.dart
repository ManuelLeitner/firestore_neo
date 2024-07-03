import 'package:cloud_firestore/cloud_firestore.dart';

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
  Future<DocumentSnapshot<T>> getFromSource(FirestoreSource source) async {
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

  Future<T> getFromSourceAsObject(FirestoreSource source) async {
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
      return get(GetOptions(source: source.source!));
    } catch (_) {
      if (source == FirestoreSource.cacheOrServer) {
        return get(const GetOptions(source: Source.server));
      }
      rethrow;
    }
  }

  Future<List<T>> getFromSourceAsList([FirestoreSource? source]) async {
    var q = await getFromSource(source);
    return q.docs.map((e) => e.data()).toList();
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

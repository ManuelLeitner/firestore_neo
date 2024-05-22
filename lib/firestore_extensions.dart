import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSource {
  static FirestoreSource cache = FirestoreSource(Source.cache);
  static FirestoreSource server = FirestoreSource(Source.server);
  static FirestoreSource serverAndCache =
      FirestoreSource(Source.serverAndCache);
  static FirestoreSource cacheOrServer = FirestoreSource(null);
  Source? source;
  FirestoreSource(this.source);
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
      var qs = await get(const GetOptions(source: Source.cache));
      if (qs.docs.isEmpty) {
        return get(GetOptions(source: source?.source ?? Source.serverAndCache));
      }
      return qs;
    } catch (_) {
      return get(const GetOptions(source: Source.server));
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
      var qs = await get(const GetOptions(source: Source.cache));
      if (qs.docs.isEmpty) return get(GetOptions(source: source.source!));
      return qs;
    } catch (_) {
      return get(const GetOptions(source: Source.server));
    }
  }

  Future<List<T>> getFromSourceAsList(FirestoreSource source) async {
    var q = await getFromSource(source);
    return q.docs.map((e) => e.data()).toList();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_neo/firestore_extensions.dart';

import 'dependency_loader.dart';
import 'firestore_collection.dart';
import 'json_object.dart';

export 'conversions.dart';
export 'json_object.dart';
export 'firestore_collection.dart';
export 'firestore_extensions.dart';

typedef Document = Map<String, dynamic>;
typedef DocRef = DocumentReference<Document>;
typedef ColRef = CollectionReference<Document>;

class WrapDocRef {
  DocRef ref;
  WrapDocRef(this.ref);

  WrapColRef get parent => WrapColRef(ref.parent);

  @override
  String toString() {
    return ref.path;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WrapDocRef && ref.path == other.ref.path;

  @override
  int get hashCode => ref.path.hashCode;

  String get id => ref.id;

  Future<Document> getObject() {
    return ref.getObject();
  }

  Future<void> delete() => ref.delete();

  Future<void> set(Document data, [SetOptions? options]) =>
      ref.set(toJson(data), options);

  Future<void> update(Map<String, dynamic> map) => ref.update(toJson(map));

  WrapColRef collection(String s) => WrapColRef(ref.collection(s));

  Future<T> getWithDependencies<T extends JsonObject>(
      FirestoreNeo firestoreNeo) async {
    return await DependencyLoader.loadObject<T>(firestoreNeo, this);
  }

  Future<DocumentSnapshot<Document>> getDoc() async {
    return await ref.get();
  }
}

class WrapColRef {
  ColRef ref;
  WrapColRef(this.ref);

  @override
  String toString() {
    return ref.path;
  }

  Future<WrapDocRef> add(Document json) async =>
      WrapDocRef(await ref.add(toJson(json)));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WrapColRef && ref.path == other.ref.path;

  @override
  int get hashCode => ref.path.hashCode;

  WrapDocRef doc(String id) => WrapDocRef(ref.doc(id));

  Query<Document> where(
    Object? field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    if (field == null) return ref;
    return ref.where(field,
        isNull: isNull,
        isGreaterThan: isGreaterThan,
        whereNotIn: whereNotIn,
        whereIn: whereIn,
        arrayContainsAny: arrayContainsAny,
        arrayContains: arrayContains,
        isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
        isLessThanOrEqualTo: isLessThanOrEqualTo,
        isLessThan: isLessThan,
        isNotEqualTo: isNotEqualTo,
        isEqualTo: isEqualTo);
  }

  Future<List<QueryDocumentSnapshot<Document>>> getDocs() => ref.getDocs();

  Query<Document> orderBy(Object field, {bool descending = false}) =>
      ref.orderBy(field, descending: descending);
}

dynamic toJson(dynamic json) {
  if (json is JsonObject) {
    return json.reference;
  }
  if (json is WrapDocRef) {
    return json.ref;
  }
  if (json is Document) {
    for (var k in json.keys) {
      json[k] = toJson(json[k]);
    }
  }
  if (json is Iterable) {
    return [for (var j in json) toJson(j)];
  }
  return json;
}

abstract class FirestoreNeo {
  var lastLoadedUpdate = <WrapColRef, Timestamp>{};

  var cache = <WrapColRef, Map<WrapDocRef, Document>>{};

  List<FirestoreCollectionBase<JsonObject>> get collections;
}

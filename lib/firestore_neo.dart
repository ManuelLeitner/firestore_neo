import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_collection.dart';
import 'json_object.dart';

export 'conversions.dart';
export 'json_object.dart';
export 'firestore_collection.dart';
export 'firestore_extensions.dart';

typedef Document = Map<String, dynamic>;
typedef DocRef = DocumentReference<Document>;

abstract class FirestoreNeo {
  List<FirestoreCollectionBase<JsonObject>> get collections;
}

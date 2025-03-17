import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_neo/firestore_neo.dart';
import 'package:json_annotation/json_annotation.dart';

WrapDocRef? loadOptionalReference(dynamic ref) {
  if (ref is DocRef) return WrapDocRef(ref);
  return null;
}

Timestamp? fromJsonTimestamp(dynamic json) {
  return json;
}

FieldValue updateTimestamp(_) => FieldValue.serverTimestamp();

mixin LastUpdate {
  @JsonKey(fromJson: fromJsonTimestamp, toJson: updateTimestamp)
  Timestamp? updatedAt;
}

mixin AfterFixUp {
  void afterFixUp();
}

mixin JsonObject {
  @JsonKey(includeToJson: false, fromJson: loadOptionalReference)
  WrapDocRef? reference;
  @JsonKey(includeFromJson: false, includeToJson: false)
  late Map<String, dynamic> properties;

  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is JsonObject) {
      return reference != null && other.reference != null && reference == other.reference;
    }
    return false;
  }

  @override
  int get hashCode => reference.hashCode;
}

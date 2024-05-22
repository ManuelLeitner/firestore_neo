import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

DocumentReference? loadOptionalReference(dynamic ref) {
  if (ref is DocumentReference) return ref;
  return null;
}

mixin JsonObject {
  @JsonKey(includeToJson: false, fromJson: loadOptionalReference)
  DocumentReference? reference;
  @JsonKey(includeFromJson: false, includeToJson: false)
  late Map<String, dynamic> properties;
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is JsonObject) {
      return reference != null &&
          other.reference != null &&
          reference?.path == other.reference?.path;
    }
    return false;
  }

  @override
  int get hashCode => reference!.path.hashCode;
}

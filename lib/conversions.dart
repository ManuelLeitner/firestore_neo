import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import 'firestore_neo.dart';

List referenceList<T extends JsonObject>(Iterable list) {
  return [for (var e in list) reference(e)];
}

List<Document> iterableToJson<T extends JsonObject>(Iterable list) {
  return [
    for (var e in list)
      if (e is JsonObject) e.toJson() else e
  ];
}

List<Document> listToJson<T extends JsonObject>(List list) =>
    iterableToJson(list);

reference(JsonObject? obj) => obj?.reference?.ref ?? obj;

object(JsonObject? obj) => obj?.toJson()?..remove(updatedAt);

class DateNullConverter implements JsonConverter<DateTime?, dynamic> {
  const DateNullConverter();

  @override
  dynamic toJson(DateTime? dt) => dt;

  @override
  DateTime? fromJson(dynamic l) {
    if (l is Timestamp) {
      return DateTime.fromMillisecondsSinceEpoch(l.millisecondsSinceEpoch);
    }
    if (l is String) return DateTime.tryParse(l);
    return null;
  }
}

class TimestampNullConverter implements JsonConverter<Timestamp?, dynamic> {
  const TimestampNullConverter();

  @override
  dynamic toJson(Timestamp? dt) => dt;

  @override
  Timestamp? fromJson(dynamic l) {
    if (l is Timestamp) {
      return l;
    }
    return null;
  }
}

class DateConverter implements JsonConverter<DateTime, dynamic> {
  const DateConverter();

  @override
  dynamic toJson(DateTime dt) => dt;

  @override
  DateTime fromJson(dynamic l) {
    if (l is Timestamp) {
      return DateTime.fromMillisecondsSinceEpoch(l.millisecondsSinceEpoch);
    }
    return DateTime.parse(l);
  }
}

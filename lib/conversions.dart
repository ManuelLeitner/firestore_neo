import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_neo/firestore_neo.dart';
import 'package:json_annotation/json_annotation.dart';

class ReferenceList<T extends JsonObject> extends JsonConverter<List<T>, List> {
  const ReferenceList();

  @override
  List<T> fromJson(List? l) => fromReferenceList(l);

  @override
  List toJson(List<T> l) => toReferenceList(l);
}

class Reference<T extends JsonObject> extends JsonConverter<T, dynamic> {
  const Reference();

  @override
  T fromJson(dynamic l) => l;

  @override
  dynamic toJson(T l) => reference(l);
}

List toReferenceList<T extends JsonObject>(Iterable list) {
  return [for (var e in list) reference(e)];
}

List<T> fromReferenceList<T extends JsonObject>(List? list) =>
    list is! List<JsonObject> ? <T>[] : list as List<T>? ?? <T>[];

List<dynamic> iterableToJson<T extends JsonObject>(Iterable? list) {
  return list == null
      ? []
      : [
          for (var e in list)
            if (e is JsonObject) e.toJson() else e
        ];
}

List<Map<String, dynamic>> objectIterableToJson<T extends JsonObject>(
    Iterable<T>? list) {
  return list == null ? [] : [for (var e in list) e.toJson()];
}

dynamic referenceOrObject(JsonObject? obj) {
  var ref = obj?.reference?.ref;
  if (ref != null) return ref;
  var json = obj?.toJson();
  json?.remove(updatedAt);
  return json;
}

List<dynamic> listToJson<T extends JsonObject>(List<T>? list) =>
    iterableToJson(list);

dynamic reference(JsonObject? obj) => obj?.reference?.ref ?? obj;

Map<String, dynamic>? object(JsonObject? obj) =>
    obj?.toJson()?..remove(updatedAt);

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

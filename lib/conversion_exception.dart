class ConversionException implements Exception {
  Object cause;
  final String? message;
  Map<String, dynamic>? data;

  ConversionException(this.cause, this.message, this.data);

  @override
  String toString() {
    return 'ConversionException(cause: $cause, message: $message)\n\n${buildString(data)}';
  }
}

String buildString(data, [int indentation = 0]) {
  var indent = "  " * indentation;
  if (data == null) return "${indent}null";
  if (data is Map<String, dynamic>) {
    var buffer = StringBuffer();
    for (var e in data.entries) {
      buffer
          .writeln("$indent${e.key}: ${buildString(e.value, indentation + 1)}");
    }
    return buffer.toString();
  }
  if (data is List<dynamic>) {
    var buffer = StringBuffer();
    for (var e in data) {
      buffer.writeln(buildString(e, indentation + 1));
    }
    return buffer.toString();
  }
  return data.toString();
}

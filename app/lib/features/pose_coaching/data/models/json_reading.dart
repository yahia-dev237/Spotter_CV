// small helpers for reading Firestore / JSON maps: numbers may arrive as int or double

double readDouble(Object? v) => (v as num).toDouble();

double? readDoubleOrNull(Object? v) => v == null ? null : (v as num).toDouble();

List<int>? readIntListOrNull(Object? v) =>
    v == null ? null : (v as List).map((e) => (e as num).toInt()).toList();

/// puts [value] in [json] only when it is not null (optional database fields)
void putIfNotNull(Map<String, dynamic> json, String key, Object? value) {
  if (value != null) json[key] = value;
}

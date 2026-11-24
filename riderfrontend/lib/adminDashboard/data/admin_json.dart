// Tolerant readers for ASP.NET camelCase JSON, with PascalCase accepted too.

Map<String, dynamic>? jsonMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

String jsonPascal(String key) {
  if (key.isEmpty) return key;
  return key[0].toUpperCase() + key.substring(1);
}

Object? jsonPick(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key)) return json[key];
    final alt = jsonPascal(key);
    if (alt != key && json.containsKey(alt)) return json[alt];
  }
  return null;
}

bool jsonHasAny(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key)) return true;
    final alt = jsonPascal(key);
    if (alt != key && json.containsKey(alt)) return true;
  }
  return false;
}

String? jsonString(Map<String, dynamic> json, List<String> keys) {
  final value = jsonPick(json, keys);
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

num? jsonNum(Map<String, dynamic> json, List<String> keys) {
  final value = jsonPick(json, keys);
  if (value is num) return value;
  if (value is String) return num.tryParse(value.replaceAll(',', '').trim());
  return null;
}

int? jsonInt(Map<String, dynamic> json, List<String> keys) =>
    jsonNum(json, keys)?.round();

int? optionalInt(Map<String, dynamic> json, List<String> keys) {
  if (!jsonHasAny(json, keys)) return null;
  return jsonInt(json, keys);
}

num? optionalNum(Map<String, dynamic> json, List<String> keys) {
  if (!jsonHasAny(json, keys)) return null;
  return jsonNum(json, keys);
}

bool? jsonBool(Map<String, dynamic> json, List<String> keys) {
  final value = jsonPick(json, keys);
  if (value is bool) return value;
  if (value is num) {
    if (value == 1) return true;
    if (value == 0) return false;
  }
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
  }
  return null;
}

DateTime? jsonDate(Map<String, dynamic> json, List<String> keys) {
  final value = jsonString(json, keys);
  if (value == null) return null;
  return DateTime.tryParse(value)?.toLocal();
}

List<Map<String, dynamic>> jsonRows(
  Object? data, {
  List<String> keys = const ['items', 'rows', 'results'],
}) {
  if (data is List) {
    return [for (final item in data) ?jsonMap(item)];
  }
  final map = jsonMap(data);
  if (map == null) return const [];
  for (final key in keys) {
    final value = jsonPick(map, [key]);
    if (value is List) {
      return [for (final item in value) ?jsonMap(item)];
    }
  }
  return const [];
}

bool isDisallowedOperationsLabel(String text) {
  final blob = text.toLowerCase();
  // Live Trackboard / GPS compliance is an approved product surface.
  // Keep filtering unverified payments and Knox marketing claims.
  const words = [
    'wallet',
    'raast',
    'ibft',
    'radar',
    'geofence',
    'knox',
    'playback',
    'history playback',
    'spot billing',
    'price list',
  ];
  return words.any(blob.contains);
}

/// Hides telemetry claims. Ordinary operational text is returned unchanged.
String? operationsDisplayText(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty || isDisallowedOperationsLabel(trimmed)) return null;
  return trimmed;
}

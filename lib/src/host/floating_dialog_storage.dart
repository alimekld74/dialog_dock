import 'dart:convert';

/// Where the holder keeps its lifetime setting and saved (display-only) item
/// list. Reads are synchronous because the holder restores its state when
/// it is created.
abstract class FloatingDialogStorage {
  /// The saved lifetime in minutes, if any.
  int? readLifetimeMinutes();

  /// Saves the lifetime in minutes.
  Future<void> writeLifetimeMinutes(int minutes);

  /// `{'userId': ..., 'entries': [...]}` as written by the holder.
  Map<String, dynamic>? readEntries();

  /// Saves the item list.
  Future<void> writeEntries(Map<String, dynamic> data);
}

/// Storage on top of any synchronous-read key-value store, such as
/// `SharedPreferences`:
///
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// final storage = KeyValueFloatingDialogStorage(
///   readString: prefs.getString,
///   writeString: prefs.setString,
/// );
/// ```
///
/// Writes two keys, `<keyPrefix>Lifetime` and `<keyPrefix>Entries`, both as
/// strings.
class KeyValueFloatingDialogStorage implements FloatingDialogStorage {
  /// Creates a storage over [readString] and [writeString].
  KeyValueFloatingDialogStorage({
    required this.readString,
    required this.writeString,
    this.keyPrefix = 'floatingDialog',
  });

  /// Reads a string value, `null` when missing.
  final String? Function(String key) readString;

  /// Writes a string value.
  final Future<Object?> Function(String key, String value) writeString;

  /// Namespaces the keys.
  final String keyPrefix;

  String get _lifetimeKey => '${keyPrefix}Lifetime';
  String get _entriesKey => '${keyPrefix}Entries';

  @override
  int? readLifetimeMinutes() {
    try {
      return int.tryParse(readString(_lifetimeKey) ?? '');
    } catch (_) {
      // e.g. SharedPreferences holds an int under this key.
      return null;
    }
  }

  @override
  Future<void> writeLifetimeMinutes(int minutes) =>
      writeString(_lifetimeKey, '$minutes');

  @override
  Map<String, dynamic>? readEntries() {
    try {
      final encoded = readString(_entriesKey);
      if (encoded == null || encoded.isEmpty) return null;
      return json.decode(encoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeEntries(Map<String, dynamic> data) =>
      writeString(_entriesKey, json.encode(data));
}

/// Keeps everything in memory; nothing survives a restart. The default.
class InMemoryFloatingDialogStorage implements FloatingDialogStorage {
  int? _lifetimeMinutes;
  Map<String, dynamic>? _entries;

  @override
  int? readLifetimeMinutes() => _lifetimeMinutes;

  @override
  Future<void> writeLifetimeMinutes(int minutes) async =>
      _lifetimeMinutes = minutes;

  @override
  Map<String, dynamic>? readEntries() => _entries;

  @override
  Future<void> writeEntries(Map<String, dynamic> data) async =>
      _entries = json.decode(json.encode(data)) as Map<String, dynamic>;
}

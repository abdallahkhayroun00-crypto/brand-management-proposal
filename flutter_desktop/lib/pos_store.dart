import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as paths;
import 'package:sqlite3/sqlite3.dart';

/// Compatible with the Python LAN prototype's state_snapshot schema.
/// All order data lives on the restaurant laptop, not in GitHub Pages.
class PosSnapshot {
  const PosSnapshot(this.revision, this.data, this.updatedAt);
  final int revision;
  final Map<String, dynamic> data;
  final String updatedAt;
}

class WriteResult {
  const WriteResult(this.ok, this.snapshot);
  final bool ok;
  final PosSnapshot snapshot;
}

Map<String, dynamic> emptyPosState() => {
      'employees': [
        {'id': 1, 'name': 'Ömer', 'role': 'Yönetici', 'active': true},
        {'id': 2, 'name': 'Mehmet', 'role': 'Personel', 'active': true},
        {'id': 3, 'name': 'Abdallah', 'role': 'Personel', 'active': true}
      ],
      'orders': <dynamic>[],
      'nextId': 1200,
      'printJobs': <dynamic>[]
    };

class PosStore extends ChangeNotifier {
  PosStore({String? databaseFile}) {
    final defaultFolder = Platform.environment['APPDATA'] ??
        paths.join(Directory.current.path, 'local-data');
    final folder = Directory(paths.join(defaultFolder, 'NohutFalafel'));
    folder.createSync(recursive: true);
    filePath = databaseFile ?? paths.join(folder.path, 'nohut-pos.sqlite3');
    final target = Directory(paths.dirname(filePath));
    target.createSync(recursive: true);
    _db = sqlite3.open(filePath);
    _db.execute('PRAGMA journal_mode=WAL');
    _db.execute('PRAGMA busy_timeout=15000');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS state_snapshot(
        id INTEGER PRIMARY KEY CHECK(id=1),
        revision INTEGER NOT NULL,
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    _db.execute(
      'INSERT OR IGNORE INTO state_snapshot(id,revision,payload,updated_at) VALUES(1,0,?,?)',
      [jsonEncode(emptyPosState()), DateTime.now().toUtc().toIso8601String()],
    );
  }

  late final String filePath;
  late final Database _db;

  PosSnapshot read() {
    final row = _db.select(
      'SELECT revision,payload,updated_at FROM state_snapshot WHERE id=1',
    ).single;
    return PosSnapshot(
      row['revision'] as int,
      Map<String, dynamic>.from(jsonDecode(row['payload'] as String) as Map),
      row['updated_at'] as String,
    );
  }

  static void validate(Map<String, dynamic> data) {
    if (data['employees'] is! List ||
        data['orders'] is! List ||
        data['printJobs'] is! List ||
        data['nextId'] is! int) {
      throw const FormatException('Invalid POS structure');
    }
    final orders = data['orders'] as List;
    if (orders.length > 50000 || (data['printJobs'] as List).length > 100000) {
      throw const FormatException('POS record limit reached');
    }
    final ids = <int>{};
    for (final item in orders) {
      if (item is! Map || item['id'] is! int ||
          item['batches'] is! List || item['payments'] is! List ||
          !ids.add(item['id'] as int)) {
        throw const FormatException('Invalid or duplicate order');
      }
    }
    if (ids.isNotEmpty &&
        (data['nextId'] as int) <= ids.reduce((a, b) => a > b ? a : b)) {
      throw const FormatException('Invalid nextId');
    }
  }

  WriteResult replace(Map<String, dynamic> next, int expectedRevision) {
    validate(next);
    _db.execute('BEGIN IMMEDIATE');
    try {
      final current = read();
      if (current.revision != expectedRevision) {
        _db.execute('ROLLBACK');
        return WriteResult(false, current);
      }
      final stamp = DateTime.now().toUtc().toIso8601String();
      _db.execute(
        'UPDATE state_snapshot SET revision=?,payload=?,updated_at=? WHERE id=1',
        [current.revision + 1, jsonEncode(next), stamp],
      );
      _db.execute('COMMIT');
      final stored = read();
      notifyListeners();
      return WriteResult(true, stored);
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  void dispose() {
    _db.dispose();
    super.dispose();
  }
}

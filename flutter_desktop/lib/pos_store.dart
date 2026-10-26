import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as paths;
import 'package:sqlite3/sqlite3.dart';
import 'pos_logic.dart';
import 'operations.dart';
import 'ticket_document.dart';

part 'staff_auth.dart';

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
    {'id': 3, 'name': 'Abdallah', 'role': 'Personel', 'active': true},
  ],
  'orders': <dynamic>[],
  'nextId': 1200,
  'printJobs': <dynamic>[],
};

class PosStore extends ChangeNotifier {
  PosStore({String? databaseFile}) {
    final defaultFolder =
        Platform.environment['APPDATA'] ??
        paths.join(Directory.current.path, 'local-data');
    final folder = Directory(paths.join(defaultFolder, 'NohutFalafel'));
    folder.createSync(recursive: true);
    filePath =
        databaseFile ??
        Platform.environment['NOHUT_POS_DATABASE'] ??
        paths.join(folder.path, 'nohut-pos.sqlite3');
    final target = Directory(paths.dirname(filePath));
    target.createSync(recursive: true);
    _db = sqlite3.open(filePath);
    _db.execute('PRAGMA journal_mode=WAL');
    _db.execute('PRAGMA busy_timeout=15000');
    _db.execute('PRAGMA synchronous=FULL');
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
    _db.execute(
      'CREATE TABLE IF NOT EXISTS command_receipts (request_id TEXT PRIMARY KEY, payload TEXT NOT NULL, result TEXT NOT NULL)',
    );
    _db.execute('''CREATE TABLE IF NOT EXISTS staff_access (
      employee_id INTEGER PRIMARY KEY, enabled INTEGER NOT NULL DEFAULT 1,
      enrollment_hash TEXT, enrollment_expires TEXT, enrollment_used TEXT
    )''');
    _db.execute('''CREATE TABLE IF NOT EXISTS staff_sessions (
      id TEXT PRIMARY KEY, employee_id INTEGER NOT NULL, token_hash TEXT UNIQUE NOT NULL,
      csrf TEXT NOT NULL, device_name TEXT NOT NULL, created_at TEXT NOT NULL,
      last_seen TEXT NOT NULL, expires_at TEXT NOT NULL, revoked_at TEXT
    )''');
  }

  late final String filePath;
  late final Database _db;

  PosSnapshot read() {
    final row = _db
        .select(
          'SELECT revision,payload,updated_at FROM state_snapshot WHERE id=1',
        )
        .single;
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
    final employeeIds = <int>{};
    for (final e in asMaps(data['employees'])) {
      if (e['id'] is! int ||
          !employeeIds.add(e['id'] as int) ||
          e['name'] is! String ||
          '${e['name']}'.trim().isEmpty ||
          e['active'] is! bool) {
        throw const FormatException('Invalid employee');
      }
    }
    if (orders.length > 50000 || (data['printJobs'] as List).length > 100000) {
      throw const FormatException('POS record limit reached');
    }
    final ids = <int>{};
    final tables = <int>{};
    final packages = <String>{};
    for (final item in orders) {
      if (item is! Map ||
          item['id'] is! int ||
          item['batches'] is! List ||
          item['payments'] is! List ||
          !ids.add(item['id'] as int)) {
        throw const FormatException('Invalid or duplicate order');
      }
      final order = item.cast<String, dynamic>();
      if (![
        'Masa',
        'Gel-Al',
        'Yemeksepeti',
        'Trendyol Go',
      ].contains(order['source'])) {
        throw const FormatException('Invalid order source');
      }
      if (order['source'] == 'Masa') {
        final table = order['table'];
        if (table is! int || table < 1 || table > 5) {
          throw const FormatException('Masa 1–5');
        }
        if (order['closed'] != true &&
            order['cancelled'] != true &&
            order['tableReleased'] != true &&
            !tables.add(table)) {
          throw const FormatException('Duplicate active table');
        }
      } else if (order['table'] != null) {
        throw const FormatException('Non-table order has table');
      }
      if (isPlatform(order) &&
          order['platformPackageId'] != null &&
          !packages.add(
            jsonEncode([
              order['source'],
              order['integrationScope'],
              order['platformPackageId'],
            ]),
          )) {
        throw const FormatException('Duplicate platform package');
      }
      final batches = <int>{};
      for (final b in asMaps(order['batches'])) {
        if (b['id'] is! int ||
            !batches.add(b['id'] as int) ||
            b['lines'] is! List) {
          throw const FormatException('Invalid batch');
        }
        for (final l in asMaps(b['lines'])) {
          if (l['qty'] is! int ||
              (l['qty'] as int) < 0 ||
              ((l['qty'] as int) == 0 && l['voided'] != true) ||
              l['price'] is! num ||
              !(l['price'] as num).isFinite ||
              cents(l['price']) < 0) {
            throw const FormatException('Invalid product quantity / price');
          }
        }
      }
      for (final p in asMaps(order['payments'])) {
        if (!['Nakit', 'Kart', 'Platform'].contains(p['method']) ||
            p['amount'] is! num ||
            !(p['amount'] as num).isFinite ||
            cents(p['amount']) <= 0 ||
            (isPlatform(order) != (p['method'] == 'Platform')) ||
            paymentNetCents(p) < 0) {
          throw const FormatException('Invalid payment');
        }
        for (final r in asMaps(p['refunds'])) {
          if (r['amount'] is! num ||
              !(r['amount'] as num).isFinite ||
              cents(r['amount']) <= 0 ||
              DateTime.tryParse('${r['createdAt']}') == null) {
            throw const FormatException('Invalid refund');
          }
        }
      }
      if (!isPlatform(order) &&
          orderPaidCents(order) > orderTotalCents(order)) {
        throw const FormatException('Overpayment');
      }
      final guests = <int>{};
      for (final g in asMaps(order['guestChecks'])) {
        if (g['id'] is! int || !guests.add(g['id'] as int)) {
          throw const FormatException('Invalid guest');
        }
        final keys = <String>{};
        for (final a in asMaps(g['allocations'])) {
          final l = checkLines(
            order,
          ).where((l) => l.key == a['key']).firstOrNull;
          if (a['key'] is! String ||
              !keys.add(a['key'] as String) ||
              a['cents'] is! int ||
              (a['cents'] as int) < 0 ||
              l == null ||
              allocatedTo(order, l.key) > l.total) {
            throw const FormatException('Invalid allocation');
          }
        }
        if (guestBalance(order, g['id'] as int) < 0) {
          throw const FormatException('Guest overpayment');
        }
      }
      for (final p in asMaps(order['payments'])) {
        final mapped = asMaps(p['guestAllocations']), mappedIds = <int>{};
        if (mapped.fold<int>(0, (n, a) => n + cents(a['amount'])) >
                paymentNetCents(p) ||
            p['guestCheckId'] != null && mapped.isNotEmpty) {
          throw const FormatException('Invalid payment allocation');
        }
        for (final a in mapped) {
          if (a['guestCheckId'] is! int ||
              !guests.contains(a['guestCheckId']) ||
              !mappedIds.add(a['guestCheckId'] as int) ||
              a['amount'] is! num ||
              cents(a['amount']) <= 0) {
            throw const FormatException('Invalid payment guest');
          }
        }
      }
    }
    if (ids.isNotEmpty &&
        (data['nextId'] as int) <= ids.reduce((a, b) => a > b ? a : b)) {
      throw const FormatException('Invalid nextId');
    }
  }

  /// Executes a synchronous domain command while holding the SQLite writer lock.
  /// Retries reuse a persisted receipt; the same ID with another payload fails.
  Map<String, dynamic> command(
    String requestId,
    Map<String, dynamic> payload,
    Map<String, dynamic> Function(Map<String, dynamic>) change,
  ) {
    if (!RegExp(r'^[A-Za-z0-9_-]{8,100}$').hasMatch(requestId)) {
      throw const FormatException('Invalid request ID');
    }
    _db.execute('BEGIN IMMEDIATE');
    Map<String, dynamic> result;
    try {
      final receipt = _db.select(
        'SELECT payload,result FROM command_receipts WHERE request_id=?',
        [requestId],
      );
      final encoded = jsonEncode(payload);
      if (receipt.isNotEmpty) {
        if (receipt.single['payload'] != encoded) {
          throw const FormatException(
            'Request ID reused with different payload',
          );
        }
        result = Map<String, dynamic>.from(
          jsonDecode(receipt.single['result'] as String) as Map,
        );
        _db.execute('COMMIT');
        return result;
      }
      final current = read(), next = copyJson(read().data);
      result = change(next);
      freezeKitchenTickets(next);
      validate(next);
      final revision = current.revision + 1;
      result['revision'] = revision;
      _db.execute(
        'UPDATE state_snapshot SET revision=?,payload=?,updated_at=? WHERE id=1',
        [revision, jsonEncode(next), DateTime.now().toUtc().toIso8601String()],
      );
      _db.execute(
        'INSERT INTO command_receipts(request_id,payload,result) VALUES(?,?,?)',
        [requestId, encoded, jsonEncode(result)],
      );
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    notifyListeners();
    return result;
  }

  /// VACUUM INTO creates one consistent database even while WAL is active.
  void backup(String destination) {
    if (File(destination).existsSync() ||
        paths.equals(paths.absolute(destination), paths.absolute(filePath))) {
      throw const FormatException('Backup destination already exists');
    }
    _db.execute('VACUUM INTO ?', [paths.absolute(destination)]);
  }

  WriteResult replace(Map<String, dynamic> next, int expectedRevision) {
    freezeKitchenTickets(next);
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
    _db.close();
    super.dispose();
  }
}

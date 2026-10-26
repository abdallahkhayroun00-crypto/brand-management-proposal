part of 'pos_store.dart';

class StaffUnauthorized implements Exception {
  const StaffUnauthorized([
    this.message = 'Personel oturumu yok veya iptal edildi',
  ]);
  final String message;
}

class StaffPrincipal {
  const StaffPrincipal(this.employeeId, this.name, this.sessionId, this.csrf);
  final int employeeId;
  final String name, sessionId, csrf;
  Json get actor => {
    'kind': 'staff',
    'id': employeeId,
    'name': name,
    'sessionId': sessionId,
  };
}

class EnrollmentCode {
  const EnrollmentCode(this.token, this.expiresAt);
  final String token, expiresAt;
}

class ActivatedSession {
  const ActivatedSession(this.token, this.principal, this.expiresAt);
  final String token, expiresAt;
  final StaffPrincipal principal;
}

/// Random bearer tokens are hashed at rest. Only native PC code can enroll/revoke.
class StaffAuth {
  StaffAuth(this.store, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final PosStore store;
  final DateTime Function() clock;
  String _now() => clock().toUtc().toIso8601String();
  String _random() => base64UrlEncode(
    List.generate(32, (_) => Random.secure().nextInt(256)),
  ).replaceAll('=', '');
  String _hash(String token) => sha256.convert(utf8.encode(token)).toString();
  T _locked<T>(T Function() change) {
    store._db.execute('BEGIN IMMEDIATE');
    try {
      final r = change();
      store._db.execute('COMMIT');
      return r;
    } catch (_) {
      store._db.execute('ROLLBACK');
      rethrow;
    }
  }

  Json _employee(int id) => asMaps(store.read().data['employees']).firstWhere(
    (e) => e['id'] == id && e['active'] == true,
    orElse: () => throw const StaffUnauthorized('Personel aktif değil'),
  );
  EnrollmentCode issue(
    int employeeId, {
    bool revokeSessions = false,
  }) => _locked(() {
    _employee(employeeId);
    final token = _random(),
        expires = clock()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String();
    store._db.execute(
      'INSERT INTO staff_access(employee_id,enabled,enrollment_hash,enrollment_expires,enrollment_used) VALUES(?,1,?,?,NULL) ON CONFLICT(employee_id) DO UPDATE SET enabled=1,enrollment_hash=excluded.enrollment_hash,enrollment_expires=excluded.enrollment_expires,enrollment_used=NULL',
      [employeeId, _hash(token), expires],
    );
    if (revokeSessions) {
      store._db.execute(
        'UPDATE staff_sessions SET revoked_at=? WHERE employee_id=? AND revoked_at IS NULL',
        [_now(), employeeId],
      );
    }
    return EnrollmentCode(token, expires);
  });
  void disable(int employeeId) => _locked(() {
    store._db.execute(
      'INSERT INTO staff_access(employee_id,enabled) VALUES(?,0) ON CONFLICT(employee_id) DO UPDATE SET enabled=0,enrollment_hash=NULL,enrollment_expires=NULL',
      [employeeId],
    );
    store._db.execute(
      'UPDATE staff_sessions SET revoked_at=? WHERE employee_id=? AND revoked_at IS NULL',
      [_now(), employeeId],
    );
  });
  bool enabled(int employeeId) {
    final rows = store._db.select(
      'SELECT enabled FROM staff_access WHERE employee_id=?',
      [employeeId],
    );
    return rows.isEmpty || rows.single['enabled'] == 1;
  }

  ActivatedSession activate(
    String enrollment,
    String deviceName,
  ) => _locked(() {
    final rows = store._db.select(
      'SELECT * FROM staff_access WHERE enrollment_hash=?',
      [_hash(enrollment)],
    );
    if (enrollment.length < 32 || rows.isEmpty) {
      throw const StaffUnauthorized('QR geçersiz veya yenilenmiş');
    }
    final r = rows.single;
    if (r['enabled'] != 1 ||
        r['enrollment_used'] != null ||
        !DateTime.parse(r['enrollment_expires'] as String).isAfter(clock())) {
      throw const StaffUnauthorized('QR kullanılmış veya süresi dolmuş');
    }
    final id = r['employee_id'] as int, e = _employee(r['employee_id'] as int);
    final token = _random(),
        session = _random(),
        csrf = _random(),
        now = _now();
    final expires = clock()
        .toUtc()
        .add(const Duration(days: 30))
        .toIso8601String();
    final name = deviceName.trim().isEmpty ? 'Telefon' : deviceName.trim();
    if (name.length > 100) throw const FormatException('Cihaz adı çok uzun');
    store._db.execute(
      'INSERT INTO staff_sessions(id,employee_id,token_hash,csrf,device_name,created_at,last_seen,expires_at) VALUES(?,?,?,?,?,?,?,?)',
      [session, id, _hash(token), csrf, name, now, now, expires],
    );
    store._db.execute(
      'UPDATE staff_access SET enrollment_used=? WHERE employee_id=?',
      [now, id],
    );
    return ActivatedSession(
      token,
      StaffPrincipal(id, '${e['name']}', session, csrf),
      expires,
    );
  });
  StaffPrincipal authenticate(
    String? token, {
    String? csrf,
    bool write = false,
  }) {
    if (token == null || token.length < 32) throw const StaffUnauthorized();
    final rows = store._db.select(
      'SELECT * FROM staff_sessions WHERE token_hash=?',
      [_hash(token)],
    );
    if (rows.isEmpty) throw const StaffUnauthorized();
    final r = rows.single, id = r['employee_id'] as int;
    if (r['revoked_at'] != null ||
        !enabled(id) ||
        !DateTime.parse(r['expires_at'] as String).isAfter(clock())) {
      throw const StaffUnauthorized();
    }
    final e = _employee(id);
    if (write && csrf != r['csrf']) {
      throw const StaffUnauthorized('İşlem doğrulaması geçersiz');
    }
    return StaffPrincipal(id, '${e['name']}', '${r['id']}', '${r['csrf']}');
  }

  void touch(StaffPrincipal p) => store._db.execute(
    'UPDATE staff_sessions SET last_seen=? WHERE id=?',
    [_now(), p.sessionId],
  );
  void revoke(String sessionId) => store._db.execute(
    'UPDATE staff_sessions SET revoked_at=? WHERE id=?',
    [_now(), sessionId],
  );
  List<Json> sessions(int id) => store._db
      .select(
        'SELECT id,device_name,created_at,last_seen,expires_at,revoked_at FROM staff_sessions WHERE employee_id=? ORDER BY created_at DESC',
        [id],
      )
      .map((r) => Map<String, dynamic>.from(r))
      .toList();

  /// Recheck inside the domain transaction, including after receipt replay.
  void validatePrincipal(StaffPrincipal p) {
    final rows = store._db.select(
      'SELECT token_hash FROM staff_sessions WHERE id=? AND revoked_at IS NULL',
      [p.sessionId],
    );
    if (rows.isEmpty || !enabled(p.employeeId)) throw const StaffUnauthorized();
    _employee(p.employeeId);
    final row = store._db.select(
      'SELECT expires_at FROM staff_sessions WHERE id=?',
      [p.sessionId],
    ).single;
    if (!DateTime.parse(row['expires_at'] as String).isAfter(clock())) {
      throw const StaffUnauthorized();
    }
  }

  String commandKey(StaffPrincipal p, String id) =>
      'staff_${_hash('${p.employeeId}:$id')}';
}

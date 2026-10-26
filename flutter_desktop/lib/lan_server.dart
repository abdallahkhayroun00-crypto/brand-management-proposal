import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'staff_commands.dart';
import 'pos_store.dart';
import 'pos_logic.dart';
import 'order_actions.dart';

/// Native Flutter Windows HTTP server for employee phones. No Python process.
class PosLanServer extends ChangeNotifier {
  PosLanServer(this.store, {this.port = 8787, String? staffHtml})
    : _staffHtml = staffHtml;
  final PosStore store;
  late final StaffAuth auth = StaffAuth(store);
  HttpServer? _server;
  String? error;
  int port;
  String? selectedIp;
  List<String> addresses = const [];
  String? _staffHtml;

  bool get running => _server != null;
  bool get available => addresses.any((a) => a != '127.0.0.1');
  String get staffUrl => 'http://${selectedIp ?? '127.0.0.1'}:$port/personel';
  String get adminBrowserUrl => 'Windows Yönetici Paneli';

  Future<void> discover() async {
    final list = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final found = <String>[];
    final ranked = <(String, String)>[];
    for (final interface in list) {
      for (final address in interface.addresses) {
        final ip = address.address;
        if (!_privateIp(ip) || found.contains(ip)) continue;
        found.add(ip);
        ranked.add((interface.name.toLowerCase(), ip));
      }
    }
    ranked.sort((a, b) {
      int rank(String x) {
        if (x.contains('wi-fi') ||
            x.contains('wlan') ||
            x.contains('wireless')) {
          return 0;
        }
        if (x.contains('ethernet')) return 1;
        return 2;
      }

      return rank(a.$1).compareTo(rank(b.$1));
    });
    addresses = ranked.map((v) => v.$2).toList(growable: false);
    if (selectedIp == null || !addresses.contains(selectedIp)) {
      selectedIp = addresses.isEmpty ? '127.0.0.1' : addresses.first;
    }
    notifyListeners();
  }

  static bool _privateIp(String ip) {
    final bytes = InternetAddress.tryParse(ip)?.rawAddress;
    if (bytes == null || bytes.length != 4) return false;
    return bytes[0] == 10 ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31);
  }

  void chooseIp(String value) {
    if (addresses.contains(value)) {
      selectedIp = value;
      notifyListeners();
    }
  }

  Future<void> start() async {
    if (_server != null) return;
    error = null;
    try {
      await discover();
      _staffHtml ??= await rootBundle.loadString('assets/staff.html');
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      port = _server!.port;
      _server!.listen(
        (r) => _handle(r).catchError((Object e, StackTrace stack) {
          debugPrint('LAN server error: $e');
          try {
            _json(r.response, 500, {'error': 'server_error'});
          } catch (_) {
            try {
              r.response.close();
            } catch (_) {}
          }
        }),
        onError: (Object e) {
          error = 'Local Server error: $e';
          notifyListeners();
        },
      );
    } catch (e) {
      error = 'Port $port kullanılamıyor: $e';
    }
    notifyListeners();
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
    notifyListeners();
  }

  void _json(HttpResponse response, int status, Map<String, dynamic> data) {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set('Cache-Control', 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.write(jsonEncode(data));
    response.close();
  }

  Future<Json> _body(HttpRequest request) async {
    if (request.headers.contentType?.mimeType != 'application/json') {
      throw const FormatException('JSON gerekli');
    }
    if (request.contentLength > 256 * 1024) {
      throw const FormatException('İstek çok büyük');
    }
    final bytes = <int>[];
    await for (final part in request) {
      bytes.addAll(part);
      if (bytes.length > 256 * 1024) {
        throw const FormatException('İstek çok büyük');
      }
    }
    final body = jsonDecode(utf8.decode(bytes));
    if (body is! Map) throw const FormatException('Geçersiz istek');
    return Map<String, dynamic>.from(body);
  }

  String? _cookie(HttpRequest r) =>
      r.cookies.where((c) => c.name == 'nf_session').firstOrNull?.value;
  Future<void> _handle(HttpRequest request) async {
    final resource = request.uri.path;
    if (request.method == 'GET' && resource == '/brand-logo') {
      final bytes = await rootBundle.load('assets/brand-logo.jpeg');
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.add(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      await request.response.close();
      return;
    }
    if (request.method == 'GET' &&
        ['/', '/personel', '/personel/'].contains(resource)) {
      request.response.headers.contentType = ContentType.html;
      request.response.headers.set('Cache-Control', 'no-store');
      request.response.headers.set('Referrer-Policy', 'no-referrer');
      request.response.headers.set('X-Content-Type-Options', 'nosniff');
      request.response.headers.set(
        'Content-Security-Policy',
        "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'; form-action 'self'",
      );
      request.response.write(_staffHtml);
      await request.response.close();
      return;
    }
    if (request.method == 'GET' && resource == '/api/health') {
      _json(request.response, 200, {'online': true});
      return;
    }
    if (request.method == 'PUT' && resource == '/api/state') {
      _json(request.response, 405, {'error': 'snapshot_writes_disabled'});
      return;
    }
    try {
      if (request.method == 'POST') {
        final origin = request.headers.value('origin');
        if (origin != null &&
            Uri.tryParse(origin)?.authority != request.headers.value('host')) {
          _json(request.response, 403, {'error': 'origin'});
          return;
        }
      }
      if (request.method == 'POST' && resource == '/api/staff/enroll') {
        final data = await _body(request);
        final session = auth.activate(
          '${data['token'] ?? ''}',
          '${data['deviceName'] ?? 'Telefon'}',
        );
        request.response.cookies.add(
          Cookie('nf_session', session.token)
            ..httpOnly = true
            ..sameSite = SameSite.strict
            ..path = '/'
            ..maxAge = 30 * 86400,
        );
        _json(request.response, 200, {
          'ok': true,
          'staff': session.principal.actor,
          'csrf': session.principal.csrf,
        });
        return;
      }
      final principal = auth.authenticate(
        _cookie(request),
        csrf: request.headers.value('x-csrf-token'),
        write: request.method != 'GET',
      );
      if (request.method == 'GET' &&
          ['/api/bootstrap', '/api/state'].contains(resource)) {
        auth.touch(principal);
        final current = store.read();
        _json(request.response, 200, {
          'online': true,
          'revision': current.revision,
          'state': staffProjection(current.data),
          'staff': principal.actor,
          'csrf': principal.csrf,
          'storage': 'SQLite (Flutter Desktop)',
          'updatedAt': current.updatedAt,
        });
        return;
      }
      if (request.method == 'POST' && resource == '/api/staff/logout') {
        auth.revoke(principal.sessionId);
        request.response.cookies.add(
          Cookie('nf_session', '')
            ..path = '/'
            ..maxAge = 0
            ..httpOnly = true
            ..sameSite = SameSite.strict,
        );
        _json(request.response, 200, {'ok': true});
        return;
      }
      if (request.method == 'POST' &&
          [
            '/api/staff/orders',
            '/api/staff/ready',
            '/api/staff/retry',
          ].contains(resource)) {
        final data = await _body(request);
        final allowed = resource.endsWith('/orders')
            ? {
                'requestId',
                'expectedRevision',
                'source',
                'table',
                'lines',
                'pickupChannel',
                'customer',
              }
            : resource.endsWith('/ready')
            ? {'requestId', 'orderId'}
            : {'requestId', 'operationId'};
        if (data.keys.any((k) => !allowed.contains(k))) {
          _json(request.response, 403, {
            'error': 'forbidden_field',
            'message': 'Bu işlem personel yetkisinde değil',
          });
          return;
        }
        final Json result;
        if (resource.endsWith('/orders')) {
          result = submitStaffOrder(
            store,
            data,
            principal: principal,
            auth: auth,
          );
        } else if (resource.endsWith('/ready')) {
          result = submitStaffReady(store, auth, principal, data);
        } else {
          result = submitStaffRetry(store, auth, principal, data);
        }
        _json(request.response, 200, result);
        return;
      }
      _json(request.response, 403, {'error': 'forbidden'});
    } on StaffUnauthorized catch (e) {
      _json(request.response, 401, {
        'error': 'unauthorized',
        'message': e.message,
      });
    } on StaffConflict {
      _json(request.response, 409, {
        'error': 'conflict',
        'revision': store.read().revision,
      });
    } on FormatException catch (e) {
      _json(request.response, 422, {
        'error': 'invalid_request',
        'message': e.message,
      });
    }
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }
}

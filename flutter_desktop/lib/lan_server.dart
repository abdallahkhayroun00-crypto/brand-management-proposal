import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'staff_commands.dart';
import 'pos_store.dart';

/// Native Flutter Windows HTTP server for employee phones. No Python process.
class PosLanServer extends ChangeNotifier {
  PosLanServer(this.store, {this.port = 8787, String? staffHtml})
    : _staffHtml = staffHtml;
  final PosStore store;
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

  Future<void> _handle(HttpRequest request) async {
    final uri = request.uri;
    final resource = uri.path;
    if (request.method == 'GET' &&
        ['/', '/personel', '/personel/'].contains(resource)) {
      request.response.headers.contentType = ContentType.html;
      request.response.headers.set('Cache-Control', 'no-store');
      request.response.headers.set('X-Content-Type-Options', 'nosniff');
      request.response.write(_staffHtml);
      await request.response.close();
      return;
    }
    if (request.method == 'GET' && resource == '/api/health') {
      _json(request.response, 200, {
        'online': true,
        'revision': store.read().revision,
      });
      return;
    }
    if (request.method == 'GET' && resource == '/api/state') {
      final current = store.read();
      _json(request.response, 200, {
        'revision': current.revision,
        'state': current.data,
      });
      return;
    }
    if (request.method == 'GET' && resource == '/api/bootstrap') {
      final current = store.read();
      _json(request.response, 200, {
        'online': true,
        'revision': current.revision,
        'state': current.data,
        'ip': selectedIp,
        'port': port,
        'staffUrl': staffUrl,
        'adminUrl': adminBrowserUrl,
        'storage': 'SQLite (Flutter Desktop)',
        'updatedAt': current.updatedAt,
      });
      return;
    }
    if (request.method == 'POST' && resource == '/api/staff/orders') {
      // Reject browser requests from unrelated origins (prototype has no login).
      final origin = request.headers.value('origin');
      if (origin != null &&
          Uri.tryParse(origin)?.authority != request.headers.value('host')) {
        _json(request.response, 403, {'error': 'origin'});
        return;
      }
      if (request.contentLength > 256 * 1024) {
        _json(request.response, 413, {'error': 'payload_size'});
        return;
      }
      final chunks = <int>[];
      await for (final part in request) {
        chunks.addAll(part);
        if (chunks.length > 256 * 1024) {
          _json(request.response, 413, {'error': 'payload_size'});
          return;
        }
      }
      try {
        final incoming = jsonDecode(utf8.decode(chunks));
        if (incoming is! Map) throw const FormatException('Geçersiz istek');
        final result = submitStaffOrder(
          store,
          Map<String, dynamic>.from(incoming),
        );
        _json(request.response, 200, result);
      } on StaffConflict {
        _json(request.response, 409, {
          'error': 'conflict',
          'revision': store.read().revision,
        });
      } on FormatException catch (e) {
        _json(request.response, 422, {
          'error': 'invalid_order',
          'message': e.message,
        });
      }
      return;
    }
    if (request.method != 'GET') {
      _json(request.response, 405, {'error': 'method_not_allowed'});
      return;
    }
    _json(request.response, 404, {'error': 'not_found'});
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }
}

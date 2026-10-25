import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as paths;
import 'pos_store.dart';

/// Native Flutter Windows HTTP server for employee phones. No Python process.
class PosLanServer extends ChangeNotifier {
  PosLanServer(this.store);
  final PosStore store;
  HttpServer? _server;
  String? error;
  int port = 8787;
  String? selectedIp;
  List<String> addresses = const [];
  String? _siteRoot;

  bool get running => _server != null;
  bool get available => addresses.any((a) => a != '127.0.0.1');
  String get staffUrl =>
      'http://${selectedIp ?? '127.0.0.1'}:$port/pos-demo/?panel=personel';
  String get adminBrowserUrl =>
      'http://127.0.0.1:$port/pos-demo/?panel=yonetici';

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
        if (x.contains('wi-fi') || x.contains('wlan') ||
            x.contains('wireless')) return 0;
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
    return bytes[0] == 10 || (bytes[0] == 192 && bytes[1] == 168) ||
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
      _siteRoot = _findSiteRoot();
      if (_siteRoot == null) {
        error = 'Personel web dosyaları yok. Windows paketi yeniden oluşturulmalı.';
        notifyListeners();
        return;
      }
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server!.listen(
        (r) => _handle(r).catchError((Object e, StackTrace stack) {
          debugPrint('LAN server error: $e');
          try {
            _json(r.response, 500, {'error': 'server_error'});
          } catch (_) {
            try { r.response.close(); } catch (_) {}
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

  String? _findSiteRoot() {
    final roots = [
      paths.join(paths.dirname(Platform.resolvedExecutable), 'site'),
      paths.normalize(paths.join(Directory.current.path, '..')),
      Directory.current.path,
    ];
    for (final root in roots) {
      if (File(paths.join(root, 'pos-demo', 'index.html')).existsSync() &&
          File(paths.join(root, 'nohut-menu', 'menu-data.js')).existsSync()) {
        return root;
      }
    }
    return null;
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
    if (request.method == 'GET' && resource == '/') {
      request.response.redirect(Uri.parse('/pos-demo/?panel=personel'));
      return;
    }
    if (request.method == 'GET' && resource == '/personel') {
      request.response.redirect(Uri.parse('/pos-demo/?panel=personel'));
      return;
    }
    if (request.method == 'GET' && resource == '/api/health') {
      _json(request.response, 200, {
        'online': true, 'revision': store.read().revision,
      });
      return;
    }
    if (request.method == 'GET' && resource == '/api/state') {
      final current = store.read();
      _json(request.response, 200, {
        'revision': current.revision, 'state': current.data,
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
    if (request.method == 'PUT' && resource == '/api/state') {
      if (request.contentLength > 4 * 1024 * 1024) {
        _json(request.response, 413, {'error': 'payload_size'});
        return;
      }
      final chunks = <int>[];
      await for (final part in request) {
        chunks.addAll(part);
        if (chunks.length > 4 * 1024 * 1024) {
          _json(request.response, 413, {'error': 'payload_size'});
          return;
        }
      }
      try {
        final incoming = jsonDecode(utf8.decode(chunks));
        if (incoming is! Map ||
            incoming['baseVersion'] is! int || incoming['state'] is! Map) {
          _json(request.response, 400, {'error': 'invalid_packet'});
          return;
        }
        final next = Map<String, dynamic>.from(incoming['state'] as Map);
        final result = store.replace(next, incoming['baseVersion'] as int);
        if (!result.ok) {
          _json(request.response, 409, {
            'error': 'conflict',
            'revision': result.snapshot.revision,
            'state': result.snapshot.data,
          });
        } else {
          _json(request.response, 200, {
            'ok': true,
            'revision': result.snapshot.revision,
          });
        }
      } on FormatException catch (e) {
        _json(request.response, 422, {
          'error': 'invalid_state', 'message': e.message,
        });
      } catch (e) {
        _json(request.response, 500, {'error': 'server_error'});
      }
      return;
    }
    if (request.method != 'GET') {
      _json(request.response, 405, {'error': 'method_not_allowed'});
      return;
    }
    await _serveAsset(request);
  }

  Future<void> _serveAsset(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    if (segments.isEmpty || !['pos-demo', 'nohut-menu'].contains(segments.first) ||
        segments.any((s) => s == '..' || s.startsWith('.') ||
            ['local-data', 'tests', '__pycache__'].contains(s))) {
      _json(request.response, 404, {'error': 'not_found'});
      return;
    }
    final root = _siteRoot!;
    var target = paths.normalize(paths.joinAll([root, ...segments]));
    if (!paths.isWithin(root, target)) {
      _json(request.response, 403, {'error': 'forbidden'});
      return;
    }
    if (request.uri.path.endsWith('/')) {
      target = paths.join(target, 'index.html');
    }
    final ext = paths.extension(target).toLowerCase();
    const types = {
      '.html': 'text/html', '.css': 'text/css', '.js': 'application/javascript',
      '.json': 'application/json', '.svg': 'image/svg+xml',
      '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
      '.webp': 'image/webp', '.ico': 'image/x-icon', '.gif': 'image/gif',
      '.woff': 'font/woff', '.woff2': 'font/woff2',
    };
    if (!types.containsKey(ext)) {
      _json(request.response, 403, {'error': 'forbidden'});
      return;
    }
    final file = File(target);
    if (!await file.exists()) {
      _json(request.response, 404, {'error': 'not_found'});
      return;
    }
    request.response.headers.set('Content-Type', '${types[ext]}; charset=utf-8');
    request.response.headers.set('X-Content-Type-Options', 'nosniff');
    if (ext == '.html' || ext == '.js') {
      request.response.headers.set('Cache-Control', 'no-store');
    }
    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }
}

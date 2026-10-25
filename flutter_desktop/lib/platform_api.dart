import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'pos_logic.dart';

abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class WindowsSecretStore implements SecretStore {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

class PlatformCredentials {
  PlatformCredentials(this.source, this.values);
  final String source;
  final Json values;
  String get mode => '${values['mode'] ?? 'off'}';
  String field(String key) => '${values[key] ?? ''}';
  bool get confirmed => values['programConfirmed'] == true;
  String get scope => jsonEncode([
    source,
    mode,
    if (source == 'Trendyol Go') ...[
      field('supplierId'),
      field('storeId'),
    ] else ...[
      field('chainCode'),
      field('remoteId'),
      field('platformKey'),
    ],
  ]);
  bool get configured {
    final fields = source == 'Trendyol Go'
        ? ['supplierId', 'storeId', 'apiKey', 'apiSecret', 'executorEmail']
        : ['username', 'password', 'chainCode', 'remoteId', 'platformKey'];
    return fields.every((k) => field(k).trim().isNotEmpty);
  }

  Uri get base => Uri.parse(
    source == 'Trendyol Go'
        ? (mode == 'live'
              ? 'https://api.tgoapis.com'
              : 'https://stageapi.tgoapis.com')
        : (mode == 'live'
              ? 'https://integration-middleware.eu.restaurant-partners.com'
              : 'https://integration-middleware.stg.restaurant-partners.com'),
  );
  void validate() {
    if (!['off', 'stage', 'live'].contains(mode)) {
      throw const FormatException('Ortam geçersiz');
    }
    if (source == 'Trendyol Go' &&
        field('supplierId').isNotEmpty &&
        !RegExp(r'^\d+$').hasMatch(field('supplierId'))) {
      throw const FormatException('Supplier ID rakam olmalı');
    }
    if (mode != 'off' && (!configured || !confirmed)) {
      throw const FormatException(
        'Önce resmi hesap bilgilerini ve entegrasyon programını doğrulayın',
      );
    }
    for (final v in values.values.whereType<String>()) {
      if (v.contains('\r') || v.contains('\n')) {
        throw const FormatException('Tek satırlık bilgi gerekli');
      }
    }
    final relay = field('relayUrl');
    if (relay.isNotEmpty) {
      final uri = Uri.tryParse(relay);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw const FormatException('Gateway HTTPS adresi gerekli');
      }
    }
  }
}

class CredentialVault {
  CredentialVault(this.storage);
  final SecretStore storage;
  String _key(String source) =>
      'nohut.pos.platform.v1.${source == 'Trendyol Go' ? 'tgo' : 'ys'}';
  Future<PlatformCredentials> load(String source) async {
    final value = await storage.read(_key(source));
    return PlatformCredentials(
      source,
      value == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(value) as Map),
    );
  }

  Future<void> save(PlatformCredentials c) async {
    c.validate();
    await storage.write(_key(c.source), jsonEncode(c.values));
  }

  Future<void> remove(String source) => storage.delete(_key(source));
}

class ApiReply {
  const ApiReply(this.status, this.data, {this.retryAfter});
  final int status;
  final dynamic data;
  final DateTime? retryAfter;
}

abstract class ApiTransport {
  Future<ApiReply> call(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? body,
    bool form = false,
  });
  void close() {}
}

class NativeApiTransport extends ApiTransport {
  NativeApiTransport({HttpClient? client}) : client = client ?? HttpClient();
  final HttpClient client;
  @override
  Future<ApiReply> call(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? body,
    bool form = false,
  }) async {
    if (url.scheme != 'https' || url.userInfo.isNotEmpty) {
      throw const FormatException('Platform bağlantıları HTTPS olmalı');
    }
    final req = await client
        .openUrl(method, url)
        .timeout(const Duration(seconds: 20));
    req.followRedirects = false;
    headers.forEach(req.headers.set);
    if (body != null) {
      req.headers.contentType = form
          ? ContentType('application', 'x-www-form-urlencoded')
          : ContentType.json;
      req.write(
        form
            ? Uri(queryParameters: (body as Map<String, String>)).query
            : jsonEncode(body),
      );
    }
    final response = await req.close().timeout(const Duration(seconds: 25));
    final bytes = <int>[];
    await for (final part in response.timeout(const Duration(seconds: 25))) {
      bytes.addAll(part);
      if (bytes.length > 8 * 1024 * 1024) {
        throw const FormatException('Platform yanıtı çok büyük');
      }
    }
    dynamic data;
    try {
      data = bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
    } catch (_) {
      data = null;
    }
    final retry = response.headers.value('retry-after');
    DateTime? next;
    if (retry != null) {
      final seconds = int.tryParse(retry);
      if (seconds != null) {
        next = DateTime.now().toUtc().add(
          Duration(seconds: seconds.clamp(1, 3600)),
        );
      } else {
        try {
          next = HttpDate.parse(retry);
        } catch (_) {}
      }
    }
    return ApiReply(response.statusCode, data, retryAfter: next);
  }

  @override
  void close() => client.close(force: true);
}

class IntegrationFailure implements Exception {
  const IntegrationFailure(
    this.message, {
    this.uncertain = false,
    this.retryAfter,
  });
  final String message;
  final bool uncertain;
  final DateTime? retryAfter;
}

void checkReply(ApiReply r, {bool mutation = false}) {
  if (r.status >= 200 && r.status < 300) return;
  // Response bodies can echo credentials/customer information; never persist them.
  throw IntegrationFailure(
    'Platform HTTP ${r.status}',
    uncertain: mutation && (r.status >= 500 || r.status == 409),
    retryAfter: r.status == 429
        ? (r.retryAfter ??
              DateTime.now().toUtc().add(const Duration(seconds: 10)))
        : null,
  );
}

class RestaurantApi {
  RestaurantApi(this.transport);
  final ApiTransport transport;
  final _tokens = <String, (String, DateTime)>{};
  Map<String, String> tgoHeaders(PlatformCredentials c) => {
    'Authorization':
        'Basic ${base64Encode(utf8.encode('${c.field('apiKey')}:${c.field('apiSecret')}'))}',
    'User-Agent': '${c.field('supplierId')} - SelfIntegration',
    'x-agentname': 'NohutFalafel',
    'x-executor-user': c.field('executorEmail'),
  };
  Future<ApiReply> tgoPage(
    PlatformCredentials c,
    int page,
    int from,
    int to,
  ) async {
    final path =
        '/integrator/order/meal/suppliers/${Uri.encodeComponent(c.field('supplierId'))}/packages';
    final r = await transport.call(
      'GET',
      c.base
          .resolve(path)
          .replace(
            queryParameters: {
              'storeId': c.field('storeId'),
              'page': '$page',
              'size': '50',
              'packageModificationStartDate': '$from',
              'packageModificationEndDate': '$to',
            },
          ),
      headers: tgoHeaders(c),
    );
    checkReply(r);
    return r;
  }

  Future<String> ysToken(PlatformCredentials c) async {
    final key = '${c.mode}:${c.field('username')}:${c.field('password')}';
    final cached = _tokens[key];
    if (cached != null &&
        cached.$2.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return cached.$1;
    }
    final reply = await transport.call(
      'POST',
      c.base.resolve('/v2/login'),
      form: true,
      body: <String, String>{
        'username': c.field('username'),
        'password': c.field('password'),
        'grant_type': 'client_credentials',
      },
    );
    checkReply(reply);
    if (reply.data is! Map || reply.data['access_token'] is! String) {
      throw const IntegrationFailure('Kimlik doğrulama yanıtı geçersiz');
    }
    final token = reply.data['access_token'] as String;
    final seconds = (reply.data['expires_in'] as num?)?.toInt() ?? 300;
    _tokens[key] = (
      token,
      DateTime.now().add(Duration(seconds: seconds.clamp(1, 86400))),
    );
    return token;
  }

  Uri ysCallback(PlatformCredentials c, Json order, String action) {
    final callbacks = order['providerCallbacks'];
    final key = action == 'ready'
        ? 'orderPreparedUrl'
        : action == 'accept'
        ? 'orderAcceptedUrl'
        : 'orderRejectedUrl';
    final uri = Uri.tryParse('${callbacks is Map ? callbacks[key] ?? '' : ''}');
    final token = Uri.encodeComponent('${order['platformPackageId']}');
    final expected = action == 'ready'
        ? '/v2/orders/$token/preparation-completed'
        : '/v2/order/status/$token';
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.origin != c.base.origin ||
        uri.path != expected ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const IntegrationFailure(
        'Bu siparişte onaylı platform callback yetkisi yok',
      );
    }
    if (action != 'ready' && c.values['directApproved'] != true) {
      throw const IntegrationFailure(
        'Yemeksepeti Direct Flow hesap onayı gerekli',
      );
    }
    if (action == 'ready' && c.values['preparedApproved'] != true) {
      throw const IntegrationFailure(
        'Yemeksepeti hazırlık bildirimi hesap onayı gerekli',
      );
    }
    return uri;
  }

  Future<void> action(PlatformCredentials c, Json order, Json job) async {
    if (c.source == 'Trendyol Go') {
      // The currently accessible primary Meal docs establish polling and states,
      // but do not expose the current Meal mutation contract after migration.
      // Grocery /picked or /invoiced are deliberately NOT substituted here.
      throw const IntegrationFailure(
        'Trendyol Go Yemek kabul / hazır servis sözleşmesi platformdan doğrulanmalı; Market endpointi kullanılmadı',
      );
    }
    final uri = ysCallback(c, order, '${job['action']}');
    final token = await ysToken(c);
    Object? body;
    if (job['action'] == 'accept') {
      final expected = order['providerExpectedPickupAt'];
      if (expected is! String || DateTime.tryParse(expected) == null) {
        throw const IntegrationFailure(
          'Platformun beklenen teslim alma zamanı eksik',
        );
      }
      body = {
        'status': 'order_accepted',
        'acceptanceTime': expected,
        'remoteOrderId': '${order['providerRemoteOrderId']}',
      };
    }
    if (job['action'] == 'reject') {
      final reason = {
        621: 'ITEM_UNAVAILABLE',
        622: 'CLOSED',
        623: 'TOO_BUSY',
        627: 'MENU_ACCOUNT_SETTINGS',
      }[job['reasonId']];
      if (reason == null) {
        throw const IntegrationFailure('Platform ret nedeni geçersiz');
      }
      body = {
        'status': 'order_rejected',
        'reason': reason,
        'message': 'Kasa (PC) tarafından reddedildi',
      };
    }
    try {
      final r = await transport.call(
        'POST',
        uri,
        headers: {'Authorization': 'Bearer $token'},
        body: body,
      );
      checkReply(r, mutation: true);
    } on IntegrationFailure {
      rethrow;
    } catch (_) {
      throw const IntegrationFailure(
        'Platform sonucu alınamadı; tekrar göndermeden doğrulayın',
        uncertain: true,
      );
    }
  }
}

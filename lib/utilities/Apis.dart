// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:trimline_parcel/models/app_location.dart';
import 'package:trimline_parcel/models/app_user.dart';
import 'package:trimline_parcel/models/app_vehicle.dart';
import 'package:trimline_parcel/models/app_version_info.dart';
import 'package:trimline_parcel/models/batches.dart';
import 'package:trimline_parcel/models/parcel_model.dart';
import 'package:trimline_parcel/utilities/logger.dart';

class ApiClient extends ChangeNotifier {
  final LoggerService logger = Get.find();
  String baseUrl = "https://nav.trimline.co.ke:4013/api/Parcel/";

  dynamic _readEnvelopeValue(Map<String, dynamic> decoded, String key) {
    if (decoded.containsKey(key)) return decoded[key];
    final lower = key.toLowerCase();
    for (final entry in decoded.entries) {
      if (entry.key.toLowerCase() == lower) {
        return entry.value;
      }
    }
    return null;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-Client-Identifier': "REMBOCLASIC",
  };

  /// Retries the [request] up to [maxRetries] times if the server returns
  /// 502 (Bad Gateway) or 503 (Service Unavailable) — typical during deploys.
  Future<http.Response> _withRetry(
    Future<http.Response> Function() request, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await request();
        if (response.statusCode != 502 && response.statusCode != 503) {
          return response;
        }
        if (attempt < maxRetries) {
          logger.info(
            'Server ${response.statusCode} — retrying in ${delay.inSeconds}s (attempt $attempt/$maxRetries)',
          );
          await Future.delayed(delay);
        } else {
          logger.warning(
            'Server still returning ${response.statusCode} after $maxRetries attempts',
          );
          return response;
        }
      } catch (_) {
        if (attempt < maxRetries) {
          logger.info(
            'Request failed — retrying in ${delay.inSeconds}s (attempt $attempt/$maxRetries)',
          );
          await Future.delayed(delay);
        } else {
          rethrow;
        }
      }
    }
    // Unreachable but satisfies return type.
    return await request();
  }

  Future<http.Response> postdata(
    String url,
    String? data, {
    Set<int> ignoredStatusCodes = const <int>{},
  }) async {
    http.Response? r = http.Response("", 200);
    try {
      String urls = '$baseUrl$url';
      logger.info(urls);
      logger.info("out: $data");
      r = await _withRetry(
        () => http.post(Uri.parse(urls), body: data, headers: _headers),
      );

      if ((r.statusCode == 307 || r.statusCode == 308) &&
          r.headers['location'] != null) {
        final redirectUri = Uri.parse(urls).resolve(r.headers['location']!);
        logger.info('POST redirect for $url -> $redirectUri');
        r = await http.post(redirectUri, body: data, headers: _headers);
      }

      logger.info('url: $url, status code: ${r.statusCode}');
      logger.info('url: ${url}body: ${r.body}');

      if (r.statusCode != 200 && !ignoredStatusCodes.contains(r.statusCode)) {
        logger.error(r.statusCode.toString());
        logger.error(r.body);
      }
    } catch (e, stackTrace) {
      logger.error("API failed", error: e, stackTrace: stackTrace);
      rethrow;
    }
    return await Future.value(r);
  }

  Future<http.Response> putdata(String url, String? data) async {
    http.Response? r = http.Response("", 200);
    try {
      String urls = '$baseUrl$url';
      logger.info(urls);
      logger.info("out: $data");
      r = await _withRetry(
        () => http.put(Uri.parse(urls), body: data, headers: _headers),
      );

      if ((r.statusCode == 307 || r.statusCode == 308) &&
          r.headers['location'] != null) {
        final redirectUri = Uri.parse(urls).resolve(r.headers['location']!);
        logger.info('PUT redirect for $url -> $redirectUri');
        r = await http.put(redirectUri, body: data, headers: _headers);
      }

      if (r.statusCode == 405) {
        logger.info('PUT not allowed for $url, retrying with POST');
        r = await http.post(Uri.parse(urls), body: data, headers: _headers);

        if ((r.statusCode == 307 || r.statusCode == 308) &&
            r.headers['location'] != null) {
          final redirectUri = Uri.parse(urls).resolve(r.headers['location']!);
          logger.info('POST fallback redirect for $url -> $redirectUri');
          r = await http.post(redirectUri, body: data, headers: _headers);
        }
      }

      logger.info('url: $url, status code: ${r.statusCode}');
      logger.info('url: ${url}body: ${r.body}');

      if (r.statusCode != 200) {
        logger.error(r.statusCode.toString());
        logger.error(r.body);
      }
    } catch (e, stackTrace) {
      logger.error("API failed", error: e, stackTrace: stackTrace);
      rethrow;
    }
    return await Future.value(r);
  }

  Future<http.Response> getdata(String url) async {
    http.Response? r = http.Response("", 200);
    try {
      String urls = '$baseUrl$url';
      logger.info(urls);
      r = await _withRetry(() => http.get(Uri.parse(urls), headers: _headers));
      logger.info('url: $url, status code: ${r.statusCode}');
      logger.info('url: ${url}body: ${r.body}');

      if (r.statusCode != 200) {
        logger.error(r.statusCode.toString());
        logger.error(r.body);
      }
    } catch (e, stackTrace) {
      logger.error("API failed", error: e, stackTrace: stackTrace);
      rethrow;
    }
    return await Future.value(r);
  }

  Future<http.Response> deletedata(String url) async {
    http.Response? r = http.Response("", 200);
    try {
      String urls = '$baseUrl$url';
      logger.info(urls);
      r = await _withRetry(
        () => http.delete(Uri.parse(urls), headers: _headers),
      );
      logger.info('url: $url, status code: ${r.statusCode}');
      logger.info('url: ${url}body: ${r.body}');

      if (r.statusCode != 200) {
        logger.error(r.statusCode.toString());
        logger.error(r.body);
      }
    } catch (e, stackTrace) {
      logger.error("API failed", error: e, stackTrace: stackTrace);
      rethrow;
    }
    return await Future.value(r);
  }

  void _ensureSuccess(Map<String, dynamic> decoded) {
    final codeRaw = _readEnvelopeValue(decoded, 'Code');
    final int code =
        codeRaw is int
            ? codeRaw
            : int.tryParse(codeRaw?.toString() ?? '') ?? -1;
    if (code != 0) {
      throw Exception(
        _readEnvelopeValue(decoded, 'Desc')?.toString() ??
            'API returned an error',
      );
    }
  }

  Future<List<AppUser>> fetchUsers({int pageSize = 500}) async {
    final payload = jsonEncode({'PageSize': pageSize});
    final response = await postdata('nav/users', payload);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch users. HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected users response format');
    }

    final codeRaw = _readEnvelopeValue(decoded, 'Code');
    final int code =
        codeRaw is int
            ? codeRaw
            : int.tryParse(codeRaw?.toString() ?? '') ?? -1;
    if (code != 0) {
      throw Exception(
        _readEnvelopeValue(decoded, 'Desc')?.toString() ??
            'User API returned an error',
      );
    }

    final dynamic contents = _readEnvelopeValue(decoded, 'Contents');
    if (contents is! List) {
      return <AppUser>[];
    }

    return contents
        .whereType<Map>()
        .map((item) => AppUser.fromApi(Map<String, dynamic>.from(item)))
        .where((user) => user.agentCode.trim().isNotEmpty)
        .toList();
  }

  Future<AppUser?> fetchUserByAgentCode(String agentCode) async {
    final response = await getdata(
      'nav/users/${Uri.encodeComponent(agentCode)}',
    );

    if (response.statusCode != 200) {
      return null;
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final int code =
        decoded['Code'] is int
            ? decoded['Code']
            : int.tryParse(decoded['Code']?.toString() ?? '') ?? -1;
    if (code != 0) return null;

    final dynamic contents = decoded['Contents'];
    if (contents is! Map<String, dynamic>) return null;

    return AppUser.fromApi(contents);
  }

  Future<List<AppLocation>> fetchLocations({int pageSize = 500}) async {
    final payload = jsonEncode({'PageSize': pageSize});
    final response = await postdata('Locations', payload);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch locations. HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected locations response format');
    }

    final codeRaw = _readEnvelopeValue(decoded, 'Code');
    final int code =
        codeRaw is int
            ? codeRaw
            : int.tryParse(codeRaw?.toString() ?? '') ?? -1;
    if (code != 0) {
      throw Exception(
        _readEnvelopeValue(decoded, 'Desc')?.toString() ??
            'Location API returned an error',
      );
    }

    final dynamic contents = _readEnvelopeValue(decoded, 'Contents');
    if (contents is! List) {
      return <AppLocation>[];
    }

    return contents
        .whereType<Map>()
        .map((item) => AppLocation.fromApi(Map<String, dynamic>.from(item)))
        .where((location) => location.code.trim().isNotEmpty)
        .toList();
  }

  Future<List<AppVehicle>> fetchVehicles({int pageSize = 500}) async {
    final payload = jsonEncode({'PageSize': pageSize});
    final response = await postdata('Vehicles', payload);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch vehicles. HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected vehicles response format');
    }

    final codeRaw = _readEnvelopeValue(decoded, 'Code');
    final int code =
        codeRaw is int
            ? codeRaw
            : int.tryParse(codeRaw?.toString() ?? '') ?? -1;
    if (code != 0) {
      throw Exception(
        _readEnvelopeValue(decoded, 'Desc')?.toString() ??
            'Vehicle API returned an error',
      );
    }

    final dynamic contents = _readEnvelopeValue(decoded, 'Contents');
    if (contents is! List) {
      return <AppVehicle>[];
    }

    return contents
        .whereType<Map>()
        .map((item) => AppVehicle.fromApi(Map<String, dynamic>.from(item)))
        .where((vehicle) => vehicle.code.trim().isNotEmpty)
        .toList();
  }

  Future<List<Parcel>> fetchParcels({int pageSize = 1000}) async {
    final payload = jsonEncode({'PageSize': pageSize});
    var response = await postdata(
      'parcels',
      payload,
      ignoredStatusCodes: const <int>{404},
    );

    if (response.statusCode == 404) {
      logger.info('parcels not found, retrying with nav/parcels');
      response = await postdata(
        'nav/parcels',
        payload,
        ignoredStatusCodes: const <int>{404},
      );
    }

    if (response.statusCode == 404) {
      logger.info('nav/parcels not found, retrying with Parcels');
      response = await postdata('Parcels', payload);
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch parcels. HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected parcels response format');
    }

    _ensureSuccess(decoded);

    final dynamic contents = _readEnvelopeValue(decoded, 'Contents');
    if (contents is! List) {
      return <Parcel>[];
    }

    return contents
        .whereType<Map>()
        .map((item) => Parcel.fromJson(Map<String, dynamic>.from(item)))
        .map((parcel) => parcel.copyWith(isSynced: true))
        .where((parcel) => (parcel.Document_No ?? '').trim().isNotEmpty)
        .toList();
  }

  Future<List<Batches>> fetchBatches({int pageSize = 1000}) async {
    final payload = jsonEncode({'PageSize': pageSize});
    var response = await postdata(
      'nav/batches',
      payload,
      ignoredStatusCodes: const <int>{404},
    );

    if (response.statusCode == 404) {
      logger.info('nav/batches not found, retrying with Batches');
      response = await postdata('Batches', payload);
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch batches. HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected batches response format');
    }

    _ensureSuccess(decoded);

    final dynamic contents = _readEnvelopeValue(decoded, 'Contents');
    if (contents is! List) {
      return <Batches>[];
    }

    return contents
        .whereType<Map>()
        .map((item) => Batches.fromJson(Map<String, dynamic>.from(item)))
        .map((batch) => batch.copyWith(isSynced: true))
        .where((batch) => (batch.batchNo ?? '').trim().isNotEmpty)
        .toList();
  }

  Future<void> changeUserPassword({
    required String agentCode,
    required String password,
  }) async {
    final payload = jsonEncode({
      'AgentCode': agentCode.trim(),
      'Password': password.trim(),
    });

    final response = await postdata('nav/users/change-password', payload);
    if (response.statusCode != 200) {
      throw Exception('Failed to update password. HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected change-password response format');
    }

    final codeRaw = _readEnvelopeValue(decoded, 'Code');
    final int code =
        codeRaw is int
            ? codeRaw
            : int.tryParse(codeRaw?.toString() ?? '') ?? -1;
    if (code != 0) {
      throw Exception(
        _readEnvelopeValue(decoded, 'Desc')?.toString() ??
            'Password update failed on server',
      );
    }
  }

  Future<void> createUser({
    required String agentCode,
    required String name,
    required String mobileNo,
    required String password,
    required String location,
    required String accountType,
    required String createdByAgentCode,
  }) async {
    final payload = jsonEncode({
      'AgentCode': agentCode.trim(),
      'Name': name.trim(),
      'MobileNo': mobileNo.trim(),
      'Password': password.trim(),
      'Location': location.trim(),
      'AccountType': accountType.trim(),
      'CreatedByAgentCode': createdByAgentCode.trim(),
    });

    final response = await postdata('nav/users/create', payload);
    if (response.statusCode != 200) {
      throw Exception('Failed to create user. HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected create-user response format');
    }

    final codeRaw = _readEnvelopeValue(decoded, 'Code');
    final int code =
        codeRaw is int
            ? codeRaw
            : int.tryParse(codeRaw?.toString() ?? '') ?? -1;
    if (code != 0) {
      throw Exception(
        _readEnvelopeValue(decoded, 'Desc')?.toString() ??
            'Create user failed on server',
      );
    }
  }

  // ==================== Parcel CRUD ====================

  Future<void> createParcel(Parcel parcel) async {
    final payload = jsonEncode(parcel.toNavJson());
    final response = await postdata('nav/parcels/create', payload);

    if (response.statusCode != 200) {
      throw Exception('Failed to create parcel. HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected parcel create response format');
    }
    _ensureSuccess(decoded);
  }

  Future<void> updateParcel(Parcel parcel) async {
    final payload = jsonEncode(parcel.toNavJson());
    var response = await putdata('nav/parcels/update', payload);

    if (response.statusCode == 405) {
      logger.info('Retrying parcel update with POST alias endpoint');
      response = await postdata('nav/parcels/update-post', payload);
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to update parcel. HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected parcel update response format');
    }
    _ensureSuccess(decoded);
  }

  Future<void> deleteParcel(String documentNo) async {
    final response = await deletedata('nav/parcels/by-document/$documentNo');

    if (response.statusCode != 200) {
      throw Exception('Failed to delete parcel. HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected parcel delete response format');
    }
    _ensureSuccess(decoded);
  }

  /// Fetches a single parcel from NAV by its document number.
  /// Returns null when the parcel is not found.
  Future<Parcel?> fetchParcelByDocumentNo(String documentNo) async {
    final trimmed = documentNo.trim();
    if (trimmed.isEmpty) return null;

    final response = await getdata(
      'nav/parcels/${Uri.encodeComponent(trimmed)}',
    );

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch parcel. HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected parcel response format');
    }

    final dynamic contents = _readEnvelopeValue(decoded, 'Contents');
    if (contents is! Map) return null;

    return Parcel.fromJson(
      Map<String, dynamic>.from(contents),
    ).copyWith(isSynced: true);
  }

  // ==================== Batch CRUD ====================

  Future<void> createBatch(Batches batch) async {
    final payload = jsonEncode(batch.toNavJson());
    final response = await postdata('nav/batches/create', payload);

    if (response.statusCode != 200) {
      throw Exception('Failed to create batch. HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected batch create response format');
    }
    _ensureSuccess(decoded);
  }

  Future<void> updateBatch(Batches batch) async {
    final payload = jsonEncode(batch.toNavJson());
    var response = await putdata('nav/batches/update', payload);

    if (response.statusCode == 405) {
      logger.info('Retrying batch update with POST alias endpoint');
      response = await postdata('nav/batches/update-post', payload);
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to update batch. HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected batch update response format');
    }
    _ensureSuccess(decoded);
  }

  // ==================== M-Pesa QR Code ====================

  Future<String?> generateMpesaQrCode({
    required double amount,
    String? reference,
    String size = '300',
  }) async {
    final payload = jsonEncode({
      'amount': amount,
      'reference': reference,
      'size': size,
    });
    final response = await postdata('mpesa/qrcode', payload);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to generate QR code. HTTP ${response.statusCode}',
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected QR code response format');
    }
    _ensureSuccess(decoded);

    final contents = decoded['contents'] as Map<String, dynamic>?;
    return contents?['QRCode'] as String?;
  }

  Future<Map<String, dynamic>> initiateStkPush({
    required double amount,
    required String phoneNumber,
    String? reference,
    String? description,
  }) async {
    final payload = jsonEncode({
      'amount': amount,
      'phoneNumber': phoneNumber,
      'reference': reference ?? 'ParcelPayment',
      'description': description ?? 'Parcel delivery payment',
    });
    final response = await postdata('mpesa/stkpush', payload);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to initiate STK push. HTTP ${response.statusCode}',
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected STK push response format');
    }
    _ensureSuccess(decoded);

    final contents = decoded['contents'] as Map<String, dynamic>?;
    if (contents == null) {
      throw Exception('STK push response missing contents');
    }
    return contents;
  }

  Future<Map<String, dynamic>?> checkStkStatus(String checkoutRequestId) async {
    final response = await getdata(
      'mpesa/stkpush/status/${Uri.encodeComponent(checkoutRequestId)}',
    );

    if (response.statusCode != 200) {
      return null;
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    // Return the Contents (the MpesaStkStatus object) regardless of the
    // envelope Code. The API sets envelope Code = -1 for any non-success
    // ResultCode, so we must not discard it here — the dialog inspects the
    // inner resultCode (0 = success, -1 = pending, anything else = failure).
    return _readEnvelopeValue(decoded, 'Contents') as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> checkC2BTransaction(String reference) async {
    final response = await getdata(
      'mpesa/c2b/${Uri.encodeComponent(reference)}',
    );

    if (response.statusCode != 200) {
      return null;
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final codeRaw = _readEnvelopeValue(decoded, 'Code');
    final int code =
        codeRaw is int
            ? codeRaw
            : int.tryParse(codeRaw?.toString() ?? '') ?? -1;

    return {
      'code': code,
      'contents':
          _readEnvelopeValue(decoded, 'Contents') as Map<String, dynamic>?,
    };
  }

  // ==================== App Version ====================

  /// Fetches the latest Android app version info from the server.
  Future<AppVersionInfo?> fetchAppVersionInfo() async {
    final appUrl = '${_baseUrlForApp()}api/AppUpdate/android';
    try {
      final response = await _withRetry(
        () => http.get(
          Uri.parse(appUrl),
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final envelope = ApiEnvelope<AppVersionInfo>.fromJson(
        decoded,
        (c) => AppVersionInfo.fromJson(c as Map<String, dynamic>),
      );

      return envelope.isSuccess ? envelope.contents : null;
    } catch (e) {
      logger.error('Failed to fetch app version', error: e);
      return null;
    }
  }

  /// Derives the base URL (without /api/Parcel/ suffix) for non-Parcel endpoints.
  String _baseUrlForApp() {
    // baseUrl is like "https://nav.trimline.co.ke:4013/api/Parcel/"
    // We need "https://nav.trimline.co.ke:4013/"
    final idx = baseUrl.indexOf('/api/');
    if (idx > 0) return baseUrl.substring(0, idx + 1);
    return baseUrl;
  }

  // ==================== SMS ====================

  Future<void> sendBulkSms(List<Map<String, String>> messages) async {
    final payload = jsonEncode({
      'Messages':
          messages
              .map(
                (m) => {
                  'Phone': m['Phone'],
                  'Message': m['Message'],
                  'DocumentNo': m['DocumentNo'],
                },
              )
              .toList(),
    });

    final response = await postdata('sms/send-bulk', payload);

    if (response.statusCode != 200) {
      throw Exception('Failed to send SMS. HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected SMS response format');
    }

    final codeRaw = _readEnvelopeValue(decoded, 'Code');
    final int code =
        codeRaw is int
            ? codeRaw
            : int.tryParse(codeRaw?.toString() ?? '') ?? -1;

    if (code != 0 && code != 1) {
      throw Exception(
        _readEnvelopeValue(decoded, 'Desc')?.toString() ??
            'SMS API returned an error',
      );
    }
  }
}

class ApiService extends GetxService {
  Future<ApiService> init() async {
    // Initialize your API service here
    print('ApiService initialized');
    return this;
  }

  // ... other API methods
}

// class AesDecryption {
//   static final key = encrypt.Key.fromUtf8('kOFq5NYMkfiYPayzs3GntbP2mCT+39WLDcnuLJ5Rsrg='); // 32 bytes
//   static final iv = encrypt.IV.fromUtf8('1234567890abcdef'); // 16 bytes

//   static String decrypt(String encryptedBase64) {
//     final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
//     final encrypted = encrypt.Encrypted.fromBase64(encryptedBase64);
//     final decrypted = encrypter.decrypt(encrypted, iv: iv);
//     return decrypted; // This is the original plaintext
//   }
// }

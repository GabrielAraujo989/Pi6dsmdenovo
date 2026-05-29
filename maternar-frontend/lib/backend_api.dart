import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiClientException implements Exception {
  ApiClientException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.birthDate,
  });

  final String id;
  final String name;
  final String email;
  final DateTime birthDate;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      birthDate:
          DateTime.tryParse(json['birthDate'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class LoginResponse {
  const LoginResponse({required this.accessToken, required this.expiresIn});

  final String accessToken;
  final int expiresIn;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] as String? ?? '',
      expiresIn: json['expiresIn'] as int? ?? 0,
    );
  }
}

class BackendApi {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  const BackendApi({this.baseUrl = defaultBaseUrl});

  final String baseUrl;
  static const Duration _requestTimeout = Duration(seconds: 12);

  Uri _uri(String path) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalized$path');
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String birthDateIso,
  }) async {
    final response = await _runRequest(
      () => http
          .post(
            _uri('/users/register'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'birthDate': birthDateIso,
            }),
          )
          .timeout(_requestTimeout),
    );

    _throwIfFailure(response, defaultMessage: 'Falha ao cadastrar usuaria.');
  }

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _runRequest(
      () => http
          .post(
            _uri('/auth/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_requestTimeout),
    );

    _throwIfFailure(response, defaultMessage: 'Falha ao autenticar.');

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return LoginResponse.fromJson(json);
  }

  Future<UserProfile> profile(String token) async {
    final response = await _runRequest(
      () => http
          .get(
            _uri('/users/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_requestTimeout),
    );

    _throwIfFailure(response, defaultMessage: 'Falha ao carregar perfil.');

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return UserProfile.fromJson(json);
  }

  void _throwIfFailure(http.Response response, {required String defaultMessage}) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = defaultMessage;
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final error = body['error'];
        if (error is Map<String, dynamic>) {
          final serverMessage = error['message'];
          if (serverMessage is String && serverMessage.trim().isNotEmpty) {
            message = serverMessage;
          }
        }
      }
    } catch (_) {
      // Keep default message when backend response is not JSON.
    }

    throw ApiClientException(message);
  }

  Future<http.Response> _runRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request();
    } on TimeoutException {
      throw ApiClientException(
        'Tempo de conexao excedido. Verifique se o backend esta online e acessivel em $baseUrl.',
      );
    } on SocketException {
      throw ApiClientException(
        'Nao foi possivel conectar ao backend em $baseUrl. Confira servidor, porta e rede do emulador.',
      );
    } on http.ClientException {
      throw ApiClientException(
        'Falha de comunicacao com a API. Tente novamente em instantes.',
      );
    }
  }
}

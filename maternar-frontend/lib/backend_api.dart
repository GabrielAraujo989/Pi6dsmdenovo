import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;

import 'package:flutter/foundation.dart' show kIsWeb;
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
    required this.zipCode,
    required this.raceColor,
    required this.educationLevel,
    this.phone,
    this.height,
    this.preGestationalWeight,
    this.previousPregnancies,
    this.hadPreviousComplication,
  });

  final String id;
  final String name;
  final String email;
  final DateTime birthDate;
  final String zipCode;
  final int raceColor;
  final int educationLevel;
  final String? phone;
  final double? height;
  final double? preGestationalWeight;
  final int? previousPregnancies;
  final bool? hadPreviousComplication;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      birthDate:
          DateTime.tryParse(json['birthDate'] as String? ?? '') ?? DateTime.now(),
      zipCode: json['zipCode'] as String? ?? '',
      raceColor: json['raceColor'] as int? ?? 1,
      educationLevel: json['educationLevel'] as int? ?? 1,
      phone: json['phone'] as String?,
      height: (json['height'] as num?)?.toDouble(),
      preGestationalWeight: (json['preGestationalWeight'] as num?)?.toDouble(),
      previousPregnancies: json['previousPregnancies'] as int?,
      hadPreviousComplication: json['hadPreviousComplication'] as bool?,
    );
  }
}

class ClassificationResult {
  const ClassificationResult({
    required this.clusterId,
    required this.clusterNomeApp,
    required this.nivelRisco,
    required this.corHex,
    required this.recomendacoes,
  });

  final int clusterId;
  final String clusterNomeApp;
  final String nivelRisco;
  final String corHex;
  final List<String> recomendacoes;

  // C1 = Caminho Seguro (71% da base, grupo majoritário SUS).
  // C0 e C2 indicam atenção adicional.
  bool get isAlert => clusterId != 1;

  factory ClassificationResult.fromJson(Map<String, dynamic> json) {
    final recsRaw = json['recomendacoes'] as List<dynamic>? ?? [];
    final recs = recsRaw
        .whereType<Map<String, dynamic>>()
        .map((r) => r['texto'] as String? ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
    return ClassificationResult(
      clusterId: json['cluster_id'] as int? ?? 1,
      clusterNomeApp: json['cluster_nome_app'] as String? ?? '',
      nivelRisco: json['nivel_risco'] as String? ?? '',
      corHex: json['cor_hex'] as String? ?? '#A8D8EA',
      recomendacoes: recs,
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

class PregnancyInfo {
  const PregnancyInfo({
    required this.id,
    required this.status,
    this.currentClusterName,
    this.currentRiskLevel,
    this.currentHexColor,
    this.currentClusterId,
    this.createdAt,
  });

  final String id;
  final String status;
  final String? currentClusterName;
  final String? currentRiskLevel;
  final String? currentHexColor;
  final int? currentClusterId;
  final DateTime? createdAt;

  bool get isActive => status == 'ACTIVE';

  factory PregnancyInfo.fromJson(Map<String, dynamic> json) {
    return PregnancyInfo(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      currentClusterName: json['currentClusterName'] as String?,
      currentRiskLevel: json['currentRiskLevel'] as String?,
      currentHexColor: json['currentHexColor'] as String?,
      currentClusterId: json['currentClusterId'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

class QuestionnaireRecord {
  const QuestionnaireRecord({
    required this.id,
    required this.responseDate,
    required this.currentWeight,
    this.clusterId,
    this.clusterName,
    this.riskLevel,
    this.hexColor,
    this.calculatedImc,
    this.recommendations,
  });

  final String id;
  final DateTime responseDate;
  final double currentWeight;
  final int? clusterId;
  final String? clusterName;
  final String? riskLevel;
  final String? hexColor;
  final double? calculatedImc;
  final List<String>? recommendations;

  factory QuestionnaireRecord.fromJson(Map<String, dynamic> json) {
    List<String>? recs;
    final recsRaw = json['recommendations'] as List<dynamic>?;
    if (recsRaw != null) {
      recs = recsRaw
          .whereType<Map<String, dynamic>>()
          .map((r) => r['texto'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
    }
    return QuestionnaireRecord(
      id: json['id'] as String? ?? '',
      responseDate: DateTime.tryParse(json['responseDate'] as String? ?? '') ??
          DateTime.now(),
      currentWeight: (json['currentWeight'] as num?)?.toDouble() ?? 0,
      clusterId: json['clusterId'] as int?,
      clusterName: json['clusterName'] as String?,
      riskLevel: json['riskLevel'] as String?,
      hexColor: json['hexColor'] as String?,
      calculatedImc: (json['calculatedImc'] as num?)?.toDouble(),
      recommendations: recs,
    );
  }
}

class BackendApi {
  // Resolve a URL correta por plataforma em tempo de execução.
  // --dart-define=API_BASE_URL=... sobrescreve o valor automático.
  static String get defaultBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) return 'https://api.gapsaa.com.br';
    if (Platform.isAndroid) return 'https://api.gapsaa.com.br';
    return 'https://api.gapsaa.com.br'; // Linux, macOS, Windows desktop
  }

  BackendApi({String? baseUrl}) : baseUrl = baseUrl ?? BackendApi.defaultBaseUrl;

  final String baseUrl;
  static const Duration _requestTimeout = Duration(seconds: 12);
  static const Duration _classifyTimeout = Duration(seconds: 30);

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
    required String zipCode,
    required int raceColor,
    required int educationLevel,
    String? phone,
    double? height,
    double? preGestationalWeight,
    int? previousPregnancies,
    bool? hadPreviousComplication,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'birthDate': birthDateIso,
      'zipCode': zipCode,
      'raceColor': raceColor,
      'educationLevel': educationLevel,
    };
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;
    if (height != null) body['height'] = height;
    if (preGestationalWeight != null) {
      body['preGestationalWeight'] = preGestationalWeight;
    }
    if (previousPregnancies != null) {
      body['previousPregnancies'] = previousPregnancies;
    }
    if (hadPreviousComplication != null) {
      body['hadPreviousComplication'] = hadPreviousComplication;
    }

    final response = await _runRequest(
      () => http
          .post(
            _uri('/users/register'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
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

  Future<UserProfile> updateProfile({
    required String token,
    String? name,
    String? phone,
    double? height,
    double? preGestationalWeight,
    int? previousPregnancies,
    bool? hadPreviousComplication,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (height != null) body['height'] = height;
    if (preGestationalWeight != null) {
      body['preGestationalWeight'] = preGestationalWeight;
    }
    if (previousPregnancies != null) {
      body['previousPregnancies'] = previousPregnancies;
    }
    if (hadPreviousComplication != null) {
      body['hadPreviousComplication'] = hadPreviousComplication;
    }

    final response = await _runRequest(
      () => http
          .patch(
            _uri('/users/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout),
    );

    _throwIfFailure(response, defaultMessage: 'Falha ao atualizar perfil.');

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return UserProfile.fromJson(json);
  }

  Future<List<PregnancyInfo>> getPregnancies(String token) async {
    final response = await _runRequest(
      () => http
          .get(
            _uri('/pregnancy'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_requestTimeout),
    );

    _throwIfFailure(response, defaultMessage: 'Falha ao buscar gestações.');

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(PregnancyInfo.fromJson)
        .toList();
  }

  Future<List<QuestionnaireRecord>> getQuestionnaires({
    required String token,
    required String pregnancyId,
  }) async {
    final response = await _runRequest(
      () => http
          .get(
            _uri('/questionnaires/pregnancy/$pregnancyId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_requestTimeout),
    );

    _throwIfFailure(
        response, defaultMessage: 'Falha ao buscar histórico de avaliações.');

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(QuestionnaireRecord.fromJson)
        .toList();
  }

  Future<ClassificationResult> classify({
    required String token,
    required double weight,
    required double height,
    required double imcPreGestacional,
    required int racaCor,
    required int escolaridade,
    int flagAntiHiv = 0,
  }) async {
    final response = await _runRequest(
      () => http
          .post(
            _uri('/classification'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'nu_peso': weight,
              'nu_altura': height,
              'nu_imc_pre_gestacional': imcPreGestacional,
              'raca_cor': racaCor,
              'escolaridade': escolaridade,
              'flag_anti_hiv': flagAntiHiv,
            }),
          )
          .timeout(_classifyTimeout),
    );

    _throwIfFailure(response, defaultMessage: 'Falha ao classificar perfil gestacional.');

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ClassificationResult.fromJson(json);
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
        'Tempo de conexao excedido ($baseUrl). Servidor indisponivel ou rede lenta.',
      );
    } on SocketException catch (e) {
      throw ApiClientException(
        'SocketException ao conectar em $baseUrl: ${e.message}',
      );
    } on http.ClientException catch (e) {
      throw ApiClientException(
        'ClientException ($baseUrl): ${e.message}',
      );
    } catch (e) {
      throw ApiClientException(
        'Erro inesperado [${e.runtimeType}]: $e',
      );
    }
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backend_api.dart';

class ViaCepService {
  static const Duration _timeout = Duration(seconds: 8);

  Future<Map<String, String>> fetch(String cep) async {
    final digits = cep.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) {
      throw ApiClientException('CEP invalido. Use 8 digitos.');
    }

    final uri = Uri.parse('https://viacep.com.br/ws/$digits/json/');

    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiClientException('Falha ao consultar ViaCEP.');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['erro'] == true) {
        throw ApiClientException('CEP nao encontrado.');
      }

      return {
        'street': (body['logradouro'] as String?) ?? '',
        'neighborhood': (body['bairro'] as String?) ?? '',
        'city': (body['localidade'] as String?) ?? '',
        'state': (body['uf'] as String?) ?? '',
      };
    } on TimeoutException {
      throw ApiClientException('Tempo esgotado na consulta do ViaCEP.');
    } on http.ClientException {
      throw ApiClientException('Falha de comunicacao com ViaCEP.');
    }
  }
}

// lib/data/auth_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/env.dart';

class AuthApi {
  final String _base = Env.apiBaseUrl; // ej: "http://100.102.184.34:3000" o "http://100.102.184.34:3000/api"

  /// Construye una URI asegurando que el path base incluya '/api' exactamente una vez.
  Uri _endpoint(String endpoint) {
    final base = Uri.parse(_base);

    // base.path sin slashes al final
    final basePath = base.path.replaceAll(RegExp(r'/+$'), '');
    final hasApi = RegExp(r'(^|/)api$').hasMatch(basePath);
    final normalizedBasePath = hasApi ? basePath : '$basePath/api';

    // endpoint limpio sin slash inicial
    final ep = endpoint.replaceFirst(RegExp(r'^/+'), '');

    return base.replace(path: '$normalizedBasePath/$ep');
  }

  Future<_LoginDTO> login(String email, String password) async {
    final uri = _endpoint('auth/login'); // siempre resultará en .../api/auth/login

    final r = await http
        .post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    )
        .timeout(const Duration(seconds: 12));

    if (r.statusCode == 404) {
      throw Exception('Endpoint no encontrado: $uri');
    }
    if (r.statusCode == 401) {
      throw Exception('Credenciales inválidas');
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Error ${r.statusCode}: ${r.body}');
    }

    final Map<String, dynamic> json = jsonDecode(r.body);
    final user = json['user'] as Map<String, dynamic>?;
    if (user == null) {
      throw Exception('Respuesta inválida del servidor (falta "user").');
    }

    // normaliza el rol
    final role = (user['role'] ?? '').toString().toLowerCase(); // 'root'|'admin'|'usuario'

    return _LoginDTO(
      id: user['id']?.toString() ?? '',
      name: user['name'] ?? '',
      email: user['email'] ?? '',
      role: role,
      accessToken: json['access_token']?.toString(),
      refreshToken: json['refresh_token']?.toString(),
    );
  }
}

class _LoginDTO {
  final String id;
  final String name;
  final String email;
  final String role; // 'root' | 'admin' | 'usuario'
  final String? accessToken;
  final String? refreshToken;
  const _LoginDTO({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.accessToken,
    this.refreshToken,
  });
}
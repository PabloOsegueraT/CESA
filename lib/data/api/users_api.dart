import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/env.dart';

class UsersApi {
  final _base = Uri.parse(Env.apiBaseUrl);

  Future<Map<String, dynamic>> createUser({
    required String role, // 'root'|'admin'|'usuario' (el rol del *creador* va via header)
    required String name,
    required String email,
    required String password,
    String? phone,
    String? about,
    String? avatarUrl,
    bool isActive = true,
  }) async {
    final uri = _base.resolve('/users');
    final r = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-role': role.toLowerCase(), // <- MUY IMPORTANTE para el backend (solo root)
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': 'usuario',     // rol del nuevo usuario (ajusta según tu UI)
        'phone': phone,
        'about': about,
        'avatar_url': avatarUrl,
        'is_active': isActive,
      }),
    );

    if (r.statusCode >= 200 && r.statusCode < 300) {
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      return json['user'] as Map<String, dynamic>;
    }
    throw Exception('Error ${r.statusCode}: ${r.body}');
  }

  Future<List<Map<String, dynamic>>> listUsers({required String role, String q = ''}) async {
    final uri = _base.resolve('/users${q.isNotEmpty ? '?q=$q' : ''}');
    final r = await http.get(uri, headers: {'x-role': role.toLowerCase()});
    if (r.statusCode == 200) {
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      final list = (json['users'] as List).cast<Map<String, dynamic>>();
      return list;
    }
    throw Exception('Error ${r.statusCode}: ${r.body}');
  }
}
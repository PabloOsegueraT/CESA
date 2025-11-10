import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/env.dart';

class ApiClient {
  final _base = Uri.parse(Env.apiBaseUrl);

  Future<T> getJson<T>(String path) async {
    final uri = _base.resolve(path);
    final r = await http.get(uri);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(r.body) as T;
    }
    throw Exception('GET ${uri.path} ${r.statusCode}: ${r.body}');
  }

  Future<T> postJson<T>(String path, Map<String, dynamic> body) async {
    final uri = _base.resolve(path);
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(r.body) as T;
    }
    throw Exception('POST ${uri.path} ${r.statusCode}: ${r.body}');
  }

  Future<void> patchJson(String path, Map<String, dynamic> body) async {
    final uri = _base.resolve(path);
    final r = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('PATCH ${uri.path} ${r.statusCode}: ${r.body}');
    }
  }
}
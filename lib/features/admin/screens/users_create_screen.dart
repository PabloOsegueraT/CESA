// lib/features/admin/screens/users_create_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/env.dart';
import '../../../state/auth_controller.dart';

class AdminUserCreateScreen extends StatefulWidget {
  const AdminUserCreateScreen({super.key});

  @override
  State<AdminUserCreateScreen> createState() => _AdminUserCreateScreenState();
}

class _AdminUserCreateScreenState extends State<AdminUserCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String _selectedRole = 'usuario'; // 'usuario' o 'admin'
  bool _sending = false;

  Future<Map<String, String>> _buildHeaders() async {
    final auth = AuthControllerProvider.of(context);
    return {
      'Content-Type': 'application/json',
      'x-role': auth.role, // debe ser 'root' cuando estés logueado como root
      'x-user-id': '1',    // ID fijo por ahora
    };
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = AuthControllerProvider.of(context);
    if (!auth.isRoot) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo root puede crear usuarios')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final headers = await _buildHeaders();
      final uri = Uri.parse('${Env.apiBaseUrl}/api/users');

      final body = {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
        'role': _selectedRole, // 'usuario' o 'admin'
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      };

      final resp = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario creado correctamente')),
        );
        Navigator.of(context).pop(true); // devolvemos true para recargar lista
      } else {
        final data =
        (jsonDecode(resp.body) as Map<String, dynamic>? ?? {});
        final msg = data['message']?.toString() ??
            'Error al crear usuario: ${resp.statusCode}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red al crear usuario: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleItems = const [
      DropdownMenuItem(
        value: 'usuario',
        child: Text('Usuario'),
      ),
      DropdownMenuItem(
        value: 'admin',
        child: Text('Administrador'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear usuario'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Text(
                      _nameCtrl.text.isNotEmpty
                          ? _nameCtrl.text[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Nuevo usuario',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Requerido';
                  }
                  if (!v.contains('@')) return 'Correo inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items: roleItems,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedRole = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Requerido';
                  }
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(_sending ? 'Creando...' : 'Crear usuario'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

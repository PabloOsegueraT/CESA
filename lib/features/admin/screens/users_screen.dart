// lib/features/admin/screens/users_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/env.dart';
import '../../../state/auth_controller.dart';
import 'users_create_screen.dart';
import 'user_detail_screen.dart';



class AdminUserListItem {
  final int id;
  final String name;
  final String email;
  final String role; // 'root' | 'admin' | 'usuario'
  final bool isActive;
  final String? phone;

  const AdminUserListItem({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.phone,
  });

  factory AdminUserListItem.fromJson(Map<String, dynamic> json) {
    return AdminUserListItem(
      id: json['id'] as int,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      isActive: (json['is_active'] ?? 1) == 1,
      phone: json['phone']?.toString(),
    );
  }
}

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  List<AdminUserListItem> _users = [];

  @override
  void initState() {
    super.initState();
    // Esperamos a que exista el contexto para leer AuthController
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }
  Future<Map<String, String>> _buildHeaders() async {
    final auth = AuthControllerProvider.of(context);

    // 👇 Traducimos el rol de la app al código del backend
    final roleCode = auth.isRoot ? 'root' : 'admin';

    return {
      'Content-Type': 'application/json',
      'x-role': roleCode,
      // NO hace falta x-user-id para listar usuarios
    };
  }
  void _openUserDetail(AdminUserListItem user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminUserDetailScreen(user: user),
      ),
    );
  }


  Future<void> _loadUsers({String query = ''}) async {
    setState(() => _loading = true);
    try {
      final headers = await _buildHeaders();
      final uri = Uri.parse(
        query.trim().isEmpty
            ? '${Env.apiBaseUrl}/api/users'
            : '${Env.apiBaseUrl}/api/users?q=${Uri.encodeQueryComponent(query)}',
      );

      final resp = await http.get(uri, headers: headers);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['users'] as List<dynamic>? ?? []);
        final users = list
            .map((u) => AdminUserListItem.fromJson(u as Map<String, dynamic>))
            .toList();

        if (!mounted) return;
        setState(() {
          _users = users;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar usuarios: ${resp.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red al cargar usuarios: $e')),
      );
    }
  }

  Future<void> _openCreateUser() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AdminUserCreateScreen(),
      ),
    );

    // Si se creó usuario, recargamos lista
    if (result == true) {
      _loadUsers(query: _searchCtrl.text);
    }
  }

  void _openMoreMenu(AdminUserListItem user) async {
    final auth = AuthControllerProvider.of(context);

    // Solo root puede cambiar contraseña / borrar
    final isRoot = auth.isRoot;
    if (!isRoot) return;

    final value = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 80, 16, 0),
      items: const [
        PopupMenuItem(
          value: 'view',
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Ver perfil'),
          ),
        ),
        PopupMenuItem(
          value: 'password',
          child: ListTile(
            leading: Icon(Icons.vpn_key_outlined),
            title: Text('Cambiar contraseña'),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Eliminar usuario'),
          ),
        ),
      ],
    );

    if (value == 'view') {
      _openUserDetail(user);
    } else if (value == 'password') {
      _showChangePasswordSheet(user);
    } else if (value == 'delete') {
      _confirmDeleteUser(user);
    }
  }


  Future<void> _showChangePasswordSheet(AdminUserListItem user) async {
    final newPassCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 8,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cambiar contraseña',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('Usuario: ${user.name}'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Requerido';
                    }
                    if (v.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) {
                    if (v != newPassCtrl.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _sending
                        ? null
                        : () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.of(ctx).pop();
                      await _changePassword(user.id, newPassCtrl.text);
                    },
                    icon: const Icon(Icons.key),
                    label: const Text('Actualizar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changePassword(int userId, String newPassword) async {
    setState(() => _sending = true);
    try {
      final headers = await _buildHeaders();
      final uri =
      Uri.parse('${Env.apiBaseUrl}/api/users/$userId/password');

      final resp = await http.put(
        uri,
        headers: headers,
        body: jsonEncode({'password': newPassword}),
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar contraseña: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDeleteUser(AdminUserListItem user) async {
    final auth = AuthControllerProvider.of(context);

// Evitar que se elimine cualquier usuario con rol root
    if (user.role == 'root') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes eliminar un usuario root'),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Seguro que quieres eliminar a ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      _deleteUser(user.id);
    }
  }

  Future<void> _deleteUser(int userId) async {
    setState(() => _sending = true);
    try {
      final headers = await _buildHeaders();
      final uri = Uri.parse('${Env.apiBaseUrl}/api/users/$userId');

      final resp = await http.delete(uri, headers: headers);

      if (!mounted) return;

      if (resp.statusCode == 204) {
        setState(() {
          _users.removeWhere((u) => u.id == userId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario eliminado')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthControllerProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre o correo',
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => _loadUsers(query: value),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? const Center(child: Text('No se encontraron usuarios'))
                : ListView.separated(
              itemCount: _users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final u = _users[i];
                final initial =
                u.name.isNotEmpty ? u.name[0].toUpperCase() : '?';
                final subtitle =
                    '${u.email} • ${_roleLabel(u.role)}';

                return ListTile(
                  leading: CircleAvatar(child: Text(initial)),
                  title: Text(u.name),
                  subtitle: Text(subtitle),
                  onTap: () => _openUserDetail(u),
                  trailing: auth.isRoot
                      ? IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _openMoreMenu(u),
                  )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: auth.isRoot
          ? FloatingActionButton.extended(
        onPressed: _sending ? null : _openCreateUser,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Crear usuario'),
      )
          : null,
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'root':
        return 'Root';
      case 'admin':
        return 'Administrador';
      default:
        return 'Usuario';
    }
  }
}

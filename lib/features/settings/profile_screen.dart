// lib/features/settings/profile_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/env.dart';
import '../../state/profile_controller.dart';
import '../../state/auth_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _name;
  late TextEditingController _email;
  late TextEditingController _role;
  late TextEditingController _phone;
  late TextEditingController _about;
  late TextEditingController _avatarUrl;

  bool _inited = false;
  bool _saving = false;
  bool _loadingFromServer = false;
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      final p = ProfileControllerProvider.of(context);

      _name      = TextEditingController(text: p.displayName);
      _email     = TextEditingController(text: p.email);
      _role      = TextEditingController(text: p.role);
      _phone     = TextEditingController(text: p.phone);
      _about     = TextEditingController(text: p.about);
      _avatarUrl = TextEditingController(text: p.avatarUrl ?? '');

      _inited = true;
    }

    // La primera vez que entra a la pantalla, cargamos desde el backend
    if (!_loadedOnce) {
      _loadedOnce = true;
      _loadProfileFromServer();
    }
  }

  @override
  void dispose() {
    if (_inited) {
      _name.dispose();
      _email.dispose();
      _role.dispose();
      _phone.dispose();
      _about.dispose();
      _avatarUrl.dispose();
    }
    super.dispose();
  }

  Future<Map<String, String>> _buildHeaders() async {
    final auth = AuthControllerProvider.of(context);
    final profile = ProfileControllerProvider.of(context);

    // Rol para el backend: root | admin | usuario
    final roleCode = auth.isRoot
        ? 'root'
        : (auth.isAdmin ? 'admin' : 'usuario');

    final userId = profile.userId;
    if (userId == null || userId <= 0) {
      throw Exception('userId no está definido en ProfileController');
    }

    return {
      'Content-Type': 'application/json',
      'x-role': roleCode,
      'x-user-id': userId.toString(),
    };
  }

  Future<void> _loadProfileFromServer() async {
    try {
      setState(() => _loadingFromServer = true);

      final headers = await _buildHeaders();
      final uri = Uri.parse('${Env.apiBaseUrl}/api/me');
      final resp = await http.get(uri, headers: headers);

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>;

        final profile = ProfileControllerProvider.of(context);
        profile.setFromBackend(user);

        // Sincronizamos los campos con lo que viene de BD
        _name.text      = profile.displayName;
        _email.text     = profile.email;
        _role.text      = profile.role;
        _phone.text     = profile.phone;
        _about.text     = profile.about;
        _avatarUrl.text = profile.avatarUrl ?? '';

        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar perfil: ${resp.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red al cargar perfil: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingFromServer = false);
      }
    }
  }

  Future<void> _changePhoto() async {
    if (!_inited) return;

    final urlController = TextEditingController(text: _avatarUrl.text.trim());

    final newUrl = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar foto de perfil'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            labelText: 'URL de la imagen',
            hintText: 'https://...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(urlController.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newUrl == null) return;

    setState(() {
      _avatarUrl.text = newUrl;
    });

    // Guardamos de una vez en la BD
    await _saveProfile();
  }

  Future<void> _saveProfile() async {
    if (!_inited) return;

    final profile = ProfileControllerProvider.of(context);
    final auth    = AuthControllerProvider.of(context);

    final name      = _name.text.trim();
    final email     = _email.text.trim();
    final role      = _role.text.trim();
    final phone     = _phone.text.trim();
    final about     = _about.text.trim();
    final avatarUrl = _avatarUrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio')),
      );
      return;
    }

    final userId = profile.userId;
    if (userId == null || userId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay usuario en sesión (userId null).'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final roleCode = auth.isRoot
          ? 'root'
          : (auth.isAdmin ? 'admin' : 'usuario');

      final headers = {
        'Content-Type': 'application/json',
        'x-role': roleCode,
        'x-user-id': userId.toString(),
      };

      final body = jsonEncode({
        'name': name,
        'phone': phone.isEmpty ? null : phone,
        'about': about.isEmpty ? null : about,
        'avatarUrl': avatarUrl.isEmpty ? null : avatarUrl,
      });

      final uri = Uri.parse('${Env.apiBaseUrl}/api/me');
      final resp = await http.put(uri, headers: headers, body: body);

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>;

        // Actualizamos el controlador global con lo que regresa la BD
        profile.setFromBackend(user);

        // Y sincronizamos los textos
        _name.text      = profile.displayName;
        _email.text     = profile.email;
        _role.text      = profile.role;
        _phone.text     = profile.phone;
        _about.text     = profile.about;
        _avatarUrl.text = profile.avatarUrl ?? '';

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado')),
        );

        setState(() {}); // refresca encabezado / avatar
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Error al actualizar perfil: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ProfileControllerProvider.of(context);

    return AnimatedBuilder(
      animation: p,
      builder: (context, _) {
        final initials = _inited ? _initials(_name.text) : '?';
        final avatar = _avatarUrl.text.trim();

        return Scaffold(
          appBar: AppBar(title: const Text('Perfil')),
          body: _loadingFromServer && !_saving
              ? const Center(child: CircularProgressIndicator())
              : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: avatar.isNotEmpty
                          ? NetworkImage(avatar)
                          : null,
                      child: avatar.isEmpty
                          ? Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _inited ? _name.text : '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _inited ? _email.text : '',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _changePhoto,
                      icon:
                      const Icon(Icons.photo_camera_outlined),
                      label: const Text('Cambiar foto'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_inited) ...[
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _role,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    prefixIcon:
                    Icon(Icons.verified_user_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _about,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Acerca de mí',
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _avatarUrl,
                  decoration: const InputDecoration(
                    labelText: 'URL de foto',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                  (!_inited || _saving) ? null : _saveProfile,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                      _saving ? 'Guardando...' : 'Guardar cambios'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last =
    parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    final txt = (first + last).toUpperCase();
    return txt.isEmpty ? '?' : txt;
  }
}

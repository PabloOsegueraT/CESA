// lib/features/settings/profile_screen.dart
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

  bool _inited = false;
  bool _saving = false;
  bool _loadingFromServer = false;
  bool _loadedOnce = false;
  bool _uploadingAvatar = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      final p = ProfileControllerProvider.of(context);

      _name = TextEditingController(text: p.displayName);
      _email = TextEditingController(text: p.email);
      _role = TextEditingController(text: p.role);
      _phone = TextEditingController(text: p.phone);
      _about = TextEditingController(text: p.about);

      _inited = true;
    }

    // Primera vez que entra, cargamos desde el backend
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
    }
    super.dispose();
  }

  // ============================
  // Helpers
  // ============================

  Future<Map<String, String>> _buildHeaders() async {
    final auth = AuthControllerProvider.of(context);
    final profile = ProfileControllerProvider.of(context);

    final roleCode =
    auth.isRoot ? 'root' : (auth.isAdmin ? 'admin' : 'usuario');

    final userId = profile.userId;
    if (userId == null || userId <= 0) {
      throw Exception('userId no está definido en ProfileController');
    }

    return {
      'x-role': roleCode,
      'x-user-id': userId.toString(),
    };
  }

  String _resolveAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    // Si el backend guarda /uploads/avatars/xxx.png -> lo colgamos de la API
    return '${Env.apiBaseUrl}$raw';
  }

  /// Dado el archivo, intenta adivinar un `MediaType` de imagen
  MediaType _guessImageMediaType(PlatformFile file) {
    final name = (file.name).toLowerCase();
    final ext = name.split('.').length > 1 ? name.split('.').last : '';

    String subtype;
    switch (ext) {
      case 'png':
        subtype = 'png';
        break;
      case 'gif':
        subtype = 'gif';
        break;
      case 'jpg':
      case 'jpeg':
        subtype = 'jpeg';
        break;
      case 'webp':
        subtype = 'webp';
        break;
      default:
      // por si acaso, siempre será image/* para que pase el filtro
        subtype = 'jpeg';
        break;
    }

    return MediaType('image', subtype);
  }

  // ============================
  // Cargar perfil desde /api/me
  // ============================

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

        _name.text = profile.displayName;
        _email.text = profile.email;
        _role.text = profile.role;
        _phone.text = profile.phone;
        _about.text = profile.about;

        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar perfil: ${resp.statusCode}')),
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

  // ============================
  // Subir foto: POST /api/me/avatar
  // ============================

  Future<void> _changePhoto() async {
    if (_uploadingAvatar) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: kIsWeb, // en web usa bytes
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;

    setState(() => _uploadingAvatar = true);

    try {
      final headers = await _buildHeaders();
      final uri = Uri.parse('${Env.apiBaseUrl}/api/me/avatar');

      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers);

      final mediaType = _guessImageMediaType(file);

      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw Exception('No se pudieron leer los bytes del archivo');
        }

        request.files.add(
          http.MultipartFile.fromBytes(
            'avatar',
            bytes,
            filename: file.name,
            contentType: mediaType,
          ),
        );
      } else {
        final path = file.path;
        if (path == null) {
          throw Exception('Ruta del archivo no disponible');
        }

        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            path,
            contentType: mediaType,
          ),
        );
      }

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>;
        final profile = ProfileControllerProvider.of(context);

        profile.setFromBackend(user);

        _name.text = profile.displayName;
        _email.text = profile.email;
        _role.text = profile.role;
        _phone.text = profile.phone;
        _about.text = profile.about;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada')),
        );

        setState(() {}); // redibujar avatar
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir foto: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir foto: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  // ============================
  // Guardar nombre / teléfono / about  -> PUT /api/me
  // ============================

  Future<void> _saveProfile() async {
    if (!_inited) return;

    final profile = ProfileControllerProvider.of(context);
    final auth = AuthControllerProvider.of(context);

    final name = _name.text.trim();
    final email = _email.text.trim();
    final role = _role.text.trim();
    final phone = _phone.text.trim();
    final about = _about.text.trim();

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
      final roleCode =
      auth.isRoot ? 'root' : (auth.isAdmin ? 'admin' : 'usuario');

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'x-role': roleCode,
        'x-user-id': userId.toString(),
      };

      final body = jsonEncode({
        'name': name,
        'phone': phone.isEmpty ? null : phone,
        'about': about.isEmpty ? null : about,
        // avatar_url se maneja SOLO en POST /me/avatar
      });

      final uri = Uri.parse('${Env.apiBaseUrl}/api/me');
      final resp = await http.put(uri, headers: headers, body: body);

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>;

        profile.setFromBackend(user);

        _name.text = profile.displayName;
        _email.text = profile.email;
        _role.text = profile.role;
        _phone.text = profile.phone;
        _about.text = profile.about;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado')),
        );

        setState(() {});
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

  // ============================
  // UI
  // ============================

  @override
  Widget build(BuildContext context) {
    final p = ProfileControllerProvider.of(context);

    return AnimatedBuilder(
      animation: p,
      builder: (context, _) {
        final initials = _inited ? _initials(_name.text) : '?';
        final avatarUrl = _resolveAvatarUrl(p.avatarUrl);

        return Scaffold(
          appBar: AppBar(title: const Text('Perfil')),
          body: _loadingFromServer
              ? const Center(child: CircularProgressIndicator())
              : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty
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
                      onPressed: (_saving || _uploadingAvatar)
                          ? null
                          : _changePhoto,
                      icon:
                      const Icon(Icons.photo_camera_outlined),
                      label: Text(
                        _uploadingAvatar
                            ? 'Subiendo...'
                            : 'Cambiar foto',
                      ),
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
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                  (!_inited || _saving) ? null : _saveProfile,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _saving
                        ? 'Guardando...'
                        : 'Guardar cambios',
                  ),
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

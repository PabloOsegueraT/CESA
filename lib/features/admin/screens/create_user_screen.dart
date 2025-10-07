import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../state/users_controller.dart';
import '../../../models/user.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _form = GlobalKey<FormState>();
  final _name  = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String _role = 'Usuario';

  Uint8List? _avatarBytes;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (src == null) return;

    final file = await picker.pickImage(source: src, maxWidth: 1024, imageQuality: 85);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() => _avatarBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(_name.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear usuario')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header con avatar y nombre dinámico
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(44),
                  onTap: _pickAvatar,
                  child: CircleAvatar(
                    radius: 32,
                    backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                    child: _avatarBytes == null
                        ? Text(initials, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _name.text.isEmpty ? 'Nuevo usuario' : _name.text,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickAvatar,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Foto'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Campos
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
                return ok ? null : 'Correo inválido';
              },
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _role,
              items: const [
                DropdownMenuItem(value: 'Usuario', child: Text('Usuario')),
                DropdownMenuItem(value: 'Administrador', child: Text('Administrador')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'Usuario'),
              decoration: const InputDecoration(
                labelText: 'Rol',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerida';
                if (v.trim().length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Crear usuario'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final usersCtrl = UsersControllerProvider.of(context);
    final user = AppUser(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      email: _email.text.trim(),
      role: _role,
      password: _password.text.trim(), // DEMO
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      avatarBytes: _avatarBytes,
    );
    usersCtrl.addUser(user);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Usuario "${user.name}" creado')),
    );
    Navigator.pop(context);
  }

  String _initials(String full) {
    final p = full.trim().split(RegExp(r'\s+'));
    if (p.isEmpty) return '?';
    final first = p.first.isNotEmpty ? p.first[0] : '';
    final last  = p.length > 1 && p.last.isNotEmpty ? p.last[0] : '';
    final s = (first + last).toUpperCase();
    return s.isEmpty ? '?' : s;
  }
}

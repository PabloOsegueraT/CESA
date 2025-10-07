import 'package:flutter/material.dart';
import '../../state/profile_controller.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    final p = ProfileControllerProvider.of(context); // <- AQUÍ YA EXISTE
    _name  = TextEditingController(text: p.displayName);
    _email = TextEditingController(text: p.email);
    _role  = TextEditingController(text: p.role);
    _phone = TextEditingController(text: p.phone);
    _about = TextEditingController(text: p.about);
    _inited = true;
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

  @override
  Widget build(BuildContext context) {
    final p = ProfileControllerProvider.of(context);
    return AnimatedBuilder(
      animation: p,
      builder: (context, _) {
        final initials = _inited ? _initials(_name.text) : '?';
        return Scaffold(
          appBar: AppBar(title: const Text('Perfil')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(radius: 36, child: Text(initials, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 8),
                    Text(_inited ? _name.text : '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(_inited ? _email.text : '', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(.7))),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambiar foto (demo)'))),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Cambiar foto'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_inited) ...[
                TextField(controller: _name,  decoration: const InputDecoration(labelText: 'Nombre',   prefixIcon: Icon(Icons.badge_outlined))),
                const SizedBox(height: 12),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Correo',   prefixIcon: Icon(Icons.alternate_email)), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(controller: _role,  decoration: const InputDecoration(labelText: 'Rol',      prefixIcon: Icon(Icons.verified_user_outlined))),
                const SizedBox(height: 12),
                TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                TextField(controller: _about, maxLines: 4, decoration: const InputDecoration(labelText: 'Acerca de mí', prefixIcon: Icon(Icons.info_outline))),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    p.update(
                      displayName: _name.text.trim(),
                      email: _email.text.trim(),
                      role: _role.text.trim(),
                      phone: _phone.text.trim(),
                      about: _about.text.trim(),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
                    setState(() {}); // refresca encabezado/iniciales
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar cambios'),
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
    final last  = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    final txt = (first + last).toUpperCase();
    return txt.isEmpty ? '?' : txt;
  }
}

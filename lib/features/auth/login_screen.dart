import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();

}


class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'admin@demo.com');
  final _pass = TextEditingController(text: '123456');
  String _role = 'admin';


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Correo')),
                const SizedBox(height: 12),
                TextField(controller: _pass, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                    DropdownMenuItem(value: 'user', child: Text('Usuario')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'user'),
                  decoration: const InputDecoration(labelText: 'Rol'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    if (_role == 'admin') {
                      Navigator.pushReplacementNamed(context, '/admin');
                    } else {
                      Navigator.pushReplacementNamed(context, '/user');
                    }
                  },
                  child: const Text('Entrar'),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showForgotPassword(context, prefillEmail:  _email?.text),
                    icon: const Icon(Icons.help_outline),
                    label: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Future<void> _showForgotPassword(BuildContext context, {String? prefillEmail}) async {
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController(text: prefillEmail ?? '');

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  'Recuperar contraseña',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Escribe tu correo para que el administrador pueda ayudarte a restablecerla.',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(.7)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (v) {
                    final txt = (v ?? '').trim();
                    if (txt.isEmpty) return 'Requerido';
                    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(txt);
                    return ok ? null : 'Correo inválido';
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx, true);
                  },
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Enviar'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se ha enviado un mensaje al root')),
      );
    }
  }

}



import 'package:flutter/material.dart';
import '../../state/auth_controller.dart';
import '../../state/profile_controller.dart';
import '../../data/services/auth_api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'pablo@demo.com');
  final _pass = TextEditingController(text: '123456');
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  // Normaliza el rol del servidor ('root'|'admin'|'usuario') a tu app ('Root'|'Administrador'|'Usuario')
  String _normalizeRole(String serverRole, String email) {
    final r = serverRole.trim().toLowerCase();
    if (r == 'root') return 'Root';
    if (r == 'admin') {
      return 'Administrador';
    }
    return 'Usuario';
  }

  Future<void> _doLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final api = AuthApi();
      final dto = await api.login(_email.text.trim(), _pass.text.trim());

      final role = _normalizeRole(dto.role, dto.email);
      final auth = AuthControllerProvider.of(context);
      auth.setRole(role);

      // Poblar perfil
      final profile = ProfileControllerProvider.maybeOf(context);
      final int? userIdInt = int.tryParse(dto.id.toString());

      profile?.setFromBackend({
        'id': userIdInt,
        'name': dto.name.isEmpty ? dto.email : dto.name,
        'email': dto.email,
        'role': role.toLowerCase(), // 'root' | 'admin' | 'usuario'
        'phone': null,
        'about': null,
        'avatar_url': null,
      });

      if (!mounted) return;
      if (role == 'Usuario') {
        Navigator.pushReplacementNamed(context, '/user');
      } else {
        Navigator.pushReplacementNamed(context, '/admin');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar sesión: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 🔁 Invertido:
    //   - Tema oscuro  -> logo_claro
    //   - Tema claro   -> logo_oscuro
    final logoPath = isDark
        ? 'assets/images/logo_light.png' // versión clara
        : 'assets/images/logo_dark.png'; // versión oscura

    // Tamaño responsivo del logo
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final availableHeight = size.height - padding.top - kToolbarHeight;
    final logoHeight =
    (availableHeight * 0.32).clamp(170.0, 320.0); // más grande pero seguro

    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      resizeToAvoidBottomInset: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // LOGO
                  Center(
                    child: SizedBox(
                      height: logoHeight,
                      child: Image.asset(
                        logoPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final txt = (v ?? '').trim();
                      if (txt.isEmpty) return 'Requerido';
                      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(txt);
                      return ok ? null : 'Correo inválido';
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (v) {
                      final txt = (v ?? '').trim();
                      if (txt.isEmpty) return 'Requerida';
                      if (txt.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : FilledButton(
                    onPressed: _doLogin,
                    child: const Text('Entrar'),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _showForgotPassword(
                        context,
                        prefillEmail: _email.text,
                      ),
                      icon: const Icon(Icons.help_outline),
                      label:
                      const Text('¿Olvidaste tu contraseña?'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPassword(BuildContext context,
      {String? prefillEmail}) async {
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController(text: prefillEmail ?? '');

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  'Recuperar contraseña',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Escribe tu correo para que el administrador (root) pueda ayudarte a restablecerla.',
                  style: TextStyle(
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withOpacity(.7),
                  ),
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
                    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(txt);
                    return ok ? null : 'Correo inválido';
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    // Aquí podrías llamar a POST /auth/forgot con emailCtrl.text.trim()
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
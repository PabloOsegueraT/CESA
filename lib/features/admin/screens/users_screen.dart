import 'dart:typed_data';
import 'package:flutter/material.dart';

// ✅ Imports necesarios
import '../../../state/users_controller.dart';
import '../../../state/auth_controller.dart';
import '../../../models/user.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _query = '';
  String _role = 'Todos'; // Todos | Usuario | Administrador | Root

  @override
  Widget build(BuildContext context) {
    // ✅ Usa maybeOf para no crashear si faltara el provider
    final usersCtrl = UsersControllerProvider.maybeOf(context);
    // ✅ Trae el AuthController (asegúrate de envolver en main.dart)
    final auth = AuthControllerProvider.of(context);

    if (usersCtrl == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Usuarios')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se encontró UsersControllerProvider.\n'
                  'Envuelve tu MaterialApp con UsersControllerProvider en main.dart.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(.7),
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: usersCtrl,
      builder: (context, _) {
        final items = _applyFilters(usersCtrl.users);

        return Scaffold(
          appBar: AppBar(title: const Text('Usuarios')),
          body: Column(
            children: [
              // Buscador + filtro de rol
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar por nombre o correo',
                        ),
                        onChanged: (q) =>
                            setState(() => _query = q.trim().toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Filtrar por rol',
                      icon: const Icon(Icons.filter_list_rounded),
                      onSelected: (v) => setState(() => _role = v),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'Todos', child: Text('Todos')),
                        PopupMenuItem(value: 'Usuario', child: Text('Usuario')),
                        PopupMenuItem(value: 'Administrador', child: Text('Administrador')),
                        PopupMenuItem(value: 'Root', child: Text('Root')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Lista
              Expanded(
                child: items.isEmpty
                    ? _emptyState(context)
                    : ListView.separated(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final u = items[i];

                    // Construye dinámicamente el menú según permisos
                    final menuItems = <PopupMenuEntry<String>>[];
                    if (auth.canManageUsers) {
                      // Root: puede cambiar contraseña y eliminar
                      menuItems.addAll(const [
                        PopupMenuItem(
                          value: 'pwd',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.key_outlined),
                            title: Text('Cambiar contraseña'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline),
                            title: Text('Eliminar usuario'),
                          ),
                        ),
                      ]);
                    } else {
                      // Admin: sin administrar
                      menuItems.add(const PopupMenuItem(
                        enabled: false,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.info_outline),
                          title: Text('Sin acciones de administración'),
                        ),
                      ));
                    }

                    return ListTile(
                      leading: _UserAvatar(name: u.name, bytes: u.avatarBytes),
                      title: Text(u.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${u.email} • ${u.role}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'pwd') {
                            if (!auth.canManageUsers) return;
                            _changePassword(context, u);
                          } else if (v == 'delete') {
                            if (!auth.canManageUsers) return;

                            if (u.role == 'Root') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'No se puede eliminar al usuario Root.')),
                              );
                              return;
                            }
                            _confirmDelete(context, u);
                          }
                        },
                        itemBuilder: (_) => menuItems,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // FAB Crear usuario (Root y Admin)
          floatingActionButton: auth.canCreateUsers
              ? FloatingActionButton.extended(
            onPressed: () =>
                Navigator.of(context).pushNamed('/create-user'),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Crear usuario'),
          )
              : null,
        );
      },
    );
  }

  // ---------- Helpers del State (¡no mover fuera de la clase!) ----------

  List<AppUser> _applyFilters(List<AppUser> source) {
    return source.where((u) {
      final matchText = _query.isEmpty ||
          u.name.toLowerCase().contains(_query) ||
          u.email.toLowerCase().contains(_query);
      final matchRole = _role == 'Todos' || u.role == _role;
      return matchText && matchRole;
    }).toList();
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Sin resultados con los filtros actuales',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.7),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Seguro que quieres eliminar a "${u.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      UsersControllerProvider.of(context).removeUser(u.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuario "${u.name}" eliminado')),
      );
    }
  }

  Future<void> _changePassword(BuildContext context, AppUser u) async {
    final form = GlobalKey<FormState>();
    final pwd = TextEditingController();
    final pwd2 = TextEditingController();
    bool obscure1 = true, obscure2 = true;

    final newPwd = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Form(
              key: form,
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text('Cambiar contraseña',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Usuario: ${u.name}',
                      style: TextStyle(
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurface
                            .withOpacity(.7),
                      )),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pwd,
                    obscureText: obscure1,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setLocal(() => obscure1 = !obscure1),
                        icon: Icon(obscure1
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerida';
                      if (v.trim().length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pwd2,
                    obscureText: obscure2,
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setLocal(() => obscure2 = !obscure2),
                        icon: Icon(obscure2
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerida';
                      if (v.trim() != pwd.text.trim()) return 'No coincide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      if (!form.currentState!.validate()) return;
                      Navigator.pop(ctx, pwd.text.trim());
                    },
                    icon: const Icon(Icons.key_outlined),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (newPwd != null && newPwd.isNotEmpty) {
      UsersControllerProvider.of(context).updatePassword(u.id, newPwd);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada')),
      );
    }
  }
}

// -------------------- Widget auxiliar: avatar --------------------

class _UserAvatar extends StatelessWidget {
  final String name;
  final Uint8List? bytes;
  const _UserAvatar({required this.name, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundImage: bytes != null ? MemoryImage(bytes!) : null,
      child: bytes == null ? Text(_initials(name)) : null,
    );
  }

  String _initials(String full) {
    final p = full.trim().split(RegExp(r'\s+'));
    if (p.isEmpty) return '?';
    final first = p.first.isNotEmpty ? p.first[0] : '';
    final last = p.length > 1 && p.last.isNotEmpty ? p.last[0] : '';
    final s = (first + last).toUpperCase();
    return s.isEmpty ? '?' : s;
  }
}

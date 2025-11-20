// lib/state/profile_controller.dart
import 'package:flutter/material.dart';

class ProfileController extends ChangeNotifier {
  int? userId;
  String displayName;
  String email;
  String role;
  String phone;
  String about;
  String avatarUrl;

  ProfileController({
    this.userId,
    this.displayName = '',
    this.email = '',
    this.role = '',
    this.phone = '',
    this.about = '',
    this.avatarUrl = '',
  });

  /// Llenar todo desde JSON que viene del backend
  void setFromBackend(Map<String, dynamic> user) {
    userId      = user['id'] as int?;
    displayName = (user['name'] ?? '').toString();
    email       = (user['email'] ?? '').toString();
    role        = (user['role'] ?? '').toString(); // root | admin | usuario
    phone       = (user['phone'] ?? '').toString();
    about       = (user['about'] ?? '').toString();
    avatarUrl   = (user['avatarUrl'] ?? user['avatar_url'] ?? '').toString();
    notifyListeners();
  }

  /// Actualizar solo algunos campos
  void update({
    int? userId,
    String? displayName,
    String? email,
    String? role,
    String? phone,
    String? about,
    String? avatarUrl,
  }) {
    this.userId      = userId      ?? this.userId;
    this.displayName = displayName ?? this.displayName;
    this.email       = email       ?? this.email;
    this.role        = role        ?? this.role;
    this.phone       = phone       ?? this.phone;
    this.about       = about       ?? this.about;
    this.avatarUrl   = avatarUrl   ?? this.avatarUrl;
    notifyListeners();
  }

  String get roleLabel => role;
}

class ProfileControllerProvider
    extends InheritedNotifier<ProfileController> {
  const ProfileControllerProvider({
    super.key,
    required ProfileController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static ProfileController of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ProfileControllerProvider>()!
          .notifier!;

  static ProfileController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ProfileControllerProvider>()
          ?.notifier;
}

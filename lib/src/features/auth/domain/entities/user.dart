/// Pure-Dart user entity for the auth domain.
///
/// No Flutter, no JSON, no package imports. The class is value-equal:
/// const constructor + final fields make it effectively immutable. The
/// data layer maps the network DTO (`AdminUser` from
/// `lib/api/akhiyan_api.dart`) into this. The presentation layer only
/// ever sees [User].
class User {
  const User({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.phone,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String role;
  final String? email;
  final String? phone;
  final String? avatarUrl;

  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff';

  User copyWith({
    String? id,
    String? name,
    String? role,
    String? email,
    String? phone,
    String? avatarUrl,
  }) =>
      User(
        id: id ?? this.id,
        name: name ?? this.name,
        role: role ?? this.role,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          other.id == id &&
          other.name == name &&
          other.role == role &&
          other.email == email &&
          other.phone == phone &&
          other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(id, name, role, email, phone, avatarUrl);
}

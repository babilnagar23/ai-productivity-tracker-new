/// Matches the backend `public_user()` response shape:
/// {
///   "id": "1",          ← String (str(user.id))
///   "name": "Bob",      ← full name or username
///   "email": "...",
///   "streak": 0,
///   "xp": 0,
///   "customConfig": {}
/// }
class UserModel {
  final String id;
  final String email;
  final String? name;
  final int streak;
  final int xp;
  final Map<String, dynamic> customConfig;

  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.streak = 0,
    this.xp = 0,
    this.customConfig = const {},
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      // Backend sends id as String ("1"), guard against int too
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      customConfig:
          json['customConfig'] as Map<String, dynamic>? ?? const {},
    );
  }

  String get displayName {
    if (name != null && name!.isNotEmpty) return name!.split(' ').first;
    return email.split('@').first;
  }

  String get initials {
    if (name != null && name!.isNotEmpty) {
      return name![0].toUpperCase();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }
}

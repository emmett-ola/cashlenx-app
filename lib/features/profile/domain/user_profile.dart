import '../../auth/domain/models/user.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.role,
    this.isActive,
    this.nickname,
    this.avatarUrl,
    this.emailAddress,
    this.gender,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String username;
  final String role;
  final bool? isActive;
  final String? nickname;
  final String? avatarUrl;
  final String? emailAddress;
  final String? gender;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    final nicknameValue = nickname?.trim();
    if (nicknameValue != null && nicknameValue.isNotEmpty) {
      return nicknameValue;
    }
    return username;
  }

  String get displayEmail {
    final emailValue = emailAddress?.trim();
    if (emailValue != null && emailValue.isNotEmpty) {
      return emailValue;
    }
    if (username.contains('@')) return username;
    return 'Not set';
  }

  UserProfile copyWith({String? nickname, String? avatarUrl, String? gender}) {
    return UserProfile(
      id: id,
      username: username,
      role: role,
      isActive: isActive,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      emailAddress: emailAddress,
      gender: gender ?? this.gender,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory UserProfile.demo(User user) {
    return UserProfile(
      id: user.id,
      username: user.username,
      role: user.role,
      isActive: user.isActive,
      nickname: 'Demo User',
      emailAddress: 'demo@cashlenx.com',
      gender: 'others',
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  factory UserProfile.fromUser(User user) {
    return UserProfile(
      id: user.id,
      username: user.username,
      role: user.role,
      isActive: user.isActive,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  factory UserProfile.fromResponse(
    Map<String, dynamic> response, {
    UserProfile? fallback,
  }) {
    final data = _unwrapData(response);
    final json = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};

    return UserProfile(
      id:
          _nullableString(json['id']) ??
          _nullableString(json['_id']) ??
          fallback?.id ??
          '',
      username: _nullableString(json['username']) ?? fallback?.username ?? '',
      role: _nullableString(json['role']) ?? fallback?.role ?? 'user',
      isActive: _nullableBool(json['is_active']) ?? fallback?.isActive,
      nickname: _nullableString(json['nickname']) ?? fallback?.nickname,
      avatarUrl: _nullableString(json['avatar_url']) ?? fallback?.avatarUrl,
      emailAddress:
          _nullableString(json['email_address']) ??
          _nullableString(json['email']) ??
          fallback?.emailAddress,
      gender: _nullableString(json['gender']) ?? fallback?.gender,
      createdAt: _nullableDate(json['created_at']) ?? fallback?.createdAt,
      updatedAt: _nullableDate(json['updated_at']) ?? fallback?.updatedAt,
    );
  }
}

Object? _unwrapData(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is Map && data['user'] is Map) return data['user'];
  if (data is Map && data['profile'] is Map) return data['profile'];
  if (data != null) return data;
  return response;
}

String? _nullableString(Object? value) {
  final rawValue = value is Map ? (value[r'$oid'] ?? value['oid']) : value;
  final text = rawValue?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

bool? _nullableBool(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
  }
  return null;
}

DateTime? _nullableDate(Object? value) {
  final text = _nullableString(value);
  if (text == null) return null;
  return DateTime.tryParse(text);
}

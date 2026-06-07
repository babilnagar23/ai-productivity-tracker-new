class ProfileAvatarOption {
  final String key;
  final String assetPath;
  final String label;

  const ProfileAvatarOption({
    required this.key,
    required this.assetPath,
    required this.label,
  });
}

class ProfileAvatars {
  static const List<ProfileAvatarOption> options = [
    ProfileAvatarOption(
      key: 'avatar1',
      assetPath: 'assets/avatars/avatar1.jpg',
      label: 'Avatar 1',
    ),
    ProfileAvatarOption(
      key: 'avatar2',
      assetPath: 'assets/avatars/avatar2.jpg',
      label: 'Avatar 2',
    ),
    ProfileAvatarOption(
      key: 'avatar3',
      assetPath: 'assets/avatars/avatar3.jpg',
      label: 'Avatar 3',
    ),
    ProfileAvatarOption(
      key: 'avatar4',
      assetPath: 'assets/avatars/avatar4.jpg',
      label: 'Avatar 4',
    ),
    ProfileAvatarOption(
      key: 'avatar5',
      assetPath: 'assets/avatars/avatar5.jpg',
      label: 'Avatar 5',
    ),
    ProfileAvatarOption(
      key: 'avatar6',
      assetPath: 'assets/avatars/avatar6.jpg',
      label: 'Avatar 6',
    ),
    ProfileAvatarOption(
      key: 'avatar7',
      assetPath: 'assets/avatars/avatar7.jpg',
      label: 'Avatar 7',
    ),
    ProfileAvatarOption(
      key: 'avatar8',
      assetPath: 'assets/avatars/avatar8.jpg',
      label: 'Avatar 8',
    ),
  ];

  static const Map<String, String> assetByKey = {
    'avatar1': 'assets/avatars/avatar1.jpg',
    'avatar2': 'assets/avatars/avatar2.jpg',
    'avatar3': 'assets/avatars/avatar3.jpg',
    'avatar4': 'assets/avatars/avatar4.jpg',
    'avatar5': 'assets/avatars/avatar5.jpg',
    'avatar6': 'assets/avatars/avatar6.jpg',
    'avatar7': 'assets/avatars/avatar7.jpg',
    'avatar8': 'assets/avatars/avatar8.jpg',
  };

  static String? assetForKey(String? key) {
    if (key == null || key.trim().isEmpty) return null;
    return assetByKey[key.trim()];
  }
}
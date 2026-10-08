const avatarPresetAssets = <String>[
  'assets/images/avatars/1a01a0838d75e3f5841daac723d44b5d014647fa.png',
  'assets/images/avatars/347fc7ee7a815779535f5264466cf573e0542bd2.png',
  'assets/images/avatars/553d3877a4d9177611e65a98367104cc5e90dc5d.png',
  'assets/images/avatars/875b94185c088fb048cf2c61735c180c88c8e1e5.png',
  'assets/images/avatars/bdb7ba529b44198f72ba0789fa4cb98e973b976b.png',
  'assets/images/avatars/f7afdf49f5c7c09b01252aeeedfd58ba5b1a8cfb.png',
  'assets/images/avatars/f9b59ca5421b2b7ef2e31c2ba4d827f48d22594a.png',
];

const defaultAvatarAsset =
    'assets/images/avatars/f9b59ca5421b2b7ef2e31c2ba4d827f48d22594a.png';

String? resolveAvatarAssetPath(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.startsWith('assets/')) return normalized;
  if (!normalized.startsWith('preset:')) return null;

  final index = int.tryParse(normalized.substring('preset:'.length));
  if (index == null || index < 0 || index >= avatarPresetAssets.length) {
    return null;
  }
  return avatarPresetAssets[index];
}

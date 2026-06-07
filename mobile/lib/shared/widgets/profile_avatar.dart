import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../constants/profile_avatars.dart';

class ProfileAvatar extends StatelessWidget {
  final String? avatarKey;
  final String initials;
  final double size;
  final bool showEditBadge;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    required this.avatarKey,
    required this.initials,
    required this.size,
    this.showEditBadge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final asset = ProfileAvatars.assetForKey(avatarKey);

    final avatar = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: asset != null
            ? Image.asset(
                asset,
                fit: BoxFit.cover,
                width: size,
                height: size,
              )
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.blue, AppColors.purple],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials.isNotEmpty ? initials : '?',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: size * 0.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
      ),
    );

    final tappableAvatar = onTap == null
        ? avatar
        : GestureDetector(
            onTap: onTap,
            child: avatar,
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        tappableAvatar,
        if (showEditBadge)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.32,
              height: size * 0.32,
              decoration: const BoxDecoration(
                color: AppColors.blue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_library_rounded,
                color: Colors.white,
                size: size * 0.16,
              ),
            ),
          ),
      ],
    );
  }
}

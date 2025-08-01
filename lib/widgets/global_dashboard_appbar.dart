import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/profile_dialog.dart';

class GlobalDashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color backgroundColor;
  final Color themeColor;
  final UserModel? currentUser;
  final VoidCallback onProfilePressed;
  final VoidCallback onLogoutPressed;

  const GlobalDashboardAppBar({
    super.key,
    required this.title,
    required this.backgroundColor,
    required this.themeColor,
    required this.currentUser,
    required this.onProfilePressed,
    required this.onLogoutPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.person, size: 28),
          onSelected: (value) {
            if (value == 'profile') {
              onProfilePressed();
            } else if (value == 'logout') {
              onLogoutPressed();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('View Profile'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
import 'package:flutter/material.dart';
import 'package:wetaran_pharma/core/widgets/app_drawer.dart';

class PharmaPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final bool showMenu;
  final bool showNotification;
  final bool showCart;
  final int? cartCount;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final VoidCallback? onNotification;
  final VoidCallback? onCart;
  final List<Widget>? extraActions;

  const PharmaPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.showMenu = false,
    this.showNotification = true,
    this.showCart = false,
    this.cartCount,
    this.onBack,
    this.onMenu,
    this.onNotification,
    this.onCart,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBlue, kBlueDk, Color(0xFF06304F)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showBack)
              _circleIcon(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack ?? () => Navigator.pop(context),
              )
            else if (showMenu)
              _circleIcon(icon: Icons.menu_rounded, onTap: onMenu),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (extraActions != null) ...extraActions!,
            if (showNotification) ...[
              const SizedBox(width: 8),
              _notificationIcon(onTap: onNotification),
            ],
            if (showCart) ...[
              const SizedBox(width: 8),
              _cartIcon(cartCount: cartCount ?? 0, onTap: onCart),
            ],
          ],
        ),
      ),
    );
  }

  Widget _circleIcon({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.13),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: Colors.white),
      ),
    );
  }

  Widget _notificationIcon({VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.13),
          shape: BoxShape.circle,
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.notifications_outlined,
                size: 18,
                color: Colors.white,
              ),
            ),
            Positioned(
              top: 9,
              right: 10,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB13D),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartIcon({required int cartCount, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(.10)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.shopping_cart_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              '$cartCount',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

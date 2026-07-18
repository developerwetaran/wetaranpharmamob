import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/features/auth/presentation/pages/complete_profile_page.dart';
import 'package:wetaran_pharma/features/orders/models/pharma_cart_provider.dart';
import 'package:wetaran_pharma/features/orders/presentation/pages/add_order_screen.dart';
import 'package:wetaran_pharma/features/purchase_history/purchase_history.dart';
import 'package:wetaran_pharma/features/rx_subscription/presentation/pages/rx_subscription.dart';

const kBlue = Color(0xFF0B4F8A);
const kBlueDk = Color(0xFF083A66);
const kTeal = Color(0xFF0FA3A3);
const kTealSoft = Color(0xFFE2F4F4);
const kBg = Color(0xFFF3F7FA);
const kCard = Colors.white;
const kLine = Color(0xFFE3EBF1);
const kInk = Color(0xFF13242F);
const kMuted = Color(0xFF63788A);
const kAmber = Color(0xFFB36A00);
const kAmberSoft = Color(0xFFFFF4E0);
const kRed = Color(0xFFC62828);
const kRedSoft = Color(0xFFFDECEC);

class AppDrawer extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onSelectPage;

  const AppDrawer({
    super.key,
    required this.currentIndex,
    required this.onSelectPage,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _appVersionText = 'Wetaran Pharma v1.0.0';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;

    setState(() {
      _appVersionText = 'Wetaran Pharma v${info.version}+${info.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final userEmail = user?.email ?? '';

    return Drawer(
      backgroundColor: kCard,
      elevation: 0,
      child: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                children: [
                  _DrawerSection(
                    label: 'MAIN',
                    items: [
                      _DrawerItem(
                        icon: Icons.home_outlined,
                        title: 'Home',
                        isActive: widget.currentIndex == 0,
                        onTap: () => widget.onSelectPage(0),
                      ),
                      _DrawerItem(
                        icon: Icons.shopping_cart_outlined,
                        title: 'Place Order',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddOrderScreen(),
                            ),
                          );
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.receipt_long_outlined,
                        title: 'Ongoing Orders',
                        isActive: widget.currentIndex == 1,
                        onTap: () => widget.onSelectPage(1),
                      ),
                      _DrawerItem(
                        icon: Icons.local_offer_outlined,
                        title: 'Schemes',
                        isActive: widget.currentIndex == 2,
                        onTap: () => widget.onSelectPage(2),
                      ),
                      _DrawerItem(
                        icon: Icons.card_giftcard_rounded,
                        title: 'Rewards',
                        isActive: widget.currentIndex == 3,
                        onTap: () => widget.onSelectPage(3),
                      ),
                      _DrawerItem(
                        icon: Icons.lock_clock_outlined,
                        title: 'Expiry',
                        isActive: widget.currentIndex == 4,
                        onTap: () => widget.onSelectPage(4),
                      ),
                      _DrawerItem(
                        icon: Icons.bar_chart_outlined,
                        title: 'Intelligence',
                        isActive: widget.currentIndex == 5,
                        onTap: () => widget.onSelectPage(5),
                      ),
                      _DrawerItem(
                        icon: Icons.calendar_month_outlined,
                        title: 'Rx Subscription',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RxSubscriptionPage(),
                            ),
                          );
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.history_edu_outlined,
                        title: 'Purchase History',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PharmaPurchaseHistoryPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _DrawerSection(
                    label: 'ACCOUNT',
                    items: [
                      _DrawerItem(
                        icon: Icons.person_outline_rounded,
                        title: 'Complete Profile',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CompleteProfilePage(
                                email: userEmail,
                                businessName: '',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _DrawerSection(
                    label: 'MORE',
                    items: [
                      _DrawerItem(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        comingSoon: true,
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(color: kLine, height: 1),
                  ),
                  const SizedBox(height: 10),
                  _DrawerItem(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    isDestructive: true,
                    onTap: () async {
                      final rootNav = Navigator.of(
                        context,
                        rootNavigator: true,
                      );
                      final cart = Provider.of<PharmaCartProvider>(
                        context,
                        listen: false,
                      );

                      Navigator.pop(context);

                      final shouldLogout = await _showLogoutDialog(
                        rootNav.context,
                      );
                      if (shouldLogout != true) return;

                      cart.clear();
                      await Supabase.instance.client.auth.signOut();
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FBFD),
                border: Border(top: BorderSide(color: kLine)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.local_hospital_outlined,
                    size: 13,
                    color: kMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _appVersionText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: kMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBlue, kBlueDk],
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Image.asset(
              'assets/images/WRxLogo_RX.webp',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wetaran Pharma',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Order smarter. Stock sharper.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFD8E7F5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.40),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: kRedSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.logout_rounded, color: kRed, size: 26),
              ),
              const SizedBox(height: 16),
              const Text(
                'Logout from account?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You will be signed out of Wetaran Pharma.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: kMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kInk,
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: kLine),
                        backgroundColor: const Color(0xFFF9FBFD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Yes, Logout',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String label;
  final List<Widget> items;

  const _DrawerSection({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: kMuted,
                letterSpacing: 1.1,
              ),
            ),
          ),
          ...items,
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool comingSoon;
  final bool isActive;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
    this.comingSoon = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDestructive ? kRed : kBlue;
    final tileBg = isDestructive
        ? kRedSoft
        : comingSoon
        ? const Color(0xFFF8FAFC)
        : isActive
        ? kTealSoft
        : Colors.transparent;

    return Opacity(
      opacity: comingSoon ? 0.72 : 1,
      child: InkWell(
        onTap: comingSoon ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDestructive
                  ? const Color(0xFFF7D4D4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? kRedSoft
                      : comingSoon
                      ? const Color(0xFFEAF1F7)
                      : const Color(0xFFE4EDF7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDestructive ? kRed : kInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (comingSoon)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: kAmberSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Soon',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: kAmber,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wetaran_pharma/core/widgets/reusable_pharma_header.dart';
import 'package:wetaran_pharma/features/orders/models/pharma_cart_provider.dart';
import 'package:wetaran_pharma/features/orders/presentation/widgets/pharma_cart_sheet.dart';

const headingColor = Color(0xFF0F172A);
const mutedColor = Color(0xFF64748B);
const borderColor = Color(0xFFE2E8F0);
const pageBg = Color(0xFFF8FAFC);
const kBlue = Color(0xFF0B4F8A);
const kBlueDk = Color(0xFF083A66);
const greenSoft = Color(0xFFDCFCE7);
const green = Color(0xFF16A34A);
const amberSoft = Color(0xFFFFEDD5);
const amber = Color(0xFFD97706);
const redSoft = Color(0xFFFEE2E2);
const red = Color(0xFFDC2626);

Widget buildShellHeader({
  required String title,
  required VoidCallback onOpenDrawer,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [kBlue, kBlueDk, Color(0xFF06304F)],
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        GestureDetector(
          onTap: onOpenDrawer,
          child: Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.13),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_rounded,
              size: 19,
              color: Colors.white,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {},
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
        ),
      ],
    ),
  );
}

Widget appCard({
  required Widget child,
  EdgeInsets padding = const EdgeInsets.all(14),
}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class SchemesPage extends StatefulWidget {
  final VoidCallback onOpenDrawer;

  const SchemesPage({super.key, required this.onOpenDrawer});

  @override
  State<SchemesPage> createState() => _SchemesPageState();
}

class _SchemesPageState extends State<SchemesPage> {
  final List<Map<String, String>> _schemes = [
    {
      'title': 'Dolo 650 - Buy 10 strips, get 1 free',
      'party': 'Micro Labs · Manufacturer',
      'meta': 'Valid till 15 Jul · Min. order 10 strips',
    },
    {
      'title': '2% extra margin on Alkem range above ₹10,000',
      'party': 'Mahavir Pharma · Distributor',
      'meta': 'Valid till 31 Jul · Pincode 400058',
    },
    {
      'title': 'Augmentin 625 Duo - 5 + 1 scheme',
      'party': 'GSK · Manufacturer',
      'meta': 'Valid till 20 Jul · All distributors',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PharmaCartProvider>();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          PharmaPageHeader(
            title: 'Schemes',
            showMenu: true,
            showNotification: false,
            showCart: true,
            cartCount: cart.itemCount,
            onMenu: widget.onOpenDrawer,
            onCart: () => showPharmaCartSheet(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              children: [
                appCard(
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: amberSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.local_offer_outlined,
                          color: amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active schemes for your area',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: headingColor,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Offers from manufacturers and distributors near you.',
                              style: TextStyle(fontSize: 12, color: mutedColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ..._schemes.map((scheme) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: appCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scheme['party']!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: mutedColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            scheme['title']!,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: headingColor,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              scheme['meta']!,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

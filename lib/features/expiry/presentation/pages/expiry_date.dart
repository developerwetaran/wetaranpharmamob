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

class ExpiryPage extends StatefulWidget {
  final VoidCallback onOpenDrawer;

  const ExpiryPage({super.key, required this.onOpenDrawer});

  @override
  State<ExpiryPage> createState() => _ExpiryPageState();
}

class _ExpiryPageState extends State<ExpiryPage> {
  final List<_BatchItem> _batches = const [
    _BatchItem(
      product: 'Telma 40',
      company: 'Glenmark',
      batchNo: 'TL4-2408B',
      orderNo: '#WP-10389',
      qtyLeft: '22 strips',
      expiry: '28 Jul 2026',
      status: '26 days left',
      statusType: BatchStatus.danger,
    ),
    _BatchItem(
      product: 'Pan 40',
      company: 'Alkem',
      batchNo: 'PN40-1147',
      orderNo: '#WP-10395',
      qtyLeft: '15 strips',
      expiry: '18 Aug 2026',
      status: '47 days left',
      statusType: BatchStatus.warning,
    ),
    _BatchItem(
      product: 'Shelcal 500',
      company: 'Torrent',
      batchNo: 'SH5-0921',
      orderNo: '#WP-10412',
      qtyLeft: '30 strips',
      expiry: '25 Aug 2026',
      status: '54 days left',
      statusType: BatchStatus.warning,
    ),
    _BatchItem(
      product: 'Ecosprin 75',
      company: 'USV',
      batchNo: 'EC75-3310',
      orderNo: '#WP-10420',
      qtyLeft: '40 strips',
      expiry: '30 Aug 2026',
      status: '59 days left',
      statusType: BatchStatus.warning,
    ),
    _BatchItem(
      product: 'Dolo 650',
      company: 'Micro Labs',
      batchNo: 'DL65-5502',
      orderNo: '#WP-10471',
      qtyLeft: '110 strips',
      expiry: 'Mar 2027',
      status: 'Healthy',
      statusType: BatchStatus.good,
    ),
    _BatchItem(
      product: 'Azithral 500',
      company: 'Alembic',
      batchNo: 'AZ5-7718',
      orderNo: '#WP-10482',
      qtyLeft: '25 strips',
      expiry: 'Jan 2027',
      status: 'Healthy',
      statusType: BatchStatus.good,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PharmaCartProvider>();
    return Container(
      color: pageBg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PharmaPageHeader(
              title: 'Expiry & Batch',
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
                  const Text(
                    'Expiry & Batch Tracking',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: headingColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Every product bought via the platform, tracked batch by batch.',
                    style: TextStyle(
                      fontSize: 13,
                      color: mutedColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Expiring ≤ 30 days',
                          value: '1',
                          subtitle: 'Act now — return or push sales',
                          accentColor: red,
                          accentSoft: redSoft,
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Expiring ≤ 60 days',
                          value: '3',
                          subtitle: 'Plan returns with distributor',
                          accentColor: amber,
                          accentSoft: amberSoft,
                          icon: Icons.schedule_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Healthy batches',
                          value: '38',
                          subtitle: 'More than 90 days shelf life',
                          accentColor: green,
                          accentSoft: greenSoft,
                          icon: Icons.verified_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'BATCH REGISTER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: mutedColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ..._batches.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildBatchCard(item),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color accentColor,
    required Color accentSoft,
    required IconData icon,
  }) {
    return appCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accentColor, size: 19),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.2,
              color: mutedColor,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: accentColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: mutedColor,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(_BatchItem item) {
    final statusColors = _statusColors(item.statusType);

    return appCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: headingColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.company,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: mutedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColors.$1,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusColors.$2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(child: _infoBlock('Batch no.', item.batchNo)),
              const SizedBox(width: 12),
              Expanded(
                child: _infoBlock('Order', item.orderNo, valueColor: kBlue),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _infoBlock('Qty left', item.qtyLeft)),
              const SizedBox(width: 12),
              Expanded(child: _infoBlock('Expiry', item.expiry)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBlock(
    String label,
    String value, {
    Color valueColor = headingColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: mutedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.2,
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _statusColors(BatchStatus statusType) {
    switch (statusType) {
      case BatchStatus.danger:
        return (redSoft, red);
      case BatchStatus.warning:
        return (amberSoft, amber);
      case BatchStatus.good:
        return (greenSoft, green);
    }
  }
}

enum BatchStatus { danger, warning, good }

class _BatchItem {
  final String product;
  final String company;
  final String batchNo;
  final String orderNo;
  final String qtyLeft;
  final String expiry;
  final String status;
  final BatchStatus statusType;

  const _BatchItem({
    required this.product,
    required this.company,
    required this.batchNo,
    required this.orderNo,
    required this.qtyLeft,
    required this.expiry,
    required this.status,
    required this.statusType,
  });
}

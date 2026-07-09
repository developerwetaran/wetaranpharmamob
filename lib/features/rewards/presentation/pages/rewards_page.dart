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

class CashbackEntry {
  final String orderId;
  final String distributor;
  final String orderValue;
  final String cashback;
  final String status;

  CashbackEntry({
    required this.orderId,
    required this.distributor,
    required this.orderValue,
    required this.cashback,
    required this.status,
  });
}

class RewardsPage extends StatefulWidget {
  final VoidCallback onOpenDrawer;

  const RewardsPage({super.key, required this.onOpenDrawer});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final List<CashbackEntry> _cashbackEntries = [
    CashbackEntry(
      orderId: '#WP-10482',
      distributor: 'Mahavir Pharma',
      orderValue: '₹6,420',
      cashback: '₹64',
      status: 'Credited',
    ),
    CashbackEntry(
      orderId: '#WP-10471',
      distributor: 'Shree Sai Medico',
      orderValue: '₹3,150',
      cashback: '₹32',
      status: 'Credited',
    ),
    CashbackEntry(
      orderId: '#WP-10465',
      distributor: 'Lifeline Pharma',
      orderValue: '₹8,900',
      cashback: '₹89',
      status: 'Credited',
    ),
    CashbackEntry(
      orderId: '#WP-10458',
      distributor: 'Mahavir Pharma',
      orderValue: '₹2,700',
      cashback: '₹27',
      status: 'Pending delivery',
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
              title: 'Rewards',
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
                    'Rewards',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: headingColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Cashback on every order — credited automatically to your wallet.',
                    style: TextStyle(
                      fontSize: 13,
                      color: mutedColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildWalletCard(),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Cashback this month',
                          value: '₹412',
                          subtitle: 'Across 11 orders in July',
                          valueColor: const Color(0xFF0FA3A3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Lifetime cashback',
                          value: '₹3,180',
                          subtitle: 'Since joining Wetaran Pharma',
                          valueColor: kBlue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Recent cashback',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: mutedColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  appCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        _buildTableHeader(),
                        const Divider(height: 1, color: borderColor),
                        ..._cashbackEntries.map(_buildCashbackRow),
                      ],
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

  Widget _buildWalletCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBlue, kBlueDk, Color(0xFF06304F)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Wallet balance',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '₹240',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Use it against your next order at checkout.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color valueColor,
  }) {
    return appCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              color: mutedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: mutedColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: const [
          Expanded(flex: 22, child: Text('Order', style: _tableHeadStyle)),
          Expanded(
            flex: 30,
            child: Text('Distributor', style: _tableHeadStyle),
          ),
          Expanded(
            flex: 20,
            child: Text(
              'Value',
              style: _tableHeadStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              'Cashback',
              style: _tableHeadStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashbackRow(CashbackEntry item) {
    final bool credited = item.status == 'Credited';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 22,
                child: Text(
                  item.orderId,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: headingColor,
                  ),
                ),
              ),
              Expanded(
                flex: 30,
                child: Text(
                  item.distributor,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: headingColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 20,
                child: Text(
                  item.orderValue,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 18,
                child: Text(
                  item.cashback,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: kBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: credited ? greenSoft : amberSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: credited ? green : amber,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: borderColor),
        ],
      ),
    );
  }
}

const _tableHeadStyle = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w800,
  color: mutedColor,
  letterSpacing: 0.6,
);

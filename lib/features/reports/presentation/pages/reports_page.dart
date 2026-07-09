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

class ReportsPage extends StatefulWidget {
  final VoidCallback onOpenDrawer;

  const ReportsPage({super.key, required this.onOpenDrawer});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final List<_TrendItem> monthlyTrend = const [
    _TrendItem(month: 'Feb', value: 2.6, heightFactor: 0.52),
    _TrendItem(month: 'Mar', value: 2.9, heightFactor: 0.58),
    _TrendItem(month: 'Apr', value: 3.1, heightFactor: 0.62),
    _TrendItem(month: 'May', value: 3.2, heightFactor: 0.64),
    _TrendItem(month: 'Jun', value: 3.4, heightFactor: 0.68),
    _TrendItem(month: 'Jul', value: 3.8, heightFactor: 0.76, highlight: true),
  ];

  final List<_DistributorItem> distributors = const [
    _DistributorItem(
      name: 'Mahavir Pharma Distributors',
      value: '₹1.72L',
      percent: 45,
      color: Color(0xFF0FA3A3),
    ),
    _DistributorItem(
      name: 'Shree Sai Medico Agencies',
      value: '₹1.15L',
      percent: 30,
      color: kBlue,
    ),
    _DistributorItem(
      name: 'Lifeline Pharma Agency',
      value: '₹0.73L',
      percent: 19,
      color: amber,
    ),
    _DistributorItem(
      name: 'Others',
      value: '₹0.24L',
      percent: 6,
      color: Color(0xFF7FB2D9),
    ),
  ];

  final List<_FastMoverItem> fastMovers = const [
    _FastMoverItem(name: 'Dolo 650', qty: '140 strips', spend: '₹3,794'),
    _FastMoverItem(name: 'Pan 40', qty: '95 strips', spend: '₹9,120'),
    _FastMoverItem(name: 'Telma 40', qty: '80 strips', spend: '₹8,560'),
    _FastMoverItem(
      name: 'Augmentin 625 Duo',
      qty: '60 strips',
      spend: '₹12,270',
    ),
  ];

  final List<_SavingItem> savings = const [
    _SavingItem(
      title: 'Saved via distributor comparison',
      value: '₹2,140',
      progress: 0.70,
      color: Color(0xFF0FA3A3),
    ),
    _SavingItem(
      title: 'Scheme benefits captured',
      value: '₹1,380',
      progress: 0.45,
      color: kBlue,
    ),
    _SavingItem(
      title: 'Cashback earned',
      value: '₹412',
      progress: 0.14,
      color: amber,
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
              title: 'Reports',
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
                    'Reports',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: headingColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Your pharmacy's buying, decoded. Data from platform orders only.",
                    style: TextStyle(
                      fontSize: 13,
                      color: mutedColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),

                  appCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monthly purchase trend (₹ in lakh)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: headingColor,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 180,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: monthlyTrend
                                .map((item) => Expanded(child: _buildBar(item)))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  appCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Purchase by distributor — July',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: headingColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...distributors.map(_buildDistributorRow),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  appCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: const [
                              Expanded(
                                flex: 42,
                                child: Text(
                                  'Fast movers — July',
                                  style: _tableHeadStyle,
                                ),
                              ),
                              Expanded(
                                flex: 28,
                                child: Text('Qty', style: _tableHeadStyle),
                              ),
                              Expanded(
                                flex: 30,
                                child: Text(
                                  'Spend',
                                  style: _tableHeadStyle,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: borderColor),
                        ...fastMovers.map(_buildFastMoverRow),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  appCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Savings snapshot — July',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: headingColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...savings.map(_buildSavingsRow),
                        const SizedBox(height: 10),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              color: mutedColor,
                              height: 1.45,
                            ),
                            children: [
                              TextSpan(text: 'Total July advantage: '),
                              TextSpan(
                                text: '₹3,932',
                                style: TextStyle(
                                  color: green,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: ' versus buying without comparison.',
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildBar(_TrendItem item) {
    final Color fillColor = item.highlight ? amber : kBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            item.value.toString(),
            style: TextStyle(
              fontSize: 10.5,
              color: item.highlight ? amber : kBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: item.heightFactor,
                child: Container(
                  width: 28,
                  decoration: BoxDecoration(
                    gradient: item.highlight
                        ? null
                        : const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [kBlue, Color(0xFF0FA3A3)],
                          ),
                    color: item.highlight ? amber : null,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                      bottom: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.month,
            style: const TextStyle(
              fontSize: 10.5,
              color: mutedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributorRow(_DistributorItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w600,
                    color: headingColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${item.value} · ${item.percent}%',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: item.percent / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(item.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFastMoverRow(_FastMoverItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 42,
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: headingColor,
                  ),
                ),
              ),
              Expanded(
                flex: 28,
                child: Text(
                  item.qty,
                  style: const TextStyle(
                    fontSize: 12,
                    color: mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 30,
                child: Text(
                  item.spend,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: headingColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: borderColor),
        ],
      ),
    );
  }

  Widget _buildSavingsRow(_SavingItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w600,
                    color: headingColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                item.value,
                style: const TextStyle(
                  fontSize: 11.8,
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: item.progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(item.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendItem {
  final String month;
  final double value;
  final double heightFactor;
  final bool highlight;

  const _TrendItem({
    required this.month,
    required this.value,
    required this.heightFactor,
    this.highlight = false,
  });
}

class _DistributorItem {
  final String name;
  final String value;
  final int percent;
  final Color color;

  const _DistributorItem({
    required this.name,
    required this.value,
    required this.percent,
    required this.color,
  });
}

class _FastMoverItem {
  final String name;
  final String qty;
  final String spend;

  const _FastMoverItem({
    required this.name,
    required this.qty,
    required this.spend,
  });
}

class _SavingItem {
  final String title;
  final String value;
  final double progress;
  final Color color;

  const _SavingItem({
    required this.title,
    required this.value,
    required this.progress,
    required this.color,
  });
}

const _tableHeadStyle = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w800,
  color: mutedColor,
  letterSpacing: 0.6,
);

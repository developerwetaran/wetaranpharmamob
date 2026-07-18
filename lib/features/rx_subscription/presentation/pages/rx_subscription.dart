import 'package:flutter/material.dart';
import 'package:wetaran_pharma/core/widgets/reusable_pharma_header.dart';

const headingColor = Color(0xFF0F172A);
const mutedColor = Color(0xFF64748B);
const borderColor = Color(0xFFE2E8F0);
const pageBg = Color(0xFFF8FAFC);
const kBlue = Color(0xFF0B4F8A);
const kBlueDk = Color(0xFF083A66);
const tealSoft = Color(0xFFCCFBF1);
const teal = Color(0xFF0F766E);
const amberSoft = Color(0xFFFFEDD5);
const amber = Color(0xFFD97706);
const blueSoft = Color(0xFFDBEAFE);
const blue = Color(0xFF2563EB);

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

class RxSubscriptionPage extends StatefulWidget {
  const RxSubscriptionPage({super.key});

  @override
  State<RxSubscriptionPage> createState() => _RxSubscriptionPageState();
}

class _RxSubscriptionPageState extends State<RxSubscriptionPage> {
  final List<_RefillItem> _refills = [
    const _RefillItem(
      customer: 'R. Deshpande',
      medication: 'Telma 40 · 1 strip',
      cycle: 'Every 30 days',
      nextRefill: '04 Jul',
      status: 'Reminder sent',
      statusTone: _StatusTone.blue,
    ),
    const _RefillItem(
      customer: 'S. Iyer',
      medication: 'Thyronorm 50 · 1 bottle',
      cycle: 'Every 30 days',
      nextRefill: '05 Jul',
      status: 'Reminder sent',
      statusTone: _StatusTone.blue,
    ),
    const _RefillItem(
      customer: 'M. Shaikh',
      medication: 'Ecosprin 75 + Shelcal 500',
      cycle: 'Every 30 days',
      nextRefill: '06 Jul',
      status: 'Confirmed',
      statusTone: _StatusTone.teal,
    ),
    const _RefillItem(
      customer: 'P. Nair',
      medication: 'Pan 40 · 2 strips',
      cycle: 'Every 45 days',
      nextRefill: '08 Jul',
      status: 'Awaiting reply',
      statusTone: _StatusTone.amber,
    ),
    const _RefillItem(
      customer: 'A. Kulkarni',
      medication: 'Telma 40 · 1 strip',
      cycle: 'Every 30 days',
      nextRefill: '09 Jul',
      status: 'Reminder sent',
      statusTone: _StatusTone.blue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: pageBg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PharmaPageHeader(
              title: 'Rx Subscription',
              showBack: true,
              showMenu: false,
              showNotification: false,
              showCart: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  const _PageIntro(),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          title: 'Active subscriptions',
                          value: '14',
                          subtitle: 'Recurring monthly revenue',
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _KpiCard(
                          title: 'Refills due this week',
                          value: '5',
                          subtitle: 'Customers get auto-reminders',
                          highlighted: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const _KpiCard(
                    title: 'Est. monthly value',
                    value: '₹21.6K',
                    subtitle: 'From subscription customers',
                    fullWidth: true,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Upcoming refills',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: headingColor,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._refills.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: appCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.customer,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: headingColor,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.medication,
                                        style: const TextStyle(
                                          fontSize: 12.3,
                                          height: 1.4,
                                          fontWeight: FontWeight.w600,
                                          color: headingColor,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _StatusChip(item: item),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _MiniMeta(
                                    label: 'Cycle',
                                    value: item.cycle,
                                  ),
                                ),
                                Expanded(
                                  child: _MiniMeta(
                                    label: 'Next refill',
                                    value: item.nextRefill,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${item.customer} marked ready',
                                      ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(42),
                                  side: const BorderSide(color: borderColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Mark ready',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: headingColor,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: tealSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '+',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: teal,
                              height: 1,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Set up a new subscription',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: headingColor,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Add a customer\'s repeat prescription and Wetaran Pharma will remind them before every refill - so the sale walks back to your counter, not the one next door.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: mutedColor,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Open new subscription flow',
                                      ),
                                    ),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('New subscription'),
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
}

class _PageIntro extends StatelessWidget {
  const _PageIntro();

  @override
  Widget build(BuildContext context) {
    return appCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.autorenew_rounded, color: kBlue),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recurring prescriptions for your regular customers',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: headingColor,
                    height: 1.35,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Scheduled, reminded, and ready - so every repeat refill feels organized and easy to process.',
                  style: TextStyle(
                    fontSize: 12.2,
                    color: mutedColor,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final bool highlighted;
  final bool fullWidth;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    this.highlighted = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlighted ? const Color(0xFFF0FDFA) : Colors.white;
    final side = highlighted ? const Color(0xFF99F6E4) : borderColor;
    final accent = highlighted ? teal : headingColor;

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: side),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: mutedColor,
              height: 1.35,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: mutedColor,
              height: 1.4,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

enum _StatusTone { blue, teal, amber }

class _RefillItem {
  final String customer;
  final String medication;
  final String cycle;
  final String nextRefill;
  final String status;
  final _StatusTone statusTone;

  const _RefillItem({
    required this.customer,
    required this.medication,
    required this.cycle,
    required this.nextRefill,
    required this.status,
    required this.statusTone,
  });
}

class _StatusChip extends StatelessWidget {
  final _RefillItem item;

  const _StatusChip({required this.item});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (item.statusTone) {
      case _StatusTone.blue:
        bg = blueSoft;
        fg = blue;
        break;
      case _StatusTone.teal:
        bg = tealSoft;
        fg = teal;
        break;
      case _StatusTone.amber:
        bg = amberSoft;
        fg = amber;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        item.status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: mutedColor,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.2,
            fontWeight: FontWeight.w700,
            color: headingColor,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

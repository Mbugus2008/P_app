import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/parcel_controller.dart';
import '../models/parcel_model.dart';
import '../utilities/status_color.dart';

class LocationParcelsPage extends StatefulWidget {
  const LocationParcelsPage({super.key});

  @override
  State<LocationParcelsPage> createState() => _LocationParcelsPageState();
}

class _LocationParcelsPageState extends State<LocationParcelsPage> {
  ParcelController get _controller => Get.find<ParcelController>();

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  final ScrollController _fromScrollCtrl = ScrollController();
  final ScrollController _toScrollCtrl = ScrollController();

  ParcelStatus? _fromStatusFilter;
  bool? _fromPaidFilter;
  PaymentMethod? _fromPaymentFilter;
  ParcelStatus? _toStatusFilter;
  bool? _toPaidFilter;
  PaymentMethod? _toPaymentFilter;

  final Set<String> _expandedGroups = {};

  @override
  void dispose() {
    _fromScrollCtrl.dispose();
    _toScrollCtrl.dispose();
    super.dispose();
  }

  List<Parcel> _applyDateFilter(List<Parcel> parcels) {
    final from = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final to = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);
    return parcels.where((p) {
      final d = p.Date_sent ?? p.Date_Created ?? DateTime.now();
      return !d.isBefore(from) && !d.isAfter(to);
    }).toList();
  }

  List<Parcel> _applyChipFilters(
    List<Parcel> parcels, {
    ParcelStatus? status,
    bool? paid,
    PaymentMethod? method,
  }) {
    var list = parcels;
    if (status != null) list = list.where((p) => p.Status == status).toList();
    if (paid != null)
      list = list.where((p) => (p.Paid == true) == paid).toList();
    if (method != null)
      list = list.where((p) => p.paymentMethod == method).toList();
    return list;
  }

  Map<String, List<Parcel>> _groupByTo(List<Parcel> parcels) {
    final map = <String, List<Parcel>>{};
    for (final p in parcels) {
      final key = (p.To ?? 'Unknown').trim();
      map.putIfAbsent(key.isEmpty ? 'Unknown' : key, () => <Parcel>[]).add(p);
    }
    return map;
  }

  Map<String, List<Parcel>> _groupByFrom(List<Parcel> parcels) {
    final map = <String, List<Parcel>>{};
    for (final p in parcels) {
      final key = (p.From ?? 'Unknown').trim();
      map.putIfAbsent(key.isEmpty ? 'Unknown' : key, () => <Parcel>[]).add(p);
    }
    return map;
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null)
      setState(() => isFrom ? _fromDate = picked : _toDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final location = _controller.currentLocation;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 72,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _appBarDateChip('From', _fromDate, () => _pickDate(true)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            _appBarDateChip('To', _toDate, () => _pickDate(false)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Container(
            color: Colors.black.withValues(alpha: 0.15),
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _appBarFilterChip(
                  'Status',
                  _fromStatusFilter?.name ?? 'All',
                  () => _showFilterMenu(
                    'Status',
                    const {
                      'All': null,
                      'Pending': ParcelStatus.pending,
                      'In Transit': ParcelStatus.inTransit,
                      'Received': ParcelStatus.received,
                      'Collected': ParcelStatus.collected,
                    },
                    (v) =>
                        setState(() => _fromStatusFilter = v as ParcelStatus?),
                    _fromStatusFilter,
                  ),
                ),
                const SizedBox(width: 6),
                _appBarFilterChip(
                  'Paid',
                  _fromPaidFilter == null
                      ? 'All'
                      : (_fromPaidFilter == true ? 'Paid' : 'Unpaid'),
                  () => _showFilterMenu(
                    'Paid',
                    const {'All': null, 'Paid': true, 'Unpaid': false},
                    (v) => setState(() => _fromPaidFilter = v as bool?),
                    _fromPaidFilter,
                  ),
                ),
                const SizedBox(width: 6),
                _appBarFilterChip(
                  'Pay',
                  _fromPaymentFilter?.name ?? 'All',
                  () => _showFilterMenu(
                    'Pay',
                    const {
                      'All': null,
                      'Cash': PaymentMethod.cash,
                      'M-Pesa': PaymentMethod.mpesa,
                    },
                    (v) => setState(
                      () => _fromPaymentFilter = v as PaymentMethod?,
                    ),
                    _fromPaymentFilter,
                  ),
                ),
              ],
            ),
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF667eea), Color(0xFFF5F7FA)],
            stops: [0.0, 0.28],
          ),
        ),
        child: Obx(() {
          if (_controller.isLoading)
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );

          final fromRaw = _applyDateFilter(_controller.parcelsFromLocation);
          final toRaw = _applyDateFilter(_controller.parcelsToLocation);
          final fromParcels = _applyChipFilters(
            fromRaw,
            status: _fromStatusFilter,
            paid: _fromPaidFilter,
            method: _fromPaymentFilter,
          );
          final toParcels = _applyChipFilters(
            toRaw,
            status: _toStatusFilter,
            paid: _toPaidFilter,
            method: _toPaymentFilter,
          );
          final fromGrouped = _groupByTo(fromParcels);
          final toGrouped = _groupByFrom(toParcels);

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: Column(
              children: [
                const SizedBox(height: 110),
                Expanded(
                  child: _buildHalf(
                    'From $location',
                    Icons.arrow_upward_rounded,
                    fromGrouped,
                    const Color(0xFFFF7E5F),
                    'No parcels sent from $location',
                    _fromScrollCtrl,
                    'To',
                    fromParcels.length,
                  ),
                ),
                Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7E5F), Color(0xFF4FACFE)],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildHalf(
                      'To $location',
                      Icons.arrow_downward_rounded,
                      toGrouped,
                      const Color(0xFF4FACFE),
                      'No parcels sent to $location',
                      _toScrollCtrl,
                      'From',
                      toParcels.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _appBarDateChip(String label, DateTime date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          '$label ${DateFormat('dd/MM/yy').format(date)}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.3),
        side: BorderSide.none,
        avatar: const Icon(
          Icons.calendar_today_rounded,
          size: 14,
          color: Colors.white,
        ),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _appBarFilterChip(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          '$label: $value',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.25),
        side: BorderSide.none,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _showFilterMenu<T>(
    String title,
    Map<String, T?> options,
    void Function(T?) onSelected,
    T? current,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Divider(),
                ...options.entries.map(
                  (e) => ListTile(
                    title: Text(e.key),
                    trailing:
                        current == e.value
                            ? const Icon(Icons.check, color: Color(0xFF667eea))
                            : null,
                    onTap: () {
                      onSelected(e.value);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _statusDropdown(
    ParcelStatus? value,
    void Function(ParcelStatus?) onChanged,
  ) {
    return _filterDropdown(
      value: value?.name,
      items: const {
        'all': 'All Status',
        'pending': 'Pending',
        'inTransit': 'In Transit',
        'received': 'Received',
        'collected': 'Collected',
      },
      onChanged:
          (k) => onChanged(
            k == 'all'
                ? null
                : ParcelStatus.values.firstWhere((s) => s.name == k),
          ),
    );
  }

  Widget _paidDropdown(bool? value, void Function(bool?) onChanged) {
    return _filterDropdown(
      value: value == null ? 'all' : (value ? 'paid' : 'unpaid'),
      items: const {'all': 'All Paid', 'paid': 'Paid', 'unpaid': 'Unpaid'},
      onChanged: (k) => onChanged(k == 'all' ? null : k == 'paid'),
    );
  }

  Widget _methodDropdown(
    PaymentMethod? value,
    void Function(PaymentMethod?) onChanged,
  ) {
    return _filterDropdown(
      value: value?.name,
      items: const {'all': 'All Payment', 'cash': 'Cash', 'mpesa': 'M-Pesa'},
      onChanged:
          (k) => onChanged(
            k == 'all'
                ? null
                : PaymentMethod.values.firstWhere((m) => m.name == k),
          ),
    );
  }

  Widget _filterDropdown({
    required String? value,
    required Map<String, String> items,
    required void Function(String) onChanged,
  }) {
    final selectedLabel = items[value] ?? items.values.first;
    return PopupMenuButton<String>(
      onSelected: onChanged,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedLabel!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
          ],
        ),
      ),
      itemBuilder:
          (ctx) =>
              items.entries
                  .map(
                    (e) => PopupMenuItem<String>(
                      value: e.key,
                      child: Text(
                        e.value,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
    );
  }

  Widget _buildHalf(
    String title,
    IconData icon,
    Map<String, List<Parcel>> grouped,
    Color color,
    String emptyMsg,
    ScrollController scrollCtrl,
    String groupLabel,
    int total,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _sectionHeader(title, icon, total, color),
        ),
        Expanded(
          child:
              grouped.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 36,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          emptyMsg,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    controller: scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                    itemCount: grouped.length,
                    itemBuilder: (ctx, i) {
                      final entry = grouped.entries.elementAt(i);
                      final locName = entry.key;
                      final parcels = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ExpandedGroup(
                          groupKey: '$title|$locName',
                          locName: locName,
                          groupLabel: groupLabel,
                          parcels: parcels,
                          color: color,
                          expanded: _expandedGroups.contains('$title|$locName'),
                          onToggle:
                              () => setState(() {
                                final key = '$title|$locName';
                                if (_expandedGroups.contains(key))
                                  _expandedGroups.remove(key);
                                else
                                  _expandedGroups.add(key);
                              }),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.7), color],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D3436),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactCard(Parcel parcel, Color routeColor) {
    final color = getStatusColor(parcel.Status ?? ParcelStatus.pending);
    final isPaid = parcel.Paid == true;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: routeColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parcel.Document_No ?? '-',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${parcel.Sender_Name ?? '-'} → ${parcel.Receiver_Name ?? '-'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 10,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _formatDateTime(
                          parcel.Time_Created ??
                              parcel.Date_Created ??
                              parcel.Date_sent,
                        ),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient:
                        isPaid
                            ? const LinearGradient(
                              colors: [Color(0xFF00B894), Color(0xFF00A381)],
                            )
                            : const LinearGradient(
                              colors: [Color(0xFFFF7675), Color(0xFFD63031)],
                            ),
                  ),
                  child: Text(
                    isPaid ? 'PAID' : 'DUE',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                if (parcel.Amount_Paid != null && parcel.Amount_Paid! > 0)
                  Text(
                    'KES ${parcel.Amount_Paid!.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd MMM HH:mm').format(dt);
  }
}

class _ExpandedGroup extends StatelessWidget {
  final String groupKey;
  final String locName;
  final String groupLabel;
  final List<Parcel> parcels;
  final Color color;
  final bool expanded;
  final VoidCallback onToggle;

  const _ExpandedGroup({
    required this.groupKey,
    required this.locName,
    required this.groupLabel,
    required this.parcels,
    required this.color,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // "Paid here" = paid at this location
    // From group: all paid parcels originated here → paid here
    // To group: paid by receiver (Who_to_Pay==Receiver) → paid here
    final paidHere =
        groupLabel == 'To'
            ? parcels.where(
              (p) => p.Paid == true && p.Who_to_Pay == WhoToPay.Receiver,
            )
            : parcels.where((p) => p.Paid == true);

    final paidAmount = parcels
        .where((p) => p.Paid == true)
        .fold<double>(0, (sum, p) => sum + (p.Amount_Paid ?? 0));
    final unpaidAmount = parcels
        .where((p) => p.Paid != true)
        .fold<double>(0, (sum, p) => sum + (p.Amount_Paid ?? 0));
    final cashAmount = paidHere
        .where((p) => p.paymentMethod == PaymentMethod.cash)
        .fold<double>(0, (sum, p) => sum + (p.Amount_Paid ?? 0));
    final mpesaAmount = paidHere
        .where((p) => p.paymentMethod == PaymentMethod.mpesa)
        .fold<double>(0, (sum, p) => sum + (p.Amount_Paid ?? 0));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header — always visible, tappable
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        size: 18,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$groupLabel $locName',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${parcels.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Summary row
                  Row(
                    children: [
                      _summaryChip('Total', parcels.length, color),
                      const SizedBox(width: 8),
                      _summaryChip(
                        'Paid',
                        '${paidAmount.toStringAsFixed(0)}',
                        Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _summaryChip(
                        'Unpaid',
                        '${unpaidAmount.toStringAsFixed(0)}',
                        Colors.red,
                      ),
                      const SizedBox(width: 8),
                      _summaryChip(
                        'Cash',
                        '${cashAmount.toStringAsFixed(0)}',
                        Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      _summaryChip(
                        'MPesa',
                        '${mpesaAmount.toStringAsFixed(0)}',
                        Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Collapsible parcel list
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                children:
                    parcels
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _CompactParcelCard(parcel: p, color: color),
                          ),
                        )
                        .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, dynamic value, Color chipColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: chipColor,
          ),
        ),
      ],
    );
  }
}

class _CompactParcelCard extends StatelessWidget {
  final Parcel parcel;
  final Color color;

  const _CompactParcelCard({required this.parcel, required this.color});

  @override
  Widget build(BuildContext context) {
    final statusColor = getStatusColor(parcel.Status ?? ParcelStatus.pending);
    final isPaid = parcel.Paid == true;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parcel.Document_No ?? '-',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${parcel.Sender_Name ?? '-'} → ${parcel.Receiver_Name ?? '-'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 10,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _fmt(
                          parcel.Time_Created ??
                              parcel.Date_Created ??
                              parcel.Date_sent,
                        ),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'KES ${parcel.Amount_Paid?.toStringAsFixed(0) ?? '0'}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isPaid
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? 'PAID' : 'DUE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color:
                          isPaid ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd MMM HH:mm').format(dt);
  }
}

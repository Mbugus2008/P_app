import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/parcel_controller.dart';
import '../database/database_helper.dart';
import '../dialogs/printer_selector_dialog.dart';
import '../models/parcel_model.dart';
import '../receipts/thermal_receipt_printer.dart';
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
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // DB-backed data (full table — not affected by in-memory 100-collected cap)
  List<Parcel> _dbFromLoc = <Parcel>[];
  List<Parcel> _dbToLoc = <Parcel>[];
  List<Parcel> _dbPaidToday = <Parcel>[];
  bool _loadingData = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Loads Sent/Received/PaidToday straight from SQLite with date filters.
  Future<void> _loadData() async {
    if (_loadingData) return;
    _loadingData = true;
    try {
      final candidates = <String>{
        _controller.currentLocation.trim(),
        _controller.currentLocationCode.trim(),
        _controller.currentLocationName.trim(),
      }.where((s) => s.isNotEmpty).toList();

      final from = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
      final to = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

      final results = await Future.wait([
        _dbHelper.getParcelsFromLocationsInRange(
          candidates,
          from: from,
          to: to,
        ),
        _dbHelper.getParcelsToLocationsInRange(candidates, from: from, to: to),
        _dbHelper.getParcelsPaidBetweenForLocation(
          candidates,
          from: from,
          to: to,
          sentBefore: from,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _dbFromLoc = results[0];
        _dbToLoc = results[1];
        _dbPaidToday = results[2];
      });
    } finally {
      _loadingData = false;
    }
  }

  @override
  void dispose() {
    _fromScrollCtrl.dispose();
    _toScrollCtrl.dispose();
    super.dispose();
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

  /// Groups parcels by Date_sent, sorted latest first.
  List<MapEntry<String, List<Parcel>>> _groupByDate(List<Parcel> parcels) {
    final map = <String, List<Parcel>>{};
    for (final p in parcels) {
      final d = p.Date_sent ?? p.Date_Created ?? DateTime.now();
      final key = DateFormat('dd MMM yyyy').format(d);
      map.putIfAbsent(key, () => <Parcel>[]).add(p);
    }
    final entries = map.entries.toList();
    entries.sort((a, b) => b.key.compareTo(a.key)); // latest first
    return entries;
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder:
          (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF667eea),
                onPrimary: Colors.white,
                surface: Colors.white,
              ),
            ),
            child: child!,
          ),
    );
    if (range != null) {
      setState(() {
        _fromDate = range.start;
        _toDate = range.end;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = _controller.currentLocation;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 72,
        title: _appBarDateChip(
          '${DateFormat('dd/MM/yy').format(_fromDate)} .. ${DateFormat('dd/MM/yy').format(_toDate)}',
          _pickDateRange,
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

          // DB-backed data, already date-filtered by the queries above
          final fromLoc = _dbFromLoc;
          final toLoc = _dbToLoc;

          final fromParcels = _applyChipFilters(
            fromLoc,
            status: _fromStatusFilter,
            paid: _fromPaidFilter,
            method: _fromPaymentFilter,
          );
          final toParcels = _applyChipFilters(
            toLoc,
            status: _toStatusFilter,
            paid: _toPaidFilter,
            method: _toPaymentFilter,
          );
          final fromGrouped = _groupByTo(fromParcels);
          final toDateGrouped = _groupByDate(toParcels);

          return RefreshIndicator(
            onRefresh: _loadData,
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 80),
                _buildTopSummary(
                  fromParcels,
                  toParcels,
                  location,
                  _dbPaidToday,
                ),
                const SizedBox(height: 6),
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
                    child: _buildDateHalf(
                      'Received at $location',
                      Icons.arrow_downward_rounded,
                      toDateGrouped,
                      const Color(0xFF4FACFE),
                      'No parcels received at $location',
                      _toScrollCtrl,
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

  Widget _buildTopSummary(
    List<Parcel> fromParcels,
    List<Parcel> toParcels,
    String location,
    List<Parcel> paidTodayList,
  ) {
    final dateStr =
        '${DateFormat('dd/MM/yy').format(_fromDate)} .. ${DateFormat('dd/MM/yy').format(_toDate)}';

    // --- Sent ---
    final sentTotal = fromParcels.length;
    final sentPaid = fromParcels.where((p) => p.Paid == true).length;

    final sentCash = fromParcels
        .where(
          (p) =>
              p.paymentMethod == PaymentMethod.cash &&
              p.Who_to_Pay == WhoToPay.Sender,
        )
        .fold<double>(0, (s, p) => s + (p.Amount_Paid ?? 0));
    final sentMpesa = fromParcels
        .where(
          (p) =>
              p.paymentMethod == PaymentMethod.mpesa &&
              p.Who_to_Pay == WhoToPay.Sender,
        )
        .fold<double>(0, (s, p) => s + (p.Amount_Paid ?? 0));

    // --- Received ---
    final recvTotal = toParcels.length;
    final recvPaid = toParcels.where((p) => p.Paid == true).length;
    final recvCash = toParcels
        .where(
          (p) =>
              p.paymentMethod == PaymentMethod.cash &&
              p.Who_to_Pay == WhoToPay.Receiver,
        )
        .fold<double>(0, (s, p) => s + (p.Amount_Paid ?? 0));
    final recvMpesa = toParcels
        .where(
          (p) =>
              p.paymentMethod == PaymentMethod.mpesa &&
              p.Who_to_Pay == WhoToPay.Receiver,
        )
        .fold<double>(0, (s, p) => s + (p.Amount_Paid ?? 0));

    // --- Paid Today ---
    // Sourced from DB query: To == location AND Who_to_Pay == Receiver AND
    // Payment_Date within the selected range AND sent before the selected day.
    final paidTodayAll = paidTodayList;
    final paidTodayPaidList =
        paidTodayAll.where((p) => p.Paid == true).toList();
    final paidTodayTotal = paidTodayAll.length;
    final paidTodayPaid = paidTodayPaidList.length;
    final paidTodayCash = paidTodayPaidList
        .where((p) => p.paymentMethod == PaymentMethod.cash)
        .fold<double>(0, (s, p) => s + (p.Amount_Paid ?? 0));
    final paidTodayMpesa = paidTodayPaidList
        .where((p) => p.paymentMethod == PaymentMethod.mpesa)
        .fold<double>(0, (s, p) => s + (p.Amount_Paid ?? 0));

    // --- Totals ---
    final totalCash = sentCash + recvCash + paidTodayCash;
    final totalMpesa = sentMpesa + recvMpesa + paidTodayMpesa;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.summarize_rounded,
                size: 20,
                color: Color(0xFF667eea),
              ),
              const SizedBox(width: 6),
              Text(
                'Summary — ',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D3436),
                ),
              ),
              Flexible(
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D3436),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap:
                    () => _printSummary(
                      location,
                      dateStr,
                      sentTotal,
                      sentPaid,
                      sentCash,
                      sentMpesa,
                      recvTotal,
                      recvPaid,
                      recvCash,
                      recvMpesa,
                      paidTodayTotal,
                      paidTodayPaid,
                      paidTodayCash,
                      paidTodayMpesa,
                      totalCash,
                      totalMpesa,
                    ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.print_rounded,
                    size: 18,
                    color: Color(0xFF667eea),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Table
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1.3),
              4: FlexColumnWidth(1.3),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Header row
              _tableHeaderRow(['', 'Total', 'Paid', 'Cash', 'M-Pesa']),
              // Sent
              _tableDataRow(
                'Sent',
                Icons.arrow_upward_rounded,
                const Color(0xFFFF7E5F),
                sentTotal,
                sentPaid,
                sentCash,
                sentMpesa,
              ),
              // Received
              _tableDataRow(
                'Received',
                Icons.arrow_downward_rounded,
                const Color(0xFF4FACFE),
                recvTotal,
                recvPaid,
                recvCash,
                recvMpesa,
              ),
              // Paid Today
              _tableDataRow(
                'Paid Today',
                Icons.payment_rounded,
                const Color(0xFF00B894),
                paidTodayTotal,
                paidTodayPaid,
                paidTodayCash,
                paidTodayMpesa,
              ),
              // TOTAL
              _tableTotalRow(totalCash, totalMpesa),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _printSummary(
    String location,
    String dateStr,
    int sentTotal,
    int sentPaid,
    double sentCash,
    double sentMpesa,
    int recvTotal,
    int recvPaid,
    double recvCash,
    double recvMpesa,
    int paidTodayTotal,
    int paidTodayPaid,
    double paidTodayCash,
    double paidTodayMpesa,
    double totalCash,
    double totalMpesa,
  ) async {
    final printer = ThermalReceiptPrinter();
    final connected = await printer.isConnected();

    if (!connected) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => const PrinterSelectorDialog(),
      );
      final reconnected = await printer.isConnected();
      if (!reconnected) return;
    }

    try {
      final totalAll = sentTotal + recvTotal + paidTodayTotal;
      final totalRevenue =
          sentCash +
          sentMpesa +
          recvCash +
          recvMpesa +
          paidTodayCash +
          paidTodayMpesa;
      final fmt = NumberFormat('#,##0');

      await printer.printReport(
        title: 'Location Summary — $location',
        dateRange: dateStr,
        columns: const ['', 'Total', 'Paid', 'Cash', 'M-Pesa'],
        rows: [
          [
            'Sent',
            sentTotal.toString(),
            sentPaid.toString(),
            fmt.format(sentCash),
            fmt.format(sentMpesa),
          ],
          [
            'Received',
            recvTotal.toString(),
            recvPaid.toString(),
            fmt.format(recvCash),
            fmt.format(recvMpesa),
          ],
          [
            'Paid Today',
            paidTodayTotal.toString(),
            paidTodayPaid.toString(),
            fmt.format(paidTodayCash),
            fmt.format(paidTodayMpesa),
          ],
          ['TOTAL', '', '', fmt.format(totalCash), fmt.format(totalMpesa)],
        ],
        totalCount: totalAll,
        totalAmount: totalRevenue,
        location: location,
        printedBy: _controller.loggedInUserLabel,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Print failed: $e')));
    }
  }

  TableRow _tableHeaderRow(List<String> headers) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      children:
          headers
              .map(
                (h) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    h,
                    textAlign: h.isEmpty ? TextAlign.left : TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }

  TableRow _tableDataRow(
    String label,
    IconData icon,
    Color color,
    int total,
    int paid,
    double cash,
    double mpesa,
  ) {
    final fmt = NumberFormat('#,##0');
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        _tableCell(total.toString(), Colors.black87),
        _tableCell(paid.toString(), const Color(0xFF00B894)),
        _tableCell(
          fmt.format(cash),
          const Color(0xFF636E72),
          align: TextAlign.right,
        ),
        _tableCell(
          fmt.format(mpesa),
          const Color(0xFF636E72),
          align: TextAlign.right,
        ),
      ],
    );
  }

  TableRow _tableTotalRow(double cash, double mpesa) {
    final fmt = NumberFormat('#,##0');
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
      ),
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'TOTAL',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(),
        const SizedBox(),
        _tableCell(
          fmt.format(cash),
          const Color(0xFF00B894),
          bold: true,
          align: TextAlign.right,
        ),
        _tableCell(
          fmt.format(mpesa),
          const Color(0xFF667eea),
          bold: true,
          align: TextAlign.right,
        ),
      ],
    );
  }

  Widget _tableCell(
    String text,
    Color color, {
    bool bold = false,
    TextAlign align = TextAlign.center,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _appBarDateChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        side: BorderSide.none,
        avatar: const Icon(
          Icons.date_range_rounded,
          size: 15,
          color: Colors.white,
        ),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildDateHalf(
    String title,
    IconData icon,
    List<MapEntry<String, List<Parcel>>> grouped,
    Color color,
    String emptyMsg,
    ScrollController scrollCtrl,
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
                      final entry = grouped[i];
                      final dateKey = entry.key;
                      final parcels = entry.value;
                      final paidCount =
                          parcels.where((p) => p.Paid == true).length;
                      final cashAmt = parcels
                          .where((p) => p.paymentMethod == PaymentMethod.cash)
                          .fold<double>(0, (s, p) => s + (p.Amount_Paid ?? 0));
                      final mpesaAmt = parcels
                          .where((p) => p.paymentMethod == PaymentMethod.mpesa)
                          .fold<double>(0, (s, p) => s + (p.Amount_Paid ?? 0));
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DateGroup(
                          groupKey: '$title|$dateKey',
                          date: dateKey,
                          parcels: parcels,
                          paidCount: paidCount,
                          cashAmount: cashAmt,
                          mpesaAmount: mpesaAmt,
                          color: color,
                          expanded: _expandedGroups.contains('$title|$dateKey'),
                          onToggle:
                              () => setState(() {
                                final key = '$title|$dateKey';
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

class _DateGroup extends StatelessWidget {
  final String groupKey;
  final String date;
  final List<Parcel> parcels;
  final int paidCount;
  final double cashAmount;
  final double mpesaAmount;
  final Color color;
  final bool expanded;
  final VoidCallback onToggle;

  const _DateGroup({
    required this.groupKey,
    required this.date,
    required this.parcels,
    required this.paidCount,
    required this.cashAmount,
    required this.mpesaAmount,
    required this.color,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final total = parcels.length;
    final unpaidCount = total - paidCount;

    return Container(
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
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(top: const Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        size: 20,
                        color: color,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          date,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$total',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _chip('Paid', paidCount, const Color(0xFF00B894)),
                      _chip('Unpaid', unpaidCount, const Color(0xFFE74A3B)),
                      _chip(
                        'Cash',
                        '${cashAmount.toStringAsFixed(0)}',
                        const Color(0xFFE17055),
                      ),
                      _chip(
                        'M-Pesa',
                        '${mpesaAmount.toStringAsFixed(0)}',
                        const Color(0xFF667eea),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
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

  Widget _chip(String label, dynamic value, Color chipColor) {
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

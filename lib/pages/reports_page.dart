import 'dart:io';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/parcel_controller.dart';
import '../database/database_helper.dart';
import '../dialogs/printer_selector_dialog.dart';
import '../pages/change_password_page.dart';
import '../receipts/thermal_receipt_printer.dart';
import '../utils/app_colors.dart';

enum ReportType {
  statusBreakdown,
  dailyVolume,
  revenue,
  routePerformance,
  driverWorkload,
  vehicleWorkload,
  paymentMethod,
  batchPerformance,
  activityLog,
  myCollections,
  myCollectedParcels,
}

extension ReportTypeLabel on ReportType {
  String get label {
    switch (this) {
      case ReportType.statusBreakdown:
        return 'Status Breakdown';
      case ReportType.dailyVolume:
        return 'Daily Volume';
      case ReportType.revenue:
        return 'Revenue';
      case ReportType.routePerformance:
        return 'Route Performance';
      case ReportType.driverWorkload:
        return 'Driver Workload';
      case ReportType.vehicleWorkload:
        return 'Vehicle Workload';
      case ReportType.paymentMethod:
        return 'Payment Method';
      case ReportType.batchPerformance:
        return 'Batch Performance';
      case ReportType.activityLog:
        return 'Activity Log';
      case ReportType.myCollections:
        return 'My Collections';
      case ReportType.myCollectedParcels:
        return 'My Parcels';
    }
  }

  IconData get icon {
    switch (this) {
      case ReportType.statusBreakdown:
        return Icons.pie_chart;
      case ReportType.dailyVolume:
        return Icons.calendar_today;
      case ReportType.revenue:
        return Icons.attach_money;
      case ReportType.routePerformance:
        return Icons.route;
      case ReportType.driverWorkload:
        return Icons.person;
      case ReportType.vehicleWorkload:
        return Icons.local_shipping;
      case ReportType.paymentMethod:
        return Icons.payment;
      case ReportType.batchPerformance:
        return Icons.inventory;
      case ReportType.activityLog:
        return Icons.history;
      case ReportType.myCollections:
        return Icons.account_balance_wallet;
      case ReportType.myCollectedParcels:
        return Icons.receipt_long;
    }
  }

  Color get color {
    switch (this) {
      case ReportType.statusBreakdown:
        return const Color(0xFF13678A);
      case ReportType.dailyVolume:
        return const Color(0xFFE67E22);
      case ReportType.revenue:
        return const Color(0xFF2E7D32);
      case ReportType.routePerformance:
        return const Color(0xFF5C6BC0);
      case ReportType.driverWorkload:
        return const Color(0xFF8E24AA);
      case ReportType.vehicleWorkload:
        return const Color(0xFF6D4C41);
      case ReportType.paymentMethod:
        return const Color(0xFF00897B);
      case ReportType.batchPerformance:
        return const Color(0xFF546E7A);
      case ReportType.activityLog:
        return const Color(0xFF757575);
      case ReportType.myCollections:
        return const Color(0xFFC62828);
      case ReportType.myCollectedParcels:
        return const Color(0xFF1565C0);
    }
  }
}

class ReportsPage extends StatefulWidget {
  final ReportType? initialReport;

  const ReportsPage({super.key, this.initialReport});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final DateFormat _displayFormat = DateFormat('dd MMM yyyy');
  final DateFormat _csvDateFormat = DateFormat('yyyy-MM-dd');
  final ThermalReceiptPrinter _thermalPrinter = ThermalReceiptPrinter();

  late ReportType _selectedReport;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isLoading = false;
  bool _isExporting = false;
  bool _isBluetoothPrinting = false;
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _collectedDetail = [];
  List<Map<String, dynamic>> _collectedSummary = [];
  List<Map<String, dynamic>> _collectedFromOthers = [];
  String? _error;
  String _deviceId = ''; // empty = show all parcels regardless of device

  @override
  void initState() {
    super.initState();
    _selectedReport = widget.initialReport ?? ReportType.myCollectedParcels;
    final today = DateTime.now();
    _dateFrom = DateTime(today.year, today.month, today.day);
    _dateTo = DateTime(today.year, today.month, today.day, 23, 59, 59);
    // Collected Parcels shows all-time by default
    if (_selectedReport == ReportType.myCollectedParcels) {
      _dateFrom = null;
      _dateTo = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDeviceAndLoad());
  }

  Future<void> _initDeviceAndLoad() async {
    // Reports show all parcels regardless of creating device
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<Map<String, dynamic>> results;
      _collectedDetail = [];
      _collectedSummary = [];
      _collectedFromOthers = [];
      switch (_selectedReport) {
        case ReportType.statusBreakdown:
          results = await _dbHelper.getStatusBreakdown(
            from: _dateFrom,
            to: _dateTo,
            deviceId: _deviceId,
          );
        case ReportType.dailyVolume:
          results = await _dbHelper.getDailyVolume(
            from: _dateFrom,
            to: _dateTo,
            deviceId: _deviceId,
          );
        case ReportType.revenue:
          results = await _dbHelper.getRevenueBreakdown(
            from: _dateFrom,
            to: _dateTo,
            deviceId: _deviceId,
          );
        case ReportType.routePerformance:
          results = await _dbHelper.getRoutePerformance(
            from: _dateFrom,
            to: _dateTo,
            deviceId: _deviceId,
          );
        case ReportType.driverWorkload:
          results = await _dbHelper.getDriverWorkload(
            from: _dateFrom,
            to: _dateTo,
            deviceId: _deviceId,
          );
        case ReportType.vehicleWorkload:
          results = await _dbHelper.getVehicleWorkload(
            from: _dateFrom,
            to: _dateTo,
            deviceId: _deviceId,
          );
        case ReportType.paymentMethod:
          results = await _dbHelper.getPaymentMethodBreakdown(
            from: _dateFrom,
            to: _dateTo,
            deviceId: _deviceId,
          );
        case ReportType.batchPerformance:
          results = await _dbHelper.getBatchPerformance(
            from: _dateFrom,
            to: _dateTo,
            deviceId: _deviceId,
          );
        case ReportType.activityLog:
          results = await _dbHelper.getActivityLog(
            from: _dateFrom,
            to: _dateTo,
            deviceId: _deviceId,
          );
        case ReportType.myCollections:
          final controller = Get.find<ParcelController>();
          final agentCode = controller.loggedInUser?.agentCode ?? '';
          results = await _dbHelper.getMyCollections(
            from: _dateFrom,
            to: _dateTo,
            deviceId: _deviceId,
            agentCode: agentCode,
          );
        case ReportType.myCollectedParcels:
          final controller = Get.find<ParcelController>();
          final agentCode = controller.loggedInUser?.agentCode ?? '';
          final locations =
              <String>[
                controller.currentLocation,
                controller.currentLocationCode,
                controller.currentLocationName,
              ].where((l) => l.trim().isNotEmpty).toList();
          final data = await _dbHelper.getMyCollectedParcels(
            from: _dateFrom,
            to: _dateTo,
            agentCode: agentCode,
            locations: locations,
          );
          _collectedDetail = List<Map<String, dynamic>>.from(
            data['detail'] as List,
          );
          _collectedSummary = List<Map<String, dynamic>>.from(
            data['myCreated'] as List,
          );
          _collectedFromOthers = List<Map<String, dynamic>>.from(
            data['fromOthers'] as List,
          );
          results = _collectedDetail; // for export compatibility
      }

      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: _dateFrom ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _dateTo ?? DateTime.now(),
      ),
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: AppColors.surface,
                onSurface: AppColors.onSurface,
              ),
            ),
            child: child!,
          ),
    );

    if (range != null) {
      setState(() {
        _dateFrom = range.start;
        _dateTo = range.end;
      });
      _loadReport();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
    _loadReport();
  }

  Future<void> _printToBluetooth() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMac = prefs.getString('printer_mac');

    if (savedMac == null || savedMac.isEmpty) {
      if (!mounted) return;
      await showDialog<bool>(
        context: context,
        builder:
            (ctx) => PrinterSelectorDialog(
              onPrint: () async {
                await _doBluetoothPrint();
              },
            ),
      );
      return;
    }

    setState(() {
      _isBluetoothPrinting = true;
    });

    try {
      final device = BluetoothDevice('Saved Printer', savedMac);
      final connected = await _thermalPrinter.connect(device);
      if (!connected) {
        if (mounted) {
          setState(() => _isBluetoothPrinting = false);
          await showDialog<bool>(
            context: context,
            builder:
                (ctx) => PrinterSelectorDialog(
                  onPrint: () async {
                    await _doBluetoothPrint();
                  },
                ),
          );
        }
        return;
      }

      await _doBluetoothPrint();
    } catch (e) {
      if (mounted) {
        setState(() => _isBluetoothPrinting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bluetooth print failed: $e')));
      }
    }
  }

  Future<void> _doBluetoothPrint() async {
    final columns = _getColumns();
    final rows = _getTableRows();
    final totalCount = _totalCount();
    final totalAmount = _totalAmount();
    final controller = Get.find<ParcelController>();
    final user = controller.loggedInUser;
    final location =
        (user?.location?.trim().isNotEmpty == true)
            ? user!.location!.trim()
            : controller.currentLocation.trim();
    final printedBy =
        (user?.name?.trim().isNotEmpty == true)
            ? user!.name!.trim()
            : user?.agentCode.trim();

    await _thermalPrinter.printReport(
      title: _selectedReport.label,
      dateRange: _dateRangeLabel(),
      columns: columns,
      rows: rows,
      totalCount: _selectedReport != ReportType.activityLog ? totalCount : null,
      totalAmount:
          _selectedReport != ReportType.activityLog ? totalAmount : null,
      location: location.isNotEmpty ? location : null,
      printedBy: printedBy?.isNotEmpty == true ? printedBy : null,
    );

    if (mounted) {
      setState(() => _isBluetoothPrinting = false);
    }
  }

  int _totalCount() {
    return _results.fold<int>(
      0,
      (sum, r) => sum + ((r['count'] ?? 0) as num).toInt(),
    );
  }

  double _totalAmount() {
    return _results.fold<double>(
      0,
      (sum, r) => sum + ((r['total_amount'] ?? 0) as num).toDouble(),
    );
  }

  // ---- Export helpers ----

  List<String> _getColumns() {
    switch (_selectedReport) {
      case ReportType.statusBreakdown:
        return ['Status', 'Count', 'Amount (KES)'];
      case ReportType.dailyVolume:
        return ['Date', 'Count', 'Amount (KES)'];
      case ReportType.revenue:
        return ['Date', 'Count', 'Total (KES)', 'Paid (KES)', 'Unpaid (KES)'];
      case ReportType.routePerformance:
        return ['From', 'To', 'Count', 'Amount (KES)'];
      case ReportType.driverWorkload:
        return ['Driver', 'Count', 'Amount (KES)'];
      case ReportType.vehicleWorkload:
        return ['Vehicle', 'Count', 'Amount (KES)'];
      case ReportType.paymentMethod:
        return ['Method', 'Count', 'Amount (KES)', 'Paid', 'Unpaid'];
      case ReportType.batchPerformance:
        return ['Status', 'Batches', 'Parcels', 'Amount (KES)'];
      case ReportType.activityLog:
        return [
          'Document',
          'Date',
          'Status',
          'Sender',
          'Receiver',
          'Route',
          'Amount (KES)',
        ];
      case ReportType.myCollections:
        return ['Method', 'Count', 'Amount (KES)', 'Paid', 'Unpaid'];
      case ReportType.myCollectedParcels:
        return [
          'From',
          'Doc No',
          'Sender',
          'Receiver',
          'Amount',
          'Payment',
          'Status',
        ];
    }
  }

  List<List<String>> _getTableRows() {
    switch (_selectedReport) {
      case ReportType.statusBreakdown:
        return _results
            .map(
              (r) => [
                _formatStatus(r['Status']?.toString()),
                '${r['count'] ?? 0}',
                _formatCurrency(r['total_amount']),
              ],
            )
            .toList();
      case ReportType.dailyVolume:
        return _results
            .map(
              (r) => [
                _formatDateLabel(r['date']),
                '${r['count'] ?? 0}',
                _formatCurrency(r['total_amount']),
              ],
            )
            .toList();
      case ReportType.revenue:
        return _results
            .map(
              (r) => [
                _formatDateLabel(r['date']),
                '${r['count'] ?? 0}',
                _formatCurrency(r['total_amount']),
                _formatCurrency(r['paid_amount']),
                _formatCurrency(r['unpaid_amount']),
              ],
            )
            .toList();
      case ReportType.routePerformance:
        return _results
            .map(
              (r) => [
                r['source']?.toString() ?? '-',
                r['destination']?.toString() ?? '-',
                '${r['count'] ?? 0}',
                _formatCurrency(r['total_amount']),
              ],
            )
            .toList();
      case ReportType.driverWorkload:
        return _results
            .map(
              (r) => [
                r['Driver']?.toString() ?? '-',
                '${r['count'] ?? 0}',
                _formatCurrency(r['total_amount']),
              ],
            )
            .toList();
      case ReportType.vehicleWorkload:
        return _results
            .map(
              (r) => [
                r['Vehicle']?.toString() ?? '-',
                '${r['count'] ?? 0}',
                _formatCurrency(r['total_amount']),
              ],
            )
            .toList();
      case ReportType.paymentMethod:
        return _results
            .map(
              (r) => [
                r['method']?.toString() ?? 'Pending',
                '${r['count'] ?? 0}',
                _formatCurrency(r['total_amount']),
                '${r['paid_count'] ?? 0}',
                '${r['unpaid_count'] ?? 0}',
              ],
            )
            .toList();
      case ReportType.batchPerformance:
        return _results
            .map(
              (r) => [
                _formatStatus(r['Status']?.toString()),
                '${r['count'] ?? 0}',
                '${r['total_parcels'] ?? 0}',
                _formatCurrency(r['total_amount']),
              ],
            )
            .toList();
      case ReportType.activityLog:
        return _results
            .map(
              (r) => [
                r['Document_No']?.toString() ?? '-',
                _formatDateLabel(r['Date_sent']),
                _formatStatus(r['Status']?.toString()),
                r['Sender_Name']?.toString() ?? '-',
                r['Receiver_Name']?.toString() ?? '-',
                '${r['From_Location'] ?? '?'} \u2192 ${r['To_Location'] ?? '?'}',
                _formatCurrency(r['Amount_Paid']),
              ],
            )
            .toList();
      case ReportType.myCollections:
        return _results
            .map(
              (r) => [
                r['method']?.toString() ?? 'Pending',
                '${r['count'] ?? 0}',
                _formatCurrency(r['total_amount']),
                '${r['paid_count'] ?? 0}',
                '${r['unpaid_count'] ?? 0}',
              ],
            )
            .toList();
      case ReportType.myCollectedParcels:
        return _collectedDetail
            .map(
              (r) => [
                r['from']?.toString() ?? '-',
                r['docNo']?.toString() ?? '-',
                r['sender']?.toString() ?? '-',
                r['receiver']?.toString() ?? '-',
                _formatCurrency(r['amount']),
                r['method']?.toString() ?? '-',
                '${r['status']?.toString() ?? '-'} (${r['origin'] ?? '-'})',
              ],
            )
            .toList();
    }
  }

  String _dateRangeLabel() {
    if (_dateFrom == null && _dateTo == null) return 'All Time';
    if (_dateFrom != null && _dateTo != null) {
      return '${_csvDateFormat.format(_dateFrom!)} to ${_csvDateFormat.format(_dateTo!)}';
    }
    if (_dateFrom != null) return 'From ${_csvDateFormat.format(_dateFrom!)}';
    return 'Until ${_csvDateFormat.format(_dateTo!)}';
  }

  // ---- PDF Export ----

  Future<void> _printPdf() async {
    setState(() => _isExporting = true);
    try {
      final doc = await _buildPdf();
      await Printing.layoutPdf(
        onLayout: (format) => doc.save(),
        name: '${_selectedReport.label} - ${_dateRangeLabel()}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Print failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _isExporting = true);
    try {
      final doc = await _buildPdf();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/report_${_selectedReport.name}.pdf');
      await file.writeAsBytes(await doc.save());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${_selectedReport.label} - ${_dateRangeLabel()}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<pw.Document> _buildPdf() async {
    final doc = pw.Document();
    final columns = _getColumns();
    final rows = _getTableRows();
    final totalCount = _totalCount();
    final totalAmount = _totalAmount();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build:
            (context) => [
              pw.Header(
                level: 0,
                child: pw.Text(
                  _selectedReport.label,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#13678A'),
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _dateRangeLabel(),
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: ${_csvDateFormat.format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey500,
                ),
              ),
              pw.SizedBox(height: 12),
              if (_selectedReport != ReportType.activityLog)
                pw.Row(
                  children: [
                    _pdfSummaryBox(
                      'Total Parcels',
                      totalCount.toString(),
                      PdfColor.fromHex('#13678A'),
                    ),
                    pw.SizedBox(width: 12),
                    _pdfSummaryBox(
                      'Total Revenue',
                      'KES ${_formatCurrency(totalAmount)}',
                      PdfColor.fromHex('#2E7D32'),
                    ),
                  ],
                ),
              if (_selectedReport != ReportType.activityLog)
                pw.SizedBox(height: 16),
              if (_selectedReport == ReportType.myCollectedParcels)
                _buildPdfSummarySection(context),
              _buildPdfTable(columns, rows),
            ],
        footer:
            (context) => pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey500,
                ),
              ),
            ),
      ),
    );
    return doc;
  }

  pw.Widget _pdfSummaryBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPdfSummarySection(pw.Context context) {
    final items = <pw.Widget>[];
    items.add(
      pw.Text(
        'Summary',
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#1565C0'),
        ),
      ),
    );
    items.add(pw.SizedBox(height: 6));

    void addGroup(String title, List<Map<String, dynamic>> data) {
      items.add(
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#666666'),
          ),
        ),
      );
      if (data.isEmpty) {
        items.add(
          pw.Text(
            'No data',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromHex('#999999'),
            ),
          ),
        );
      } else {
        for (final s in data) {
          final method = s['method']?.toString() ?? 'Pending';
          final count = s['count']?.toString() ?? '0';
          final total = _formatCurrency(s['total']);
          items.add(
            pw.Text(
              '  $method — $count parcels — KES $total',
              style: const pw.TextStyle(fontSize: 10),
            ),
          );
        }
      }
      items.add(pw.SizedBox(height: 4));
    }

    addGroup('My Parcels', _collectedSummary);
    addGroup('Received Parcels', _collectedFromOthers);
    items.add(pw.SizedBox(height: 8));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items,
    );
  }

  pw.Widget _buildPdfTable(List<String> columns, List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#13678A')),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F4F6FB')),
      headers: columns,
      data: rows,
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
    );
  }

  // ---- CSV Export ----

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    try {
      final columns = _getColumns();
      final rows = _getTableRows();

      final buf = StringBuffer();
      if (_selectedReport == ReportType.myCollectedParcels) {
        buf.writeln('Summary');
        void addCsvGroup(String title, List<Map<String, dynamic>> data) {
          for (final s in data) {
            buf.writeln(
              '$title,${s['method']},${s['count']} parcels,KES ${_formatCurrency(s['total'])}',
            );
          }
          if (data.isEmpty) buf.writeln('$title,No data');
        }

        addCsvGroup('My Parcels', _collectedSummary);
        addCsvGroup('Received Parcels', _collectedFromOthers);
        buf.writeln('');
      }
      buf.writeln(columns.map(_csvEscape).join(','));
      for (final row in rows) {
        buf.writeln(row.map(_csvEscape).join(','));
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/report_${_selectedReport.name}.csv');
      await file.writeAsString(buf.toString());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${_selectedReport.label} - ${_dateRangeLabel()}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _csvEscape(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final totalCount = _totalCount();
    final totalAmount = _totalAmount();

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Reports'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        actions: [
          if (_results.isNotEmpty && !_isLoading) ...[
            if (_isExporting)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.print),
                tooltip: 'Print PDF',
                onPressed: _printPdf,
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share PDF',
                onPressed: _sharePdf,
              ),
              IconButton(
                icon: const Icon(Icons.table_chart_outlined),
                tooltip: 'Export CSV',
                onPressed: _exportCsv,
              ),
              IconButton(
                icon:
                    _isBluetoothPrinting
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.bluetooth),
                tooltip: 'Print via Bluetooth',
                onPressed: _isBluetoothPrinting ? null : _printToBluetooth,
              ),
            ],
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                if (value == 'pdf') _printPdf();
                if (value == 'share_pdf') _sharePdf();
                if (value == 'csv') _exportCsv();
                if (value == 'bluetooth') _printToBluetooth();
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'pdf',
                      child: ListTile(
                        leading: Icon(Icons.print),
                        title: Text('Print PDF'),
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share_pdf',
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf),
                        title: Text('Share PDF'),
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'csv',
                      child: ListTile(
                        leading: Icon(Icons.table_chart_outlined),
                        title: Text('Export CSV'),
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'bluetooth',
                      child: ListTile(
                        leading: Icon(Icons.bluetooth),
                        title: Text('Bluetooth Print'),
                        dense: true,
                      ),
                    ),
                  ],
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadReport,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.secondary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.assessment, size: 32, color: Colors.white70),
                  const SizedBox(height: 8),
                  Text(
                    _selectedReport.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            ...ReportType.values.map((type) {
              final isSelected = _selectedReport == type;
              return ListTile(
                leading: Icon(type.icon, size: 20, color: type.color),
                title: Text(
                  type.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color:
                        isSelected ? AppColors.secondary : AppColors.onSurface,
                  ),
                ),
                selected: isSelected,
                selectedTileColor: AppColors.secondary.withAlpha(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () {
                  if (_selectedReport != type) {
                    setState(() => _selectedReport = type);
                    Navigator.of(context).pop();
                    _loadReport();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              );
            }),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change Password'),
              onTap: () {
                Navigator.of(context).pop();
                Get.to(() => const ChangePasswordPage());
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildDateFilter(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_results.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No data for the selected period',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  if (_selectedReport != ReportType.activityLog)
                    _buildSummaryCards(totalCount, totalAmount),
                  if (_selectedReport == ReportType.myCollectedParcels)
                    _buildCollectedSummary(),
                  Expanded(child: _buildResultsTable()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    final hasFilter = _dateFrom != null || _dateTo != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Row(
        children: [
          Icon(Icons.date_range, size: 18, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _pickDateRange,
              child: Text(
                hasFilter
                    ? '${_displayFormat.format(_dateFrom!)} - ${_displayFormat.format(_dateTo!)}'
                    : 'All Time',
                style: TextStyle(
                  fontSize: 13,
                  color: hasFilter ? AppColors.onSurface : Colors.grey,
                  fontWeight: hasFilter ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ),
          if (hasFilter)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Clear date filter',
              onPressed: _clearDateFilter,
            ),
          const SizedBox(width: 4),
          TextButton.icon(
            icon: const Icon(Icons.edit_calendar, size: 16),
            label: const Text('Filter', style: TextStyle(fontSize: 12)),
            onPressed: _pickDateRange,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(int totalCount, double totalAmount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              title: 'Total Parcels',
              value: totalCount.toString(),
              icon: Icons.inventory_2,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              title: 'Total Revenue',
              value: 'KES ${NumberFormat('#,##0.00').format(totalAmount)}',
              icon: Icons.attach_money,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectedSummary() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          _summarySection(theme, 'My Parcels', _collectedSummary),
          if (_collectedFromOthers.isNotEmpty) ...[
            const SizedBox(height: 8),
            _summarySection(theme, 'Received Parcels', _collectedFromOthers),
          ],
        ],
      ),
    );
  }

  Widget _summarySection(
    ThemeData theme,
    String title,
    List<Map<String, dynamic>> data,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize, size: 18, color: AppColors.secondary),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (data.isEmpty)
            Text(
              'No data',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            )
          else
            ...data.map((s) {
              final method = (s['method']?.toString() ?? 'Pending');
              final count = s['count'] as int? ?? 0;
              final total = (s['total'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            method == 'M-Pesa'
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        method,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              method == 'M-Pesa' ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text('$count parcels', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 12),
                    Text(
                      'KES ${total.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildResultsTable() {
    final columns = _getColumns();
    final rows = _getTableRows();

    return _buildDataTable(columns: columns, rows: rows);
  }

  Widget _buildDataTable({
    required List<String> columns,
    required List<List<String>> rows,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            AppColors.secondary.withAlpha(25),
          ),
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.secondary,
          ),
          dataTextStyle: const TextStyle(fontSize: 12),
          columnSpacing: 16,
          horizontalMargin: 12,
          columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
          rows:
              rows.map((row) {
                return DataRow(
                  cells: row.map((cell) => DataCell(Text(cell))).toList(),
                );
              }).toList(),
        ),
      ),
    );
  }

  String _formatStatus(String? status) {
    if (status == null || status.isEmpty) return 'Unknown';
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'intransit':
        return 'In Transit';
      case 'received':
        return 'Received';
      case 'collected':
        return 'Collected';
      case 'cash':
        return 'Cash';
      case 'mpesa':
      case 'm-pesa':
        return 'M-Pesa';
      default:
        return status;
    }
  }

  String _formatCurrency(dynamic value) {
    final amount = (value ?? 0) is num ? (value as num).toDouble() : 0.0;
    return NumberFormat('#,##0.00').format(amount);
  }

  String _formatDateLabel(dynamic value) {
    if (value == null) return '-';
    final str = value.toString();
    final date = DateTime.tryParse(str);
    if (date != null) return _displayFormat.format(date);
    if (str.length >= 10) return str.substring(0, 10);
    return str;
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

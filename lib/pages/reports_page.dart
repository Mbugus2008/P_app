import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../utilities/device_id.dart';
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
    }
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final DateFormat _displayFormat = DateFormat('dd MMM yyyy');
  final DateFormat _csvDateFormat = DateFormat('yyyy-MM-dd');

  ReportType _selectedReport = ReportType.statusBreakdown;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isLoading = false;
  bool _isExporting = false;
  List<Map<String, dynamic>> _results = [];
  String? _error;
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _dateFrom = DateTime.now().subtract(const Duration(days: 30));
    _dateTo = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDeviceAndLoad());
  }

  Future<void> _initDeviceAndLoad() async {
    _deviceId = await DeviceIdHelper.instance.getDeviceId();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<Map<String, dynamic>> results;
      switch (_selectedReport) {
        case ReportType.statusBreakdown:
          results = await _dbHelper.getStatusBreakdown(from: _dateFrom, to: _dateTo, deviceId: _deviceId);
        case ReportType.dailyVolume:
          results = await _dbHelper.getDailyVolume(from: _dateFrom, to: _dateTo, deviceId: _deviceId);
        case ReportType.revenue:
          results = await _dbHelper.getRevenueBreakdown(from: _dateFrom, to: _dateTo, deviceId: _deviceId);
        case ReportType.routePerformance:
          results = await _dbHelper.getRoutePerformance(from: _dateFrom, to: _dateTo, deviceId: _deviceId);
        case ReportType.driverWorkload:
          results = await _dbHelper.getDriverWorkload(from: _dateFrom, to: _dateTo, deviceId: _deviceId);
        case ReportType.vehicleWorkload:
          results = await _dbHelper.getVehicleWorkload(from: _dateFrom, to: _dateTo, deviceId: _deviceId);
        case ReportType.paymentMethod:
          results = await _dbHelper.getPaymentMethodBreakdown(from: _dateFrom, to: _dateTo, deviceId: _deviceId);
        case ReportType.batchPerformance:
          results = await _dbHelper.getBatchPerformance(from: _dateFrom, to: _dateTo, deviceId: _deviceId);
        case ReportType.activityLog:
          results = await _dbHelper.getActivityLog(from: _dateFrom, to: _dateTo, deviceId: _deviceId);
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
      builder: (context, child) => Theme(
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

  IconData _iconForReport(ReportType type) {
    switch (type) {
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
        return ['Document', 'Date', 'Status', 'Sender', 'Receiver', 'Route', 'Amount (KES)'];
    }
  }

  List<List<String>> _getTableRows() {
    switch (_selectedReport) {
      case ReportType.statusBreakdown:
        return _results.map((r) => [
          _formatStatus(r['Status']?.toString()),
          '${r['count'] ?? 0}',
          _formatCurrency(r['total_amount']),
        ]).toList();
      case ReportType.dailyVolume:
        return _results.map((r) => [
          _formatDateLabel(r['date']),
          '${r['count'] ?? 0}',
          _formatCurrency(r['total_amount']),
        ]).toList();
      case ReportType.revenue:
        return _results.map((r) => [
          _formatDateLabel(r['date']),
          '${r['count'] ?? 0}',
          _formatCurrency(r['total_amount']),
          _formatCurrency(r['paid_amount']),
          _formatCurrency(r['unpaid_amount']),
        ]).toList();
      case ReportType.routePerformance:
        return _results.map((r) => [
          r['source']?.toString() ?? '-',
          r['destination']?.toString() ?? '-',
          '${r['count'] ?? 0}',
          _formatCurrency(r['total_amount']),
        ]).toList();
      case ReportType.driverWorkload:
        return _results.map((r) => [
          r['Driver']?.toString() ?? '-',
          '${r['count'] ?? 0}',
          _formatCurrency(r['total_amount']),
        ]).toList();
      case ReportType.vehicleWorkload:
        return _results.map((r) => [
          r['Vehicle']?.toString() ?? '-',
          '${r['count'] ?? 0}',
          _formatCurrency(r['total_amount']),
        ]).toList();
      case ReportType.paymentMethod:
        return _results.map((r) => [
          r['method']?.toString() ?? 'Pending',
          '${r['count'] ?? 0}',
          _formatCurrency(r['total_amount']),
          '${r['paid_count'] ?? 0}',
          '${r['unpaid_count'] ?? 0}',
        ]).toList();
      case ReportType.batchPerformance:
        return _results.map((r) => [
          _formatStatus(r['Status']?.toString()),
          '${r['count'] ?? 0}',
          '${r['total_parcels'] ?? 0}',
          _formatCurrency(r['total_amount']),
        ]).toList();
      case ReportType.activityLog:
        return _results.map((r) => [
          r['Document_No']?.toString() ?? '-',
          _formatDateLabel(r['Date_sent']),
          _formatStatus(r['Status']?.toString()),
          r['Sender_Name']?.toString() ?? '-',
          r['Receiver_Name']?.toString() ?? '-',
          '${r['From_Location'] ?? '?'} \u2192 ${r['To_Location'] ?? '?'}',
          _formatCurrency(r['Amount_Paid']),
        ]).toList();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
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
        build: (context) => [
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
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated: ${_csvDateFormat.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
          pw.SizedBox(height: 12),
          if (_selectedReport != ReportType.activityLog)
            pw.Row(
              children: [
                _pdfSummaryBox('Total Parcels', totalCount.toString(), PdfColor.fromHex('#13678A')),
                pw.SizedBox(width: 12),
                _pdfSummaryBox('Total Revenue', 'KES ${_formatCurrency(totalAmount)}', PdfColor.fromHex('#2E7D32')),
              ],
            ),
          if (_selectedReport != ReportType.activityLog) pw.SizedBox(height: 16),
          _buildPdfTable(columns, rows),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
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
            pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
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
    final theme = Theme.of(context);
    final totalCount = _totalCount();
    final totalAmount = _totalAmount();

    return Scaffold(
      appBar: AppBar(
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
            ],
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                if (value == 'pdf') _printPdf();
                if (value == 'share_pdf') _sharePdf();
                if (value == 'csv') _exportCsv();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.print), title: Text('Print PDF'), dense: true)),
                const PopupMenuItem(value: 'share_pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf), title: Text('Share PDF'), dense: true)),
                const PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.table_chart_outlined), title: Text('Export CSV'), dense: true)),
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
      body: Row(
        children: [
          _buildSidebar(theme),
          Expanded(
            child: Column(
              children: [
                _buildDateFilter(theme),
                if (_isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
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
                          Text('No data for the selected period', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      children: [
                        if (_selectedReport != ReportType.activityLog)
                          _buildSummaryCards(theme, totalCount, totalAmount),
                        Expanded(child: _buildResultsTable(theme)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ThemeData theme) {
    final isWide = MediaQuery.of(context).size.width >= 400;

    return Container(
      width: isWide ? 170 : 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: isWide ? 12 : 8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withAlpha(15),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: isWide
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reports',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'This device',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  )
                : const Icon(Icons.assessment, size: 22, color: AppColors.secondary),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: ReportType.values.map((type) {
                final isSelected = _selectedReport == type;
                return Material(
                  color: isSelected ? AppColors.secondary.withAlpha(20) : Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (_selectedReport != type) {
                        setState(() => _selectedReport = type);
                        _loadReport();
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: isWide ? 12 : 0,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: isSelected ? AppColors.secondary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: isWide
                          ? Row(
                              children: [
                                Icon(
                                  _iconForReport(type),
                                  size: 18,
                                  color: isSelected ? AppColors.secondary : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    type.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      color: isSelected ? AppColors.secondary : AppColors.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Tooltip(
                              message: type.label,
                              child: Icon(
                                _iconForReport(type),
                                size: 22,
                                color: isSelected ? AppColors.secondary : Colors.grey.shade500,
                              ),
                            ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter(ThemeData theme) {
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

  Widget _buildSummaryCards(ThemeData theme, int totalCount, double totalAmount) {
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

  Widget _buildResultsTable(ThemeData theme) {
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
          headingRowColor: WidgetStateProperty.all(AppColors.secondary.withAlpha(25)),
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.secondary,
          ),
          dataTextStyle: const TextStyle(fontSize: 12),
          columnSpacing: 16,
          horizontalMargin: 12,
          columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
          rows: rows.map((row) {
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

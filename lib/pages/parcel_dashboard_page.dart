import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../controllers/parcel_controller.dart';
import '../database/database_helper.dart';
import '../dialogs/print_receipt_dialog.dart';
import '../models/app_vehicle.dart';
import '../models/batches.dart';
import '../models/parcel_model.dart';
import '../pages/add_user_page.dart';
import '../pages/addeditparcel.dart';
import '../pages/login.dart';
import '../pages/reports_page.dart';
import '../pages/settings_page.dart';
import '../utilities/app_update_service.dart';
import '../utilities/remember_me_helper.dart';
import '../utilities/status_color.dart';
import '../utils/app_colors.dart';

class ParcelDashboardPage extends StatefulWidget {
  const ParcelDashboardPage({super.key});

  @override
  State<ParcelDashboardPage> createState() => _ParcelDashboardPageState();
}

class _ParcelDashboardPageState extends State<ParcelDashboardPage> {
  bool _isSummaryExpanded = true;
  final _sectionExpanded = ''.obs;
  final _batchExpanded = ''.obs;
  final _searchQuery = ''.obs;
  String _appVersion = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  final DatabaseHelper _dbHelper = DatabaseHelper();

  late final AppUpdateService _updateService;

  @override
  void initState() {
    super.initState();
    _updateService = Get.find<AppUpdateService>();
    _loadAppVersion();

    // Listen for when the download finishes — auto-install silently
    _updateService.updateReady.listen((ready) {
      if (ready && mounted) {
        _autoInstallUpdate();
      }
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      // Ignore errors; drawer will simply hide version text.
    }
  }

  /// Auto-install silently — no "Ready" dialog, goes direct to system prompt
  Future<void> _autoInstallUpdate() async {
    final version = _updateService.pendingVersion;
    if (version == null || !mounted) return;

    // Brief delay so user sees the download complete indicator
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final ok = await _updateService.installSilent();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Update ready — tap to install'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Install',
            onPressed: () => _retryInstall(),
          ),
        ),
      );
    }
  }

  void _retryInstall() {
    _updateService.installSilent();
  }

  GlobalKey _getKey(String id) {
    return _sectionKeys.putIfAbsent(id, () => GlobalKey());
  }

  void _toggleSection(String id) {
    final wasExpanded = _sectionExpanded.value == id;
    _sectionExpanded.value = wasExpanded ? '' : id;
    if (!wasExpanded && id.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _sectionKeys[id];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.05,
          );
        }
      });
    }
  }

  void _toggleBatch(String id) {
    final wasExpanded = _batchExpanded.value == id;
    _batchExpanded.value = wasExpanded ? '' : id;
  }

  ParcelController get _controller => Get.find<ParcelController>();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await RememberMeHelper.clearRememberedUser();
    _controller.clearLoggedInUser();
    Get.offAll(() => const LoginScreen());
  }

  Future<void> _refreshDashboard() async {
    await _controller.loadParcels();
    await _controller.loadPendingBatches();
    await _controller.loadInTransitBatches();
    await _controller.loadReceivedParcels();
  }

  Future<void> _showDispatchDialog(BuildContext context, Batches batch) async {
    List<AppVehicle> vehicles = await _dbHelper.getAllVehicles();
    if (vehicles.isEmpty) {
      await _controller.syncVehiclesOnStartup();
      vehicles = await _dbHelper.getAllVehicles();
    }

    final vehiclesWithNumber =
        vehicles
            .where((v) => v.vehicleNumber?.trim().isNotEmpty == true)
            .toList();

    final result = await showDialog<_DispatchDialogResult>(
      context: context,
      builder:
          (ctx) => _DispatchDialog(
            batch: batch,
            vehiclesWithNumber: vehiclesWithNumber,
          ),
    );

    if (result != null) {
      await _controller.dispatchBatch(
        batch,
        vehicle: result.vehicle,
        driver: result.driver,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: Obx(() {
          final user = _controller.loggedInUser;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: AppColors.secondary),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, size: 28, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user?.name?.trim().isNotEmpty == true
                          ? user!.name!
                          : user?.agentCode ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (user?.location?.trim().isNotEmpty == true)
                      Text(
                        user!.location!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  Get.to(() => const SettingsPage());
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Reports'),
                onTap: () {
                  Navigator.of(context).pop();
                  Get.to(() => const ReportsPage());
                },
              ),
              if (user?.isAdmin == true)
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1),
                  title: const Text('Add User'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Get.to(() => const AddUserPage());
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.system_update),
                title: const Text('Check for Updates'),
                onTap: () async {
                  Navigator.of(context).pop();
                  // Delay to let drawer animation finish
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (!mounted) return;
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Checking for updates...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  final result = await _updateService.checkForUpdate();
                  if (!mounted) return;
                  messenger.hideCurrentSnackBar();
                  final detail = _updateService.lastCheckMessage.value;
                  if (result == 'up_to_date') {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          detail.isNotEmpty
                              ? '✅ Up to date — $detail'
                              : '✅ You already have the latest version',
                        ),
                        duration: const Duration(seconds: 3),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else if (result == 'error') {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          detail.isNotEmpty
                              ? '❌ $detail'
                              : '❌ Could not check for updates. Try again later.',
                        ),
                        duration: const Duration(seconds: 4),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  // 'update_found' — progress bar + install dialog fire automatically
                },
              ),
              if (_appVersion.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text('Version $_appVersion'),
                  dense: true,
                  enabled: false,
                ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _logout();
                },
              ),
            ],
          );
        }),
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
        ),
        title: Obx(
          () => Text(
            _controller.loggedInUserLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Download progress bar below AppBar
          Obx(() {
            final progress = _updateService.downloadProgress.value;
            if (progress < 0) return const SizedBox.shrink();

            if (progress == -2) {
              return Container(
                height: 3,
                color: Colors.white,
                child: const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.secondary,
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.system_update,
                        size: 14,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Obx(() {
                          final msg = _updateService.lastCheckMessage.value;
                          return Text(
                            msg.isNotEmpty
                                ? msg
                                : (progress >= 1.0
                                    ? 'Update ready to install'
                                    : 'Downloading... ${(progress * 100).toInt()}%'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.secondary,
                            ),
                          );
                        }),
                      ),
                      if (progress < 1.0 && progress >= 0)
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: AppColors.secondary.withAlpha(25),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.secondary,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            );
          }),
          // Main content
          Expanded(
            child: Obx(() {
              if (_controller.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              // Read ALL reactive values here so the single Obx subscribes to everything
              final parcels = _controller.parcels;
              final grouped = _controller.parcelsByStatus;
              final sectionExpanded = _sectionExpanded.value;
              final batchExpanded = _batchExpanded.value;
              final pendingBatches = _controller.pendingBatches;
              final inTransitBatches = _controller.inTransitBatches;
              final receivedParcels = _controller.receivedParcels;

              if (parcels.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refreshDashboard,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 24,
                    ),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(
                          child: Text(
                            'No parcels available yet',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final pending =
                  (grouped[ParcelStatus.pending] ?? const <Parcel>[]).length;
              final inTransit = _controller.inTransitBatchCount;
              final received = _controller.receivedParcelCount;
              final collected =
                  (grouped[ParcelStatus.collected] ?? const <Parcel>[]).length;

              // Filter helper for in-section search
              bool match(Parcel p) {
                final q = _searchQuery.value.trim().toLowerCase();
                if (q.isEmpty) return true;
                return (p.Document_No ?? '').toLowerCase().contains(q) ||
                    (p.Sender_Name ?? '').toLowerCase().contains(q) ||
                    (p.Sender_Phone ?? '').toLowerCase().contains(q) ||
                    (p.Receiver_Name ?? '').toLowerCase().contains(q) ||
                    (p.Receiver_Phone ?? '').toLowerCase().contains(q) ||
                    (p.From ?? '').toLowerCase().contains(q) ||
                    (p.To ?? '').toLowerCase().contains(q);
              }

              return RefreshIndicator(
                onRefresh: _refreshDashboard,
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        onChanged: (v) => _searchQuery.value = v,
                        decoration: InputDecoration(
                          hintText: 'Search parcels...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              _searchQuery.value.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => _searchQuery.value = '',
                                  )
                                  : null,
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.black12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    // Collapsible summary section
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap:
                                () => setState(
                                  () =>
                                      _isSummaryExpanded = !_isSummaryExpanded,
                                ),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    'Summary',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  AnimatedRotation(
                                    turns: _isSummaryExpanded ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: const Icon(
                                      Icons.expand_more,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            firstChild: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _MetricTile(
                                    title: 'Pending',
                                    value: pending.toString(),
                                    icon: Icons.schedule,
                                    color: getStatusColor(ParcelStatus.pending),
                                  ),
                                  _MetricTile(
                                    title: 'In Transit',
                                    value: inTransit.toString(),
                                    icon: Icons.local_shipping,
                                    color: getStatusColor(
                                      ParcelStatus.inTransit,
                                    ),
                                  ),
                                  _MetricTile(
                                    title: 'Received',
                                    value: received.toString(),
                                    icon: Icons.inventory_2,
                                    color: getStatusColor(
                                      ParcelStatus.received,
                                    ),
                                  ),
                                  _MetricTile(
                                    title: 'Collected',
                                    value: collected.toString(),
                                    icon: Icons.task_alt,
                                    color: getStatusColor(
                                      ParcelStatus.collected,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            secondChild: const SizedBox.shrink(),
                            crossFadeState:
                                _isSummaryExpanded
                                    ? CrossFadeState.showFirst
                                    : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 200),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Pending batches section
                    _buildPendingBatchesSection(
                      theme,
                      pendingBatches,
                      sectionExpanded,
                      batchExpanded,
                      match: match,
                    ),
                    const SizedBox(height: 10),
                    // In Transit batches section
                    _buildInTransitSection(
                      theme,
                      inTransitBatches,
                      sectionExpanded,
                      batchExpanded,
                      match: match,
                    ),
                    const SizedBox(height: 10),
                    // Received parcels section
                    _buildReceivedSection(
                      theme,
                      context,
                      receivedParcels.where(match).toList(),
                      sectionExpanded,
                    ),
                    const SizedBox(height: 10),
                    // Collected section
                    _buildCollectedSection(
                      theme,
                      grouped,
                      sectionExpanded,
                      match: match,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          Get.snackbar(
            'Please wait',
            'Creating parcel...',
            showProgressIndicator: true,
            snackPosition: SnackPosition.BOTTOM,
          );
          await _controller.newparcel();
          Get.closeCurrentSnackbar();
          final result = await Get.to(() => const AddEditParcelPage());
          if (result == true) {
            await _controller.loadParcels();
            await _controller.loadPendingBatches();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Parcel'),
      ),
    );
  }

  Widget _buildPendingBatchesSection(
    ThemeData theme,
    List<Batches> batches,
    String sectionExpanded,
    String batchExpanded, {
    bool Function(Parcel)? match,
  }) {
    if (batches.isEmpty) {
      return _StatusSectionCard(
        key: _getKey('status-pending'),
        title: 'Pending',
        color: getStatusColor(ParcelStatus.pending),
        parcels: const <Parcel>[],
        isExpanded: sectionExpanded == 'status-pending',
        onToggle: () => _toggleSection('status-pending'),
        icon: Icons.schedule,
      );
    }

    return Container(
      key: _getKey('status-pending'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: getStatusColor(ParcelStatus.pending).withValues(alpha: 0.2),
        ),
      ),
      child: _AccordionTile(
        isExpanded: sectionExpanded == 'status-pending',
        onToggle: () => _toggleSection('status-pending'),
        title: Row(
          children: [
            Icon(
              Icons.schedule,
              size: 20,
              color: getStatusColor(ParcelStatus.pending),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pending',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: getStatusColor(
                  ParcelStatus.pending,
                ).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${batches.length} batches',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: getStatusColor(ParcelStatus.pending),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        children: [
          const SizedBox(height: 8),
          ...batches.map(
            (batch) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BatchCard(
                key: _getKey('batch-${batch.batchNo}'),
                batch: batch,
                parcels:
                    _controller.parcels
                        .where((p) => p.Batch_No == batch.batchNo)
                        .toList(),
                onDispatch: () => _showDispatchDialog(context, batch),
                isExpanded: batchExpanded == 'batch-${batch.batchNo}',
                onToggle: () => _toggleBatch('batch-${batch.batchNo}'),
                onEditParcel: (parcel) async {
                  final result = await Get.to(
                    () => AddEditParcelPage(parcel: parcel),
                  );
                  if (result == true) {
                    await _controller.loadParcels();
                    await _controller.loadPendingBatches();
                  }
                },
                onDeleteParcel: (parcel) async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          title: const Text('Delete Parcel'),
                          content: Text(
                            'Are you sure you want to delete ${parcel.Document_No ?? 'this parcel'}?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                  );
                  if (confirmed == true) {
                    await _controller.deleteParcel(parcel.Document_No ?? '');
                    await _controller.loadPendingBatches();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInTransitSection(
    ThemeData theme,
    List<Batches> batches,
    String sectionExpanded,
    String batchExpanded, {
    bool Function(Parcel)? match,
  }) {
    final color = getStatusColor(ParcelStatus.inTransit);

    if (batches.isEmpty) {
      return _StatusSectionCard(
        key: _getKey('intransit'),
        title: 'In Transit',
        color: color,
        parcels: const <Parcel>[],
        isExpanded: sectionExpanded == 'intransit',
        onToggle: () => _toggleSection('intransit'),
        icon: Icons.local_shipping,
      );
    }

    return Container(
      key: _getKey('intransit'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: _AccordionTile(
        isExpanded: sectionExpanded == 'intransit',
        onToggle: () => _toggleSection('intransit'),
        title: Row(
          children: [
            Icon(Icons.local_shipping, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'In Transit',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${batches.length}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        children: [
          const SizedBox(height: 8),
          ...batches.map(
            (batch) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _InTransitBatchCard(
                key: _getKey('intransit-${batch.batchNo}'),
                batch: batch,
                parcels:
                    _controller.parcels
                        .where((p) => p.Batch_No == batch.batchNo)
                        .toList(),
                onReceive: () => _showReceiveConfirm(context, batch),
                isExpanded: batchExpanded == 'intransit-${batch.batchNo}',
                onToggle: () => _toggleBatch('intransit-${batch.batchNo}'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showReceiveConfirm(BuildContext ctx, Batches batch) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder:
          (dialogCtx) => AlertDialog(
            title: const Text('Receive Batch'),
            content: Text(
              'Confirm receipt of batch ${batch.batchNo ?? ''}\n'
              'from ${batch.fromLocation ?? '-'} → ${batch.toLocation ?? '-'}?\n\n'
              'This will update all parcels to "Received" and send SMS notifications.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: getStatusColor(ParcelStatus.received),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Receive'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await _controller.receiveBatch(batch);
    }
  }

  Widget _buildReceivedSection(
    ThemeData theme,
    BuildContext context,
    List<Parcel> parcels,
    String sectionExpanded,
  ) {
    final color = getStatusColor(ParcelStatus.received);

    if (parcels.isEmpty) {
      return _StatusSectionCard(
        key: _getKey('received'),
        title: 'Received',
        color: color,
        parcels: const <Parcel>[],
        isExpanded: sectionExpanded == 'received',
        onToggle: () => _toggleSection('received'),
        icon: Icons.inventory_2,
      );
    }

    return Container(
      key: _getKey('received'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: _AccordionTile(
        isExpanded: sectionExpanded == 'received',
        onToggle: () => _toggleSection('received'),
        title: Row(
          children: [
            Icon(Icons.inventory_2, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Received',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${parcels.length} parcels',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        children: [
          const SizedBox(height: 8),
          ...parcels.map(
            (parcel) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReceivedParcelCard(
                parcel: parcel,
                onPay: () => _controller.payForParcel(context, parcel),
                onCollect: () => _showCollectConfirm(context, parcel),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCollectConfirm(BuildContext ctx, Parcel parcel) async {
    final idCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    var errorMsg = '';

    final result = await showDialog<Map<String, String>>(
      context: ctx,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Collect Parcel'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${parcel.Document_No ?? ''} - ${parcel.Receiver_Name ?? 'Receiver'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Receiver Phone',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: idCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Receiver ID',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        onChanged: (_) {
                          if (errorMsg.isNotEmpty) {
                            setDialogState(() => errorMsg = '');
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Collection Code (5 digits)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          counterText: '',
                          errorText: errorMsg.isNotEmpty ? errorMsg : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            idCtrl.text = parcel.Receiver_ID?.trim() ?? '';
                            phoneCtrl.text = parcel.Receiver_Phone?.trim() ?? '';
                          },
                          icon: const Icon(Icons.person_pin, size: 18),
                          label: const Text('Use Receiver Details'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final id = idCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    final code = codeCtrl.text.trim();
                    if (phone.isEmpty || code.isEmpty) {
                      setDialogState(() => errorMsg = 'Phone and Collection Code are required');
                      return;
                    }
                    if (code.length != 5) {
                      setDialogState(() => errorMsg = 'Collection Code must be 5 digits');
                      return;
                    }
                    final expected = (parcel.Receiver_Code ?? '').trim();
                    if (expected.isNotEmpty && code != expected) {
                      setDialogState(() => errorMsg = 'Incorrect collection code');
                      return;
                    }
                    Navigator.pop(dialogCtx, {
                      'id': id,
                      'phone': phone,
                      'code': code,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: getStatusColor(ParcelStatus.collected),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Collect'),
                ),
              ],
            ),
          ),
    );

    if (result != null) {
      await _controller.collectParcel(
        parcel,
        receivedByPhone: result['phone']!,
        enteredCode: result['code']!,
        receivedById: result['id']!,
      );
    }
  }

  Future<void> _printParcelForTesting(
    BuildContext context,
    Parcel parcel,
  ) async {
    final printed = await showPrintReceiptDialog(
      context: context,
      parcel: parcel,
      onSkip: () {},
    );

    if (printed == true) {
      parcel.receiptPrinted = true;
      await _controller.updateParcel(parcel);
      if (mounted) {
        Get.snackbar(
          'Printed',
          'Receipt sent to printer',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  Widget _buildCollectedSection(
    ThemeData theme,
    Map<ParcelStatus, List<Parcel>> grouped,
    String sectionExpanded, {
    bool Function(Parcel)? match,
  }) {
    final all = grouped[ParcelStatus.collected] ?? const <Parcel>[];
    final parcels = match != null ? all.where(match).toList() : all;
    final color = getStatusColor(ParcelStatus.collected);

    return Container(
      key: _getKey('status-collected'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: _AccordionTile(
        isExpanded: sectionExpanded == 'status-collected',
        onToggle: () => _toggleSection('status-collected'),
        title: Row(
          children: [
            Icon(Icons.task_alt, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Collected',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${parcels.length} parcels',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        children: [
          const SizedBox(height: 8),
          ...parcels.map(
            (parcel) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CollectedParcelCard(parcel: parcel),
            ),
          ),
        ],
      ),
    );
  }
}

class _DispatchDialogResult {
  const _DispatchDialogResult({required this.vehicle, required this.driver});

  final String vehicle;
  final String driver;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileWidth = (MediaQuery.of(context).size.width - 48) / 2;

    return Container(
      width: tileWidth,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
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

class _InTransitBatchCard extends StatelessWidget {
  const _InTransitBatchCard({
    super.key,
    required this.batch,
    required this.parcels,
    required this.onReceive,
    this.isExpanded = false,
    this.onToggle,
  });

  final Batches batch;
  final List<Parcel> parcels;
  final VoidCallback onReceive;
  final bool isExpanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = getStatusColor(ParcelStatus.inTransit);

    final hasVehicle = batch.vehicle?.trim().isNotEmpty == true;
    final hasDriver = batch.driver?.trim().isNotEmpty == true;

    final docNos =
        batch.parcelDocumentNos
            .map((d) => d.trim())
            .where((d) => d.isNotEmpty)
            .toList();
    final parcelCount =
        parcels.isNotEmpty
            ? parcels.length
            : (batch.parcelCount ?? docNos.length);

    final parcelItems =
        parcels.isEmpty
            ? (docNos.isEmpty
                ? <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'No parcels in this batch',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ]
                : [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'PARCELS IN BATCH',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...docNos.map(
                    (docNo) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.scaffold,
                          borderRadius: BorderRadius.circular(10),
                          border: Border(
                            left: BorderSide(color: color, width: 3),
                          ),
                        ),
                        child: Text(
                          docNo,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ])
            : [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(
                      'PARCELS IN BATCH',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              ...parcels.map(
                (parcel) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.scaffold,
                      borderRadius: BorderRadius.circular(10),
                      border: Border(left: BorderSide(color: color, width: 3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 12,
                                    color: color,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${parcel.From ?? '-'} → ${parcel.To ?? '-'}',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: color,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (parcel.Sender_Name?.trim().isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 12,
                                        color: Colors.black54,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          parcel.Sender_Name!,
                                          style: theme.textTheme.bodySmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 12,
                                      color: Colors.black54,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        parcel.Receiver_Name ?? '-',
                                        style: theme.textTheme.bodySmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.call_outlined,
                                      size: 12,
                                      color: Colors.black45,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      parcel.Receiver_Phone ?? '-',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              if (parcel.Details?.trim().isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    parcel.Details!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.black54,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (parcel.Paid == true
                                          ? Colors.green
                                          : Colors.red)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  parcel.Paid == true ? 'PAID' : 'NOT PAID',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        parcel.Paid == true
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          DateFormat(
                            'dd MMM',
                          ).format(parcel.Date_sent ?? DateTime.now()),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: _AccordionTile(
        isExpanded: isExpanded,
        onToggle: onToggle ?? () {},
        title: Row(
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${batch.fromLocation ?? '-'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 13,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          hasVehicle ? batch.vehicle!.trim() : 'No vehicle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 13,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          hasDriver ? batch.driver!.trim() : 'No driver',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 13,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$parcelCount',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Obx(() {
              final ctrl = Get.find<ParcelController>();
              final isRcv = ctrl.isReceivingBatch(batch.batchNo ?? '');
              return ElevatedButton.icon(
                onPressed: isRcv ? null : onReceive,
                icon:
                    isRcv
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.check_circle_outline, size: 16),
                label: Text(isRcv ? 'Receiving...' : 'Receive'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: getStatusColor(ParcelStatus.received),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }),
          ],
        ),
        children: [...parcelItems],
      ),
    );
  }
}

class _ReceivedParcelCard extends StatelessWidget {
  const _ReceivedParcelCard({
    required this.parcel,
    required this.onPay,
    required this.onCollect,
  });

  final Parcel parcel;
  final VoidCallback onPay;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = getStatusColor(ParcelStatus.received);
    final isPaid = parcel.Paid == true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parcel.Document_No ?? '-',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      isPaid
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPaid ? 'Paid' : 'Unpaid',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isPaid ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receiver: ${parcel.Receiver_Name ?? '-'}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Phone: ${parcel.Receiver_Phone ?? '-'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${parcel.From ?? '-'} → ${parcel.To ?? '-'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'KES ${(parcel.Amount_Paid ?? 0).toStringAsFixed(0)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat(
                      'dd MMM',
                    ).format(parcel.Date_sent ?? DateTime.now()),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child:
                isPaid
                    ? ElevatedButton.icon(
                      onPressed: onCollect,
                      icon: const Icon(Icons.task_alt, size: 18),
                      label: const Text('Mark Collected'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                    : ElevatedButton.icon(
                      onPressed: onPay,
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Pay'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _AccordionTile extends StatelessWidget {
  const _AccordionTile({
    required this.isExpanded,
    required this.onToggle,
    required this.title,
    required this.children,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Expanded(child: title),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    size: 24,
                    color: theme.iconTheme.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ),
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

class _CollectedParcelCard extends StatelessWidget {
  const _CollectedParcelCard({required this.parcel});

  final Parcel parcel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = getStatusColor(ParcelStatus.collected);
    final createdDate =
        parcel.Date_Created ?? parcel.Date_sent ?? DateTime.now();
    final collectedDate = parcel.Date_Collected ?? DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parcel.Document_No ?? '-',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow(theme, Icons.person, 'Sender', parcel.Sender_Name ?? '-'),
          _infoRow(
            theme,
            Icons.person_outline,
            'Receiver',
            parcel.Receiver_Name ?? '-',
          ),
          _infoRow(theme, Icons.arrow_forward, 'From', parcel.From ?? '-'),
          _infoRow(theme, Icons.location_on, 'To', parcel.To ?? '-'),
          if ((parcel.Received_By_ID?.isNotEmpty == true) ||
              (parcel.Received_By_Phone?.isNotEmpty == true))
            _infoRow(
              theme,
              Icons.check_circle_outline,
              'Collected by',
              [
                if (parcel.Received_By_ID?.isNotEmpty == true)
                  parcel.Received_By_ID!,
                if (parcel.Received_By_Phone?.isNotEmpty == true)
                  parcel.Received_By_Phone!,
              ].join(' | '),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              _dateChip(theme, Icons.calendar_today, 'Created', createdDate),
              const SizedBox(width: 8),
              _dateChip(theme, Icons.task_alt, 'Collected', collectedDate),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.black38),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(
    ThemeData theme,
    IconData icon,
    String label,
    DateTime date,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.black45),
          const SizedBox(width: 4),
          Text(
            '$label: ${DateFormat('dd MMM yy').format(date)}',
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _StatusSectionCard extends StatelessWidget {
  const _StatusSectionCard({
    super.key,
    required this.title,
    required this.color,
    required this.parcels,
    this.isExpanded = false,
    this.onToggle,
    this.icon,
  });

  final String title;
  final Color color;
  final List<Parcel> parcels;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final sectionItems = <Widget>[
      if (parcels.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'No parcels in this stage',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
        )
      else
        ...parcels
            .take(4)
            .map(
              (parcel) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parcel.Document_No ?? '-',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${parcel.From ?? '-'} -> ${parcel.To ?? '-'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat(
                          'dd MMM',
                        ).format(parcel.Date_sent ?? DateTime.now()),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      if (parcels.length > 4)
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            '+${parcels.length - 4} more',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: _AccordionTile(
        isExpanded: isExpanded,
        onToggle: onToggle ?? () {},
        title: Row(
          children: [
            if (icon != null)
              Icon(icon, size: 20, color: color)
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${parcels.length} parcels',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        children: sectionItems,
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    super.key,
    required this.batch,
    required this.parcels,
    required this.onDispatch,
    this.isExpanded = false,
    this.onToggle,
    this.onEditParcel,
    this.onDeleteParcel,
  });

  final Batches batch;
  final List<Parcel> parcels;
  final VoidCallback onDispatch;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final ValueChanged<Parcel>? onEditParcel;
  final ValueChanged<Parcel>? onDeleteParcel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = getStatusColor(ParcelStatus.pending);

    final parcelItems =
        parcels.isEmpty
            ? <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'No parcels in this batch',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ),
            ]
            : [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(
                      'PARCELS IN BATCH',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              ...parcels.map(
                (parcel) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap:
                        onEditParcel != null
                            ? () => onEditParcel!(parcel)
                            : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.scaffold,
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(color: color, width: 3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  parcel.Document_No ?? '-',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${parcel.Receiver_Name ?? '-'} | ${parcel.Receiver_Phone ?? '-'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (parcel.Paid == true)
                                      const Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: Colors.green,
                                      )
                                    else
                                      const Icon(
                                        Icons.pending,
                                        size: 14,
                                        color: Colors.orange,
                                      ),
                                    Text(
                                      parcel.Paid == true ? 'Paid' : 'Unpaid',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color:
                                                parcel.Paid == true
                                                    ? Colors.green
                                                    : Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (parcel.paymentMethod != null &&
                                        parcel.paymentMethod !=
                                            PaymentMethod.pending)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Text(
                                          parcel.paymentMethod ==
                                                  PaymentMethod.mpesa
                                              ? 'M-Pesa'
                                              : 'Cash',
                                          style: theme.textTheme.labelSmall,
                                        ),
                                      ),
                                    if (parcel.Amount_Paid != null &&
                                        parcel.Amount_Paid! > 0)
                                      Text(
                                        'KES ${parcel.Amount_Paid!.toStringAsFixed(0)}',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            DateFormat(
                              'dd MMM',
                            ).format(parcel.Date_sent ?? DateTime.now()),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.black54,
                            ),
                          ),
                          if (onDeleteParcel != null)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => onDeleteParcel!(parcel),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ];

    final hasVehicle = batch.vehicle?.trim().isNotEmpty == true;
    final hasDriver = batch.driver?.trim().isNotEmpty == true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: _AccordionTile(
        isExpanded: isExpanded,
        onToggle: onToggle ?? () {},
        title: Row(
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
                    batch.toLocation ?? '-',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (hasVehicle)
                    Row(
                      children: [
                        const Icon(Icons.directions_car, size: 13),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            batch.vehicle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${parcels.length} parcels',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 34,
              child: ElevatedButton.icon(
                onPressed: onDispatch,
                icon: const Icon(Icons.local_shipping, size: 16),
                label: const Text('Dispatch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
        children: [
          if (hasVehicle || hasDriver)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (hasVehicle)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.directions_car, size: 16),
                      label: Text(batch.vehicle!),
                    ),
                  if (hasDriver)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.person, size: 16),
                      label: Text(batch.driver!),
                    ),
                ],
              ),
            ),
          ...parcelItems,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DispatchDialog extends StatefulWidget {
  const _DispatchDialog({
    required this.batch,
    required this.vehiclesWithNumber,
  });

  final Batches batch;
  final List<AppVehicle> vehiclesWithNumber;

  @override
  State<_DispatchDialog> createState() => _DispatchDialogState();
}

class _DispatchDialogState extends State<_DispatchDialog> {
  late final TextEditingController _vehicleCtrl;
  late final TextEditingController _driverCtrl;
  late final ValueNotifier<String> _vehicleText;
  late final FocusNode _vehicleFocus;

  @override
  void initState() {
    super.initState();
    _vehicleCtrl = TextEditingController(text: widget.batch.vehicle ?? '');
    _driverCtrl = TextEditingController(text: widget.batch.driver ?? '');
    _vehicleText = ValueNotifier<String>(widget.batch.vehicle?.trim() ?? '');
    _vehicleFocus = FocusNode();
  }

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    _driverCtrl.dispose();
    _vehicleText.dispose();
    _vehicleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batch = widget.batch;
    final vehiclesWithNumber = widget.vehiclesWithNumber;
    final hasVehicleList = vehiclesWithNumber.isNotEmpty;

    return AlertDialog(
      title: const Text('Dispatch Batch'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Batch: ${batch.batchNo ?? '-'}'),
            const SizedBox(height: 4),
            Text(
              '${batch.fromLocation ?? '-'} → ${batch.toLocation ?? '-'}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            hasVehicleList
                ? RawAutocomplete<String>(
                  textEditingController: _vehicleCtrl,
                  focusNode: _vehicleFocus,
                  optionsBuilder: (TextEditingValue value) {
                    final query = value.text.trim().toLowerCase();
                    // Only show suggestions after at least 2 characters typed.
                    if (query.length < 2) {
                      return const Iterable<String>.empty();
                    }
                    return vehiclesWithNumber
                        .map((v) => v.vehicleNumber!.trim())
                        .where((reg) {
                          final lower = reg.toLowerCase();
                          // Hide the list once an exact match is chosen.
                          if (lower == query) return false;
                          return lower.contains(query);
                        });
                  },
                  onSelected: (selection) {
                    _vehicleText.value = selection;
                  },
                  fieldViewBuilder: (
                    context,
                    controller,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Vehicle Registration *',
                        prefixIcon: const Icon(Icons.directions_car),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) => _vehicleText.value = value.trim(),
                      onSubmitted: (_) => onFieldSubmitted(),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    final items = options.toList();
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 200,
                            maxWidth: 360,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final reg = items[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.directions_car,
                                  size: 18,
                                ),
                                title: Text(reg),
                                onTap: () => onSelected(reg),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                )
                : TextField(
                  controller: _vehicleCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Registration *',
                    prefixIcon: const Icon(Icons.directions_car),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (value) => _vehicleText.value = value.trim(),
                ),
            const SizedBox(height: 12),
            TextField(
              controller: _driverCtrl,
              decoration: InputDecoration(
                labelText: 'Driver Name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            ValueListenableBuilder<String>(
              valueListenable: _vehicleText,
              builder: (context, value, _) {
                if (value.trim().isNotEmpty) {
                  return const SizedBox.shrink();
                }
                return const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '* Vehicle registration is required before dispatch',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<String>(
          valueListenable: _vehicleText,
          builder: (context, value, _) {
            final vehicleValid = value.trim().isNotEmpty;
            return ElevatedButton(
              onPressed:
                  vehicleValid
                      ? () => Navigator.pop(
                        context,
                        _DispatchDialogResult(
                          vehicle: _vehicleCtrl.text.trim(),
                          driver: _driverCtrl.text.trim(),
                        ),
                      )
                      : null,
              child: const Text('Dispatch'),
            );
          },
        ),
      ],
    );
  }
}

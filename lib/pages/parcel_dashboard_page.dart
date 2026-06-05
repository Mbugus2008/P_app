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

    // Listen for when the download finishes to prompt installation.
    _updateService.updateReady.listen((ready) {
      if (ready && mounted) {
        _promptInstallUpdate();
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

  Future<void> _promptInstallUpdate() async {
    final version = _updateService.pendingVersion;
    if (version == null || !mounted) return;

    final dialog = AlertDialog(
      title: Text('Update v${version.version} Ready'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A new version is ready to install.'),
          if (version.releaseNotes != null &&
              version.releaseNotes!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              version.releaseNotes!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        if (!version.forceUpdate)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _updateService.installUpdate(context);
          },
          child: const Text('Install Now'),
        ),
      ],
    );

    // Small delay to ensure the download progress indicator is seen first.
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      await showDialog(context: context, builder: (_) => dialog);
    }
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
                onTap: () {
                  Navigator.of(context).pop();
                  _updateService.checkForUpdate();
                  Get.snackbar(
                    'Checking',
                    'Looking for updates...',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Obx(() {
            final progress = _updateService.downloadProgress.value;
            if (progress < 0) return const SizedBox.shrink();

            if (progress == -2) {
              // Checking for updates
              return Container(
                height: 2,
                color: Colors.white24,
                child: const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              color: AppColors.secondary,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.system_update,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          progress >= 1.0
                              ? 'Update ready to install'
                              : 'Downloading update... ${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            );
          }),
        ),
      ),
      body: Obx(() {
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
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

        final pendingBatchesCount = _controller.pendingBatchCount;
        final inTransit = _controller.inTransitBatchCount;
        final received = _controller.receivedParcelCount;
        final collected =
            (grouped[ParcelStatus.collected] ?? const <Parcel>[]).length;

        return RefreshIndicator(
          onRefresh: _refreshDashboard,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            children: [
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
                            () => _isSummaryExpanded = !_isSummaryExpanded,
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
                              child: const Icon(Icons.expand_more, size: 20),
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
                              title: 'Pending Batches',
                              value: pendingBatchesCount.toString(),
                              icon: Icons.schedule,
                              color: getStatusColor(ParcelStatus.pending),
                            ),
                            _MetricTile(
                              title: 'In Transit',
                              value: inTransit.toString(),
                              icon: Icons.local_shipping,
                              color: getStatusColor(ParcelStatus.inTransit),
                            ),
                            _MetricTile(
                              title: 'Received',
                              value: received.toString(),
                              icon: Icons.inventory_2,
                              color: getStatusColor(ParcelStatus.received),
                            ),
                            _MetricTile(
                              title: 'Collected',
                              value: collected.toString(),
                              icon: Icons.task_alt,
                              color: getStatusColor(ParcelStatus.collected),
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
              ),
              const SizedBox(height: 10),
              // In Transit batches section
              _buildInTransitSection(
                theme,
                inTransitBatches,
                sectionExpanded,
                batchExpanded,
              ),
              const SizedBox(height: 10),
              // Received parcels section
              _buildReceivedSection(
                theme,
                context,
                receivedParcels,
                sectionExpanded,
              ),
              const SizedBox(height: 10),
              // Collected section
              _buildCollectedSection(theme, grouped, sectionExpanded),
            ],
          ),
        );
      }),
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
    String batchExpanded,
  ) {
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
    String batchExpanded,
  ) {
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                'In Transit',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${batches.length} batches',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                'Received',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
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
          const SizedBox(height: 8),
          ...parcels.map(
            (parcel) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReceivedParcelCard(
                parcel: parcel,
                onPay: () => _controller.payForParcel(context, parcel),
                onCollect: () => _showCollectConfirm(context, parcel),
                onPrint: () => _printParcelForTesting(context, parcel),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCollectConfirm(BuildContext ctx, Parcel parcel) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder:
          (dialogCtx) => AlertDialog(
            title: const Text('Confirm Collection'),
            content: Text(
              'Has parcel ${parcel.Document_No ?? ''} been collected by ${parcel.Receiver_Name ?? 'the receiver'}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: getStatusColor(ParcelStatus.collected),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Collected'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await _controller.collectParcel(parcel);
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
    String sectionExpanded,
  ) {
    final parcels = grouped[ParcelStatus.collected] ?? const <Parcel>[];
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
                              Text(
                                parcel.Receiver_Name ?? '-',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                parcel.Receiver_Phone ?? '-',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
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
                  Text(
                    '${batch.fromLocation ?? '-'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 13,
                        color: Colors.black54,
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
                      const SizedBox(width: 8),
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
            ElevatedButton.icon(
              onPressed: onReceive,
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Receive'),
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
            ),
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
    required this.onPrint,
  });

  final Parcel parcel;
  final VoidCallback onPay;
  final VoidCallback onCollect;
  final VoidCallback onPrint;

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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Print'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    isPaid
                        ? ElevatedButton.icon(
                          onPressed: onCollect,
                          icon: const Icon(Icons.task_alt, size: 18),
                          label: const Text('Collected'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: getStatusColor(
                              ParcelStatus.collected,
                            ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parcel.Document_No ?? '-',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Receiver: ${parcel.Receiver_Name ?? '-'} | ${parcel.Receiver_Phone ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('dd MMM').format(
                  parcel.Date_Collected ?? parcel.Date_sent ?? DateTime.now(),
                ),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
            ],
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onDispatch,
              icon: const Icon(Icons.local_shipping, size: 18),
              label: const Text('Dispatch Batch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
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

class _DispatchDialogResult {
  const _DispatchDialogResult({required this.vehicle, required this.driver});

  final String vehicle;
  final String driver;
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

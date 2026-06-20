import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../dialogs/mpesa_payment_dialog.dart';
import '../dialogs/print_receipt_dialog.dart';
import '../models/Parcel_Details.dart';
import '../models/app_location.dart';
import '../models/app_user.dart';
import '../models/app_vehicle.dart';
import '../models/batches.dart';
import '../models/parcel_model.dart';
import '../utilities/Apis.dart';
import '../utilities/device_id.dart';

class ParcelController extends GetxController {
  ParcelController({Parcel? initialParcel}) {
    parcel = initialParcel ?? _buildSampleParcel();
    populateFormWithParcel(parcel!);
  }

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ApiClient _apiClient = ApiClient();

  ApiClient get apiClient => _apiClient;

  final RxList<Parcel> _parcels = <Parcel>[].obs;
  final RxList<Parcel> _filteredParcels = <Parcel>[].obs;
  final RxBool _isLoading = true.obs;
  final RxString _searchQuery = ''.obs;
  final Rx<ParcelStatus?> _statusFilter = Rx<ParcelStatus?>(null);
  final RxBool _isSyncingUsers = false.obs;
  final RxInt _usersCount = 0.obs;
  final Rxn<AppUser> _loggedInUser = Rxn<AppUser>();
  final RxString _currentLocation = ''.obs;
  final Rxn<AppLocation> _currentLocationRecord = Rxn<AppLocation>();
  final RxList<Batches> _pendingBatches = <Batches>[].obs;
  final RxList<Batches> _inTransitBatches = <Batches>[].obs;
  final RxList<Parcel> _receivedParcels = <Parcel>[].obs;
  final RxSet<String> _receivingBatches = <String>{}.obs;
  bool _hasSyncedReferenceDataOnLogin = false;
  Future<void>? _referenceDataSyncFuture;
  Timer? _autoSyncTimer;
  bool _isAutoSyncRunning = false;
  static const String _locationRecordPrefKey = 'user_location_record';

  static const List<ParcelStatus> _statusOrder = <ParcelStatus>[
    ParcelStatus.pending,
    ParcelStatus.inTransit,
    ParcelStatus.received,
    ParcelStatus.collected,
  ];

  Parcel? parcel;

  List<Parcel> get parcels => _parcels;
  List<Parcel> get filteredParcels => _filteredParcels;
  bool get isLoading => _isLoading.value;
  String get searchQuery => _searchQuery.value;
  ParcelStatus? get statusFilter => _statusFilter.value;
  List<ParcelStatus> get supportedStatuses => _statusOrder;
  bool get isSyncingUsers => _isSyncingUsers.value;
  int get usersCount => _usersCount.value;
  AppUser? get loggedInUser => _loggedInUser.value;
  String get currentLocation => _currentLocation.value;
  AppLocation? get currentLocationRecord => _currentLocationRecord.value;
  String get currentLocationCode =>
      _currentLocationRecord.value?.code.trim() ?? '';
  String get currentLocationName =>
      _currentLocationRecord.value?.name?.trim() ?? '';
  List<Batches> get pendingBatches => _pendingBatches;
  int get pendingBatchCount => _pendingBatches.length;
  List<Batches> get inTransitBatches => _inTransitBatches;
  int get inTransitBatchCount => _inTransitBatches.length;
  List<Parcel> get receivedParcels => _receivedParcels;
  int get receivedParcelCount => _receivedParcels.length;
  bool isReceivingBatch(String batchNo) => _receivingBatches.contains(batchNo);
  String get loggedInUserLabel {
    final user = _loggedInUser.value;
    if (user == null) return 'Signed in';
    final displayName =
        (user.name?.trim().isNotEmpty ?? false)
            ? user.name!.trim()
            : user.agentCode.trim();
    final displayLocation = _currentLocation.value.trim();

    if (displayLocation.isNotEmpty) {
      return '${displayName.toUpperCase()} | ${displayLocation.toUpperCase()}';
    }

    return displayName.toUpperCase();
  }

  void setLoggedInUser(AppUser user) {
    _loggedInUser.value = user;
    // Reload location-dependent lists after login
    loadInTransitBatches();
    loadReceivedParcels();
    _startAutoSync();
  }

  Future<void> syncParcelsAndBatchesNow() async {
    if (_loggedInUser.value == null) return;
    await _runAutoSyncCycle();
  }

  void clearLoggedInUser() {
    _loggedInUser.value = null;
    _stopAutoSync();
  }

  Future<void> loadCurrentLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final rawRecord = prefs.getString(_locationRecordPrefKey);
    final parsedRecord = _decodeLocationRecord(rawRecord);
    _currentLocationRecord.value = parsedRecord;

    var saved = prefs.getString('user_location') ?? '';
    if (saved.isEmpty && parsedRecord != null) {
      final preferred = parsedRecord.name?.trim();
      saved =
          (preferred != null && preferred.isNotEmpty)
              ? preferred
              : parsedRecord.code.trim();
      if (saved.isNotEmpty) {
        await prefs.setString('user_location', saved);
      }
    }

    if (saved.isEmpty && _loggedInUser.value?.location != null) {
      // Fallback to user record on first run
      saved = _loggedInUser.value!.location!;
      await prefs.setString('user_location', saved);
    }
    _currentLocation.value = saved;
  }

  Future<void> setCurrentLocation(String location) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = location.trim();
    await prefs.setString('user_location', trimmed);
    _currentLocation.value = trimmed;

    final record = AppLocation(code: trimmed, name: trimmed);
    _currentLocationRecord.value = record;
    await prefs.setString(
      _locationRecordPrefKey,
      _encodeLocationRecord(record),
    );

    await loadInTransitBatches();
    await loadReceivedParcels();
  }

  Future<void> setCurrentLocationRecord(AppLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    final preferred =
        (location.name?.trim().isNotEmpty ?? false)
            ? location.name!.trim()
            : location.code.trim();

    await prefs.setString('user_location', preferred);
    await prefs.setString(
      _locationRecordPrefKey,
      _encodeLocationRecord(location),
    );

    _currentLocation.value = preferred;
    _currentLocationRecord.value = location;

    await loadInTransitBatches();
    await loadReceivedParcels();
  }

  AppLocation? _decodeLocationRecord(String? rawRecord) {
    if (rawRecord == null || rawRecord.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(rawRecord);
      if (decoded is Map<String, dynamic>) {
        final code = (decoded['code'] ?? '').toString().trim();
        final nameRaw = (decoded['name'] ?? '').toString().trim();
        if (code.isEmpty && nameRaw.isEmpty) return null;
        final codeValue = code.isNotEmpty ? code : nameRaw;
        final nameValue = nameRaw.isNotEmpty ? nameRaw : null;
        return AppLocation(code: codeValue, name: nameValue);
      }
    } catch (_) {
      // Ignore malformed data and continue without a record.
    }
    return null;
  }

  String _encodeLocationRecord(AppLocation location) {
    return jsonEncode(<String, dynamic>{
      'code': location.code,
      'name': location.name,
    });
  }

  Map<ParcelStatus, List<Parcel>> get parcelsByStatus {
    final Map<ParcelStatus, List<Parcel>> grouped = {
      for (final status in _statusOrder) status: <Parcel>[],
    };
    for (final parcel in _parcels) {
      final status = parcel.Status ?? ParcelStatus.pending;
      grouped.putIfAbsent(status, () => <Parcel>[]).add(parcel);
    }
    return grouped;
  }

  String statusLabel(ParcelStatus status) {
    switch (status) {
      case ParcelStatus.pending:
        return 'Pending';
      case ParcelStatus.inTransit:
        return 'In Transit';
      case ParcelStatus.received:
        return 'Received';
      case ParcelStatus.collected:
        return 'Collected';
    }
  }

  final formKey = GlobalKey<FormState>();

  final documentNoController = TextEditingController();
  final senderNameController = TextEditingController();
  final senderIdController = TextEditingController();
  final senderPhoneController = TextEditingController();
  final fromController = TextEditingController();
  final toController = TextEditingController();
  final receiverNameController = TextEditingController();
  final receiverIdController = TextEditingController();
  final receiverPhoneController = TextEditingController();
  final driverController = TextEditingController();
  final vehicleController = TextEditingController();
  final amountPaidController = TextEditingController();
  final mpesaCodeController = TextEditingController();

  ParcelStatus selectedStatus = ParcelStatus.pending;
  WhoToPay paymentResponsibility = WhoToPay.Sender;
  PaymentMethod paymentMethod = PaymentMethod.pending;
  DateTime selectedDate = DateTime.now();
  bool paid = false;

  RxString parcelinformationError = ''.obs;
  RxString senderinformationError = ''.obs;
  RxString receiverinformationError = ''.obs;
  RxString deliveryinformationError = ''.obs;
  RxString paymentinformationError = ''.obs;

  void _showSnack(String title, String message) {
    void showNow() {
      Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);
    }

    if (Get.overlayContext != null) {
      showNow();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.overlayContext != null) {
        showNow();
      }
    });
  }

  @override
  void onInit() {
    super.onInit();
    _initAsync();
  }

  Future<void> _initAsync() async {
    await loadCurrentLocation();
    await loadParcels();
    await loadPendingBatches();
    await loadInTransitBatches();
    await loadReceivedParcels();

    if (_loggedInUser.value != null) {
      _startAutoSync();
    }
  }

  void _startAutoSync() {
    _stopAutoSync();

    _autoSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_runAutoSyncCycle());
    });

    unawaited(_runAutoSyncCycle());
  }

  void _stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  Future<void> _runAutoSyncCycle() async {
    if (_isAutoSyncRunning || _loggedInUser.value == null) return;

    _isAutoSyncRunning = true;
    try {
      final summary = await _syncParcelsAndBatches();
      if (!summary.hasWork && !summary.hasErrors) return;

      if (summary.hasErrors) {
        _showSnack('Sync issue', summary.message);
      } else if (summary.pushedParcels > 0 || summary.pushedBatches > 0) {
        _showSnack('Sync complete', summary.message);
      }
    } finally {
      _isAutoSyncRunning = false;
    }
  }

  Future<_SyncSummary> _syncParcelsAndBatches() async {
    final summary = _SyncSummary();
    List<Parcel> pulledParcels = <Parcel>[];
    List<Batches> pulledBatches = <Batches>[];
    var parcelsPulled = false;
    var batchesPulled = false;

    try {
      final unsyncedParcels = await _dbHelper.getUnsyncedParcels();
      for (final parcel in unsyncedParcels) {
        try {
          await _apiClient.createParcel(parcel);
          await _dbHelper.updateParcel(parcel.copyWith(isSynced: true));
          summary.pushedParcels++;
        } catch (_) {
          try {
            await _apiClient.updateParcel(parcel);
            await _dbHelper.updateParcel(parcel.copyWith(isSynced: true));
            summary.pushedParcels++;
          } catch (e) {
            summary.failedParcels++;
            if (kDebugMode) {
              debugPrint('Background parcel push failed: $e');
            }
          }
        }
      }
    } catch (e) {
      summary.failedParcels++;
      if (kDebugMode) {
        debugPrint('Background unsynced parcel queue failed: $e');
      }
    }

    try {
      final unsyncedBatches = await _dbHelper.getUnsyncedBatches();
      for (final batch in unsyncedBatches) {
        try {
          await _apiClient.createBatch(batch);
          batch.isSynced = true;
          await _dbHelper.updateBatch(batch);
          summary.pushedBatches++;
        } catch (_) {
          try {
            await _apiClient.updateBatch(batch);
            batch.isSynced = true;
            await _dbHelper.updateBatch(batch);
            summary.pushedBatches++;
          } catch (e) {
            summary.failedBatches++;
            if (kDebugMode) {
              debugPrint('Background batch push failed: $e');
            }
          }
        }
      }
    } catch (e) {
      summary.failedBatches++;
      if (kDebugMode) {
        debugPrint('Background unsynced batch queue failed: $e');
      }
    }

    try {
      pulledParcels = await _apiClient.fetchParcels();
      parcelsPulled = true;
      summary.pulledParcels = pulledParcels.length;
    } catch (e) {
      summary.failedParcels++;
      if (kDebugMode) {
        debugPrint('Background parcel pull failed: $e');
      }
    }

    try {
      pulledBatches = await _apiClient.fetchBatches();
      batchesPulled = true;
      summary.pulledBatches = pulledBatches.length;
    } catch (e) {
      summary.failedBatches++;
      if (kDebugMode) {
        debugPrint('Background batch pull failed: $e');
      }
    }

    if (parcelsPulled) {
      // Protect parcels with unpushed local changes from being reverted by the
      // pull. They were attempted first in the push phase above; any still
      // unsynced must win until they are successfully pushed.
      final pendingDocNos = await _dbHelper.getUnsyncedParcelDocumentNos();
      final attached =
          batchesPulled
              ? _attachBatchNumbersToParcels(pulledParcels, pulledBatches)
              : pulledParcels;
      final parcelsToSave =
          pendingDocNos.isEmpty
              ? attached
              : attached
                  .where(
                    (p) =>
                        !pendingDocNos.contains(
                          (p.Document_No ?? '').trim().toUpperCase(),
                        ),
                  )
                  .toList();
      await _dbHelper.upsertParcels(parcelsToSave);
    }

    if (batchesPulled) {
      final pendingBatchNos = await _dbHelper.getUnsyncedBatchNos();
      final batchesToSave =
          pendingBatchNos.isEmpty
              ? pulledBatches
              : pulledBatches
                  .where(
                    (b) =>
                        !pendingBatchNos.contains(
                          (b.batchNo ?? '').trim().toUpperCase(),
                        ),
                  )
                  .toList();
      await _dbHelper.upsertBatches(batchesToSave);
    }

    if (summary.hasWork) {
      await loadParcels(showLoadingIndicator: false);
      await loadPendingBatches();
      await loadInTransitBatches();
      await loadReceivedParcels();
    }

    return summary;
  }

  List<Parcel> _attachBatchNumbersToParcels(
    List<Parcel> parcels,
    List<Batches> batches,
  ) {
    if (parcels.isEmpty || batches.isEmpty) return parcels;

    final docToBatch = <String, String>{};
    for (final batch in batches) {
      final batchNo = (batch.batchNo ?? '').trim();
      if (batchNo.isEmpty) continue;

      for (final docNo in batch.parcelDocumentNos) {
        final key = docNo.trim().toUpperCase();
        if (key.isEmpty) continue;
        docToBatch.putIfAbsent(key, () => batchNo);
      }
    }

    if (docToBatch.isEmpty) return parcels;

    return parcels.map((parcel) {
      final existingBatch = (parcel.Batch_No ?? '').trim();
      if (existingBatch.isNotEmpty) return parcel;

      final docNo = (parcel.Document_No ?? '').trim();
      if (docNo.isEmpty) return parcel;

      final mappedBatch = docToBatch[docNo.toUpperCase()];
      if (mappedBatch == null || mappedBatch.isEmpty) return parcel;

      return parcel.copyWith(Batch_No: mappedBatch);
    }).toList();
  }

  Future<void> loadPendingBatches() async {
    try {
      final batches = await _dbHelper.getPendingBatches();
      final nonEmptyBatches =
          batches.where((batch) {
            return batch.parcelDocumentNos
                .where((d) => d.trim().isNotEmpty)
                .isNotEmpty;
          }).toList();
      _pendingBatches.assignAll(nonEmptyBatches);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading pending batches: $e');
      }
    }
  }

  Future<void> dispatchBatch(
    Batches batch, {
    String? vehicle,
    String? driver,
  }) async {
    _isLoading.value = true;
    try {
      batch.status = BatchStatus.inTransit;
      batch.dispatchDateTime = DateTime.now();
      batch.updatedAt = DateTime.now();
      if (vehicle != null && vehicle.isNotEmpty) {
        batch.vehicle = vehicle;
      }
      if (driver != null && driver.isNotEmpty) {
        batch.driver = driver;
      }
      await _dbHelper.updateBatch(batch);

      final dispatchedAt = DateTime.now();
      for (final docNo in batch.parcelDocumentNos) {
        if (docNo.trim().isEmpty) continue;
        final parcel = await _dbHelper.getParcel(docNo);
        if (parcel != null) {
          final updated = parcel.copyWith(
            Status: ParcelStatus.inTransit,
            Out_For_Delivery_Time: dispatchedAt,
            Time_Sent: dispatchedAt,
            Vehicle: batch.vehicle,
            Driver: batch.driver,
          );
          await _dbHelper.updateParcel(updated);

          // Sync parcel to backend: create if not yet synced, otherwise update
          if (updated.isSynced) {
            _apiClient.updateParcel(updated).catchError((e) {
              if (kDebugMode)
                debugPrint('Backend sync failed for parcel in batch: $e');
            });
          } else {
            _apiClient
                .createParcel(updated)
                .then((_) async {
                  final synced = updated.copyWith(isSynced: true);
                  await _dbHelper.updateParcel(synced);
                })
                .catchError((e) {
                  if (kDebugMode)
                    debugPrint('Backend create failed for parcel in batch: $e');
                });
          }
        }
      }

      // Sync batch to backend: create if not yet synced, otherwise update
      if (batch.isSynced) {
        _apiClient.updateBatch(batch).catchError((e) {
          if (kDebugMode)
            debugPrint('Backend sync failed for batch dispatch: $e');
        });
      } else {
        _apiClient
            .createBatch(batch)
            .then((_) async {
              batch.isSynced = true;
              await _dbHelper.updateBatch(batch);
            })
            .catchError((e) {
              if (kDebugMode)
                debugPrint('Backend create failed for batch dispatch: $e');
            });
      }

      await loadParcels();
      await loadPendingBatches();
      await loadInTransitBatches();
      _showSnack(
        'Dispatched',
        'Batch ${batch.batchNo ?? ''} is now In Transit.',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error dispatching batch: $e');
      }
      _showSnack('Error', 'Failed to dispatch batch. Please try again.');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> loadInTransitBatches() async {
    try {
      final locations = _locationMatchCandidates();
      if (locations.isEmpty) {
        _inTransitBatches.clear();
        return;
      }
      final batches = await _dbHelper.getInTransitBatchesForLocation(locations);
      final validBatches =
          batches.where((batch) {
            return batch.parcelDocumentNos
                .where((d) => d.trim().isNotEmpty)
                .isNotEmpty;
          }).toList();
      _inTransitBatches.assignAll(validBatches);
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading in-transit batches: $e');
    }
  }

  Future<void> loadReceivedParcels() async {
    try {
      final locations = _locationMatchCandidates();
      if (locations.isEmpty) {
        _receivedParcels.clear();
        return;
      }
      final parcels = await _dbHelper.getReceivedParcelsForLocation(locations);
      _receivedParcels.assignAll(parcels);
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading received parcels: $e');
    }
  }

  /// Location values a batch/parcel destination may be stored as.
  /// NAV stores the location code (e.g. GRATEWALL) while the device may have
  /// the display name (e.g. GreatWall Nairobi), so match against both.
  List<String> _locationMatchCandidates() {
    return <String>[
      _currentLocation.value,
      currentLocationCode,
      currentLocationName,
    ].map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  }

  Future<void> receiveBatch(Batches batch) async {
    final batchNo = batch.batchNo ?? '';
    _receivingBatches.add(batchNo);
    try {
      final location = _currentLocation.value.trim();

      // 1. Update batch status to received
      batch.status = BatchStatus.received;
      batch.receivedDateTime = DateTime.now();
      batch.updatedAt = DateTime.now();
      batch.isSynced = false;
      await _dbHelper.updateBatch(batch);

      // 2. Update all parcels in batch to received
      final smsMessages = <Map<String, String>>[];
      for (final docNo in batch.parcelDocumentNos) {
        if (docNo.trim().isEmpty) continue;
        var parcel = await _dbHelper.getParcel(docNo);

        // Parcel may not exist on this device (created on another device).
        // Pull it from the backend so it can be received and notified.
        if (parcel == null) {
          try {
            final remote = await _apiClient.fetchParcelByDocumentNo(docNo);
            if (remote != null) {
              await _dbHelper.upsertParcels([remote]);
              parcel = remote;
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Failed to fetch parcel $docNo for receive: $e');
            }
          }
        }

        if (parcel != null && parcel.Status != ParcelStatus.received) {
          // Generate a 5-digit OTP for collection
          final otp =
              (10000 + (DateTime.now().millisecondsSinceEpoch % 90000))
                  .toString();

          // Mark unsynced first so a concurrent pull cannot revert this change
          // before it is pushed to the backend.
          final updated = parcel.copyWith(
            Status: ParcelStatus.received,
            Date_Delivered: DateTime.now(),
            Time_Delivered: DateTime.now(),
            isSynced: false,
            Receiver_Code: otp,
          );
          await _dbHelper.updateParcel(updated);

          // Push immediately; on failure the sync cycle retries while the
          // parcel stays unsynced (and protected from pull overwrites).
          try {
            await _apiClient.updateParcel(updated);
            await _dbHelper.updateParcel(updated.copyWith(isSynced: true));
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Backend sync failed for parcel receive: $e');
            }
          }

          // Compose SMS
          final phone = parcel.Receiver_Phone?.trim() ?? '';
          if (phone.isNotEmpty) {
            final name = parcel.Receiver_Name?.trim() ?? 'Customer';
            final doc = parcel.Document_No ?? '';
            final amount = parcel.Amount_Paid ?? 0;
            final isPaid = parcel.Paid == true;
            final msg =
                isPaid
                    ? 'Hello $name, your parcel $doc has arrived at $location. Collection code: $otp. Please come and collect it. Thank you.'
                    : 'Hello $name, your parcel $doc has arrived at $location. Amount due: KES ${amount.toStringAsFixed(0)}. Collection code: $otp. Please pay before collection. Thank you.';
            smsMessages.add({'Phone': phone, 'Message': msg});
          }
        }
      }

      // 3. Send bulk SMS
      if (smsMessages.isNotEmpty) {
        try {
          await _apiClient.sendBulkSms(smsMessages);
          _showSnack(
            'SMS Sent',
            'Notification sent to ${smsMessages.length} receiver(s).',
          );
        } catch (e) {
          if (kDebugMode) debugPrint('SMS send failed: $e');
          _showSnack('SMS Failed', 'Could not send SMS notifications.');
        }
      }

      // 4. Sync batch to backend
      try {
        await _apiClient.updateBatch(batch);
        batch.isSynced = true;
        await _dbHelper.updateBatch(batch);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Backend sync failed for batch receive: $e');
        }
      }

      await loadParcels();
      await loadInTransitBatches();
      await loadReceivedParcels();
      _showSnack('Received', 'Batch ${batch.batchNo ?? ''} has been received.');
    } catch (e) {
      if (kDebugMode) debugPrint('Error receiving batch: $e');
      _showSnack('Error', 'Failed to receive batch. Please try again.');
    } finally {
      _receivingBatches.remove(batchNo);
    }
  }

  Future<void> collectParcel(
    Parcel parcel, {
    required String receivedByPhone,
    required String enteredCode,
    String receivedById = '',
  }) async {
    // Verify the OTP code
    final expectedCode = parcel.Receiver_Code?.trim() ?? '';
    if (expectedCode.isNotEmpty && enteredCode.trim() != expectedCode) {
      _showSnack('Invalid Code', 'The collection code entered does not match.');
      return;
    }

    try {
      final updated = parcel.copyWith(
        Status: ParcelStatus.collected,
        Date_Collected: DateTime.now(),
        Time_Collected: DateTime.now(),
        isSynced: false,
        Received_By_ID: receivedById.trim(),
        Received_By_Phone: receivedByPhone.trim(),
      );
      await _dbHelper.updateParcel(updated);

      try {
        await _apiClient.updateParcel(updated);
        await _dbHelper.updateParcel(updated.copyWith(isSynced: true));
      } catch (e) {
        if (kDebugMode) debugPrint('Backend sync failed for collect: $e');
      }

      await loadParcels(showLoadingIndicator: false);
      await loadReceivedParcels();
      _showSnack(
        'Collected',
        'Parcel ${updated.Document_No ?? ''} has been collected.',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error collecting parcel: $e');
      _showSnack('Error', 'Failed to collect parcel. Please try again.');
    }
  }

  Future<void> payForParcel(BuildContext context, Parcel parcel) async {
    final amount = parcel.Amount_Paid ?? 0;
    if (amount <= 0) {
      // No amount to pay — just mark as paid
      final updated = parcel.copyWith(
        Paid: true,
        paymentMethod: PaymentMethod.cash,
        isSynced: false,
      );
      await _dbHelper.updateParcel(updated);
      try {
        await _apiClient.updateParcel(updated);
        await _dbHelper.updateParcel(updated.copyWith(isSynced: true));
      } catch (e) {
        if (kDebugMode) debugPrint('Backend sync failed for payment: $e');
      }
      await loadParcels();
      await loadReceivedParcels();
      _showSnack('Paid', 'Parcel ${parcel.Document_No ?? ''} marked as paid.');
      return;
    }

    final result = await showMpesaPaymentDialog(
      context: context,
      amount: amount,
      reference: parcel.Document_No,
      senderPhone: parcel.Sender_Phone,
      allowPayLater: false,
    );

    if (result == null) return;

    final (method, receiptCode) = result;
    final isPayLater = method == PaymentMethod.pending;
    final updated = parcel.copyWith(
      Paid: !isPayLater,
      paymentMethod: method,
      mpesaCode: receiptCode,
      isSynced: false,
    );
    await _dbHelper.updateParcel(updated);

    try {
      await _apiClient.updateParcel(updated);
      await _dbHelper.updateParcel(updated.copyWith(isSynced: true));
    } catch (e) {
      if (kDebugMode) debugPrint('Backend sync failed for payment: $e');
    }

    await loadParcels();
    await loadReceivedParcels();

    if (isPayLater) {
      _showSnack(
        'Receiver to Pay',
        'Parcel ${parcel.Document_No ?? ''} marked for payment on collection.',
      );
      if (context.mounted) {
        await _promptPrintReceipt(context, updated);
      }
    } else {
      _showSnack(
        'Payment Recorded',
        'Parcel ${parcel.Document_No ?? ''} is now paid.',
      );
    }
  }

  /// Shows the print receipt dialog for [parcel] and marks it as printed on
  /// success. Used for "Receiver to Pay" parcels so a receipt can be handed
  /// to the sender even though payment will be collected later.
  Future<void> _promptPrintReceipt(BuildContext context, Parcel parcel) async {
    final printed = await showPrintReceiptDialog(
      context: context,
      parcel: parcel,
      onSkip: () {},
    );

    if (printed == true) {
      final marked = parcel.copyWith(receiptPrinted: true, isSynced: false);
      await _dbHelper.updateParcel(marked);
      try {
        await _apiClient.updateParcel(marked);
        await _dbHelper.updateParcel(marked.copyWith(isSynced: true));
      } catch (e) {
        if (kDebugMode) debugPrint('Backend sync failed for receipt print: $e');
      }
      await loadParcels();
      await loadReceivedParcels();
    }
  }

  Future<void> syncReferenceDataOnLogin() async {
    if (_hasSyncedReferenceDataOnLogin) {
      _usersCount.value = await _dbHelper.getUsersCount();
      return;
    }

    final inFlight = _referenceDataSyncFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    _referenceDataSyncFuture = _runReferenceDataSync();
    await _referenceDataSyncFuture;
  }

  Future<void> _runReferenceDataSync() async {
    try {
      await syncUsersOnStartup();
      await syncLocationsOnStartup();
      await syncVehiclesOnStartup();
      _hasSyncedReferenceDataOnLogin = true;
    } finally {
      _referenceDataSyncFuture = null;
    }
  }

  Future<void> syncUsersOnStartup() async {
    _isSyncingUsers.value = true;
    try {
      final List<AppUser> users = await _apiClient.fetchUsers();
      await _dbHelper.replaceUsers(users);
      _usersCount.value = users.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to sync users on startup: $e');
      }
    } finally {
      _usersCount.value = await _dbHelper.getUsersCount();
      _isSyncingUsers.value = false;
    }
  }

  Future<void> syncLocationsOnStartup() async {
    try {
      final List<AppLocation> locations = await _apiClient.fetchLocations();
      await _dbHelper.replaceLocations(locations);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to sync locations on startup: $e');
      }
    }
  }

  Future<void> syncVehiclesOnStartup() async {
    try {
      final List<AppVehicle> vehicles = await _apiClient.fetchVehicles();
      await _dbHelper.replaceVehicles(vehicles);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to sync vehicles on startup: $e');
      }
    }
  }

  Future<void> loadParcels({bool showLoadingIndicator = true}) async {
    if (showLoadingIndicator) {
      _isLoading.value = true;
    }
    try {
      final items = await _dbHelper.getAllParcels();
      _mergeParcels(items);

      // Auto-attach orphaned pending parcels to batches
      final orphans = items.where(
        (p) =>
            p.Status == ParcelStatus.pending &&
            (p.Batch_No == null || p.Batch_No!.isEmpty),
      );
      if (orphans.isNotEmpty) {
        for (final p in orphans) {
          await _assignOrCreateBatch(p);
          await _dbHelper.updateParcel(p);
        }
        final fixed = await _dbHelper.getAllParcels();
        _mergeParcels(fixed);
        await loadPendingBatches();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading parcels: ');
      }
      _parcels.clear();
      _filteredParcels.clear();
      _showSnack('Error', 'Failed to load parcels');
    } finally {
      if (showLoadingIndicator) {
        _isLoading.value = false;
      }
    }
  }

  /// Merges [items] into [_parcels]: updates existing parcels in place
  /// and appends new ones at the end, preserving UI order.
  void _mergeParcels(List<Parcel> items) {
    final itemMap = <String, Parcel>{};
    for (final item in items) {
      final docNo = (item.Document_No ?? '').trim();
      if (docNo.isNotEmpty) itemMap[docNo.toUpperCase()] = item;
    }

    for (var i = 0; i < _parcels.length; i++) {
      final docNo = (_parcels[i].Document_No ?? '').trim().toUpperCase();
      if (itemMap.containsKey(docNo)) {
        _parcels[i] = itemMap[docNo]!;
        itemMap.remove(docNo);
      }
    }

    if (itemMap.isNotEmpty) {
      _parcels.addAll(itemMap.values);
    }

    _filterParcels();
  }

  void setSearchQuery(String query) {
    _searchQuery.value = query;
    _filterParcels();
  }

  void setStatusFilter(ParcelStatus? status) {
    _statusFilter.value = status;
    _filterParcels();
  }

  void _filterParcels() {
    final query = _searchQuery.value.trim().toLowerCase();
    final status = _statusFilter.value;

    Iterable<Parcel> filtered = _parcels;

    if (status != null) {
      filtered = filtered.where(
        (parcel) => (parcel.Status ?? ParcelStatus.pending) == status,
      );
    }

    if (query.isNotEmpty) {
      filtered = filtered.where((parcel) {
        bool matches(String? value) =>
            value?.toLowerCase().contains(query) ?? false;

        return matches(parcel.Document_No) ||
            matches(parcel.Sender_Name) ||
            matches(parcel.Sender_Phone) ||
            matches(parcel.Receiver_Name) ||
            matches(parcel.Receiver_Phone) ||
            matches(parcel.From) ||
            matches(parcel.To) ||
            parcel.parcelDetails.any((detail) => matches(detail.Description));
      });
    }

    _filteredParcels.assignAll(filtered);
  }

  void addParcelDetail() {
    final docNo =
        documentNoController.text.isEmpty ? 'TEMP-' : documentNoController.text;
    parcel ??= _buildEmptyParcel(docNo);
    parcel!.parcelDetails.add(
      Parcel_Details(
        Document_No: docNo,
        Description: '',
        Amount: 0,
        Remarks: '',
      ),
    );
  }

  void addParcelDetailItem({
    required String description,
    required double amount,
    String? remarks,
    int? noOfItems,
  }) {
    final docNo =
        documentNoController.text.isEmpty ? 'TEMP-' : documentNoController.text;
    parcel ??= _buildEmptyParcel(docNo);
    parcel!.parcelDetails.add(
      Parcel_Details(
        Document_No: docNo,
        Description: description,
        Amount: amount,
        Remarks: remarks,
        No_Of_Items: noOfItems,
      ),
    );
  }

  void updateParcelDetail(
    int index, {
    required String description,
    required double amount,
    String? remarks,
    int? noOfItems,
  }) {
    final details = parcel?.parcelDetails;
    if (details == null || index < 0 || index >= details.length) return;
    details[index] = details[index].copyWith(
      Description: description,
      Amount: amount,
      Remarks: remarks,
      No_Of_Items: noOfItems,
    );
  }

  void removeParcelDetail(int index) {
    final details = parcel?.parcelDetails;
    if (details == null || index < 0 || index >= details.length) return;
    details.removeAt(index);
  }

  Future<void> updateParcelStatus(Parcel parcel, ParcelStatus newStatus) async {
    final currentStatus = parcel.Status ?? ParcelStatus.pending;
    if (currentStatus == newStatus) return;

    final currentIndex = _statusOrder.indexOf(currentStatus);
    final nextIndex = _statusOrder.indexOf(newStatus);
    if (nextIndex < currentIndex || nextIndex - currentIndex > 1) {
      _showSnack(
        'Invalid transition',
        'Status can only advance one step at a time.',
      );
      return;
    }

    final updated = parcel.copyWith(
      Status: newStatus,
      Date_Delivered:
          newStatus == ParcelStatus.received
              ? DateTime.now()
              : parcel.Date_Delivered,
      Date_Collected:
          newStatus == ParcelStatus.collected
              ? DateTime.now()
              : parcel.Date_Collected,
    );

    try {
      await _dbHelper.updateParcel(updated);
      final index = _parcels.indexWhere(
        (p) => p.Document_No == updated.Document_No,
      );
      if (index != -1) {
        _parcels[index] = updated;
        _parcels.refresh();
      }
      _filterParcels();

      // Only sync to backend if already dispatched
      if (updated.isSynced) {
        _apiClient.updateParcel(updated).catchError((e) {
          if (kDebugMode)
            debugPrint('Backend sync failed for status update: $e');
        });
      }

      _showSnack(
        'Status updated',
        'Parcel ${updated.Document_No ?? ''} is now ${statusLabel(newStatus)}.',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to update parcel status: ');
      }
      _showSnack('Error', 'Unable to update parcel status. Please try again.');
    }
  }

  Future<void> addParcel(Parcel parcel) async {
    _isLoading.value = true;
    try {
      parcel.Time_Created ??= DateTime.now();
      parcel.deviceId ??= await DeviceIdHelper.instance.getDeviceId();
      parcel.Created_By ??= _loggedInUser.value?.agentCode;
      await _assignOrCreateBatch(parcel);
      await _dbHelper.insertParcel(parcel);

      await loadParcels();
      await loadPendingBatches();
      await loadInTransitBatches();
      await loadReceivedParcels();
      _showSnack('Success', 'Parcel  added successfully.');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding parcel: $e');
      }
      _showSnack('Error', 'Failed to add parcel. Please try again.');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _assignOrCreateBatch(Parcel parcel) async {
    final from = parcel.From?.trim() ?? '';
    final to = parcel.To?.trim() ?? '';
    if (from.isEmpty || to.isEmpty) return;

    final existingBatch = await _dbHelper.getPendingBatchByRoute(from, to);
    if (existingBatch != null) {
      // Attach to existing batch
      parcel.Batch_No = existingBatch.batchNo;
      existingBatch.parcelDocumentNos.add(parcel.Document_No ?? '');
      existingBatch.parcelCount = existingBatch.parcelDocumentNos.length;
      existingBatch.totalAmount =
          (existingBatch.totalAmount ?? 0) + (parcel.Amount_Paid ?? 0);
      existingBatch.updatedAt = DateTime.now();
      await _dbHelper.updateBatch(existingBatch);

      return;
    }

    // Create new batch
    final batchNo = await _generateBatchNumber();
    final user = _loggedInUser.value;
    final now = DateTime.now();
    final newBatch = Batches(
      batchNo: batchNo,
      date: now,
      userAgentCode: user?.agentCode,
      userName: user?.name,
      status: BatchStatus.pending,
      sourceLocation: from,
      destinationLocation: to,
      fromLocation: from,
      toLocation: to,
      parcelDocumentNos: [parcel.Document_No ?? ''],
      parcelCount: 1,
      totalAmount: parcel.Amount_Paid ?? 0,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
    );
    await _dbHelper.insertBatch(newBatch);
    parcel.Batch_No = batchNo;

    // Batch will be synced when dispatched
  }

  Future<String> _generateBatchNumber() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId;
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceId = info.id;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceId = info.identifierForVendor ?? 'IOSDEVICE';
      } else {
        deviceId = 'UNKNOWNDEVICE';
      }
      final sanitized = deviceId
          .replaceAll(RegExp('[^A-Za-z0-9]'), '')
          .padRight(6, 'X');
      final normalized = sanitized.substring(0, 6).toUpperCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final suffix = timestamp.substring(timestamp.length - 6);
      return 'BATCH-$normalized-$suffix';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error generating batch number: $e');
      }
      return 'BATCH-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> updateParcel(Parcel parcel) async {
    _isLoading.value = true;
    try {
      parcel.deviceId ??= await DeviceIdHelper.instance.getDeviceId();
      await _dbHelper.updateParcel(parcel);

      // Only sync to backend if already dispatched
      if (parcel.isSynced) {
        _apiClient.updateParcel(parcel).catchError((e) {
          if (kDebugMode) debugPrint('Backend sync failed for update: $e');
        });
      }

      await loadParcels();
      await loadPendingBatches();
      await loadInTransitBatches();
      await loadReceivedParcels();
      _showSnack('Success', 'Parcel  updated successfully.');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating parcel: ');
      }
      _showSnack('Error', 'Failed to update parcel. Please try again.');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> deleteParcel(String documentNo) async {
    _isLoading.value = true;
    try {
      final parcel = await _dbHelper.getParcel(documentNo);
      await _dbHelper.deleteParcel(documentNo);

      // Only sync to backend if parcel was already dispatched
      if (parcel?.isSynced ?? false) {
        _apiClient.deleteParcel(documentNo).catchError((e) {
          if (kDebugMode) debugPrint('Backend sync failed for delete: $e');
        });
      }

      await loadParcels();
      await loadPendingBatches();
      await loadInTransitBatches();
      await loadReceivedParcels();
      _showSnack('Deleted', 'Parcel  deleted successfully.');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting parcel: ');
      }
      _showSnack('Error', 'Failed to delete parcel. Please try again.');
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _stopAutoSync();
    super.onClose();
  }

  Future<Parcel> newparcel() async {
    final docNo = await _generateDocumentNumber();
    final fresh = _buildEmptyParcel(docNo);
    parcel = fresh;
    populateFormWithParcel(fresh);
    return fresh;
  }

  Future<String> _generateDocumentNumber() async {
    try {
      final now = DateTime.now();
      final rawLocation =
          currentLocationCode.isNotEmpty
              ? currentLocationCode
              : (_currentLocation.value.trim().isNotEmpty
                  ? _currentLocation.value.trim()
                  : 'LOC');
      final locationPart =
          rawLocation.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
      final normalizedLocation =
          locationPart.isEmpty
              ? 'LOC'
              : locationPart.substring(0, locationPart.length.clamp(0, 3));
      final monthDate =
          '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final prefix = '$normalizedLocation$monthDate';
      final nextSerial = await _dbHelper.getNextDocumentSerial(prefix);

      return '$prefix${nextSerial.toString().padLeft(3, '0')}';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error generating document number: ');
      }
      return 'DOC';
    }
  }

  Parcel _buildEmptyParcel(String documentNo) {
    final loggedLocation = _currentLocation.value.trim();
    return Parcel(
      Document_No: documentNo,
      Date_sent: DateTime.now(),
      From: loggedLocation.isNotEmpty ? loggedLocation : null,
      Status: ParcelStatus.pending,
      parcelDetails: <Parcel_Details>[],
    );
  }

  Parcel _buildSampleParcel() {
    return Parcel(
      Document_No: 'PENDING-SAMPLE',
      Date_sent: DateTime.now(),
      Sender_Name: 'Sample Sender',
      Sender_ID: 'S123456',
      Sender_Phone: '0712345678',
      From: 'Nairobi',
      To: 'Mombasa',
      Receiver_Name: 'Sample Receiver',
      Receiver_ID: 'R987654',
      Receiver_Phone: '0798765432',
      Status: ParcelStatus.pending,
      Driver: 'Sample Driver',
      Vehicle: 'KBA 123X',
      Amount_Paid: 0,
      Paid: false,
      Notes: 'Sample data for testing',
    );
  }

  void populateFormWithParcel(Parcel parcel) {
    final loggedLocation = _currentLocation.value.trim();
    final parcelFrom = parcel.From?.trim() ?? '';
    documentNoController.text = parcel.Document_No ?? '';
    senderNameController.text = parcel.Sender_Name ?? '';
    senderIdController.text = parcel.Sender_ID ?? '';
    senderPhoneController.text = parcel.Sender_Phone ?? '';
    fromController.text = parcelFrom.isNotEmpty ? parcelFrom : loggedLocation;
    toController.text = parcel.To ?? '';
    receiverNameController.text = parcel.Receiver_Name ?? '';
    receiverIdController.text = parcel.Receiver_ID ?? '';
    receiverPhoneController.text = parcel.Receiver_Phone ?? '';
    driverController.text = parcel.Driver ?? '';
    vehicleController.text = parcel.Vehicle ?? '';
    amountPaidController.text = (parcel.Amount_Paid ?? 0).toString();
    mpesaCodeController.text = parcel.mpesaCode ?? '';
    selectedStatus = parcel.Status ?? ParcelStatus.pending;
    paymentResponsibility = parcel.Who_to_Pay ?? WhoToPay.Sender;
    paymentMethod = parcel.paymentMethod ?? PaymentMethod.pending;
    selectedDate = parcel.Date_sent ?? DateTime.now();
    paid = parcel.Paid ?? false;
  }

  void PopulateFormWithParcel(Parcel parcel) => populateFormWithParcel(parcel);
}

class _SyncSummary {
  int pushedParcels = 0;
  int pushedBatches = 0;
  int pulledParcels = 0;
  int pulledBatches = 0;
  int failedParcels = 0;
  int failedBatches = 0;

  bool get hasErrors => failedParcels > 0 || failedBatches > 0;
  bool get hasWork =>
      pushedParcels > 0 ||
      pushedBatches > 0 ||
      pulledParcels > 0 ||
      pulledBatches > 0;

  String get message {
    final parts = <String>[
      'Push P:$pushedParcels B:$pushedBatches',
      'Pull P:$pulledParcels B:$pulledBatches',
    ];
    if (hasErrors) {
      parts.add('Failed P:$failedParcels B:$failedBatches');
    }
    return parts.join(' | ');
  }
}

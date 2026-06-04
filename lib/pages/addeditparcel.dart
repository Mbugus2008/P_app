import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/parcel_controller.dart';
import '../database/database_helper.dart';
import '../dialogs/mpesa_payment_dialog.dart';
import '../dialogs/print_receipt_dialog.dart';
import '../models/Parcel_Details.dart';
import '../models/app_location.dart';
import '../models/parcel_model.dart';
import '../utils/app_colors.dart';

typedef PaymentResponsibility = WhoToPay;

class AddEditParcelPage extends StatefulWidget {
  final Parcel? parcel;

  const AddEditParcelPage({super.key, this.parcel});

  @override
  State<AddEditParcelPage> createState() => _AddEditParcelPageState();
}

class _AddEditParcelPageState extends State<AddEditParcelPage> {
  late final ParcelController controller = Get.find<ParcelController>();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Focus nodes for form field navigation
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _senderNameFocusNode = FocusNode();
  final FocusNode _senderPhoneFocusNode = FocusNode();
  final FocusNode _senderIdFocusNode = FocusNode();
  final FocusNode _receiverNameFocusNode = FocusNode();
  final FocusNode _receiverPhoneFocusNode = FocusNode();
  final FocusNode _receiverIdFocusNode = FocusNode();

  bool _isLoadingLocations = false;
  List<AppLocation> _destinationLocations = <AppLocation>[];
  bool _hasSavedParcel = false;
  late bool _isEditingMode;
  bool _showSenderId = false;
  bool _showReceiverId = false;

  @override
  void initState() {
    super.initState();
    _isEditingMode = widget.parcel != null;
    controller.parcel = widget.parcel;
    if (widget.parcel != null) {
      controller.PopulateFormWithParcel(widget.parcel!);
      _showSenderId = controller.senderIdController.text.trim().isNotEmpty;
      _showReceiverId = controller.receiverIdController.text.trim().isNotEmpty;
    }
    _loadDestinationLocations();
  }

  @override
  void dispose() {
    _amountFocusNode.dispose();
    _senderNameFocusNode.dispose();
    _senderPhoneFocusNode.dispose();
    _senderIdFocusNode.dispose();
    _receiverNameFocusNode.dispose();
    _receiverPhoneFocusNode.dispose();
    _receiverIdFocusNode.dispose();
    super.dispose();
  }

  void _showSnackBar(
    String title,
    String message, {
    Color backgroundColor = Colors.green,
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: backgroundColor,
      duration: const Duration(seconds: 3),
    );
  }

  bool _equalsIgnoreCase(String left, String right) {
    return left.toLowerCase() == right.toLowerCase();
  }

  String _locationLabel(AppLocation location) {
    final name = location.name?.trim() ?? '';
    if (name.isEmpty || _equalsIgnoreCase(name, location.code)) {
      return location.code;
    }
    return '${location.code} - $name';
  }

  String? _selectedToLocationCode() {
    final current = controller.toController.text.trim();
    if (current.isEmpty) return null;

    for (final location in _destinationLocations) {
      final code = location.code.trim();
      final name = location.name?.trim() ?? '';
      if (_equalsIgnoreCase(code, current) ||
          (name.isNotEmpty && _equalsIgnoreCase(name, current))) {
        return code;
      }
    }
    return null;
  }

  Future<void> _loadDestinationLocations() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocations = true;
    });

    try {
      var locations = await _dbHelper.getAllLocations();
      if (locations.isEmpty) {
        await controller.syncLocationsOnStartup();
        locations = await _dbHelper.getAllLocations();
      }

      final settingsLocation = controller.currentLocation.trim();
      final loginLocation = (controller.loggedInUser?.location ?? '').trim();
      final currentUserLocation =
          settingsLocation.isNotEmpty ? settingsLocation : loginLocation;

      final filtered =
          locations.where((location) {
            if (currentUserLocation.isEmpty) return true;
            final code = location.code.trim();
            final name = location.name?.trim() ?? '';
            return !_equalsIgnoreCase(code, currentUserLocation) &&
                (name.isEmpty || !_equalsIgnoreCase(name, currentUserLocation));
          }).toList();

      if (!mounted) return;
      setState(() {
        _destinationLocations = filtered;
        _isLoadingLocations = false;
      });

      final selectedCode = _selectedToLocationCode();
      if (selectedCode != null) {
        controller.toController.text = selectedCode;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocations = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.parcel?.receiptPrinted == true;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_hasSavedParcel ? true : null);
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.scaffold,
        appBar: AppBar(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller.documentNoController,
            builder: (context, docValue, _) {
              final documentNo =
                  docValue.text.trim().isEmpty
                      ? 'New Parcel'
                      : docValue.text.trim();
              final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());
              final currentLocation = controller.currentLocation.trim();
              final fallbackLocation =
                  controller.loggedInUser?.location?.trim() ?? '';
              final location =
                  currentLocation.isNotEmpty
                      ? currentLocation
                      : (fallbackLocation.isNotEmpty
                          ? fallbackLocation
                          : 'Unknown');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    documentNo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$dateStr | $location',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            if (isLocked)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 16, color: Colors.white70),
                    SizedBox(width: 4),
                    Text(
                      'Locked',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AbsorbPointer(
                    absorbing: isLocked,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildParcelSection(context),
                          const SizedBox(height: 4),
                          _buildSenderSection(context),
                          const SizedBox(height: 4),
                          _buildReceiverSection(context),
                          const SizedBox(height: 4),
                          _buildDetailsSection(context),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: keyboardInset),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    decoration: BoxDecoration(
                      color: AppColors.scaffold,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed:
                                  isLocked
                                      ? null
                                      : () async {
                                        if (controller.formKey.currentState!
                                            .validate()) {
                                          await _submitForm();
                                        }
                                      },
                              icon: Icon(
                                _isEditingMode
                                    ? Icons.save_rounded
                                    : Icons.check_circle_outline,
                              ),
                              label: Text(
                                _isEditingMode
                                    ? 'Update Parcel'
                                    : 'Save Parcel',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _handlePayAction,
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Pay'),
                            ),
                          ),
                        ),
                        if (_hasSavedParcel || _isEditingMode) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 52,
                            width: 52,
                            child: OutlinedButton(
                              onPressed: _handlePrintReceipt,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Icon(Icons.print, size: 22),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePayAction() async {
    // Require the parcel to be saved before accepting payment
    if (!_hasSavedParcel && !_isEditingMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save the parcel first before making a payment'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final amount = double.tryParse(controller.amountPaidController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an amount first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final docNo = controller.documentNoController.text.trim();
    final result = await showMpesaPaymentDialog(
      context: context,
      amount: amount,
      reference: docNo.isEmpty ? null : docNo,
      senderPhone: controller.senderPhoneController.text.trim(),
    );

    if (result == null) {
      return;
    }

    final (method, receipt) = result;
    setState(() {
      controller.paymentMethod = method;
      controller.paid = true;
      if (method == PaymentMethod.mpesa && receipt != null) {
        controller.mpesaCodeController.text = receipt;
      } else {
        controller.mpesaCodeController.clear();
      }
    });

    // Persist payment for both cash and M-Pesa before showing receipt flow.
    if (controller.formKey.currentState!.validate()) {
      await _submitForm();
    }

    if (mounted && controller.parcel != null) {
      final printed = await showPrintReceiptDialog(
        context: context,
        parcel: controller.parcel!,
        onSkip: () {},
      );
      if (printed == true && mounted) {
        setState(() {
          controller.parcel!.receiptPrinted = true;
        });
        await controller.updateParcel(controller.parcel!);
      }
    }
  }

  Future<void> _handlePrintReceipt() async {
    if (controller.parcel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No parcel data to print'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Mark as printed when the print dialog is opened
    if (!controller.parcel!.receiptPrinted) {
      setState(() {
        controller.parcel!.receiptPrinted = true;
      });
      await controller.updateParcel(controller.parcel!);
    }

    await showPrintReceiptDialog(
      context: context,
      parcel: controller.parcel!,
      onSkip: () {},
    );

    // Dialog stays open after prints; refresh parcel state when closed
    if (mounted && controller.parcel != null) {
      await controller.updateParcel(controller.parcel!);
    }
  }

  Widget _buildSectionCard(
    BuildContext context, {
    IconData? icon,
    String? title,
    String? subtitle,
    List<Widget> children = const [],
    Widget? trailing,
    bool showHeader = true,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary.withValues(alpha: 0.12),
                    ),
                    child: Icon(icon, color: AppColors.secondary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? '',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            if (children.isNotEmpty) ...[
              if (showHeader) const SizedBox(height: 16),
              ...children,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParcelSection(BuildContext context) {
    return _buildSectionCard(
      context,
      showHeader: false,
      children: [
        _buildToLocationDropdown(),
        const SizedBox(height: 16),
        _buildTextField(
          controller: controller.amountPaidController,
          focusNode: _amountFocusNode,
          label: 'Amount Paid',
          isRequired: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          onSubmitted:
              () => _focusAndSelect(
                _senderNameFocusNode,
                controller.senderNameController,
              ),
          decoration: const InputDecoration(prefixText: 'Ksh '),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Amount paid is required';
            }
            final amount = double.tryParse(value.trim());
            if (amount == null || amount <= 0) {
              return 'Enter a valid amount';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildToLocationDropdown() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller.toController,
      builder: (context, _, __) {
        final selectedCode = _selectedToLocationCode();

        return DropdownButtonFormField<String>(
          initialValue: selectedCode,
          isExpanded: true,
          hint: Text(
            _isLoadingLocations
                ? 'Loading destinations...'
                : 'To (Destination)',
          ),
          decoration: const InputDecoration(
            labelText: 'To (Destination)',
            prefixIcon: Icon(Icons.location_on),
            suffixIcon: Icon(
              Icons.star_rounded,
              size: 16,
              color: Colors.redAccent,
            ),
          ),
          items:
              _destinationLocations
                  .map(
                    (location) => DropdownMenuItem<String>(
                      value: location.code,
                      child: Text(
                        _locationLabel(location),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          onChanged:
              _isLoadingLocations || _destinationLocations.isEmpty
                  ? null
                  : (value) {
                    controller.toController.text = value?.trim() ?? '';
                    // Move focus to amount field and select all
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _amountFocusNode.requestFocus();
                      controller.amountPaidController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset:
                            controller.amountPaidController.text.length,
                      );
                    });
                  },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'To destination is required';
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildSenderSection(BuildContext context) {
    return _buildSectionCard(
      context,
      icon: Icons.person_pin_circle_outlined,
      title: 'Sender',

      children: [
        _buildTextField(
          controller: controller.senderPhoneController,
          focusNode: _senderPhoneFocusNode,
          label: 'Sender Phone',
          prefixIcon: Icons.phone,
          isRequired: true,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          onSubmitted:
              () => _focusAndSelect(
                _senderNameFocusNode,
                controller.senderNameController,
              ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Sender Phone is required';
            }
            if (value.trim().length < 9) {
              return 'Minimum 9 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextField(
                controller: controller.senderNameController,
                focusNode: _senderNameFocusNode,
                label: 'Sender Name',
                prefixIcon: Icons.person,
                textInputAction: TextInputAction.next,
                onSubmitted:
                    () =>
                        _showSenderId
                            ? _focusAndSelect(
                              _senderIdFocusNode,
                              controller.senderIdController,
                            )
                            : _focusAndSelect(
                              _receiverPhoneFocusNode,
                              controller.receiverPhoneController,
                            ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: _showSenderId ? 'Hide Sender ID' : 'Add Sender ID',
              icon: Icon(_showSenderId ? Icons.expand_less : Icons.more_horiz),
              onPressed: () => setState(() => _showSenderId = !_showSenderId),
            ),
          ],
        ),
        if (_showSenderId) ...[
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.senderIdController,
            focusNode: _senderIdFocusNode,
            label: 'Sender ID / Passport',
            prefixIcon: Icons.credit_card,
            textInputAction: TextInputAction.next,
            onSubmitted:
                () => _focusAndSelect(
                  _receiverPhoneFocusNode,
                  controller.receiverPhoneController,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildReceiverSection(BuildContext context) {
    return _buildSectionCard(
      context,
      icon: Icons.person_outline,
      title: 'Receiver',
      subtitle: 'Who is expecting the parcel?',
      children: [
        _buildTextField(
          controller: controller.receiverPhoneController,
          focusNode: _receiverPhoneFocusNode,
          label: 'Receiver Phone',
          prefixIcon: Icons.phone_outlined,
          isRequired: true,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          onSubmitted:
              () => _focusAndSelect(
                _receiverNameFocusNode,
                controller.receiverNameController,
              ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Receiver Phone is required';
            }
            if (value.trim().length < 9) {
              return 'Minimum 9 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextField(
                controller: controller.receiverNameController,
                focusNode: _receiverNameFocusNode,
                label: 'Receiver Name',
                prefixIcon: Icons.person_outline,
                textInputAction:
                    _showReceiverId
                        ? TextInputAction.next
                        : TextInputAction.done,
                onSubmitted:
                    () =>
                        _showReceiverId
                            ? _focusAndSelect(
                              _receiverIdFocusNode,
                              controller.receiverIdController,
                            )
                            : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: _showReceiverId ? 'Hide Receiver ID' : 'Add Receiver ID',
              icon: Icon(
                _showReceiverId ? Icons.expand_less : Icons.more_horiz,
              ),
              onPressed:
                  () => setState(() => _showReceiverId = !_showReceiverId),
            ),
          ],
        ),
        if (_showReceiverId) ...[
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.receiverIdController,
            focusNode: _receiverIdFocusNode,
            label: 'Receiver ID / Passport',
            prefixIcon: Icons.perm_identity,
            textInputAction: TextInputAction.done,
          ),
        ],
      ],
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    final parcel = controller.parcel ??= Parcel();
    final details = parcel.parcelDetails;
    return _buildSectionCard(
      context,
      icon: Icons.list_alt_outlined,
      title: 'Parcel Items',
      subtitle: 'Breakdown of contents and values',
      trailing: IconButton(
        onPressed: () => _showAddParcelDetailDialog(context),
        icon: const Icon(Icons.add_circle_outline),
      ),
      children: [
        TextFormField(
          initialValue: parcel.Details ?? '',
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: 'Parcel Description',
            prefixIcon: Icon(Icons.description_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Parcel description is required';
            }
            return null;
          },
          onChanged: (value) => controller.parcel!.Details = value,
        ),
        const SizedBox(height: 16),
        if (details.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text(
              'No parcel items yet. Tap the + button to add.',
              style: TextStyle(color: Colors.black54),
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < details.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == details.length - 1 ? 0 : 12,
                  ),
                  child: _buildParcelDetailTile(context, details[i], i),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildParcelDetailTile(
    BuildContext context,
    Parcel_Details detail,
    int index,
  ) {
    final noOfItems = (detail.No_Of_Items ?? 0) > 0 ? detail.No_Of_Items! : 1;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showEditParcelDetailDialog(context, detail, index),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No of item: $noOfItems',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail.Description?.isNotEmpty == true
                        ? detail.Description!
                        : 'No description provided',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (detail.Remarks?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      detail.Remarks!,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () {
                controller.removeParcelDetail(index);
                setState(() {});
              },
              tooltip: 'Remove item',
            ),
          ],
        ),
      ),
    );
  }

  void _focusAndSelect(FocusNode focusNode, TextEditingController ctrl) {
    FocusScope.of(context).requestFocus(focusNode);
    ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: ctrl.text.length,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    InputDecoration? decoration,
    IconData? prefixIcon,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    void Function()? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      readOnly: readOnly,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
      decoration: (decoration ?? const InputDecoration()).copyWith(
        labelText: label,
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon) : decoration?.prefixIcon,
        suffixIcon:
            isRequired
                ? const Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: Colors.redAccent,
                )
                : decoration?.suffixIcon,
      ),
      validator:
          validator ??
          (isRequired
              ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label is required';
                }
                return null;
              }
              : null),
    );
  }

  Future<void> _showAddParcelDetailDialog(BuildContext context) async {
    await _showParcelDetailDialog(context: context);
  }

  Future<void> _showEditParcelDetailDialog(
    BuildContext context,
    Parcel_Details parcelDetail,
    int index,
  ) async {
    await _showParcelDetailDialog(
      context: context,
      existing: parcelDetail,
      index: index,
    );
  }

  Future<void> _showParcelDetailDialog({
    required BuildContext context,
    Parcel_Details? existing,
    int? index,
  }) async {
    final isEditing = existing != null && index != null;
    final descCtrl = TextEditingController(text: existing?.Description ?? '');
    final noOfItemsCtrl = TextEditingController(
      text:
          (existing?.No_Of_Items ?? 0) <= 0
              ? '1'
              : (existing!.No_Of_Items!).toString(),
    );
    final remarksCtrl = TextEditingController(text: existing?.Remarks ?? '');
    final formKey = GlobalKey<FormState>();
    final descFocus = FocusNode();

    final saved = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          descFocus.requestFocus();
        });
        return AlertDialog(
          title: Text(isEditing ? 'Edit Item' : 'Add Item'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: descCtrl,
                    focusNode: descFocus,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Description is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noOfItemsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'No of items',
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                    validator: (value) {
                      final count = int.tryParse(value?.trim() ?? '');
                      if (count == null || count <= 0) {
                        return 'Enter a valid number of items';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: remarksCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Remarks (optional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(ctx).unfocus();
                Navigator.pop(ctx, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  FocusScope.of(ctx).unfocus();
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      final amount = existing?.Amount ?? 0.0;
      final noOfItems = int.tryParse(noOfItemsCtrl.text.trim()) ?? 1;
      if (isEditing) {
        controller.updateParcelDetail(
          index,
          description: descCtrl.text.trim(),
          amount: amount,
          remarks: remarksCtrl.text.trim(),
          noOfItems: noOfItems,
        );
      } else {
        controller.addParcelDetailItem(
          description: descCtrl.text.trim(),
          amount: amount,
          remarks: remarksCtrl.text.trim(),
          noOfItems: noOfItems,
        );
      }
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }

    // Dispose after dialog pop animation settles to avoid widget lifecycle races.
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      descCtrl.dispose();
      noOfItemsCtrl.dispose();
      remarksCtrl.dispose();
      descFocus.dispose();
    });
  }

  Future<void> _submitForm() async {
    try {
      final existing = await _dbHelper.getParcel(
        controller.documentNoController.text,
      );

      final parcel = Parcel(
        Document_No: controller.documentNoController.text,
        Date_sent: controller.selectedDate,
        Sender_Name: controller.senderNameController.text,
        Sender_ID: controller.senderIdController.text,
        Sender_Phone: controller.senderPhoneController.text,
        From: controller.fromController.text,
        To: controller.toController.text,
        Receiver_Name: controller.receiverNameController.text,
        Receiver_ID: controller.receiverIdController.text,
        Receiver_Phone: controller.receiverPhoneController.text,
        Status: controller.selectedStatus,
        Driver: controller.driverController.text,
        Vehicle: controller.vehicleController.text,
        Who_to_Pay: controller.paymentResponsibility,
        Amount_Paid:
            double.tryParse(controller.amountPaidController.text) ?? 0.0,
        Paid: controller.paid,
        paymentMethod: controller.paymentMethod,
        mpesaCode: controller.mpesaCodeController.text.trim(),
        Batch_No: existing?.Batch_No,
        Date_Collected: controller.parcel?.Date_Collected,
        Date_Delivered: controller.parcel?.Date_Delivered,
        Details: controller.parcel?.Details,
        parcelDetails: controller.parcel?.parcelDetails,
      );

      if (existing != null) {
        await controller.updateParcel(parcel);
        _hasSavedParcel = true;
        _isEditingMode = true;
        _showSnackBar('Success', 'Parcel updated successfully!');
        await Future.delayed(const Duration(seconds: 1));
        Get.back(result: true);
      } else {
        await controller.addParcel(parcel);
        _hasSavedParcel = true;
        controller.parcel = parcel;
        if (mounted) {
          setState(() {
            _isEditingMode = true;
          });
        }
        _showSnackBar('Success', 'Parcel added successfully!');
      }
    } catch (e) {
      _showSnackBar(
        'Error',
        'Failed to save parcel: $e',
        backgroundColor: Colors.red,
      );
    }
  }
}

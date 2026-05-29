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

  @override
  void initState() {
    super.initState();
    _isEditingMode = widget.parcel != null;
    controller.parcel = widget.parcel;
    if (widget.parcel != null) {
      controller.PopulateFormWithParcel(widget.parcel!);
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
              )
            else
              TextButton(
                onPressed: () async {
                  final amount =
                      double.tryParse(controller.amountPaidController.text) ??
                      0;
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
                  if (result != null) {
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
                    if (method == PaymentMethod.cash &&
                        controller.formKey.currentState!.validate()) {
                      await _submitForm();
                    }
                    // Show receipt print dialog after payment
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
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text(
                  'Pay',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: AbsorbPointer(
            absorbing: isLocked,
            child: Form(
              key: controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
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
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(bottom: keyboardInset),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      decoration: BoxDecoration(
                        color: AppColors.scaffold,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (controller.formKey.currentState!.validate()) {
                              await _submitForm();
                            }
                          },
                          icon: Icon(
                            _isEditingMode
                                ? Icons.save_rounded
                                : Icons.check_circle_outline,
                          ),
                          label: Text(
                            _isEditingMode ? 'Update Parcel' : 'Save Parcel',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
          controller: controller.senderNameController,
          focusNode: _senderNameFocusNode,
          label: 'Sender Name',
          prefixIcon: Icons.person,
          textInputAction: TextInputAction.next,
          onSubmitted:
              () => _focusAndSelect(
                _senderPhoneFocusNode,
                controller.senderPhoneController,
              ),
        ),
        const SizedBox(height: 16),
        _buildInlineFields(context, [
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
                  _senderIdFocusNode,
                  controller.senderIdController,
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
          _buildTextField(
            controller: controller.senderIdController,
            focusNode: _senderIdFocusNode,
            label: 'Sender ID / Passport',
            prefixIcon: Icons.credit_card,
            textInputAction: TextInputAction.next,
            onSubmitted:
                () => _focusAndSelect(
                  _receiverNameFocusNode,
                  controller.receiverNameController,
                ),
          ),
        ]),
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
          controller: controller.receiverNameController,
          focusNode: _receiverNameFocusNode,
          label: 'Receiver Name',
          prefixIcon: Icons.person_outline,
          textInputAction: TextInputAction.next,
          onSubmitted:
              () => _focusAndSelect(
                _receiverPhoneFocusNode,
                controller.receiverPhoneController,
              ),
        ),
        const SizedBox(height: 16),
        _buildInlineFields(context, [
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
                  _receiverIdFocusNode,
                  controller.receiverIdController,
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
          _buildTextField(
            controller: controller.receiverIdController,
            focusNode: _receiverIdFocusNode,
            label: 'Receiver ID / Passport',
            prefixIcon: Icons.perm_identity,
            textInputAction: TextInputAction.done,
          ),
        ]),
      ],
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    final details = controller.parcel?.parcelDetails ?? <Parcel_Details>[];
    final total = details.fold<double>(
      0,
      (sum, item) => sum + (item.Amount ?? 0.0),
    );

    return _buildSectionCard(
      context,
      icon: Icons.list_alt_outlined,
      title: 'Parcel Items',
      subtitle: 'Breakdown of contents and values',
      trailing: IconButton(
        onPressed: () {
          controller.addParcelDetail();
          setState(() {});
        },
        icon: const Icon(Icons.add_circle_outline),
      ),
      children: [
        Row(
          children: [
            _buildSummaryPill(label: 'Items', value: '${details.length}'),
            const SizedBox(width: 12),
            _buildSummaryPill(
              label: 'Total',
              value: 'KES ${total.toStringAsFixed(0)}',
            ),
          ],
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

  Widget _buildInlineFields(BuildContext context, List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          return Column(
            children: [
              for (var i = 0; i < fields.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == fields.length - 1 ? 0 : 16,
                  ),
                  child: fields[i],
                ),
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < fields.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == fields.length - 1 ? 0 : 16,
                  ),
                  child: fields[i],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryPill({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.secondary.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildParcelDetailTile(
    BuildContext context,
    Parcel_Details detail,
    int index,
  ) {
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'KES ${(detail.Amount ?? 0).toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () {
                    // controller.removeParcelDetail(index);
                  },
                  tooltip: 'Remove item',
                ),
              ],
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

  Future<void> _showEditParcelDetailDialog(
    BuildContext context,
    Parcel_Details parcelDetail,
    int index,
  ) async {
    final descCtrl = TextEditingController(text: parcelDetail.Description);
    final amountCtrl = TextEditingController(
      text: parcelDetail.Amount?.toString(),
    );
    final remarksCtrl = TextEditingController(text: parcelDetail.Remarks);

    await showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            insetPadding: EdgeInsets.zero,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: Scaffold(
                appBar: AppBar(title: const Text('Edit Parcel Detail')),
                body: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: descCtrl,
                          maxLines: null,
                          minLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                        ),
                        TextField(
                          controller: amountCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        TextField(
                          controller: remarksCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Remarks',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                bottomNavigationBar: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // controller.updateParcelDetail(
                          //   index,
                          //   descCtrl.text,
                          //   double.tryParse(amountCtrl.text) ?? 0.0,
                          //   remarksCtrl.text,
                          // );
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
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

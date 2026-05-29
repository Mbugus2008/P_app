import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/parcel_model.dart';
import '../utilities/Apis.dart';
import '../utils/app_colors.dart';

/// Shows a payment dialog with Cash / M-Pesa selection and M-Pesa sub-tabs.
///
/// Returns `(PaymentMethod, receiptCode)` if a payment method is confirmed.
///   - Cash: `(PaymentMethod.cash, null)`
///   - M-Pesa with receipt: `(PaymentMethod.mpesa, "SOME_CODE")`
/// Returns `null` if the dialog is dismissed without confirming.
Future<(PaymentMethod, String?)?> showMpesaPaymentDialog({
  required BuildContext context,
  required double amount,
  required String? reference,
  String? senderPhone,
}) {
  return showDialog<(PaymentMethod, String?)>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => MpesaPaymentDialog(
      amount: amount,
      reference: reference,
      senderPhone: senderPhone,
    ),
  );
}

class MpesaPaymentDialog extends StatefulWidget {
  final double amount;
  final String? reference;
  final String? senderPhone;

  const MpesaPaymentDialog({
    super.key,
    required this.amount,
    required this.reference,
    this.senderPhone,
  });

  @override
  State<MpesaPaymentDialog> createState() => _MpesaPaymentDialogState();
}

class _MpesaPaymentDialogState extends State<MpesaPaymentDialog> {
  PaymentMethod _selectedMethod = PaymentMethod.mpesa;
  int _mpesaTabIndex = 0;

  // Tab 1 — Receipt
  final _receiptController = TextEditingController();
  final _receiptFormKey = GlobalKey<FormState>();

  // Tab 2 — STK Push
  final _phoneController = TextEditingController();
  bool _stkLoading = false;
  String? _stkMessage;
  String? _checkoutRequestId;
  bool _stkPolling = false;
  Timer? _stkPollTimer;

  // Tab 3 — QR Code
  bool _qrLoading = false;
  String? _qrBase64;
  String? _qrError;
  String? _qrReference;
  bool _qrPolling = false;
  Timer? _qrPollTimer;
  String? _qrReceipt;

  @override
  void initState() {
    super.initState();
    if (widget.senderPhone != null && widget.senderPhone!.trim().isNotEmpty) {
      _phoneController.text = widget.senderPhone!.trim();
    }
  }

  @override
  void dispose() {
    _stkPollTimer?.cancel();
    _qrPollTimer?.cancel();
    _receiptController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _setMethod(PaymentMethod method) {
    if (_selectedMethod == method) return;
    setState(() => _selectedMethod = method);
  }

  void _confirmCash() {
    Navigator.of(context).pop((PaymentMethod.cash, null));
  }

  void _confirmReceipt() {
    if (_receiptFormKey.currentState?.validate() ?? false) {
      Navigator.of(context)
          .pop((PaymentMethod.mpesa, _receiptController.text.trim()));
    }
  }

  Future<void> _sendStkPush() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _stkMessage = 'Please enter a phone number');
      return;
    }
    setState(() {
      _stkLoading = true;
      _stkMessage = null;
      _checkoutRequestId = null;
      _stkPolling = false;
    });
    _stkPollTimer?.cancel();

    try {
      final api = ApiClient();
      final result = await api.initiateStkPush(
        amount: widget.amount,
        phoneNumber: phone,
        reference: widget.reference ?? widget.amount.toStringAsFixed(0),
      );

      _checkoutRequestId = result['checkoutRequestId'] as String?;
      final customerMessage = result['customerMessage'] as String? ?? 'STK push sent successfully';

      setState(() {
        _stkLoading = false;
        _stkMessage = '$customerMessage\n\nPhone: $phone\nAmount: KES ${widget.amount.toStringAsFixed(0)}';
        _stkPolling = _checkoutRequestId != null;
      });

      if (_checkoutRequestId != null) {
        _startStkPolling();
      }
    } catch (e) {
      setState(() {
        _stkLoading = false;
        _stkMessage = 'Failed to send STK push: $e';
        _stkPolling = false;
      });
    }
  }

  void _startStkPolling() {
    _stkPollTimer?.cancel();
    _stkPollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_checkoutRequestId == null || !_stkPolling) {
        timer.cancel();
        return;
      }

      try {
        final api = ApiClient();
        final status = await api.checkStkStatus(_checkoutRequestId!);

        if (status == null) return;

        final resultCode = status['resultCode'] as int? ?? -1;
        final resultDesc = status['resultDesc'] as String? ?? 'Unknown status';
        final receipt = status['mpesaReceiptNumber'] as String?;

        if (resultCode == 0) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _stkPolling = false;
              _stkMessage = 'Payment successful!\nReceipt: $receipt';
            });
            // Show success for 1.5 seconds before auto-closing
            await Future.delayed(const Duration(milliseconds: 1500));
            if (mounted) {
              Navigator.of(context).pop((PaymentMethod.mpesa, receipt));
            }
          }
        } else if (resultCode == 1032 || resultCode == 1037) {
          timer.cancel();
          setState(() {
            _stkPolling = false;
            _stkMessage = 'Payment cancelled or timed out.\n$resultDesc';
          });
        }
      } catch (e) {
        // Silently ignore polling errors
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Payment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Payment method selector
              Container(
                color: AppColors.scaffold,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select payment method',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildMethodChip(
                          label: 'Cash',
                          icon: Icons.payments_outlined,
                          selected: _selectedMethod == PaymentMethod.cash,
                          onTap: () => _setMethod(PaymentMethod.cash),
                        ),
                        const SizedBox(width: 12),
                        _buildMethodChip(
                          label: 'M-Pesa',
                          icon: Icons.phone_android,
                          selected: _selectedMethod == PaymentMethod.mpesa,
                          onTap: () => _setMethod(PaymentMethod.mpesa),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Tabs — only for M-Pesa
              if (_selectedMethod == PaymentMethod.mpesa)
                Container(
                  color: AppColors.scaffold,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      _buildMpesaTab(0, Icons.receipt_long, 'Receipt'),
                      const SizedBox(width: 8),
                      _buildMpesaTab(1, Icons.phone_android, 'STK Push'),
                      const SizedBox(width: 8),
                      _buildMpesaTab(2, Icons.qr_code, 'QR Code'),
                    ],
                  ),
                ),
              // Content area
              Expanded(
                child: _selectedMethod == PaymentMethod.cash
                    ? _buildCashTab()
                    : IndexedStack(
                        index: _mpesaTabIndex,
                        children: [
                          _buildReceiptTab(),
                          _buildStkPushTab(),
                          _buildQrCodeTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMpesaTab(int index, IconData icon, String label) {
    final selected = _mpesaTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _mpesaTabIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade300,
              width: 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: selected ? 20 : 18,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: selected ? 14 : 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.payments_outlined,
            size: 48,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Cash Payment',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confirm that the customer has paid in cash.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          if (widget.amount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.scaffold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Amount: KES ${widget.amount.toStringAsFixed(0)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _confirmCash,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm Cash Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _receiptFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter M-Pesa receipt code',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'The code from the customer\'s M-Pesa confirmation SMS or pop-up.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _receiptController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Receipt / Transaction Code',
                prefixIcon: const Icon(Icons.confirmation_number),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.scaffold,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the receipt code';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _confirmReceipt,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStkPushTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Send STK push to customer',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Customer receives an M-Pesa prompt on their phone to enter PIN.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            enabled: !_stkLoading && !_stkPolling && _stkMessage?.startsWith('Payment successful') != true,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: 'e.g. 254712345678',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.scaffold,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.amount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.scaffold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.payments_outlined,
                      size: 16, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'Amount: KES ${widget.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (_stkLoading || _stkPolling || _stkMessage?.startsWith('Payment successful') == true) ? null : _sendStkPush,
              icon: _stkLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_stkLoading ? 'Sending…' : 'Send STK Push'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_stkPolling) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Waiting for customer to enter PIN on their phone...',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_stkMessage != null && !_stkPolling) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _stkMessage!.startsWith('Payment successful')
                    ? Colors.green.withValues(alpha: 0.08)
                    : AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _stkMessage!.startsWith('Payment successful')
                      ? Colors.green.withValues(alpha: 0.4)
                      : AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _stkMessage!.startsWith('Payment successful')
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    size: 18,
                    color: _stkMessage!.startsWith('Payment successful')
                        ? Colors.green
                        : AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _stkMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _stkMessage!.startsWith('Payment successful')
                            ? Colors.green.shade800
                            : AppColors.success,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generateQrCode() async {
    setState(() {
      _qrLoading = true;
      _qrError = null;
      _qrReceipt = null;
      _qrPolling = false;
    });
    _qrPollTimer?.cancel();

    // Generate a unique reference for this QR so we can track the C2B payment
    _qrReference = 'QR-${widget.reference ?? ''}-${DateTime.now().millisecondsSinceEpoch}';
    // Keep it within Safaricom's reasonable limits
    if (_qrReference!.length > 20) {
      _qrReference = 'QR${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    }

    try {
      final api = ApiClient();
      final base64 = await api.generateMpesaQrCode(
        amount: widget.amount,
        reference: _qrReference,
      );
      setState(() {
        _qrBase64 = base64;
        _qrLoading = false;
        _qrPolling = true;
      });
      _startQrPolling();
    } catch (e) {
      setState(() {
        _qrError = e.toString();
        _qrLoading = false;
        _qrPolling = false;
      });
    }
  }

  void _startQrPolling() {
    _qrPollTimer?.cancel();
    _qrPollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_qrReference == null || !_qrPolling) {
        timer.cancel();
        return;
      }

      try {
        final api = ApiClient();
        final result = await api.checkC2BTransaction(_qrReference!);

        if (result == null) return;

        final code = result['code'] as int? ?? -1;
        if (code == 0) {
          final contents = result['contents'] as Map<String, dynamic>?;
          final receipt = contents?['transID'] as String?;
          timer.cancel();
          if (mounted) {
            setState(() {
              _qrPolling = false;
              _qrReceipt = receipt;
            });
            // Show success briefly before closing
            await Future.delayed(const Duration(milliseconds: 1500));
            if (mounted) {
              Navigator.of(context).pop((PaymentMethod.mpesa, receipt));
            }
          }
        }
      } catch (e) {
        // Silently ignore polling errors
      }
    });
  }

  Widget _buildQrCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Scan to pay',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Generate a real M-Pesa QR code for the customer to scan.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          if (_qrBase64 != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black12),
                ),
                child: Image.memory(
                  base64Decode(_qrBase64!),
                  width: 280,
                  height: 280,
                  fit: BoxFit.contain,
                ),
              ),
            )
          else if (_qrLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_qrError != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to generate QR code',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _qrError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _generateQrCode,
                icon: const Icon(Icons.qr_code),
                label: const Text('Generate M-Pesa QR Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          if (_qrPolling) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Waiting for customer to scan and pay...',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_qrReceipt != null && !_qrPolling) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment successful!\nReceipt: $_qrReceipt',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_qrBase64 != null && !_qrPolling && _qrReceipt == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.scaffold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQrInfoRow('Amount', 'KES ${widget.amount.toStringAsFixed(0)}'),
                  const SizedBox(height: 4),
                  _buildQrInfoRow('Reference', _qrReference ?? '-'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMethodChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.primary : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.primary : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

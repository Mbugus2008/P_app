import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/parcel_controller.dart';
import '../database/database_helper.dart';
import '../utilities/Apis.dart';
import '../utils/app_colors.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _apiClient = ApiClient();
  final _dbHelper = DatabaseHelper();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _error;

  ParcelController get _controller => Get.find<ParcelController>();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentController.text.trim();
    final newPassword = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    if (current.isEmpty) {
      setState(() => _error = 'Enter your current password.');
      return;
    }
    if (newPassword.length < 4) {
      setState(() => _error = 'New password must be at least 4 characters.');
      return;
    }
    if (newPassword != confirm) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }
    if (newPassword == current) {
      setState(() => _error = 'New password must be different from the current one.');
      return;
    }

    final user = _controller.loggedInUser;
    if (user == null || user.agentCode.trim().isEmpty) {
      setState(() => _error = 'You are not logged in.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _apiClient.changeUserPassword(
        agentCode: user.agentCode,
        password: newPassword,
        oldPassword: current,
      );
      // Keep the local user record in sync so offline login uses the new password.
      await _dbHelper.updateUserPassword(
        agentCode: user.agentCode,
        password: newPassword,
      );

      if (!mounted) return;
      Get.back();
      Get.snackbar('Success', 'Password changed successfully.');
    } catch (e) {
      final message = e.toString();
      setState(
        () => _error = message.toLowerCase().contains('current password')
            ? 'Current password is incorrect.'
            : 'Could not change password. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    TextInputAction action = TextInputAction.next,
    void Function()? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: action,
      onFieldSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'Update your login password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              _buildPasswordField(
                controller: _currentController,
                label: 'Current Password',
                obscure: _obscureCurrent,
                onToggle: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
                onSubmitted: () => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _newController,
                label: 'New Password',
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                onSubmitted: () => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _confirmController,
                label: 'Confirm New Password',
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                action: TextInputAction.done,
                onSubmitted: _isSaving ? null : _changePassword,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _changePassword,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _isSaving ? 'Saving…' : 'Change Password',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
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
      ),
    );
  }
}

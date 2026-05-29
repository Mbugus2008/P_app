import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trimline_parcel/controllers/parcel_controller.dart';
import 'package:trimline_parcel/database/database_helper.dart';
import 'package:trimline_parcel/pages/parcel_dashboard_page.dart';
import 'package:trimline_parcel/pages/settings_page.dart';
import 'package:trimline_parcel/pages/setup_password_page.dart';
import 'package:trimline_parcel/utilities/remember_me_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late final ParcelController _parcelController;
  bool _isAuthenticating = false;
  bool _rememberMe = false;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    _parcelController = Get.find<ParcelController>();
    _loadRememberedUser();
  }

  Future<void> _loadRememberedUser() async {
    final remembered = await RememberMeHelper.isRememberMeEnabled();
    final identifier = await RememberMeHelper.getRememberedIdentifier();

    if (!mounted) return;

    if (remembered && identifier != null && identifier.isNotEmpty) {
      setState(() {
        _rememberMe = true;
        _emailController.text = identifier;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final identifier = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty) {
      setState(() => _loginError = 'Enter Agent Code or Mobile Number.');
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _loginError = null;
    });
    try {
      unawaited(_parcelController.syncReferenceDataOnLogin());

      var identifiedUser = await _dbHelper.getUserByIdentifier(identifier);

      // Fallback: query NAV directly if not found locally (new phone / empty DB)
      if (identifiedUser == null) {
        setState(() => _loginError = 'Looking up user on server...');
        final apiUser = await _parcelController.apiClient.fetchUserByAgentCode(
          identifier,
        );
        if (apiUser != null) {
          await _dbHelper.insertUser(apiUser);
          identifiedUser = apiUser;
        }
      }

      if (identifiedUser == null) {
        setState(() => _loginError = 'User not found.');
        return;
      }

      final user = identifiedUser;

      final hasPassword = (user.password ?? '').trim().isNotEmpty;
      if (!hasPassword) {
        final result = await Get.to<bool>(() => SetupPasswordPage(user: user));

        if (result == true) {
          _passwordController.clear();
          setState(
            () =>
                _loginError =
                    'Password created. Please login with your new password.',
          );
        }
        return;
      }

      if (password.isEmpty) {
        setState(() => _loginError = 'Enter your password.');
        return;
      }

      final loggedInUser = await _dbHelper.getUserForLogin(
        identifier: identifier,
        password: password,
      );

      if (loggedInUser == null) {
        setState(() => _loginError = 'Invalid credentials.');
        return;
      }

      if (_rememberMe) {
        await RememberMeHelper.saveRememberedUser(loggedInUser.agentCode);
      } else {
        await RememberMeHelper.clearRememberedUser();
      }

      _parcelController.setLoggedInUser(loggedInUser);
      await _parcelController.syncParcelsAndBatchesNow();
      await _routeAfterLogin();
    } catch (_) {
      setState(
        () => _loginError = 'Unable to login right now. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  Future<void> _routeAfterLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLocation =
        (prefs.getString('user_location') ?? '').trim().isNotEmpty;
    final hasPrinter = (prefs.getString('printer_mac') ?? '').trim().isNotEmpty;

    if (!hasLocation || !hasPrinter) {
      await Get.offAll(() => const SettingsPage(requireSetup: true));
      return;
    }

    await Get.offAll(() => const ParcelDashboardPage());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: LayoutBuilder(
          builder:
              (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      // Illustration / App Logo
                      Center(
                        child: Image.asset(
                          "assets/parcel_login.png",
                          height: 220,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Title
                      Text(
                        "Welcome Back!",
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Login to track and manage your parcels easily",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),

                      const SizedBox(height: 30),

                      // Email
                      TextField(
                        controller: _emailController,
                        onChanged: (_) {
                          if (_loginError != null) {
                            setState(() => _loginError = null);
                          }
                        },
                        decoration: const InputDecoration(
                          hintText: "Agent Code or Mobile Number",
                          prefixIcon: Icon(Icons.account_circle),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Password
                      TextField(
                        controller: _passwordController,
                        onChanged: (_) {
                          if (_loginError != null) {
                            setState(() => _loginError = null);
                          }
                        },
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: "Password",
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Remember Me
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() => _rememberMe = value ?? false);
                            },
                          ),
                          const Text('Remember me'),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (_loginError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            _loginError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isAuthenticating ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _isAuthenticating ? "Signing in..." : "Login",
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      Obx(
                        () => Text(
                          _parcelController.isSyncingUsers
                              ? 'Syncing users from server...'
                              : 'Synced users: ${_parcelController.usersCount}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

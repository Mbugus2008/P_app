import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/parcel_controller.dart';
import '../database/database_helper.dart';
import '../pages/login.dart';
import '../pages/parcel_dashboard_page.dart';
import '../pages/settings_page.dart';
import '../utilities/remember_me_helper.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final controller = Get.find<ParcelController>();
    await controller.syncUsersOnStartup();
    await controller.syncLocationsOnStartup();

    final identifier = await RememberMeHelper.getRememberedIdentifier();

    if (identifier != null && identifier.isNotEmpty) {
      final db = DatabaseHelper();
      final user = await db.getUserByIdentifier(identifier);
      final hasPassword = (user?.password ?? '').trim().isNotEmpty;

      if (user != null && hasPassword) {
        Get.find<ParcelController>().setLoggedInUser(user);
        await controller.syncParcelsAndBatchesNow();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _routeAfterLogin();
          }
        });
        return;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Get.offAll(() => const LoginScreen());
      }
    });
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
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

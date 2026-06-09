import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controllers/parcel_controller.dart';
import 'pages/auth_wrapper.dart';
import 'utilities/app_update_service.dart';
import 'utilities/logger.dart';
import 'utils/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(LoggerService());
  Get.put(ParcelController());
  Get.put(AppUpdateService());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Parcel Tracker',
      theme: _buildLightTheme(),
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

ThemeData _buildLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(secondary: AppColors.accent);

  final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.scaffold,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.surface,
      elevation: 0,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: AppColors.surface,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.onSurface,
      displayColor: AppColors.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      hintStyle: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.4)),
      prefixIconColor: colorScheme.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    iconTheme: IconThemeData(color: colorScheme.primary),
    tabBarTheme: base.tabBarTheme.copyWith(
      indicatorColor: colorScheme.secondary,
      labelColor: AppColors.surface,
      unselectedLabelColor: AppColors.surface.withValues(alpha: 0.7),
      labelStyle: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: base.textTheme.labelLarge,
    ),
    cardTheme: base.cardTheme.copyWith(
      color: AppColors.surface,
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface,
      selectedColor: colorScheme.primary,
      labelStyle: base.textTheme.labelMedium?.copyWith(
        color: AppColors.onSurface,
      ),
      secondarySelectedColor: colorScheme.secondary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

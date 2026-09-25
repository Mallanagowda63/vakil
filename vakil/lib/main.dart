import 'package:flutter/material.dart';
import 'screens/terms_privacy_screen.dart';
import 'services/app_keys.dart';
import 'services/call_service.dart';
import 'services/push_service.dart';
import 'services/wallet_service.dart';
import 'state/app_route_observer.dart';
import 'config/api_config.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  // Find the laptop (USB or Wi-Fi) before the first request; a longer search carries on in the background.
  await ApiConfig.findServer().timeout(const Duration(seconds: 4), onTimeout: () => false);
  CallService.instance.init();
  WalletService.instance.init();
  runApp(const VakilApp());
  // FCM rings incoming calls while the app is in the background or closed.
  PushService.instance.init();
}

class VakilApp extends StatelessWidget {
  const VakilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vakil',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.lightBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.purpleAccent,
          primary: AppColors.blueAccent,
        ),
        textTheme: TextTheme(bodyMedium: AppText.body(AppColors.textDark)),
      ),
      home: const TermsPrivacyScreen(),
    );
  }
}

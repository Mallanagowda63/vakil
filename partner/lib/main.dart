import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/dashboard_data.dart';
import 'models/profile_data.dart';
import 'models/registration_data.dart';
import 'models/theme_controller.dart';
import 'models/wallet_data.dart';
import 'screens/splash_screen.dart';
import 'services/alert_service.dart';
import 'services/app_keys.dart';
import 'services/call_service.dart';
import 'services/partner_settings.dart';
import 'services/push_service.dart';
import 'config/api_config.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  // Find the laptop (USB or Wi-Fi) before the first request; a longer search carries on in the background.
  await ApiConfig.findServer().timeout(const Duration(seconds: 4), onTimeout: () => false);
  final dashboard = DashboardController();
  await PartnerSettings.instance.load();
  await AlertService.instance.init();
  CallService.instance.init();
  runApp(VakilPartnerApp(dashboard: dashboard));
  // Channels, notification permission (Android 13+) and FCM; a tapped
  // notification opens its request or chat.
  PushService.instance.init(onOpen: dashboard.openFromPush);
}

class VakilPartnerApp extends StatelessWidget {
  const VakilPartnerApp({super.key, required this.dashboard});
  final DashboardController dashboard;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RegistrationData()),
        ChangeNotifierProvider.value(value: dashboard),
        ChangeNotifierProvider(create: (_) => ProfileController()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => WalletController()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) => MaterialApp(
          title: 'Vakil Partner',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.mode,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

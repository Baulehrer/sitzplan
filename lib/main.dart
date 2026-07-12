import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/seating_plan_provider.dart';
import 'providers/app_appearance_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SitzplanApp());
}

class SitzplanApp extends StatelessWidget {
  const SitzplanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAppearanceProvider()..load()),
        ChangeNotifierProvider(create: (_) => SeatingPlanListProvider()),
        ChangeNotifierProvider(create: (_) => SeatingPlanEditorProvider()),
      ],
      child: Consumer<AppAppearanceProvider>(
        builder: (context, appearance, _) => MaterialApp(
          title: "Kaufi's Sitzplan-App",
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightFor(appearance.palette),
          darkTheme: AppTheme.darkFor(appearance.palette),
          themeMode: appearance.themeMode,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}

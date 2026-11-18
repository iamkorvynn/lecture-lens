import 'package:material_ui/material_ui.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/database_helper.dart';

void main() {
  runApp(const LectureLensApp());
}

class LectureLensApp extends StatelessWidget {
  const LectureLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LectureLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D5AFE),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D5AFE),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _Root(),
    );
  }
}

/// Decides once at startup whether to show onboarding or the lecture list.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: DatabaseHelper.instance.getSetting(
        DatabaseHelper.settingOnboardingDone,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == 'true') {
          return const HomeScreen();
        }
        return const OnboardingScreen();
      },
    );
  }
}

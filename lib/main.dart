import 'package:flutter/material.dart';
import 'store.dart';
import 'screens/auth_screens.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load(connect: false);
  runApp(CityGuideApp(state: state));
  state.initialize();
}

class CityGuideApp extends StatelessWidget {
  final AppState state;
  const CityGuideApp({super.key, required this.state});

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E), brightness: b, secondary: const Color(0xFFE8553D)),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48))),
      );

  @override
  Widget build(BuildContext context) {
    // Auth gate: only registered, logged-in users reach the app (security requirement).
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        title: 'CityGuide',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: state.initializing ? const Scaffold(body: Center(child:CircularProgressIndicator())) : (state.user == null ? LoginScreen(state: state) : HomeShell(state: state)),
      ),
    );
  }
}

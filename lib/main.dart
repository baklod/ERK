import 'package:controller/orientation_lock.dart';
import 'package:controller/screens/boat_controller_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lockLandscape();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const BoatApp());
}

class BoatApp extends StatefulWidget {
  const BoatApp({super.key});

  @override
  State<BoatApp> createState() => _BoatAppState();
}

class _BoatAppState extends State<BoatApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    lockLandscape();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) lockLandscape();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1B4F8A);
    return MaterialApp(
      title: 'ERK Eco Wave',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF071422),
        ),
        scaffoldBackgroundColor: const Color(0xFF071422),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF071422),
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF163056),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFF1E3A5F)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: seed),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: seed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            shape: const RoundedRectangleBorder(),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: seed,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            shape: const RoundedRectangleBorder(),
            side: const BorderSide(color: Color(0xFF1E3A5F)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: const RoundedRectangleBorder(),
            foregroundColor: seed,
          ),
        ),
      ),
      home: const BoatControllerScreen(),
    );
  }
}

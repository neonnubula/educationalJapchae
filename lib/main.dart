import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:most_important_thing/models/goal_model.dart';
import 'package:most_important_thing/screens/main_app_screen.dart';
import 'package:most_important_thing/screens/onboarding_screen.dart';
import 'package:most_important_thing/screens/sign_in_screen.dart';
import 'package:most_important_thing/services/notification_service.dart';
import 'package:most_important_thing/services/storage_service.dart';
import 'package:most_important_thing/widgets/app_header.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  try {
    // Supabase initialization via --dart-define (SUPABASE_URL, SUPABASE_ANON_KEY)
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    bool isSupabaseReady = false;
    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      isSupabaseReady = true;
    } else {
      debugPrint('Supabase env not set; skipping Supabase.initialize');
    }

    final notificationService = NotificationService();
    await notificationService.init();

    await Hive.initFlutter();
    // Register our custom adapter that handles migration
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(GoalAdapter());
    }

    final storageService = StorageService(notificationService);
    await storageService.init();
    final isFirstLaunch = storageService.isFirstLaunch;
    Widget initial;
    if (isSupabaseReady) {
      final session = Supabase.instance.client.auth.currentSession;
      initial = session == null
          ? const SignInScreen()
          : (isFirstLaunch ? OnboardingScreen() : MainAppScreen());

      // Watch auth state to hot-switch between signed-in and signed-out
      Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        runApp(
          ChangeNotifierProvider(
            create: (context) => storageService,
            child: MostImportantThingApp(initialRoute: event.session == null ? const SignInScreen() : (isFirstLaunch ? OnboardingScreen() : MainAppScreen())),
          ),
        );
      });
    } else {
      initial = const _MissingSupabaseConfigScreen();
    }

    runApp(
      ChangeNotifierProvider(
        create: (context) => storageService,
        child: MostImportantThingApp(initialRoute: initial),
      ),
    );
  } catch (e) {
    debugPrint('Error during app initialization: $e');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error starting app: $e'),
          ),
        ),
      ),
    );
  }
}

class MostImportantThingApp extends StatelessWidget {
  final Widget initialRoute;
  const MostImportantThingApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Most Important Thing',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF32CD32), // Using header's lime green as seed
          brightness: Brightness.light,
          primary: const Color(0xFF20B2AA), // Light sea green from header
          secondary: const Color(0xFFFFD700), // Golden yellow from header
          surface: const Color(0xFFFFFBF0), // Warm white surface
        ),
        scaffoldBackgroundColor: Colors.transparent, // Let gradient show through
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFFFFEFA), // Slightly warmer white for inputs
          border: OutlineInputBorder(borderSide: BorderSide.none),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // Transparent to show gradient
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFEFA).withValues(alpha: 0.8), // Semi-transparent cards
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF32CD32), // Using header's lime green as seed
          brightness: Brightness.dark,
          primary: const Color(0xFF20B2AA), // Light sea green from header
          secondary: const Color(0xFFFFD700), // Golden yellow from header
          surface: const Color(0xFF1E1E1E), // Dark surface
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.transparent, // Let gradient show through
        cardColor: const Color(0xFF1E1E1E).withValues(alpha: 0.8), // Semi-transparent dark cards
        shadowColor: Colors.black.withValues(alpha: 0.3),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A).withValues(alpha: 0.8), // Semi-transparent dark inputs
          border: const OutlineInputBorder(borderSide: BorderSide.none),
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // Transparent to show gradient
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        textTheme: TextTheme(
          headlineSmall: const TextStyle(color: Colors.white),
          titleMedium: const TextStyle(color: Colors.white),
          bodyLarge: const TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.grey[300]),
          labelSmall: TextStyle(color: Colors.grey[400]),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF20B2AA), // Use header sea green for buttons
            foregroundColor: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E).withValues(alpha: 0.8), // Semi-transparent cards
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.3),
        ),
      ),
      themeMode: ThemeMode.system,
      home: Builder(
        builder: (context) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          return GradientBackground(
            isDarkMode: isDarkMode,
            child: initialRoute,
          );
        },
      ),
    );
  }
}

class _MissingSupabaseConfigScreen extends StatelessWidget {
  const _MissingSupabaseConfigScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Text(
                'Missing Supabase configuration',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Run the app with:\n' 
                '--dart-define=SUPABASE_URL=...\n' 
                '--dart-define=SUPABASE_ANON_KEY=...\n' 
                'Then restart the app.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

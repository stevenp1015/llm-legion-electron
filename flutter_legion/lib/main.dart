import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'providers/app_provider.dart';
import 'providers/chat_provider.dart';
import 'services/legion_api_service.dart';
import 'screens/enhanced_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize window manager for desktop
  if (WidgetsBinding.instance.platformDispatcher.platformBrightness != null) {
    await windowManager.ensureInitialized();
    
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1400, 900),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'LLM Legion Command Center - Flutter',
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  
  runApp(const LegionApp());
}

class LegionApp extends StatelessWidget {
  const LegionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LegionApiService>(
          create: (_) => LegionApiService(),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider<AppProvider>(
          create: (_) => AppProvider(),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(),
        ),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return MaterialApp(
            title: 'Legion Command Center',
            debugShowCheckedModeBanner: false,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: ThemeMode.light,
            home: const EnhancedMainScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const primaryColor = Color(0xFF3B82F6);
    const secondaryColor = Color(0xFF10B981);
    const tertiaryColor = Color(0xFFF59E0B);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        secondary: secondaryColor,
        tertiary: tertiaryColor,
      ).copyWith(
        surface: const Color(0xFFFAFAFA),
        surfaceContainerHighest: const Color(0xFFF4F4F5),
        outline: const Color(0xFFE4E4E7),
      ),
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAFAFA),
        foregroundColor: Color(0xFF18181B),
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE4E4E7),
        thickness: 1,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFF3B82F6);
    const secondaryColor = Color(0xFF10B981);
    const tertiaryColor = Color(0xFFF59E0B);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        secondary: secondaryColor,
        tertiary: tertiaryColor,
      ).copyWith(
        surface: const Color(0xFF0F0F0F),
        surfaceContainerHighest: const Color(0xFF1F1F1F),
        outline: const Color(0xFF3F3F3F),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F0F0F),
        foregroundColor: Color(0xFFFAFAFA),
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: const Color(0xFF1F1F1F),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF3F3F3F),
        thickness: 1,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'providers/app_provider.dart';
import 'providers/chat_provider.dart';
import 'services/api_traffic_logger.dart';
import 'services/legion_api_service.dart';
import 'services/mcp_service.dart';
import 'screens/enhanced_main_screen.dart';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1400, 900),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'LLM Legion Command Center - Flutter',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      // On macOS, make the title bar transparent
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        await windowManager
            .setHasShadow(true); // Optional: remove window shadow
      }
    });
  }

  runApp(const LegionApp());
}

class LegionApp extends StatelessWidget {
  const LegionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseLight = ThemeData.light();
    final baseDark = ThemeData.dark();

    return MultiProvider(
      providers: [
        Provider<ApiTrafficRecorder>(
          create: (_) => ApiTrafficRecorder(),
          dispose: (_, recorder) => recorder.dispose(),
        ),
        Provider<LegionApiService>(
          create: (context) {
            final recorder = context.read<ApiTrafficRecorder>();
            final llmClient = LoggingHttpClient(recorder: recorder);
            final mcpClient = LoggingHttpClient(
              recorder: recorder,
              captureResponseChunks: false,
            );
            final mcpService = McpService(httpClient: mcpClient);
            return LegionApiService(
              mcpService: mcpService,
              httpClient: llmClient,
            );
          },
          dispose: (_, service) => service.dispose(),
        ),
        ProxyProvider<LegionApiService, McpService>(
          update: (_, apiService, __) => apiService.mcpService,
        ),
        ChangeNotifierProvider<AppProvider>(
          create: (_) => AppProvider(),
        ),
        ChangeNotifierProxyProvider<LegionApiService, ChatProvider>(
          create: (context) => ChatProvider(context.read<LegionApiService>()),
          update: (context, apiService, previous) {
            if (previous == null) {
              return ChatProvider(apiService);
            }
            previous.replaceApi(apiService);
            return previous;
          },
        ),
      ],
      child: MacosApp(
        title: 'Legion Command Center',
        debugShowCheckedModeBanner: false,
        darkTheme: MacosThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF5AC8FA),
          canvasColor: const Color(0xFFFFAAFF),
          iconTheme: const MacosIconThemeData(color: Color(0xFF5AC8FA)),
        ),
        theme: MacosThemeData(
          brightness: Brightness.light,
          primaryColor: const Color(0xFF5AC8FA),
          iconTheme: const MacosIconThemeData(color: Color(0xFF5AC8FA)),
        ),
        home: const EnhancedMainScreen(),
        builder: (context, child) {
          final macosTheme = MacosTheme.of(context);
          final colorScheme = ColorScheme.fromSeed(
            seedColor: macosTheme.primaryColor,
            brightness: macosTheme.brightness,
          );
          final materialTheme = ThemeData(
            colorScheme: colorScheme,
            brightness: macosTheme.brightness,
            scaffoldBackgroundColor: macosTheme.canvasColor,
            textTheme: GoogleFonts.quicksandTextTheme(
              macosTheme.brightness == Brightness.dark
                  ? baseDark.textTheme
                  : baseLight.textTheme,
            ),
          );

          return Theme(
            data: materialTheme,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import '../services/mcp_service.dart';

class McpManagerScreen extends StatelessWidget {
  const McpManagerScreen({super.key});

  static Future<void> show(BuildContext context) {
    return showMacosSheet<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const McpManagerScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mcpService = context.read<McpService>();
    final typography = MacosTheme.of(context).typography;

    return MacosSheet(
      child: SizedBox(
        width: 640,
        height: 440,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'MCP Server Manager',
                    style: typography.title1,
                  ),
                  const Spacer(),
                  MacosTooltip(
                    message: 'Refresh server list',
                    child: MacosIconButton(
                      boxConstraints: const BoxConstraints.tightFor(width: 32, height: 32),
                      icon: const MacosIcon(CupertinoIcons.refresh),
                      onPressed: () => mcpService.fetchInitialServers(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PushButton(
                    controlSize: ControlSize.small,
                    secondary: true,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<McpServer>>(
                  stream: mcpService.serverStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: ProgressCircle(radius: 16));
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to connect to MCP hub.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: typography.subheadline,
                        ),
                      );
                    }
                    final servers = snapshot.data ?? [];
                    if (servers.isEmpty) {
                      return Center(
                        child: Text(
                          'No MCP servers configured yet.',
                          style: typography.subheadline,
                        ),
                      );
                    }
                    return MacosScrollbar(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: servers.length,
                        itemBuilder: (context, index) {
                          final server = servers[index];
                          return _ServerTile(
                            server: server,
                            onStart: () => mcpService.startServer(server.name),
                            onStop: () => mcpService.stopServer(server.name),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.server,
    required this.onStart,
    required this.onStop,
  });

  final McpServer server;
  final Future<void> Function()? onStart;
  final Future<void> Function()? onStop;

  bool get _canStart =>
      server.status == 'stopped' || server.status == 'error';
  bool get _canStop => server.status == 'running';

  String get _displayName => server.displayName?.isNotEmpty == true
      ? '${server.displayName} (${server.name})'
      : server.name;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final typography = theme.typography;
    final details =
        'Transport: ${server.transportType ?? 'unknown'} • Tools: ${server.tools.length}';
    final background = theme.brightness == Brightness.dark
        ? const Color(0xFF1E1F24)
        : const Color(0xFFF2F2F7);
    final borderColor = theme.dividerColor.withValues(alpha: 0.4);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusBadge(status: server.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        style: typography.title3,
                      ),
                      if (server.description?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            server.description!,
                            style: typography.caption1,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (_canStart)
                      PushButton(
                        controlSize: ControlSize.small,
                        onPressed: () => onStart?.call(),
                        child: const Text('Start'),
                      ),
                    if (_canStop)
                      PushButton(
                        controlSize: ControlSize.small,
                        secondary: true,
                        onPressed: () => onStop?.call(),
                        child: const Text('Stop'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              details,
              style: typography.caption1,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final IconData icon;

    switch (status) {
      case 'running':
        color = const Color(0xFF30D158);
        icon = CupertinoIcons.check_mark_circled_solid;
        break;
      case 'stopped':
        color = MacosColors.systemGrayColor;
        icon = CupertinoIcons.pause_circle;
        break;
      case 'error':
        color = const Color(0xFFFF453A);
        icon = CupertinoIcons.exclamationmark_triangle_fill;
        break;
      default:
        color = const Color(0xFFFF9F0A);
        icon = CupertinoIcons.hourglass_bottomhalf_fill;
    }

    return MacosIcon(
      icon,
      color: color,
    );
  }
}

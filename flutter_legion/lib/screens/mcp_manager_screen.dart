import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mcp_service.dart';
import '../theming/vista_effects.dart';

class McpManagerScreen extends StatelessWidget {
  const McpManagerScreen({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const McpManagerScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mcpService = context.read<McpService>();
    final theme = Theme.of(context);

    return VistaModal(
      onDismiss: () => Navigator.of(context).pop(),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        height: MediaQuery.of(context).size.height * 0.7,
        child: VistaPanel(
          title: 'MCP Server Manager',
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => mcpService.fetchInitialServers(),
              tooltip: 'Refresh Server List',
            ),
          ],
          child: StreamBuilder<List<McpServer>>(
            stream: mcpService.serverStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: VistaSpinner());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error connecting to MCP Hub:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                );
              }

              final servers = snapshot.data ?? [];

              if (servers.isEmpty) {
                return const Center(
                  child: Text('No MCP servers configured in the hub.'),
                );
              }

              return ListView.builder(
                itemCount: servers.length,
                itemBuilder: (context, index) {
                  final server = servers[index];
                  return ListTile(
                    leading: _buildStatusIcon(server.status),
                    title: Text(server.name),
                    subtitle: Text(server.command.join(' ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (server.status == 'stopped' || server.status == 'error')
                          VistaButton(
                            child: const Text('Start'),
                            onPressed: () => mcpService.startServer(server.name),
                          ),
                        if (server.status == 'running')
                          VistaButton(
                            child: const Text('Stop'),
                            onPressed: () => mcpService.stopServer(server.name),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'running':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'stopped':
        color = Colors.grey;
        icon = Icons.stop_circle;
        break;
      case 'error':
        color = Colors.red;
        icon = Icons.error;
        break;
      default:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
    }
    return Icon(icon, color: color);
  }
}

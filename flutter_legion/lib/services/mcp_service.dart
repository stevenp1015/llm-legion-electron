import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mcp_client/mcp_client.dart';

export 'package:mcp_client/mcp_client.dart' show McpServer, McpTool;

// Service to interact with the MCP Hub API using the mcp_client package.
class McpService {
  static const String _defaultMcpHubUrl = 'http://localhost:37373';
  final String _mcpHubUrl;
  Client? _mcpClient;

  // Stream controller to broadcast server updates to the app.
  final _serverController = StreamController<List<McpServer>>.broadcast();
  Stream<List<McpServer>> get serverStream => _serverController.stream;

  // Internal cache of servers.
  List<McpServer> _servers = [];

  McpService({String? mcpHubUrl})
      : _mcpHubUrl = mcpHubUrl ?? _defaultMcpHubUrl;

  /// Initializes the service, creates an MCP client, and connects to the hub.
  Future<void> initialize() async {
    debugPrint('Initializing McpService with mcp_client...');

    final clientConfig = McpClientConfig(
      name: 'LegionCommandCenterFlutter',
      version: '1.0.0',
      enableDebugLogging: true, // Turn on for debugging
    );

    final transportConfig = TransportConfig.sse(
      serverUrl: _mcpHubUrl,
    );

    final result = await McpClient.createAndConnect(
      config: clientConfig,
      transportConfig: transportConfig,
    );

    if (result.isSuccess) {
      _mcpClient = result.getOrThrow();
      debugPrint('MCP client connected successfully.');
      _setupListeners();
      await fetchInitialServers();
    } else {
      final error = result.exceptionOrNull() ?? 'Unknown error';
      debugPrint('Failed to connect MCP client: $error');
      _serverController.addError(error);
      throw Exception('Failed to connect MCP client: $error');
    }
  }

  /// Sets up listeners for events from the MCP client.
  void _setupListeners() {
    _mcpClient?.hubEvents.listen((event) {
      debugPrint('Hub event received: ${event.type}');
      // A more robust implementation would inspect the event payload.
      // For now, we refetch the server list on any hub event.
      fetchInitialServers();
    });
  }

  /// Fetches the initial list of servers from the hub.
  Future<void> fetchInitialServers() async {
    if (_mcpClient == null) return;

    try {
      final servers = await _mcpClient!.listServers();
      _servers = servers;
      _serverController.add(List.from(_servers));
    } catch (e) {
      debugPrint('Error fetching servers: $e');
      _serverController.addError(e);
    }
  }

  /// Sends a request to the hub to start a server.
  Future<void> startServer(String serverName) async {
    if (_mcpClient == null) return;
    try {
      await _mcpClient!.startServer(serverName);
      // The hub event will trigger a refresh.
    } catch (e) {
      debugPrint('Error starting server $serverName: $e');
      rethrow;
    }
  }

  /// Sends a request to the hub to stop a server.
  Future<void> stopServer(String serverName) async {
    if (_mcpClient == null) return;
    try {
      await _mcpClient!.stopServer(serverName);
      // The hub event will trigger a refresh.
    } catch (e) {
      debugPrint('Error stopping server $serverName: $e');
      rethrow;
    }
  }

  /// Calls a tool on a specific server via the hub.
  Future<Map<String, dynamic>> callTool({
    required String serverName,
    required String toolName,
    required Map<String, dynamic> arguments,
  }) async {
    if (_mcpClient == null) throw Exception('MCP Client not initialized');
    try {
      final result = await _mcpClient!.callTool(
        serverName,
        toolName,
        arguments,
      );
      return result.toJson();
    } catch (e) {
      debugPrint('Error calling tool $toolName on $serverName: $e');
      rethrow;
    }
  }

  /// Disposes of the resources used by the service.
  void dispose() {
    _mcpClient?.disconnect();
    _serverController.close();
    debugPrint('McpService disposed.');
  }
}

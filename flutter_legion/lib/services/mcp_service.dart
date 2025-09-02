import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sse_client/sse_client.dart';

// Represents the configuration and live status of an MCP server managed by the hub.
class McpServer {
  final String name;
  final String? mcpId;
  final String status;
  final List<String> command;
  final List<McpTool> tools;
  final bool disabled;
  final int? pid;
  final String? lastError;

  McpServer({
    required this.name,
    this.mcpId,
    required this.status,
    required this.command,
    this.tools = const [],
    this.disabled = false,
    this.pid,
    this.lastError,
  });

  factory McpServer.fromJson(Map<String, dynamic> json) {
    var toolsList = (json['tools'] as List<dynamic>?)
        ?.map((toolJson) => McpTool.fromJson(toolJson as Map<String, dynamic>))
        .toList() ?? [];

    return McpServer(
      name: json['name'],
      mcpId: json['mcp_id'],
      status: json['status'],
      command: List<String>.from(json['command'] ?? []),
      tools: toolsList,
      disabled: json['disabled'] ?? false,
      pid: json['pid'],
      lastError: json['last_error'],
    );
  }

  McpServer copyWith({
    String? name,
    String? mcpId,
    String? status,
    List<String>? command,
    List<McpTool>? tools,
    bool? disabled,
    int? pid,
    String? lastError,
  }) {
    return McpServer(
      name: name ?? this.name,
      mcpId: mcpId ?? this.mcpId,
      status: status ?? this.status,
      command: command ?? this.command,
      tools: tools ?? this.tools,
      disabled: disabled ?? this.disabled,
      pid: pid ?? this.pid,
      lastError: lastError ?? this.lastError,
    );
  }
}

// Represents a single tool available from an MCP server.
class McpTool {
  final String name;
  final String? description;
  final Map<String, dynamic>? inputSchema;

  const McpTool({
    required this.name,
    this.description,
    this.inputSchema,
  });

  factory McpTool.fromJson(Map<String, dynamic> json) {
    return McpTool(
      name: json['name'],
      description: json['description'],
      inputSchema: json['input_schema'] as Map<String, dynamic>?,
    );
  }
}

// Service to interact with the MCP Hub API.
class McpService {
  static const String _defaultMcpHubUrl = 'http://localhost:37373';
  final String _mcpHubUrl;
  final http.Client _httpClient;
  SseClient? _sseClient;

  // Stream controller to broadcast server updates to the app.
  final _serverController = StreamController<List<McpServer>>.broadcast();
  Stream<List<McpServer>> get serverStream => _serverController.stream;

  // Internal cache of servers.
  List<McpServer> _servers = [];

  McpService({String? mcpHubUrl})
      : _mcpHubUrl = mcpHubUrl ?? _defaultMcpHubUrl,
        _httpClient = http.Client();

  /// Initializes the service, fetches initial data, and connects to the SSE stream.
  Future<void> initialize() async {
    debugPrint('Initializing McpService...');
    try {
      await fetchInitialServers();
      _connectToSse();
      debugPrint('McpService initialized successfully with ${_servers.length} servers.');
    } catch (e) {
      debugPrint('Failed to initialize McpService: $e');
      // In case of failure, broadcast an empty list.
      _serverController.add([]);
      rethrow;
    }
  }

  /// Fetches the initial list of servers from the hub.
  Future<void> fetchInitialServers() async {
    final response = await _httpClient.get(
      Uri.parse('$_mcpHubUrl/api/servers'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final serverList = (data['servers'] as List<dynamic>?)
          ?.map((serverJson) => McpServer.fromJson(serverJson as Map<String, dynamic>))
          .toList() ?? [];
      _servers = serverList;
      _serverController.add(List.from(_servers)); // Broadcast initial list
    } else {
      throw Exception('Failed to fetch servers from hub: ${response.statusCode}');
    }
  }

  /// Connects to the hub's Server-Sent Events stream for real-time updates.
  void _connectToSse() {
    debugPrint('Connecting to MCP Hub SSE at $_mcpHubUrl/api/events');
    _sseClient = SseClient.connect(Uri.parse('$_mcpHubUrl/api/events'));

    _sseClient!.stream.listen(
      (event) {
        debugPrint('SSE event received: ${event.event}');
        debugPrint('SSE data received: ${event.data}');
        // TODO: Handle different event types (e.g., 'SERVERS_UPDATED')
        // For now, we'll just refetch the whole list on any event.
        // A more robust implementation would parse the event data and update the list incrementally.
        fetchInitialServers();
      },
      onError: (error) {
        debugPrint('SSE connection error: $error');
        // Optional: Implement reconnection logic.
      },
      onDone: () {
        debugPrint('SSE connection closed.');
      },
    );
  }

  /// Sends a request to the hub to start a server.
  Future<void> startServer(String serverName) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_mcpHubUrl/api/servers/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'server_name': serverName}),
      );
      if (response.statusCode != 200) {
        debugPrint('Failed to start server $serverName: ${response.statusCode} ${response.body}');
        // Optionally throw an exception here to notify the UI
      }
      // The SSE event should update the state, but we can optimistically fetch
      await fetchInitialServers();
    } catch (e) {
      debugPrint('Error starting server $serverName: $e');
      rethrow;
    }
  }

  /// Sends a request to the hub to stop a server.
  Future<void> stopServer(String serverName) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_mcpHubUrl/api/servers/stop'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'server_name': serverName}),
      );
      if (response.statusCode != 200) {
        debugPrint('Failed to stop server $serverName: ${response.statusCode} ${response.body}');
      }
      // The SSE event should update the state, but we can optimistically fetch
      await fetchInitialServers();
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
    try {
      final response = await _httpClient.post(
        Uri.parse('$_mcpHubUrl/api/servers/tools'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'server_name': serverName,
          'tool': toolName,
          'arguments': arguments,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result'] as Map<String, dynamic>;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception('Failed to call tool: ${response.statusCode} - ${errorBody['error']}');
      }
    } catch (e) {
      debugPrint('Error calling tool $toolName on $serverName: $e');
      rethrow;
    }
  }

  /// Disposes of the resources used by the service.
  void dispose() {
    _sseClient?.close();
    _serverController.close();
    _httpClient.close();
    debugPrint('McpService disposed.');
  }
}

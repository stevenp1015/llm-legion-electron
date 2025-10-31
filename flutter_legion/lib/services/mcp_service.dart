import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Representation of an MCP tool exposed by a server in the hub.
class McpTool {
  final String serverName;
  final String name;
  final String? description;
  final Map<String, dynamic> inputSchema;
  final Map<String, dynamic>? metadata;

  const McpTool({
    required this.serverName,
    required this.name,
    this.description,
    this.inputSchema = const {},
    this.metadata,
  });

  factory McpTool.fromJson(
      {required String serverName, required Map<String, dynamic> json}) {
    return McpTool(
      serverName: serverName,
      name: json['name'] as String? ?? 'unknown',
      description: json['description'] as String?,
      inputSchema:
          Map<String, dynamic>.from(json['inputSchema'] as Map? ?? const {}),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }
}

/// Representation of an MCP server managed by the hub.
class McpServer {
  final String name;
  final String? displayName;
  final String? description;
  final String status;
  final String? transportType;
  final DateTime? lastStarted;
  final double? uptimeSeconds;
  final List<McpTool> tools;
  final Map<String, dynamic> raw;

  McpServer({
    required this.name,
    this.displayName,
    this.description,
    required this.status,
    this.transportType,
    this.lastStarted,
    this.uptimeSeconds,
    this.tools = const [],
    Map<String, dynamic>? raw,
  }) : raw = raw != null ? Map<String, dynamic>.unmodifiable(raw) : const {};

  factory McpServer.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'unknown';
    final capabilities = json['capabilities'] as Map<String, dynamic>?;
    final toolsJson =
        capabilities != null ? capabilities['tools'] as List<dynamic>? : null;

    final tools = toolsJson != null
        ? toolsJson
            .whereType<Map<String, dynamic>>()
            .map((tool) => McpTool.fromJson(serverName: name, json: tool))
            .toList()
        : <McpTool>[];

    return McpServer(
      name: name,
      displayName: json['displayName'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'unknown',
      transportType: json['transportType'] as String?,
      lastStarted: json['lastStarted'] != null
          ? DateTime.tryParse(json['lastStarted'].toString())
          : null,
      uptimeSeconds:
          json['uptime'] is num ? (json['uptime'] as num).toDouble() : null,
      tools: tools,
      raw: json,
    );
  }
}

/// Service wrapper that talks to the Node-based MCP Hub over HTTP.
class McpService {
  static const String _defaultHubBaseUrl = 'http://localhost:37373/api';

  final String _baseUrl;
  final http.Client _httpClient;

  final _serverController = StreamController<List<McpServer>>.broadcast();
  List<McpServer> _servers = [];
  final Map<String, List<McpTool>> _toolsByServer = {};
  final Map<String, McpTool> _toolIndex = {};
  Object? _lastError;

  McpService({String? baseUrl, http.Client? httpClient})
      : _baseUrl = baseUrl ?? _defaultHubBaseUrl,
        _httpClient = httpClient ?? http.Client();

  /// Stream of server lists for interested UI widgets.
  Stream<List<McpServer>> get serverStream => _serverController.stream;

  /// Current cached servers (immutable snapshot).
  List<McpServer> get servers => List.unmodifiable(_servers);

  /// Quick lookup of tools per server.
  Map<String, List<McpTool>> get availableTools {
    return _toolsByServer
        .map((key, value) => MapEntry(key, List.unmodifiable(value)));
  }

  /// Flattened view of tools for LLM planning. Currently returns all tools.
  List<McpTool> getToolsForLLM(String model) {
    return _toolsByServer.values.expand((list) => list).toList(growable: false);
  }

  McpTool? findTool(String serverName, String toolName) {
    final tools = _toolsByServer[serverName];
    if (tools == null) return null;
    for (final tool in tools) {
      if (tool.name == toolName) {
        return tool;
      }
    }
    return null;
  }

  McpTool? findToolByName(String toolName) => _toolIndex[toolName];

  ({String serverName, McpTool tool})? resolveTool(
    String toolName, {
    String? preferredServer,
  }) {
    if (preferredServer != null && preferredServer.isNotEmpty) {
      final tool = findTool(preferredServer, toolName);
      if (tool != null) {
        return (serverName: preferredServer, tool: tool);
      }
    }

    for (final entry in _toolsByServer.entries) {
      for (final tool in entry.value) {
        if (tool.name == toolName) {
          return (serverName: entry.key, tool: tool);
        }
      }
    }
    return null;
  }

  Object? get lastError => _lastError;

  Future<void> initialize() async {
    debugPrint('Initializing McpService (HTTP hub mode)');
    try {
      await fetchInitialServers();
    } catch (e) {
      debugPrint('Continuing without MCP hub connection: $e');
    }
  }

  Future<void> fetchInitialServers() async {
    try {
      final payload = await _get('/servers', context: 'list servers');
      final serversJson = (payload['servers'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

      final parsed = serversJson.map(McpServer.fromJson).toList();

      _servers = parsed;
      _toolsByServer
        ..clear()
        ..addEntries(parsed.map((s) => MapEntry(s.name, s.tools)));
      _toolIndex.clear();
      for (final server in parsed) {
        for (final tool in server.tools) {
          _toolIndex.putIfAbsent(tool.name, () => tool);
        }
      }

      _lastError = null;

      _serverController.add(List.unmodifiable(_servers));
    } catch (e, st) {
      debugPrint('Error fetching MCP servers: $e');
      _serverController.addError(e, st);
      _lastError = e;
      rethrow;
    }
  }

  Future<void> startServer(String serverName) async {
    await _post(
      '/servers/start',
      body: {'server_name': serverName},
      context: 'start server',
    );
    await fetchInitialServers();
  }

  Future<void> stopServer(String serverName) async {
    await _post(
      '/servers/stop',
      body: {'server_name': serverName},
      context: 'stop server',
    );
    await fetchInitialServers();
  }

  Future<Map<String, dynamic>> callTool({
    required String serverName,
    required String toolName,
    Map<String, dynamic> arguments = const {},
    Map<String, dynamic>? requestOptions,
  }) async {
    final payload = await _post(
      '/servers/tools',
      body: {
        'server_name': serverName,
        'tool': toolName,
        'arguments': arguments,
        if (requestOptions != null) 'request_options': requestOptions,
      },
      context: 'call tool',
    );

    final result = payload['result'];
    if (result is Map<String, dynamic>) {
      return Map<String, dynamic>.from(result);
    }

    if (result is List) {
      return {'results': result};
    }

    return {'value': result};
  }

  void dispose() {
    _serverController.close();
    _httpClient.close();
    debugPrint('McpService disposed.');
  }

  Uri _uri(String path) {
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    return Uri.parse('$_baseUrl$path');
  }

  Future<Map<String, dynamic>> _get(String path,
      {required String context}) async {
    final response = await _httpClient.get(_uri(path));
    return _decodeJsonResponse(response, context);
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
    required String context,
  }) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decodeJsonResponse(response, context);
  }

  Map<String, dynamic> _decodeJsonResponse(
      http.Response response, String context) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'MCP hub $context failed (status ${response.statusCode})');
    }

    if (response.body.isEmpty) {
      return const {};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  }
}

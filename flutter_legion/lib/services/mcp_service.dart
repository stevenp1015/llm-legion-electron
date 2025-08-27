import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';

class McpServerConfig {
  final String id;
  final String name;
  final List<String> command;
  final List<String>? args;
  final Map<String, String>? env;
  final bool enabled;

  const McpServerConfig({
    required this.id,
    required this.name,
    required this.command,
    this.args,
    this.env,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'command': command,
    'args': args,
    'env': env,
    'enabled': enabled,
  };

  factory McpServerConfig.fromJson(Map<String, dynamic> json) {
    return McpServerConfig(
      id: json['id'],
      name: json['name'],
      command: List<String>.from(json['command']),
      args: json['args'] != null ? List<String>.from(json['args']) : null,
      env: json['env'] != null ? Map<String, String>.from(json['env']) : null,
      enabled: json['enabled'] ?? true,
    );
  }
}

class McpTool {
  final String name;
  final String? description;
  final Map<String, dynamic>? inputSchema;
  final String? serverId;
  final String? serverName;

  const McpTool({
    required this.name,
    this.description,
    this.inputSchema,
    this.serverId,
    this.serverName,
  });

  factory McpTool.fromJson(Map<String, dynamic> json) {
    return McpTool(
      name: json['name'],
      description: json['description'],
      inputSchema: json['inputSchema'],
      serverId: json['serverId'],
      serverName: json['serverName'],
    );
  }
}

class McpService {
  static const String _defaultMcpHubUrl = 'http://localhost:3000';
  late String _mcpHubUrl;
  late http.Client _httpClient;
  
  bool _isInitialized = false;
  final Map<String, McpServerConfig> _serverConfigs = {};
  final Map<String, List<McpTool>> _availableTools = {};

  McpService({String? mcpHubUrl}) {
    _mcpHubUrl = mcpHubUrl ?? _defaultMcpHubUrl;
    _httpClient = http.Client();
  }

  bool get isInitialized => _isInitialized;
  Map<String, McpServerConfig> get serverConfigs => _serverConfigs;
  Map<String, List<McpTool>> get availableTools => _availableTools;

  /// Initialize the MCP service and connect to MCP Hub
  Future<void> initialize() async {
    try {
      // Test connection to MCP Hub
      final response = await _httpClient.get(
        Uri.parse('$_mcpHubUrl/api/servers'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        _isInitialized = true;
        await _loadServerConfigs();
        await _refreshAvailableTools();
        debugPrint('MCP Service initialized successfully');
      } else {
        throw Exception('Failed to connect to MCP Hub: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to initialize MCP Service: $e');
      // For development, we can still proceed without MCP Hub
      _isInitialized = true;
    }
  }

  /// Load server configurations from MCP Hub
  Future<void> _loadServerConfigs() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_mcpHubUrl/api/servers'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> servers = data['servers'] ?? [];
        
        _serverConfigs.clear();
        for (final serverData in servers) {
          final config = McpServerConfig.fromJson(serverData);
          _serverConfigs[config.id] = config;
        }
      }
    } catch (e) {
      debugPrint('Failed to load server configs: $e');
    }
  }

  /// Refresh available tools from all active servers
  Future<void> _refreshAvailableTools() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_mcpHubUrl/api/tools'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Map<String, dynamic> toolsByServer = data['tools'] ?? {};
        
        _availableTools.clear();
        toolsByServer.forEach((serverId, tools) {
          final List<dynamic> toolList = tools;
          _availableTools[serverId] = toolList
              .map((tool) => McpTool.fromJson(tool))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to refresh available tools: $e');
    }
  }

  /// Add a new MCP server configuration
  Future<bool> addServer(McpServerConfig config) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_mcpHubUrl/api/servers'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(config.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _serverConfigs[config.id] = config;
        await _refreshAvailableTools();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to add server: $e');
      return false;
    }
  }

  /// Remove an MCP server configuration
  Future<bool> removeServer(String serverId) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('$_mcpHubUrl/api/servers/$serverId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        _serverConfigs.remove(serverId);
        _availableTools.remove(serverId);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to remove server: $e');
      return false;
    }
  }

  /// Start an MCP server
  Future<bool> startServer(String serverId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_mcpHubUrl/api/servers/$serverId/start'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        await _refreshAvailableTools();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to start server: $e');
      return false;
    }
  }

  /// Stop an MCP server
  Future<bool> stopServer(String serverId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_mcpHubUrl/api/servers/$serverId/stop'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        _availableTools.remove(serverId);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to stop server: $e');
      return false;
    }
  }

  /// Call an MCP tool
  Future<Map<String, dynamic>?> callTool(String toolName, Map<String, dynamic> arguments) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_mcpHubUrl/mcp/tools/call'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': toolName,
          'arguments': arguments,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Failed to call tool: $e');
      return null;
    }
  }

  /// Get available tools for a specific LLM (if permissions are configured)
  List<McpTool> getToolsForLLM(String? llmId) {
    final allTools = <McpTool>[];
    
    _availableTools.forEach((serverId, tools) {
      // In a real implementation, you'd check permissions here
      allTools.addAll(tools);
    });
    
    return allTools;
  }

  /// Stream tool call responses (for long-running operations)
  Stream<Map<String, dynamic>> streamToolCall(String toolName, Map<String, dynamic> arguments) async* {
    try {
      // For now, just yield the single response
      // In a real implementation, you might use Server-Sent Events or WebSockets
      final result = await callTool(toolName, arguments);
      if (result != null) {
        yield result;
      }
    } catch (e) {
      debugPrint('Failed to stream tool call: $e');
      yield {'error': 'Tool call failed: $e'};
    }
  }

  /// Dispose of resources
  void dispose() {
    _httpClient.close();
    _isInitialized = false;
  }
}
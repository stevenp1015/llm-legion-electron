/// Protocol constants and utilities for MCP
library;

/// MCP protocol versions and constants
class McpProtocol {
  /// Protocol version for 2025-03-26
  static const String v2025_03_26 = "2025-03-26";

  /// Protocol version for 2024-11-05
  static const String v2024_11_05 = "2024-11-05";

  /// Supported protocol versions in order of preference
  static const List<String> supportedVersions = [v2025_03_26, v2024_11_05];

  /// Default protocol version
  static const String defaultVersion = v2025_03_26;

  /// JSON-RPC version
  static const String jsonRpcVersion = "2.0";

  /// Standard MCP methods
  static const String methodInitialize = "initialize";
  static const String methodInitialized = "notifications/initialized";
  static const String methodShutdown = "shutdown";
  static const String methodListTools = "tools/list";
  static const String methodCallTool = "tools/call";
  static const String methodCancelTool = "tools/cancel";
  static const String methodListResources = "resources/list";
  static const String methodReadResource = "resources/read";
  static const String methodSubscribeResource = "resources/subscribe";
  static const String methodUnsubscribeResource = "resources/unsubscribe";
  static const String methodListResourceTemplates = "resources/templates/list";
  static const String methodListPrompts = "prompts/list";
  static const String methodGetPrompt = "prompts/get";
  static const String methodComplete = "completion/complete";
  static const String methodListRoots = "roots/list";
  static const String methodAddRoot = "roots/add";
  static const String methodRemoveRoot = "roots/remove";

  /// 2025-03-26 New methods
  static const String methodBatch = "batch";
  static const String methodHealthCheck = "health/check";
  static const String methodCapabilitiesUpdate = "capabilities/update";

  /// Notifications
  static const String methodProgress = "notifications/progress";
  static const String methodCancelled = "notifications/cancelled";
  static const String methodResourceUpdated = "notifications/resources/updated";
  static const String methodResourceListChanged =
      "notifications/resources/list_changed";
  static const String methodToolListChanged =
      "notifications/tools/list_changed";
  static const String methodPromptListChanged =
      "notifications/prompts/list_changed";
  static const String methodRootListChanged =
      "notifications/roots/list_changed";
  static const String methodLog = "notifications/message";
  static const String methodSetLevel = "logging/setLevel";

  /// Authorization methods (2025-03-26)
  static const String methodAuthorize = "auth/authorize";
  static const String methodToken = "auth/token";
  static const String methodRevoke = "auth/revoke";
  static const String methodRefresh = "auth/refresh";

  /// Progress token types
  static const String progressTokenString = "string";
  static const String progressTokenNumber = "number";

  /// Standard error codes
  static const int errorParse = -32700;
  static const int errorInvalidRequest = -32600;
  static const int errorMethodNotFound = -32601;
  static const int errorInvalidParams = -32602;
  static const int errorInternal = -32603;

  /// MCP-specific error codes
  static const int errorResourceNotFound = -32001;
  static const int errorResourceAccessDenied = -32002;
  static const int errorToolNotFound = -32003;
  static const int errorToolExecutionFailed = -32004;
  static const int errorPromptNotFound = -32005;
  static const int errorProtocolError = -32006;

  /// Check if a version is supported
  static bool isVersionSupported(String version) {
    return supportedVersions.contains(version);
  }

  /// Get the best common version from client and server versions
  static String? negotiateVersion(
    List<String> clientVersions,
    List<String> serverVersions,
  ) {
    for (final version in clientVersions) {
      if (serverVersions.contains(version) && isVersionSupported(version)) {
        return version;
      }
    }
    return null;
  }
}

/// Protocol capabilities
class ProtocolCapabilities {
  final bool experimental;
  final bool tools;
  final bool resources;
  final bool prompts;
  final bool logging;

  const ProtocolCapabilities({
    this.experimental = false,
    this.tools = true,
    this.resources = true,
    this.prompts = true,
    this.logging = true,
  });

  Map<String, dynamic> toJson() => {
    if (experimental) 'experimental': experimental,
    if (tools) 'tools': tools,
    if (resources) 'resources': resources,
    if (prompts) 'prompts': prompts,
    if (logging) 'logging': logging,
  };

  factory ProtocolCapabilities.fromJson(Map<String, dynamic> json) {
    return ProtocolCapabilities(
      experimental: json['experimental'] ?? false,
      tools: json['tools'] ?? true,
      resources: json['resources'] ?? true,
      prompts: json['prompts'] ?? true,
      logging: json['logging'] ?? true,
    );
  }
}

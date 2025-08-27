import 'package:json_annotation/json_annotation.dart';

part 'minion_config.g.dart';

@JsonSerializable()
class UsageStats {
  final int totalTokens;
  final int totalCost;
  final int totalRequests;
  final DateTime? lastUsed;

  const UsageStats({
    this.totalTokens = 0,
    this.totalCost = 0,
    this.totalRequests = 0,
    this.lastUsed,
  });

  factory UsageStats.fromJson(Map<String, dynamic> json) =>
      _$UsageStatsFromJson(json);

  Map<String, dynamic> toJson() => _$UsageStatsToJson(this);
}

@JsonSerializable()
class MinionConfig {
  final String id;
  final String name;
  final String role;
  final String systemPrompt;
  final String model;
  final String apiKeyId;
  final String? chatColor;
  final String? fontColor;
  final double temperature;
  final int maxTokens;
  final bool enabled;
  final UsageStats? usageStats;
  final Map<String, dynamic>? mcpTools;

  const MinionConfig({
    required this.id,
    required this.name,
    required this.role,
    required this.systemPrompt,
    required this.model,
    required this.apiKeyId,
    this.chatColor,
    this.fontColor,
    this.temperature = 0.7,
    this.maxTokens = 2000,
    this.enabled = true,
    this.usageStats,
    this.mcpTools,
  });

  factory MinionConfig.fromJson(Map<String, dynamic> json) =>
      _$MinionConfigFromJson(json);

  Map<String, dynamic> toJson() => _$MinionConfigToJson(this);

  MinionConfig copyWith({
    String? id,
    String? name,
    String? role,
    String? systemPrompt,
    String? model,
    String? apiKeyId,
    String? chatColor,
    String? fontColor,
    double? temperature,
    int? maxTokens,
    bool? enabled,
    UsageStats? usageStats,
    Map<String, dynamic>? mcpTools,
  }) {
    return MinionConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      model: model ?? this.model,
      apiKeyId: apiKeyId ?? this.apiKeyId,
      chatColor: chatColor ?? this.chatColor,
      fontColor: fontColor ?? this.fontColor,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      enabled: enabled ?? this.enabled,
      usageStats: usageStats ?? this.usageStats,
      mcpTools: mcpTools ?? this.mcpTools,
    );
  }
}
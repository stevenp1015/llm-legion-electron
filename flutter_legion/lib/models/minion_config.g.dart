// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'minion_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UsageStats _$UsageStatsFromJson(Map<String, dynamic> json) => UsageStats(
      totalTokens: (json['totalTokens'] as num?)?.toInt() ?? 0,
      totalCost: (json['totalCost'] as num?)?.toInt() ?? 0,
      totalRequests: (json['totalRequests'] as num?)?.toInt() ?? 0,
      lastUsed: json['lastUsed'] == null
          ? null
          : DateTime.parse(json['lastUsed'] as String),
    );

Map<String, dynamic> _$UsageStatsToJson(UsageStats instance) =>
    <String, dynamic>{
      'totalTokens': instance.totalTokens,
      'totalCost': instance.totalCost,
      'totalRequests': instance.totalRequests,
      'lastUsed': instance.lastUsed?.toIso8601String(),
    };

MinionConfig _$MinionConfigFromJson(Map<String, dynamic> json) => MinionConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      systemPrompt: json['systemPrompt'] as String,
      model: json['model'] as String,
      apiKeyId: json['apiKeyId'] as String,
      chatColor: json['chatColor'] as String?,
      fontColor: json['fontColor'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 2000,
      enabled: json['enabled'] as bool? ?? true,
      usageStats: json['usageStats'] == null
          ? null
          : UsageStats.fromJson(json['usageStats'] as Map<String, dynamic>),
      mcpTools: json['mcpTools'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$MinionConfigToJson(MinionConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'role': instance.role,
      'systemPrompt': instance.systemPrompt,
      'model': instance.model,
      'apiKeyId': instance.apiKeyId,
      'chatColor': instance.chatColor,
      'fontColor': instance.fontColor,
      'temperature': instance.temperature,
      'maxTokens': instance.maxTokens,
      'enabled': instance.enabled,
      'usageStats': instance.usageStats,
      'mcpTools': instance.mcpTools,
    };

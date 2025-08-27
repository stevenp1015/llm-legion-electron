// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
      id: json['id'] as String,
      channelId: json['channelId'] as String,
      senderType: $enumDecode(_$MessageSenderEnumMap, json['senderType']),
      senderName: json['senderName'] as String,
      senderRole: json['senderRole'] as String?,
      content: json['content'] as String,
      timestamp: (json['timestamp'] as num).toInt(),
      chatColor: json['chatColor'] as String?,
      fontColor: json['fontColor'] as String?,
      isStreaming: json['isStreaming'] as bool? ?? false,
      toolResults: json['toolResults'] as Map<String, dynamic>?,
      isDiaryEntry: json['isDiaryEntry'] as bool? ?? false,
      internalDiary: json['internalDiary'] as Map<String, dynamic>?,
      isError: json['isError'] as bool?,
    );

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'channelId': instance.channelId,
      'senderType': _$MessageSenderEnumMap[instance.senderType]!,
      'senderName': instance.senderName,
      'senderRole': instance.senderRole,
      'content': instance.content,
      'timestamp': instance.timestamp,
      'chatColor': instance.chatColor,
      'fontColor': instance.fontColor,
      'isStreaming': instance.isStreaming,
      'toolResults': instance.toolResults,
      'isDiaryEntry': instance.isDiaryEntry,
      'internalDiary': instance.internalDiary,
      'isError': instance.isError,
    };

const _$MessageSenderEnumMap = {
  MessageSender.user: 'user',
  MessageSender.ai: 'ai',
  MessageSender.system: 'system',
};

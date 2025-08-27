import 'package:json_annotation/json_annotation.dart';

part 'chat_message.g.dart';

enum MessageSender {
  @JsonValue('user')
  user,
  @JsonValue('ai')
  ai,
  @JsonValue('system')
  system,
}

@JsonSerializable()
class ChatMessage {
  final String id;
  final String channelId;
  final MessageSender senderType;
  final String senderName;
  final String? senderRole;
  final String content;
  final int timestamp;
  final String? chatColor;
  final String? fontColor;
  final bool isStreaming;
  final Map<String, dynamic>? toolResults;
  final bool isDiaryEntry;
  final Map<String, dynamic>? internalDiary;
  final bool? isError;

  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.senderType,
    required this.senderName,
    this.senderRole,
    required this.content,
    required this.timestamp,
    this.chatColor,
    this.fontColor,
    this.isStreaming = false,
    this.toolResults,
    this.isDiaryEntry = false,
    this.internalDiary,
    this.isError,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);

  ChatMessage copyWith({
    String? id,
    String? channelId,
    MessageSender? senderType,
    String? senderName,
    String? senderRole,
    String? content,
    int? timestamp,
    String? chatColor,
    String? fontColor,
    bool? isStreaming,
    Map<String, dynamic>? toolResults,
    bool? isDiaryEntry,
    Map<String, dynamic>? internalDiary,
    bool? isError,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      senderType: senderType ?? this.senderType,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      chatColor: chatColor ?? this.chatColor,
      fontColor: fontColor ?? this.fontColor,
      isStreaming: isStreaming ?? this.isStreaming,
      toolResults: toolResults ?? this.toolResults,
      isDiaryEntry: isDiaryEntry ?? this.isDiaryEntry,
      internalDiary: internalDiary ?? this.internalDiary,
      isError: isError ?? this.isError,
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);
}
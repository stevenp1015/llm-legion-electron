
export interface ApiKey {
  id: string;
  name: string;
  key: string; // The actual API key value
}

export interface SelectedKeyInfo {
  key: string;
  name: string;
  method: 'Assigned' | 'Load Balanced' | 'None' | 'Proxy';
}

export interface ModelQuotas {
  rpm: number;
  tpm: number;
  rpd: number;
  sharedPool?: string; // Identifier for shared quotas
}

export interface UsageStat {
  timestamp: number;
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}

export interface PromptPreset {
  id: string;
  name: string;
  content: string;
}

export interface McpTool {
    name: string;
    description?: string;
    inputSchema?: any; // The JSON schema for the tool's input
    serverId: string;
    serverName: string;
}

export interface McpServerInfo {
    id: string;
    name: string;
    url: string;
    status: 'disconnected' | 'connecting' | 'connected' | 'error';
    errorMessage?: string;
    tools?: McpTool[];
}

export interface MinionConfig {
  id: string;
  name: string; // Unique Minion name (e.g., "Alpha", "Bravo")
  role: 'standard' | 'regulator';
  provider: 'google'; // Assuming Gemini models via ADK backend
  model_id: string; // Specific model for this Minion
  model_name?: string; // Optional user-friendly name for the model
  system_prompt_persona: string; // The Minion's core personality and Fire Code
  params: {
    temperature: number;
    // Potentially other ADK-specific params in future
  };
  apiKeyId?: string; // Optional: Assign a specific key from the user's pool
  opinionScores: Record<string, number>; // Minion's opinion of others { participantName: score }
  lastDiaryState?: MinionDiaryState | null; // The last known structured diary state
  status?: string; // e.g., "Idle", "Processing Task X"
  currentTask?: string;
  usageStats: {
    requests: UsageStat[];
  };
  mcpTools?: { toolName: string }[];

  // --- UI Customization ---
  chatColor?: string; // Optional: Hex code for chat bubble background
  fontColor?: string; // Optional: Hex code for chat text color

  // --- Regulator-specific ---
  regulationInterval?: number; // e.g., trigger every 10 messages

  // --- Transient properties added at runtime ---
  currentUsage?: { rpm: number; tpm: number; rpd: number };
  quotas?: ModelQuotas;
}

export enum MessageSender {
  User = 'User',
  AI = 'AI', // Represents a Minion
  System = 'System',
  Tool = 'Tool'
}

export interface MinionDiaryState {
  perceptionAnalysis: string;
  opinionUpdates: {
    participantName: string;
    newScore: number;
    reasonForChange: string;
  }[];
  finalOpinions: Record<string, number>;
  selectedResponseMode: string;
  personalNotes?: string;
}

export interface ToolCall {
    name: string;
    arguments: Record<string, any>;
}

export interface PerceptionPlan extends MinionDiaryState {
  action: 'SPEAK' | 'STAY_SILENT' | 'USE_TOOL';
  responsePlan: string; // A brief summary of what the minion intends to say if it chooses to speak.
  predictedResponseTime: number; // Estimated time in ms for how quickly the Minion wants to respond.
  toolCall?: ToolCall;
  speakWhileTooling?: string | null; // A message to speak *before* executing a tool.
}

export interface RegulatorReport {
  overall_sentiment: 'positive' | 'negative' | 'neutral' | 'mixed';
  conversation_goal_inference: string;
  on_topic_score: number; // 0-100
  progress_score: number; // 0-100
  is_stalled_or_looping: boolean;
  summary_of_discussion: string;
  suggested_next_steps: string[];
}


export interface ChatMessageData {
  id:string;
  channelId: string; // ID of the channel this message belongs to
  senderType: MessageSender;
  senderName: string; // "Steven" for user, Minion's name for AI, "System", "Tool"
  senderRole?: MinionConfig['role'];
  content: string;
  timestamp: number;
  internalDiary?: MinionDiaryState | null; // For Minion messages, now structured
  isError?: boolean;
  replyToMessageId?: string; // For threaded replies (future)
  isProcessing?: boolean; // New flag for typing indicator

  // New fields for structured tool calls
  isToolCall?: boolean;
  isToolOutput?: boolean;
  toolCall?: ToolCall;
  toolOutput?: string; // The raw output from the tool
}

export interface ModelOption {
  id: string;
  name: string;
}

export type ChannelType = 'user_minion_group' | 'minion_minion_auto' | 'system_log' | 'dm';

export interface Channel {
  id:string;
  name: string; // e.g., "#general", "#commander_direct_alpha"
  description?: string;
  type: ChannelType;
  members: string[]; // IDs of Minions/User in this channel
  isPrivate?: boolean;
  
  // Properties for the new autonomous mode
  isAutoModeActive?: boolean;
  autoModeDelayType?: 'fixed' | 'random';
  autoModeFixedDelay?: number; // in seconds
  autoModeRandomDelay?: { min: number, max: number }; // in seconds

  // --- Regulator properties ---
  messageCounter?: number;
}

export interface ChannelPayload extends Omit<Channel, 'id' | 'members'> {
  id?: string;
  members: string[];
}


// Environment variable access (still relevant for UI's own potential key)
export interface ProcessEnv {
  API_KEY?: string;
}

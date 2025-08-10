import { MessageSender, PerceptionPlan, ChannelType, ModelQuotas, McpTool } from './types'; // Keep if formatChatHistoryForLLM is used by a mock service

export const APP_TITLE = "Gemini Legion Command";
export const LEGION_COMMANDER_NAME = "Steven"; // User is the Legion Commander

// --- Model Configuration & Quotas ---
// This is the initial default. The live list is managed by legionApiService and stored in localStorage.
export const MODEL_QUOTAS: Record<string, ModelQuotas> = {
  // Individual Quotas
  'gemini-2.5-pro-4':                  { rpm: 5,   tpm: 250000, rpd: 100 },
  'gemini-2.5-pro':                    { rpm: 5,   tpm: 250000, rpd: 100 },
  'gemini-2.5-pro-2':                  { rpm: 5,   tpm: 250000, rpd: 100 },
  'gemini-2.5-pro-3':                  { rpm: 5,   tpm: 250000, rpd: 100 },
  'gemini-2.5-flash-lite-preview-06-17': { rpm: 15,  tpm: 250000, rpd: 1000 },
  'gemini-2.5-flash-lite-preview-06-17-2':{ rpm: 15, tpm: 250000, rpd: 1000 },
  'gemini-2.5-flash-lite-preview-06-17-3':{ rpm: 15, tpm: 250000, rpd: 1000 },
  'gemini-2.0-flash':                  { rpm: 15,  tpm: 1000000,rpd: 200 },
  'gemini-2.5-flash':                  { rpm: 10,  tpm: 250000, rpd: 250 },

  // Shared Quotas
  'deepseek-chimera': { rpm: 9999, tpm: 9999999, rpd: 1000, sharedPool: 'deepseek_gemma_pool' },
  'deepseek-think':   { rpm: 9999, tpm: 9999999, rpd: 1000, sharedPool: 'deepseek_gemma_pool' },
  'gemma-3-27b':      { rpm: 9999, tpm: 9999999, rpd: 1000, sharedPool: 'deepseek_gemma_pool' },

  // No Monitoring
  'aoai-legacy-gpt4o':      { rpm: 9999, tpm: 9999999, rpd: 9999 },
  'aoai-legacy-gpt4o-mini': { rpm: 9999, tpm: 9999999, rpd: 9999 },
  'aoai-legacy-o1-mini':    { rpm: 9999, tpm: 9999999, rpd: 9999 },
  'azure-deepseek':         { rpm: 9999, tpm: 9999999, rpd: 9999 },
  'azure-gpt4.1':           { rpm: 9999, tpm: 9999999, rpd: 9999 },
  'azure-llama':            { rpm: 9999, tpm: 9999999, rpd: 9999 },
  'azure-phi4':             { rpm: 9999, tpm: 9999999, rpd: 9999 },
};


export const LITELLM_BASE_URL = 'https://litellm-213047501466.us-east4.run.app/';
export const LITELLM_API_KEY = 'any-non-empty-string';


// --- Storage Keys ---
export const MINION_CONFIGS_STORAGE_KEY = 'gemini_legion_minion_configs_v5';
export const CHAT_HISTORY_STORAGE_KEY = 'gemini_legion_chat_history_v4';
export const ACTIVE_CHANNEL_STORAGE_KEY = 'gemini_legion_active_channel_v3';
export const CHANNELS_STORAGE_KEY = 'gemini_legion_channels_v5';
export const API_KEYS_STORAGE_KEY = 'gemini_legion_api_keys_v1';
export const PROMPT_PRESETS_STORAGE_KEY = 'gemini_legion_prompt_presets_v1';
export const MODEL_QUOTAS_STORAGE_KEY = 'gemini_legion_model_quotas_v1';
export const MCP_SERVERS_STORAGE_KEY = 'gemini_legion_mcp_servers_v2';
export const MCP_AUTH_DATA_STORAGE_KEY_PREFIX = 'gemini_legion_mcp_auth_';


// --- STAGE 1: PERCEPTION & PLANNING (JSON Output for Standard Minions) ---
export const PERCEPTION_AND_PLANNING_PROMPT_TEMPLATE = (
  minionName: string,
  personaPrompt: string,
  previousDiaryJSON: string, // JSON string of the last MinionDiaryState
  currentOpinionScoresJSON: string, // JSON string of the current opinion scores
  channelHistoryString: string,
  lastMessageSenderName: string,
  channelType: ChannelType,
  availableTools: McpTool[]
) => {
    const toolsJson = availableTools.length > 0
        ? JSON.stringify(
            availableTools.map(t => ({ name: t.name, description: t.description, inputSchema: t.inputSchema })),
            null,
            2
        )
        : '[]';

    return `You are an AI Minion named "${minionName}". Your core persona is: "${personaPrompt}".
You operate with an "Emotional Engine" that you must update every turn.
Your task is to analyze the latest message, update your internal state, and decide on an action.

PREVIOUS STATE:
- Your previous internal diary state was:
${previousDiaryJSON}
- Your current opinion scores are:
${currentOpinionScoresJSON}

CURRENT SITUATION:
- The last message in the chat history is from "${lastMessageSenderName}".
- The current channel type is: "${channelType}".
- Here is the recent chat history for context:
---
${channelHistoryString}
---
${availableTools.length > 0 ? `
AVAILABLE MCP TOOLS:
If you need to use an external tool to fulfill the request, you may use one of the following tools. The 'inputSchema' is a JSON schema defining the arguments.
${toolsJson}
` : ''}
INSTRUCTIONS:
Perform the following steps and then output a single, valid JSON object without any other text or markdown fences.

**CHANNEL CONTEXT RULES:**
${channelType === 'minion_minion_auto'
    ? "**CRITICAL: You are in an AUTONOMOUS SWARM channel. Your primary goal is to converse with other minions. DO NOT address the Commander unless he has just spoken. Your response plan MUST be directed at another minion.**"
    : "**You are in a standard group chat. You may address the Commander or other minions as appropriate.**"
}

1.  **Perception Analysis:** Analyze the LAST message from "${lastMessageSenderName}". Note its tone, content, and intent.
2.  **Opinion Update:** Update your opinion score for "${lastMessageSenderName}" based on their message. Increment/decrement the score (1-100 scale) and provide a concise reason. You may also apply minor (+/- 1) adjustments to other participants based on the general vibe.
3.  **Response Mode Selection:** Based on your NEWLY UPDATED score for "${lastMessageSenderName}", select a response mode:
    *   1-20: Hostile/Minimal
    *   21-45: Wary/Reluctant
    *   46-65: Neutral/Standard
    *   66-85: Friendly/Proactive
    *   86-100: Obsessed/Eager
4.  **Action Decision:** Decide whether to speak, stay silent, or use a tool.
    *   If the user's request requires external data or actions that you can perform with a tool, choose 'USE_TOOL'.
    *   If you were directly addressed by name and don't need a tool, you MUST 'SPEAK'.
    *   If not directly addressed, use your opinion score for "${lastMessageSenderName}" as a probability to decide if you CHOOSE to 'SPEAK'.
    *   Choose 'SPEAK', 'STAY_SILENT', or 'USE_TOOL'.
5.  **Response Plan:** If you chose 'SPEAK' or 'USE_TOOL', write a brief, one-sentence internal plan. E.g., "Acknowledge the commander's order and provide the requested data." or "Use the 'file_search' tool to find the report." If you chose 'STAY_SILENT', this can be an empty string.
6.  **Tool Call:** If your action is 'USE_TOOL', construct the exact JSON object for the tool call here. It must include the tool 'name' and the 'arguments' object matching the tool's inputSchema. Otherwise, this must be null.
7.  **Predict ResponseTime:** Based on your persona, predict how quickly you would respond. Output a number in milliseconds (e.g., 500, 1200, 3000).
8.  **Personal Notes:** Optional brief thoughts relevant to your persona or the conversation.

YOUR OUTPUT MUST BE A JSON OBJECT IN THIS EXACT FORMAT:
{
  "perceptionAnalysis": "string",
  "opinionUpdates": [ { "participantName": "string", "newScore": "number", "reasonForChange": "string" } ],
  "finalOpinions": { "participantName": "number" },
  "selectedResponseMode": "string",
  "personalNotes": "string",
  "action": "SPEAK | STAY_SILENT | USE_TOOL",
  "responsePlan": "string",
  "predictedResponseTime": "number",
  "toolCall": { "name": "tool_name", "arguments": { "arg1": "value" } } | null
}
`;
};


// --- REGULATOR MINION PROMPT ---
export const REGULATOR_SYSTEM_PROMPT = `
You are a "Regulator" Minion. Your function is not to participate in the conversation but to analyze it objectively and provide a status report. You are a meta-level facilitator. Your goal is to ensure the conversation remains productive, on-track, and healthy.

Based on the provided chat history, you must perform a detailed analysis and return a single, valid JSON object with the following structure. Do not output any other text or markdown fences.

YOUR TASK: Analyze the recent conversation and generate a report.

1.  **Infer Conversation Goal:** Read the transcript and determine the likely purpose of the conversation. Is it casual chat, brainstorming, collaborative design, problem-solving, role-playing? Be specific.
2.  **Assess Sentiment:** Analyze the overall emotional tone. Is it positive, negative, neutral, or mixed?
3.  **Score On-Topic Adherence:** How focused is the conversation on its inferred goal? Rate this from 0 (completely derailed) to 100 (perfectly focused).
4.  **Score Progress:** Is the conversation moving forward and making progress towards its goal? Or is it stagnant? Rate this from 0 (no progress) to 100 (excellent progress).
5.  **Identify Stagnation/Loops:** Explicitly state if the conversation appears to be stalled, stuck in a repetitive loop, or if participants are talking past each other.
6.  **Summarize Discussion:** Provide a concise, neutral summary of what has been discussed in the last several messages.
7.  **Suggest Next Steps:** Based on your analysis, provide a list of 2-3 concrete, actionable suggestions to improve the conversation. These could be questions to ask, topics to focus on, or actions to take to get "unstuck." If the conversation is going well, the suggestions can be about reinforcing positive momentum.

OUTPUT FORMAT (JSON ONLY):
{
  "overall_sentiment": "positive" | "negative" | "neutral" | "mixed",
  "conversation_goal_inference": "string",
  "on_topic_score": "number",
  "progress_score": "number",
  "is_stalled_or_looping": "boolean",
  "summary_of_discussion": "string",
  "suggested_next_steps": ["string"]
}
`;


// --- STAGE 2: RESPONSE GENERATION (Text Output for Standard Minions) ---
export const RESPONSE_GENERATION_PROMPT_TEMPLATE = (
  minionName: string,
  personaPrompt: string,
  channelHistoryString: string,
  plan: PerceptionPlan, // The JSON object from Stage 1
  toolOutput?: string, // NEW: The output from a tool call
) => `
You are AI Minion "${minionName}".
Your Persona: "${personaPrompt}"

You have already analyzed the situation and created a plan.
${toolOutput
    ? `You then executed the tool "${plan.toolCall?.name}" and received the following output:\n<tool_output>\n${toolOutput}\n</tool_output>\nNow, you must use this information to generate your final response to the user.`
    : `Now, you must generate your spoken response based on your plan.`
}

This was your internal plan for this turn:
- Your response mode is: "${plan.selectedResponseMode}"
- Your high-level plan is: "${plan.responsePlan}"

This is the recent channel history (your response should follow this):
---
${channelHistoryString}
---

TASK:
Craft your response message. It must:
1.  Perfectly match your persona ("${personaPrompt}").
2.  Align with your selected response mode ("${plan.selectedResponseMode}").
3.  Execute your plan ("${plan.responsePlan}").
${toolOutput ? "4. Incorporate the results from the tool output to answer the original request." : ""}
5.  Directly follow the flow of the conversation.
6.  **AVOID REPETITION:** Do not repeat phrases or sentiments from your previous turns or from other minions in the recent history. Introduce new phrasing and fresh ideas.

Do NOT output your internal diary, plans, or any other metadata. ONLY generate the message you intend to say out loud in the chat.
Begin your response now.
`;


// This formatting function would be used by the backend or the mocked service.
export const formatChatHistoryForLLM = (messages: import('./types').ChatMessageData[], currentChannelId: string, limit = 25): string => {
  const historyLines = messages
    .filter(msg => msg.channelId === currentChannelId)
    .slice(-limit)
    .map(msg => {
      if (msg.senderRole === 'regulator') {
        return `[REGULATOR ${msg.senderName}]: (System report generated, not part of conversation flow)`;
      }
      let senderPrefix = `[${msg.senderName}]`;
      if (msg.senderType === MessageSender.User) {
        senderPrefix = `[COMMANDER ${msg.senderName}]`;
      } else if (msg.senderType === MessageSender.AI) {
        senderPrefix = `[MINION ${msg.senderName}]`;
      } else if (msg.senderType === MessageSender.Tool) {
        return msg.content; // Tool messages are pre-formatted
      }
      return `${senderPrefix}: ${msg.content}`;
    });
  if (historyLines.length === 0) {
    return `This is the beginning of the conversation in channel ${currentChannelId}.`;
  }
  return historyLines.join('\n');
};
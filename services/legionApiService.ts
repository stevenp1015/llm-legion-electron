
import { MinionConfig, ChatMessageData, MessageSender, Channel, ModelOption, PerceptionPlan, ChannelPayload, ApiKey, SelectedKeyInfo, UsageStat, PromptPreset, RegulatorReport, ChannelType, ModelQuotas, ToolCall, McpTool } from '../types';
import { 
    LEGION_COMMANDER_NAME, 
    MINION_CONFIGS_STORAGE_KEY, 
    CHAT_HISTORY_STORAGE_KEY,
    CHANNELS_STORAGE_KEY,
    API_KEYS_STORAGE_KEY,
    PROMPT_PRESETS_STORAGE_KEY,
    MODEL_QUOTAS_STORAGE_KEY,
    RESPONSE_GENERATION_PROMPT_TEMPLATE,
    PERCEPTION_AND_PLANNING_PROMPT_TEMPLATE,
    REGULATOR_SYSTEM_PROMPT,
    formatChatHistoryForLLM,
    LITELLM_API_KEY,
    LITELLM_BASE_URL,
    MODEL_QUOTAS,
} from '../constants';
import { callLiteLLMAPIStream, callLiteLLMApiForJson } from './geminiService';
import { mcpElectronService } from './mcpElectronService';


// @ts-nocheck

// --- IPC-based Storage Helpers ---

// This function now asynchronously fetches data from the main process.
const getStoredData = async <T>(key: string, defaultValue: T): Promise<T> => {
  const value = await window.electronAPI.invoke('store:get', key, defaultValue);
  return value;
};

// This function asynchronously sends data to the main process.
const setStoredData = async <T>(key: string, data: T): Promise<void> => {
  await window.electronAPI.invoke('store:set', key, data);
};

// --- One-Time Data Migration from localStorage to electron-store via IPC ---
const performMigration = async () => {
    // We ask the main process if migration is done.
    const isMigrationComplete = await window.electronAPI.invoke('store:get', 'migration_complete_v1', false);
    if (isMigrationComplete) {
        return;
    }

    console.log("Checking for data to migrate from localStorage...");

    const keysToMigrate = [
        MINION_CONFIGS_STORAGE_KEY,
        CHANNELS_STORAGE_KEY,
        CHAT_HISTORY_STORAGE_KEY,
        API_KEYS_STORAGE_KEY,
        PROMPT_PRESETS_STORAGE_KEY,
        MODEL_QUOTAS_STORAGE_KEY
    ];

    const migrationData = {};
    let needsMigration = false;
    for (const key of keysToMigrate) {
        const lsData = localStorage.getItem(key);
        if (lsData) {
            try {
                migrationData[key] = JSON.parse(lsData);
                needsMigration = true;
            } catch (error) {
                console.error(`Could not parse localStorage data for ${key}`, error);
            }
        }
    }

    if (needsMigration) {
        console.log("Sending data to main process for migration...");
        const result = await window.electronAPI.invoke('store:migrate', migrationData);
        if (result.success) {
            console.log("Migration successful. You can now clear localStorage if desired.");
            // You might want to clear localStorage after a successful migration
            // keysToMigrate.forEach(key => localStorage.removeItem(key));
        } else {
            console.error("Migration failed in main process:", result.message);
        }
    } else {
        console.log("No data found in localStorage. Marking migration as complete.");
        // Still need to mark it as complete to avoid checking every time.
        await window.electronAPI.invoke('store:set', 'migration_complete_v1', true);
    }
};

// We can't run async logic at the top level, so we'll trigger migration
// inside the service constructor.

interface HandleUserMessageParams {
    channelId: string;
    triggeringMessage: ChatMessageData;
    onMinionResponse: (message: ChatMessageData) => void;
    onMinionResponseChunk: (channelId: string, messageId: string, chunk: string) => void;
    onMinionProcessingUpdate: (minionName: string, isProcessing: boolean) => void;
    onSystemMessage: (systemMessage: ChatMessageData) => void;
    onRegulatorReport: (reportMsg: ChatMessageData) => void;
}


class LegionApiService {
  private minionConfigs: MinionConfig[];
  private channels: Channel[];
  private messages: Record<string, ChatMessageData[]>;
  private apiKeys: ApiKey[];
  private promptPresets: PromptPreset[];
  private modelQuotas: Record<string, ModelQuotas>;
  private apiKeyRoundRobinIndex = 0;
  private sharedPoolUsage: Record<string, { requests: UsageStat[] }> = {};
  private isInitialized = false;

  constructor() {
    // Initialize with empty data, will be populated by async init
    this.minionConfigs = [];
    this.channels = [];
    this.messages = {};
    this.apiKeys = [];
    this.promptPresets = [];
    this.modelQuotas = {};
    this.init();
  }

  async init() {
    if (this.isInitialized) return;
    
    await performMigration();

    this.minionConfigs = await getStoredData<MinionConfig[]>(MINION_CONFIGS_STORAGE_KEY, []);
    this.channels = await getStoredData<Channel[]>(CHANNELS_STORAGE_KEY, []);
    this.messages = await getStoredData<Record<string, ChatMessageData[]>>(CHAT_HISTORY_STORAGE_KEY, {});
    this.apiKeys = await getStoredData<ApiKey[]>(API_KEYS_STORAGE_KEY, []);
    this.promptPresets = await getStoredData<PromptPreset[]>(PROMPT_PRESETS_STORAGE_KEY, []);
    this.modelQuotas = await getStoredData<Record<string, ModelQuotas>>(MODEL_QUOTAS_STORAGE_KEY, MODEL_QUOTAS);

    if (this.channels.length === 0) {
        this.channels = this.getInitialChannels();
        // Also save the initial channels to the store
        await this.saveState();
    }
    this.isInitialized = true;
    console.log("LegionApiService initialized with data from electron-store.");
  }

  getInitialChannels(): Channel[] {
      return [
        { id: 'general', name: '#general', description: 'General discussion with all Minions.', type: 'user_minion_group', members: [LEGION_COMMANDER_NAME, ...this.minionConfigs.map(m=>m.name)], messageCounter: 0 },
        { id: 'legion_ops_log', name: '#legion_ops_log', description: 'Automated Legion operational logs.', type: 'system_log', members: [], messageCounter: 0 },
      ];
  }

  private saveState() {
    setStoredData(MINION_CONFIGS_STORAGE_KEY, this.minionConfigs);
    setStoredData(CHANNELS_STORAGE_KEY, this.channels);
    setStoredData(CHAT_HISTORY_STORAGE_KEY, this.messages);
    setStoredData(API_KEYS_STORAGE_KEY, this.apiKeys);
    setStoredData(PROMPT_PRESETS_STORAGE_KEY, this.promptPresets);
    setStoredData(MODEL_QUOTAS_STORAGE_KEY, this.modelQuotas);
  }

  // --- API Key, Preset & Model Management ---
  async getApiKeys(): Promise<ApiKey[]> { return Promise.resolve([...this.apiKeys]); }
  async addApiKey(name: string, key: string): Promise<void> { this.apiKeys.push({ id: `key-${Date.now()}`, name, key }); this.saveState(); }
  async deleteApiKey(id: string): Promise<void> {
    this.minionConfigs.forEach(minion => { if (minion.apiKeyId === id) minion.apiKeyId = undefined; });
    this.apiKeys = this.apiKeys.filter(k => k.id !== id); this.saveState();
  }
  async getPromptPresets(): Promise<PromptPreset[]> { return Promise.resolve([...this.promptPresets]); }
  async addPromptPreset(name: string, content: string): Promise<void> { this.promptPresets.push({ id: `preset-${Date.now()}`, name, content }); this.saveState(); }
  async deletePromptPreset(id: string): Promise<void> { this.promptPresets = this.promptPresets.filter(p => p.id !== id); this.saveState(); }
  
  async getModelOptions(): Promise<ModelOption[]> {
    const options = Object.keys(this.modelQuotas).map(id => ({ id, name: id }));
    options.sort((a, b) => a.name.localeCompare(b.name));
    options.push({ id: 'custom-model-entry', name: 'Custom Model...' });
    return Promise.resolve(options);
  }

  async refreshModelsFromLiteLLM(): Promise<void> {
    try {
      const response = await fetch(`${LITELLM_BASE_URL}/models`, {
        headers: { 'Authorization': `Bearer ${LITELLM_API_KEY}` }
      });
      if (!response.ok) {
        const errorBody = await response.text();
        throw new Error(`Failed to fetch models: ${response.status} ${response.statusText} - ${errorBody}`);
      }
      const data = await response.json();
      const modelsFromApi = data.data as { id: string }[];
      
      let updated = false;
      for (const model of modelsFromApi) {
        if (!this.modelQuotas[model.id]) {
          // New model found, check if it should be added to the shared pool
          if (!/gemini|azure|aoai/i.test(model.id)) {
            this.modelQuotas[model.id] = { rpm: 9999, tpm: 9999999, rpd: 1000, sharedPool: 'deepseek_gemma_pool' };
            updated = true;
          }
        }
      }

      if (updated) {
        this.saveState();
      }
    } catch (error) {
      console.error("Error refreshing models from LiteLLM:", error);
      throw error;
    }
  }



  private _selectApiKey(minion?: MinionConfig): SelectedKeyInfo {
    if (minion?.model_id && this.modelQuotas[minion.model_id]) { return { key: LITELLM_API_KEY, name: 'LiteLLM Proxy', method: 'Proxy' }; }
    // Fallback for custom models not yet in the refreshed list
    if (minion?.model_id) { return { key: LITELLM_API_KEY, name: 'LiteLLM Proxy (Custom)', method: 'Proxy'}; }
    
    if (minion?.apiKeyId) { const key = this.apiKeys.find(k => k.id === minion.apiKeyId); if (key) return { key: key.key, name: key.name, method: 'Assigned' }; }
    if (this.apiKeys.length > 0) { const keyInfo = this.apiKeys[this.apiKeyRoundRobinIndex]; this.apiKeyRoundRobinIndex = (this.apiKeyRoundRobinIndex + 1) % this.apiKeys.length; return { key: keyInfo.key, name: keyInfo.name, method: 'Load Balanced' }; }
    return { key: '', name: 'N/A', method: 'None' };
  }
  
  // --- Minion Management ---
  private _getMinionWithStats(minion: MinionConfig): MinionConfig {
    const quotas = this.modelQuotas[minion.model_id];
    if (!quotas) return minion;
    const now = Date.now(), oneMinAgo = now - 6e4, oneDayAgo = now - 864e5;
    let requests = minion.usageStats.requests;
    if (quotas.sharedPool) {
      if (!this.sharedPoolUsage[quotas.sharedPool]) this.sharedPoolUsage[quotas.sharedPool] = { requests: [] };
      requests = this.minionConfigs.filter(m => this.modelQuotas[m.model_id]?.sharedPool === quotas.sharedPool).flatMap(m => m.usageStats.requests);
    }
    const requestsLastMinute = requests.filter(r => r.timestamp > oneMinAgo);
    const requestsLastDay = requests.filter(r => r.timestamp > oneDayAgo);
    const rpm = requestsLastMinute.length, tpm = requestsLastMinute.reduce((s, r) => s + r.totalTokens, 0), rpd = requestsLastDay.length;
    return { ...minion, quotas, currentUsage: { rpm, tpm, rpd } };
  }

  async getMinions(): Promise<MinionConfig[]> { return Promise.resolve(this.minionConfigs.map(m => this._getMinionWithStats(m))); }

  async addMinion(config: MinionConfig): Promise<MinionConfig> {
    const newMinionName = config.name;
    this.minionConfigs.forEach(m => { m.opinionScores[newMinionName] = 50; });
    const initialScoresForNewMinion: Record<string, number> = { [LEGION_COMMANDER_NAME]: 50 };
    this.minionConfigs.forEach(m => { initialScoresForNewMinion[m.name] = 50; });
    const newMinion: MinionConfig = { ...config, id: config.id || `minion-${Date.now()}`, opinionScores: initialScoresForNewMinion, status: 'Idle', lastDiaryState: null, usageStats: { requests: [] }};
    this.minionConfigs.push(newMinion);
    this.channels.forEach(c => { if(c.type !== 'system_log') c.members.push(newMinion.name); });
    this.saveState();
    return newMinion;
  }
  async updateMinion(updatedConfig: MinionConfig): Promise<MinionConfig> {
    const index = this.minionConfigs.findIndex(m => m.id === updatedConfig.id);
    if (index === -1) throw new Error("Minion not found.");
    updatedConfig.usageStats = this.minionConfigs[index].usageStats;
    this.minionConfigs[index] = updatedConfig; this.saveState();
    return updatedConfig;
  }
  async deleteMinion(id: string): Promise<void> {
    const minionToDelete = this.minionConfigs.find(m => m.id === id);
    if (!minionToDelete) return;
    this.minionConfigs = this.minionConfigs.filter(m => m.id !== id);
    this.minionConfigs.forEach(m => { delete m.opinionScores[minionToDelete.name]; });
    this.channels.forEach(c => { c.members = c.members.filter(name => name !== minionToDelete.name); });
    this.saveState();
  }

  // --- Channel Management ---
  async getChannels(): Promise<Channel[]> { return Promise.resolve([...this.channels]); }
  async addOrUpdateChannel(channelData: ChannelPayload): Promise<Channel> {
      if (channelData.id) {
          const index = this.channels.findIndex(c => c.id === channelData.id);
          if (index > -1) {
              this.channels[index] = { ...this.channels[index], ...channelData };
              this.saveState();
              return this.channels[index];
          }
      }
      const newChannel: Channel = { id: `channel-${Date.now()}`, name: channelData.name, type: channelData.type, description: channelData.description || '', isPrivate: false, members: channelData.members, isAutoModeActive: false, autoModeDelayType: 'fixed', autoModeFixedDelay: 5, autoModeRandomDelay: { min: 3, max: 10 }, messageCounter: 0 };
      this.channels.push(newChannel);
      if (!this.messages[newChannel.id]) this.messages[newChannel.id] = [];
      this.saveState();
      return newChannel;
  }

  // --- Message Management ---
  async getMessages(channelId: string): Promise<ChatMessageData[]> { return Promise.resolve([...(this.messages[channelId] || [])]); }
  private _updateUsage(minionId: string, usage: {prompt_tokens: number, completion_tokens: number, total_tokens: number}) {
      const minion = this.minionConfigs.find(m => m.id === minionId);
      if (minion) {
          minion.usageStats.requests.push({ timestamp: Date.now(), promptTokens: usage.prompt_tokens, completionTokens: usage.completion_tokens, totalTokens: usage.total_tokens });
          const oneDayAgo = Date.now() - 864e5;
          minion.usageStats.requests = minion.usageStats.requests.filter(r => r.timestamp > oneDayAgo);
          this.saveState();
      }
  }
  private _checkLimits(minionId: string): { allowed: boolean, reason: string } {
      const minion = this.minionConfigs.find(m => m.id === minionId);
      if (!minion) return { allowed: false, reason: "Minion not found." };
      const { quotas, currentUsage } = this._getMinionWithStats(minion);
      if (!quotas || !currentUsage) return { allowed: true, reason: "" }; // Allow if not monitored
      if (currentUsage.rpm >= quotas.rpm) return { allowed: false, reason: `RPM limit of ${quotas.rpm} reached.` };
      if (currentUsage.tpm >= quotas.tpm) return { allowed: false, reason: `TPM limit of ${quotas.tpm} reached.` };
      if (currentUsage.rpd >= quotas.rpd) return { allowed: false, reason: `RPD limit of ${quotas.rpd} reached.` };
      return { allowed: true, reason: "" };
  }
  
  private async _executeMcpTool(channelId: string, minionName: string, toolCall: ToolCall, onSystemMessage: (msg: ChatMessageData) => void): Promise<string> {
    const toolCallMessage: ChatMessageData = {
        id: `tool-call-${Date.now()}`,
        channelId,
        senderType: MessageSender.Tool,
        senderName: 'System',
        content: `[TOOL CALL] Minion ${minionName} is using tool: ${toolCall.name}(${JSON.stringify(toolCall.arguments)})`,
        timestamp: Date.now()
    };
    onSystemMessage(toolCallMessage);
    this.messages[channelId].push(toolCallMessage);

    try {
        const result = await mcpElectronService.callTool(toolCall);
        const output = result.content.map((c: any) => {
            if (c.type === 'text') return c.text;
            if (c.type === 'resource_link') return `[Resource Link: ${c.name} at ${c.uri}]`;
            return `[Unsupported tool output type: ${c.type}]`;
        }).join('\n');
        
        const toolOutputMessage: ChatMessageData = {
            id: `tool-output-${Date.now()}`,
            channelId,
            senderType: MessageSender.Tool,
            senderName: 'System',
            content: `[TOOL OUTPUT] ${output}`,
            timestamp: Date.now()
        };
        onSystemMessage(toolOutputMessage);
        this.messages[channelId].push(toolOutputMessage);
        
        return output;

    } catch (e: any) {
        const error = e.message || 'Unknown error during tool execution.';
        const toolErrorMessage: ChatMessageData = {
            id: `tool-error-${Date.now()}`,
            channelId,
            senderType: MessageSender.Tool,
            senderName: 'System',
            content: `[TOOL ERROR] ${error}`,
            timestamp: Date.now(),
            isError: true
        };
        onSystemMessage(toolErrorMessage);
        this.messages[channelId].push(toolErrorMessage);
        return `ERROR: ${error}`;
    }
  }

  async processMessageTurn(params: HandleUserMessageParams): Promise<void> {
    const { channelId, triggeringMessage: userMessage, onMinionResponse, onMinionResponseChunk, onMinionProcessingUpdate, onSystemMessage, onRegulatorReport } = params;
    if (!this.messages[channelId]) this.messages[channelId] = [];
    this.messages[channelId].push(userMessage);
    const channel = this.channels.find(c => c.id === channelId);
    if(channel) channel.messageCounter = (channel.messageCounter || 0) + 1;

    const activeChannel = this.channels.find(c => c.id === channelId);
    if (!activeChannel) return;

    const minionsInChannel = this.minionConfigs.filter(minion => activeChannel.members.includes(minion.name) && minion.role === 'standard');
    if (minionsInChannel.length === 0 && userMessage.senderType === MessageSender.User) {
       await this._checkForRegulatorAction(activeChannel, onRegulatorReport, onSystemMessage);
       this.saveState();
       return;
    }
    
    let dynamicChatHistory = formatChatHistoryForLLM(this.messages[channelId], channelId);
    const perceptionPromises = minionsInChannel.map(minion => this._getPerceptionPlan(minion, dynamicChatHistory, userMessage.senderName, activeChannel.type));
    
    const perceptionResults = await Promise.all(perceptionPromises);
    const minionsWhoWillAct = perceptionResults.filter((r): r is {minion: MinionConfig, plan: PerceptionPlan, error: undefined} => !!r.plan && (r.plan.action === 'SPEAK' || r.plan.action === 'USE_TOOL'));
    
    for (const { minion, plan, error } of perceptionResults) {
        if (error) { onSystemMessage({ id: `sys-err-${minion.id}-${Date.now()}`, channelId, senderType: MessageSender.System, senderName: 'System', content: `Error for ${minion.name}: ${error}`, timestamp: Date.now(), isError: true }); continue; }
        if (plan) this.updateMinionState(minion.id, plan);
    }
    
    minionsWhoWillAct.forEach(({minion}) => onMinionProcessingUpdate(minion.name, true));
    minionsWhoWillAct.sort((a, b) => a.plan.predictedResponseTime - b.plan.predictedResponseTime);

    for (const { minion, plan } of minionsWhoWillAct) {
        let toolOutput: string | undefined = undefined;

        if (plan.action === 'USE_TOOL' && plan.toolCall) {
            toolOutput = await this._executeMcpTool(channelId, minion.name, plan.toolCall, onSystemMessage);
            dynamicChatHistory += `\n[TOOL CALL] Minion ${minion.name} is using tool: ${plan.toolCall.name}(${JSON.stringify(plan.toolCall.arguments)})`
            dynamicChatHistory += `\n[TOOL OUTPUT] ${toolOutput}`;
        }

        const tempMessageId = `ai-${minion.id}-${Date.now()}`;
        onMinionResponse({ id: tempMessageId, channelId, senderType: MessageSender.AI, senderName: minion.name, content: "", timestamp: Date.now(), isProcessing: true, senderRole: 'standard' });
        const responseGenPrompt = RESPONSE_GENERATION_PROMPT_TEMPLATE(minion.name, minion.system_prompt_persona, dynamicChatHistory, plan, toolOutput);
        const keyInfo = this._selectApiKey(minion);
        await this.runStreamingResponse(channelId, tempMessageId, minion, plan, responseGenPrompt, keyInfo, onMinionResponse, onMinionResponseChunk, onSystemMessage);
        
        const finalMessage = (this.messages[channelId] || []).find(m => m.id === tempMessageId);
        if (finalMessage) {
          dynamicChatHistory += `\n[MINION ${minion.name}]: ${finalMessage.content}`;
          if(channel) channel.messageCounter = (channel.messageCounter || 0) + 1;
        }
        onMinionProcessingUpdate(minion.name, false);
    }

    await this._checkForRegulatorAction(activeChannel, onRegulatorReport, onSystemMessage);
    this.saveState();
  }

  private async _getPerceptionPlan(minion: MinionConfig, chatHistory: string, lastSenderName: string, channelType: ChannelType) {
    const keyInfo = this._selectApiKey(minion);
    const { allowed, reason } = this._checkLimits(minion.id);
    if (!allowed) return { minion, plan: null, error: `Quota limit reached: ${reason}` };
    if (!keyInfo.key) return { minion, plan: null, error: "No API key available." };

    // Get available tools from Electron MCP service
    const mcpToolServers = await mcpElectronService.getAvailableTools(minion.id);
    const allAvailableTools = mcpToolServers.flatMap(server => 
      server.tools.map(tool => ({ ...tool, serverId: server.serverId, serverName: server.serverName }))
    );
    const availableTools = (minion.mcpTools || [])
        .map(assignedTool => allAvailableTools.find(t => t.name === assignedTool.toolName))
        .filter((t): t is McpTool => !!t);

    const prompt = PERCEPTION_AND_PLANNING_PROMPT_TEMPLATE( minion.name, minion.system_prompt_persona, JSON.stringify(minion.lastDiaryState || {}), JSON.stringify(minion.opinionScores, null, 2), chatHistory, lastSenderName, channelType, availableTools );
    const { data: plan, error, usage } = await callLiteLLMApiForJson<PerceptionPlan>(prompt, minion.model_id, minion.params.temperature, keyInfo.key);
    if (usage) this._updateUsage(minion.id, usage);
    return { minion, plan, error };
  }

  private async _checkForRegulatorAction(channel: Channel, onRegulatorReport: (reportMsg: ChatMessageData) => void, onSystemMessage: (msg: ChatMessageData) => void) {
    const regulators = this.minionConfigs.filter(m => m.role === 'regulator' && channel.members.includes(m.name));
    for (const regulator of regulators) {
      if ((channel.messageCounter || 0) >= (regulator.regulationInterval || 10)) {
        onSystemMessage({ id: `sys-reg-${Date.now()}`, channelId: channel.id, senderType: MessageSender.System, senderName: 'System', content: `Regulator ${regulator.name} is generating a status report...`, timestamp: Date.now() });
        const history = formatChatHistoryForLLM(this.messages[channel.id] || [], channel.id, 50);
        const keyInfo = this._selectApiKey(regulator);
        const {data: report, error, usage} = await callLiteLLMApiForJson<RegulatorReport>(history, regulator.model_id, regulator.params.temperature, keyInfo.key, REGULATOR_SYSTEM_PROMPT);
        if (usage) this._updateUsage(regulator.id, usage);
        if (report && !error) {
          const reportMsg: ChatMessageData = { id: `regulator-${regulator.id}-${Date.now()}`, channelId: channel.id, senderType: MessageSender.AI, senderName: regulator.name, senderRole: 'regulator', content: JSON.stringify(report), timestamp: Date.now() };
          this.messages[channel.id].push(reportMsg);
          onRegulatorReport(reportMsg);
          channel.messageCounter = 0; // Reset counter
        } else {
          onSystemMessage({ id: `sys-reg-err-${Date.now()}`, channelId: channel.id, senderType: MessageSender.System, senderName: 'System', content: `Regulator ${regulator.name} failed to generate report: ${error}`, timestamp: Date.now(), isError: true });
        }
      }
    }
  }

  async triggerNextAutoChatTurn(channelId: string, onMinionResponse: (m: ChatMessageData) => void, onMinionResponseChunk: (cid: string, mid: string, c: string) => void, onMinionProcessingUpdate: (n: string, p: boolean) => void, onSystemMessage: (m: ChatMessageData) => void, onRegulatorReport: (m: ChatMessageData) => void): Promise<void> {
    const channel = this.channels.find(c => c.id === channelId);
    if (!channel || !channel.isAutoModeActive) return;
    const minionsInChannel = this.minionConfigs.filter(m => channel.members.includes(m.name) && m.role === 'standard');
    if (minionsInChannel.length < 1) { onSystemMessage({ id: `sys-auto-err-${Date.now()}`, channelId, senderType: MessageSender.System, senderName: 'System', content: `Auto-mode paused. Requires at least 1 standard minion in the channel.`, timestamp: Date.now(), isError: true }); return; }
    
    const currentMessages = this.messages[channelId] || [];
    let dynamicChatHistory = formatChatHistoryForLLM(currentMessages, channelId);
    const lastMessage = currentMessages[currentMessages.length - 1];
    if (!lastMessage) { await this._checkForRegulatorAction(channel, onRegulatorReport, onSystemMessage); this.saveState(); return; };

    const perceptionPromises = minionsInChannel.map(minion => {
      if (minion.name === lastMessage.senderName && minionsInChannel.length > 1) return Promise.resolve({ minion, plan: null, error: "Cannot respond to self." });
      return this._getPerceptionPlan(minion, dynamicChatHistory, lastMessage.senderName, channel.type);
    });

    const results = await Promise.all(perceptionPromises);
    const actors = results.filter((r): r is { minion: MinionConfig; plan: PerceptionPlan; error: undefined } => !!r.plan && (r.plan.action === 'SPEAK' || r.plan.action === 'USE_TOOL')).sort((a, b) => a.plan.predictedResponseTime - b.plan.predictedResponseTime);
    
    const nextActor = actors[0];
    if (!nextActor) { await this._checkForRegulatorAction(channel, onRegulatorReport, onSystemMessage); this.saveState(); return; }

    const { minion, plan } = nextActor;
    onMinionProcessingUpdate(minion.name, true);

    let toolOutput: string | undefined = undefined;
    if (plan.action === 'USE_TOOL' && plan.toolCall) {
        toolOutput = await this._executeMcpTool(channelId, minion.name, plan.toolCall, onSystemMessage);
        dynamicChatHistory += `\n[TOOL CALL] Minion ${minion.name} is using tool: ${plan.toolCall.name}(${JSON.stringify(plan.toolCall.arguments)})`
        dynamicChatHistory += `\n[TOOL OUTPUT] ${toolOutput}`;
    }

    const tempMessageId = `ai-${minion.id}-${Date.now()}`;
    onMinionResponse({ id: tempMessageId, channelId, senderType: MessageSender.AI, senderName: minion.name, content: '', timestamp: Date.now(), isProcessing: true, senderRole: 'standard' });
    const responsePrompt = RESPONSE_GENERATION_PROMPT_TEMPLATE(minion.name, minion.system_prompt_persona, dynamicChatHistory, plan, toolOutput);
    await this.runStreamingResponse(channelId, tempMessageId, minion, plan, responsePrompt, this._selectApiKey(minion), onMinionResponse, onMinionResponseChunk, onSystemMessage);
    
    const finalMessage = (this.messages[channelId] || []).find(m => m.id === tempMessageId);
    if(finalMessage) channel.messageCounter = (channel.messageCounter || 0) + 1;
    onMinionProcessingUpdate(minion.name, false);

    await this._checkForRegulatorAction(channel, onRegulatorReport, onSystemMessage);
    this.saveState();
  }
  
  private async runStreamingResponse(channelId: string, messageId: string, minion: MinionConfig, plan: PerceptionPlan, prompt: string, keyInfo: SelectedKeyInfo, onMinionResponse: (m: ChatMessageData) => void, onMinionResponseChunk: (cid: string, mid: string, c: string) => void, onSystemMessage: (m: ChatMessageData) => void): Promise<void> {
      let accumulatedContent = "";
      const { allowed, reason } = this._checkLimits(minion.id);
      if (!allowed || !keyInfo.key) {
          const errorMsg = !keyInfo.key ? `No API key available for ${minion.name}.` : `Quota limit reached for ${minion.name}: ${reason}`;
          const finalMessage: ChatMessageData = { id: messageId, channelId, senderType: MessageSender.AI, senderName: minion.name, content: `Error: ${errorMsg}`, timestamp: Date.now(), isError: true, isProcessing: false, senderRole: 'standard' };
          onMinionResponse(finalMessage);
          this.messages[channelId] = (this.messages[channelId] || []).map(m => m.id === messageId ? finalMessage : m);
          return;
      }

      await new Promise<void>(resolve => {
          callLiteLLMAPIStream(prompt, minion.model_id, minion.params.temperature, keyInfo.key,
              (chunk, isFinal) => { // onStreamChunk
                  if (!isFinal) { accumulatedContent += chunk; onMinionResponseChunk(channelId, messageId, chunk); }
                  else {
                      const finalContent = accumulatedContent.trim();
                      const finalMessage: ChatMessageData = { id: messageId, channelId, senderType: MessageSender.AI, senderName: minion.name, content: finalContent, timestamp: Date.now(), internalDiary: plan, isProcessing: false, senderRole: 'standard' };
                      onMinionResponse(finalMessage); this.updateMinionState(minion.id, plan);
                      const msgIndex = (this.messages[channelId] || []).findIndex(m => m.id === messageId);
                      if (msgIndex > -1) this.messages[channelId][msgIndex] = finalMessage; else this.messages[channelId].push(finalMessage);
                      resolve();
                  }
              },
              (errorMessage) => { // onError
                  const errorMsg: ChatMessageData = { id: messageId, channelId, senderType: MessageSender.AI, senderName: minion.name, content: `Error: ${errorMessage}`, timestamp: Date.now(), isError: true, isProcessing: false, senderRole: 'standard' };
                  onMinionResponse(errorMsg); this.messages[channelId] = (this.messages[channelId] || []).map(m => m.id === messageId ? errorMsg : m); resolve();
              },
              (usage) => { if (usage) this._updateUsage(minion.id, usage); }
          );
      });
  }

  private updateMinionState(minionId: string, plan: PerceptionPlan) {
      const minionIndex = this.minionConfigs.findIndex(m => m.id === minionId);
      if (minionIndex > -1) { this.minionConfigs[minionIndex].opinionScores = plan.finalOpinions; this.minionConfigs[minionIndex].lastDiaryState = plan; }
  }

  async deleteMessage(channelId: string, messageId: string): Promise<void> { this.messages[channelId] = (this.messages[channelId] || []).filter(m => m.id !== messageId); this.saveState(); }
  async editMessage(channelId: string, messageId: string, newContent: string): Promise<void> { this.messages[channelId] = (this.messages[channelId] || []).map(m => m.id === messageId ? { ...m, content: newContent } : m); this.saveState(); }
  
  async getAnalyticsData(minionId: string, startDate: number, endDate: number) {
      const minion = this.minionConfigs.find(m => m.id === minionId);
      if (!minion) return null;
      
      // Calculate cumulative stats for the date range
      const historicalRequests = minion.usageStats.requests.filter(r => r.timestamp >= startDate && r.timestamp <= endDate);
      const cumulativeStats = {
          requests: historicalRequests.length,
          promptTokens: historicalRequests.reduce((sum, r) => sum + r.promptTokens, 0),
          completionTokens: historicalRequests.reduce((sum, r) => sum + r.completionTokens, 0),
          totalTokens: historicalRequests.reduce((sum, r) => sum + r.totalTokens, 0),
      };

      // Get current usage stats and quotas using the same logic as the roster panel
      const minionWithStats = this._getMinionWithStats(minion);

      return {
          currentUsage: minionWithStats.currentUsage,
          quotas: minionWithStats.quotas,
          cumulativeStats: cumulativeStats,
      };
  }
}

const legionApiService = new LegionApiService();
export default legionApiService;

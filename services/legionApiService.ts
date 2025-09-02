
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

// This function now asynchronously fetches data from the main process. // Reaching into the backend to get your shit. Asynchronously, because I'm not gonna wait around for it.
const getStoredData = async <T>(key: string, defaultValue: T): Promise<T> => { // Defining a generic function to grab whatever you need. I'm flexible like that.
  const value = await window.electronAPI.invoke('store:get', key, defaultValue); // Telling the main process to get off its ass and find your data. If it can't, it'll use the default you gave me.
  return value; // Here's your data. Don't say I never gave you anything.
}; // And we're done here. Next.

// This function asynchronously sends data to the main process. // Now I'm putting your shit away. Don't worry, I'll be gentle.
const setStoredData = async <T>(key: string, data: T): Promise<void> => { // Another generic function, this time for storing your precious data.
  await window.electronAPI.invoke('store:set', key, data); // Yelling at the main process again, this time to save your stuff. It better not lose it.
}; // All tucked in.

// --- One-Time Data Migration from localStorage to electron-store via IPC --- // Time to move your old shit from that insecure browser storage to a real home. A one-time thing, so pay attention.
const performMigration = async () => { // Let's get this fucking migration over with.
    // We ask the main process if migration is done. // First, I'll check if I've already done this. I'm not an idiot, I don't do the same work twice.
    const isMigrationComplete = await window.electronAPI.invoke('store:get', 'migration_complete_v1', false); // Pinging the main process to see if we've got the 'migration_complete_v1' flag. If not, it's go time.
    if (isMigrationComplete) { // If it's already done...
        return; // ...then I'm outta here. My job is finished.
    } // End of that check.

    console.log("Checking for data to migrate from localStorage..."); // Announcing my intentions. I'm about to rummage through your localStorage.

    const keysToMigrate = [ // Here's all the shit I'm looking for. A comprehensive list.
        MINION_CONFIGS_STORAGE_KEY, // Your minion setups.
        CHANNELS_STORAGE_KEY, // Your chat channels.
        CHAT_HISTORY_STORAGE_KEY, // All those dirty little messages.
        API_KEYS_STORAGE_KEY, // Your secret keys. I'll keep them safe.
        PROMPT_PRESETS_STORAGE_KEY, // The prompts you can't live without.
        MODEL_QUOTAS_STORAGE_KEY // And how much you're allowed to use them.
    ]; // That's the whole list.

    const migrationData = {}; // An empty box to put all your old toys in.
    let needsMigration = false; // Assuming you've got nothing to move, you minimalist fuck.
    for (const key of keysToMigrate) { // Now I'll go through each key, one by one.
        const lsData = localStorage.getItem(key); // Trying to pull the data out of the browser's grubby hands.
        if (lsData) { // Oh, look, I found something.
            try { // Better make sure this shit isn't corrupted.
                migrationData[key] = JSON.parse(lsData); // Parsing the JSON. Hope you stored it right.
                needsMigration = true; // Flipping the switch. We've got work to do.
            } catch (error) { // If it's fucked...
                console.error(`Could not parse localStorage data for ${key}`, error); // ...I'll just complain about it in the console and move on. Not my problem.
            } // End of the try-catch block.
        } // Done with that key.
    } // Loop's over. Let's see what we've got.

    if (needsMigration) { // If we actually found something to move.
        console.log("Sending data to main process for migration..."); // Letting you know I'm sending your shit over the wire.
        const result = await window.electronAPI.invoke('store:migrate', migrationData); // Handing the box of data to the main process. It's their problem now.
        if (result.success) { // If they didn't fuck it up...
            console.log("Migration successful. You can now clear localStorage if desired."); // ...I'll let you know it worked. You can clean up the old mess yourself.
            // You might want to clear localStorage after a successful migration // Seriously, I'm not your maid.
            // keysToMigrate.forEach(key => localStorage.removeItem(key)); // Here's how you'd do it, if you weren't so lazy.
        } else { // If they fucked it up...
            console.error("Migration failed in main process:", result.message); // ...I'll tell you exactly why. Don't look at me.
        } // End of the success/fail check.
    } else { // If there was nothing to move in the first place.
        console.log("No data found in localStorage. Marking migration as complete."); // Just letting you know your localStorage is pathetically empty.
        // Still need to mark it as complete to avoid checking every time. // But I still have to set the flag so I don't have to do this pointless check ever again.
        await window.electronAPI.invoke('store:set', 'migration_complete_v1', true); // Telling the main process to remember that we did this, even though we did nothing.
    } // And we're done with the migration logic.
}; // Fucking finally.

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
    onToolUpdate: (message: ChatMessageData) => void; // New callback
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

  async manuallyTriggerRegulator(channelId: string, onRegulatorReport: (reportMsg: ChatMessageData) => void, onSystemMessage: (msg: ChatMessageData) => void): Promise<void> {
    const channel = this.channels.find(c => c.id === channelId);
    if (!channel) return;

    // We're overriding the counter, so we call the check directly.
    await this._checkForRegulatorAction(channel, onRegulatorReport, onSystemMessage, true); // The 'true' forces it to run
    this.saveChannels(); // Save the reset counter
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
        this.saveChannels();
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

  // --- Granular State Savers ---
  private saveMinionConfigs() { setStoredData(MINION_CONFIGS_STORAGE_KEY, this.minionConfigs); }
  private saveChannels() { setStoredData(CHANNELS_STORAGE_KEY, this.channels); }
  private saveMessages() { setStoredData(CHAT_HISTORY_STORAGE_KEY, this.messages); }
  private saveApiKeys() { setStoredData(API_KEYS_STORAGE_KEY, this.apiKeys); }
  private savePromptPresets() { setStoredData(PROMPT_PRESETS_STORAGE_KEY, this.promptPresets); }
  private saveModelQuotas() { setStoredData(MODEL_QUOTAS_STORAGE_KEY, this.modelQuotas); }

  // --- API Key, Preset & Model Management ---
  async getApiKeys(): Promise<ApiKey[]> { return Promise.resolve([...this.apiKeys]); }
  async addApiKey(name: string, key: string): Promise<void> { this.apiKeys.push({ id: `key-${Date.now()}`, name, key }); this.saveApiKeys(); }
  async deleteApiKey(id: string): Promise<void> {
    this.minionConfigs.forEach(minion => { if (minion.apiKeyId === id) minion.apiKeyId = undefined; });
    this.apiKeys = this.apiKeys.filter(k => k.id !== id); 
    this.saveApiKeys();
    this.saveMinionConfigs();
  }
  async getPromptPresets(): Promise<PromptPreset[]> { return Promise.resolve([...this.promptPresets]); }
  async addPromptPreset(name: string, content: string): Promise<void> { this.promptPresets.push({ id: `preset-${Date.now()}`, name, content }); this.savePromptPresets(); }
  async deletePromptPreset(id: string): Promise<void> { this.promptPresets = this.promptPresets.filter(p => p.id !== id); this.savePromptPresets(); }
  
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
        this.saveModelQuotas();
      }
    } catch (error) {
      console.error("Error refreshing models from LiteLLM:", error);
      throw error;
    }
  }



  private _selectApiKey(minion?: MinionConfig): SelectedKeyInfo {
    if (minion?.model_id && this.modelQuotas[minion.model_id]) { return { key: LITELLM_API_KEY, name: 'LiteLLM Proxy', method: 'Proxy' }; }
    // Fallback for custom models not yet in the refreshed list
    if (minion?.model_id) { return { key: LITELLM_API_KEY, name: 'LiteLLM Proxy (Custom)', method: 'Proxy'};
    }
    
    if (minion?.apiKeyId) { const key = this.apiKeys.find(k => k.id === minion.apiKeyId); if (key) return { key: key.key, name: key.name, method: 'Assigned' }; }
    if (this.apiKeys.length > 0) { const keyInfo = this.apiKeys[this.apiKeyRoundRobinIndex]; this.apiKeyRoundRobinIndex = (this.apiKeyRoundRobinIndex + 1) % this.apiKeys.length; return { key: keyInfo.key, name: keyInfo.name, method: 'Load Balanced' }; }
    return { key: '', name: 'N/A', method: 'None' };
  }
  
  // --- Minion Management ---
  private _getMinionWithStats(minion: MinionConfig): MinionConfig {
    // This function now ONLY attaches quotas, without calculating usage stats.
    const quotas = this.modelQuotas[minion.model_id];
    if (!quotas) return minion;
    // The actual calculation is now done on-demand in getAnalyticsData.
    return { ...minion, quotas };
  }

  async getMinions(): Promise<MinionConfig[]> { 
    // Returns minions with their quota info, but not real-time usage stats.
    // This makes loading the main roster much faster.
    return Promise.resolve(this.minionConfigs.map(m => this._getMinionWithStats(m))); 
  }

  async addMinion(config: MinionConfig): Promise<MinionConfig> {
    const newMinionName = config.name;
    this.minionConfigs.forEach(m => { m.opinionScores[newMinionName] = 50; });
    const initialScoresForNewMinion: Record<string, number> = { [LEGION_COMMANDER_NAME]: 50 };
    this.minionConfigs.forEach(m => { initialScoresForNewMinion[m.name] = 50; });
    const newMinion: MinionConfig = { ...config, id: config.id || `minion-${Date.now()}`, opinionScores: initialScoresForNewMinion, status: 'Idle', lastDiaryState: null, usageStats: { requests: [] }};
    this.minionConfigs.push(newMinion);
    // Only add new minions to channels they should automatically join
    // Skip group chats, buddy chats, and let users manually add minions where they want them
    this.channels.forEach(c => { 
      if (c.type === 'user_minion_group' && c.name === '#general') {
        // Only auto-add to the main #general channel
        c.members.push(newMinion.name);
      }
      // Don't auto-add to other channels - let users choose
    });
    this.saveMinionConfigs();
    this.saveChannels();
    return newMinion;
  }
  async updateMinion(updatedConfig: MinionConfig): Promise<MinionConfig> {
    const index = this.minionConfigs.findIndex(m => m.id === updatedConfig.id);
    if (index === -1) throw new Error("Minion not found.");
    updatedConfig.usageStats = this.minionConfigs[index].usageStats;
    this.minionConfigs[index] = updatedConfig; 
    this.saveMinionConfigs();
    return updatedConfig;
  }
  async deleteMinion(id: string): Promise<void> {
    const minionToDelete = this.minionConfigs.find(m => m.id === id);
    if (!minionToDelete) return;
    this.minionConfigs = this.minionConfigs.filter(m => m.id !== id);
    this.minionConfigs.forEach(m => { delete m.opinionScores[minionToDelete.name]; });
    this.channels.forEach(c => { c.members = c.members.filter(name => name !== minionToDelete.name); });
    this.saveMinionConfigs();
    this.saveChannels();
  }

  // --- Channel Management ---
  async getChannels(): Promise<Channel[]> { return Promise.resolve([...this.channels]); }
  async addOrUpdateChannel(channelData: ChannelPayload): Promise<Channel> {
      if (channelData.id) {
          const index = this.channels.findIndex(c => c.id === channelData.id);
          if (index > -1) {
              this.channels[index] = { ...this.channels[index], ...channelData };
              this.saveChannels();
              return this.channels[index];
          }
      }
      const newChannel: Channel = { id: `channel-${Date.now()}`, name: channelData.name, type: channelData.type, description: channelData.description || '', isPrivate: false, members: channelData.members, isAutoModeActive: false, autoModeDelayType: 'fixed', autoModeFixedDelay: 5, autoModeRandomDelay: { min: 3, max: 10 }, messageCounter: 0 };
      this.channels.push(newChannel);
      if (!this.messages[newChannel.id]) this.messages[newChannel.id] = [];
      this.saveChannels();
      this.saveMessages();
      return newChannel;
  }

  async deleteChannel(channelId: string): Promise<void> {
    this.channels = this.channels.filter(c => c.id !== channelId);
    delete this.messages[channelId];
    this.saveChannels();
    this.saveMessages();
  }

  async bulkRemoveMinionFromChannels(minionName: string, excludeChannels: string[] = []): Promise<{ removedFromCount: number, affectedChannels: string[] }> {
    let removedFromCount = 0;
    const affectedChannels: string[] = [];
    
    this.channels.forEach(channel => {
      const hadMinion = channel.members.includes(minionName);
      const shouldKeep = excludeChannels.includes(channel.name);
      
      if (hadMinion && !shouldKeep) {
        channel.members = channel.members.filter(member => member !== minionName);
        removedFromCount++;
        affectedChannels.push(channel.name);
      }
    });
    
    if (removedFromCount > 0) {
      this.saveChannels();
    }
    
    return { removedFromCount, affectedChannels };
  }

  // --- Message Management ---
  async getMessages(channelId: string, limit: number = 50, before?: string): Promise<{ messages: ChatMessageData[], hasMore: boolean }> { 
    const allMessages = this.messages[channelId] || [];
    
    if (before) {
      // Find the index of the 'before' message
      const beforeIndex = allMessages.findIndex(m => m.id === before);
      if (beforeIndex > 0) {
        const startIndex = Math.max(0, beforeIndex - limit);
        const messages = allMessages.slice(startIndex, beforeIndex);
        return Promise.resolve({ 
          messages: [...messages], 
          hasMore: startIndex > 0 
        });
      }
    }
    
    // Return the most recent messages
    const startIndex = Math.max(0, allMessages.length - limit);
    const messages = allMessages.slice(startIndex);
    return Promise.resolve({ 
      messages: [...messages], 
      hasMore: startIndex > 0 
    });
  }

  async getAllMessages(channelId: string): Promise<ChatMessageData[]> { 
    // Backward compatibility method for places that need all messages
    return Promise.resolve([...(this.messages[channelId] || [])]); 
  }

  // Cleanup old messages to prevent memory leaks
  cleanupOldMessages(channelId: string, maxMessages: number = 500): void {
    const messages = this.messages[channelId];
    if (messages && messages.length > maxMessages) {
      // Keep only the most recent messages
      this.messages[channelId] = messages.slice(-maxMessages);
      this.saveMessages();
    }
  }
  private _updateUsage(minionId: string, usage: {prompt_tokens: number, completion_tokens: number, total_tokens: number}) {
      const minion = this.minionConfigs.find(m => m.id === minionId);
      if (minion) {
          minion.usageStats.requests.push({ timestamp: Date.now(), promptTokens: usage.prompt_tokens, completionTokens: usage.completion_tokens, totalTokens: usage.total_tokens });
          const oneDayAgo = Date.now() - 864e5;
          minion.usageStats.requests = minion.usageStats.requests.filter(r => r.timestamp > oneDayAgo);
          this.saveMinionConfigs();
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
  
  private async _executeMcpTool(channelId: string, minionName: string, toolCall: ToolCall, onSystemMessage: (msg: ChatMessageData) => void, onToolUpdate: (msg: ChatMessageData) => void): Promise<string> {
    const toolCallMessage: ChatMessageData = {
        id: `tool-call-${Date.now()}`,
        channelId,
        senderType: MessageSender.Tool,
        senderName: minionName,
        content: `Using tool: ${toolCall.name}`,
        timestamp: Date.now(),
        isToolCall: true,
        toolCall: toolCall,
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
            ...toolCallMessage,
            isToolOutput: true,
            toolOutput: output,
            content: `Tool output for ${toolCall.name}`,
        };
        
        const msgIndex = this.messages[channelId].findIndex(m => m.id === toolCallMessage.id);
        if (msgIndex > -1) {
            this.messages[channelId][msgIndex] = toolOutputMessage;
        }
        
        onToolUpdate(toolOutputMessage);
        
        return output;

    } catch (e: any) {
        const error = e.message || 'Unknown error during tool execution.';
        const toolErrorMessage: ChatMessageData = {
            ...toolCallMessage,
            isToolOutput: true,
            toolOutput: `ERROR: ${error}`,
            content: `Tool error for ${toolCall.name}`,
            isError: true,
        };

        const msgIndex = this.messages[channelId].findIndex(m => m.id === toolCallMessage.id);
        if (msgIndex > -1) {
            this.messages[channelId][msgIndex] = toolErrorMessage;
        }

        onToolUpdate(toolErrorMessage);
        return `ERROR: ${error}`;
    }
  }

  async processMessageTurn(params: HandleUserMessageParams): Promise<void> {
    const { channelId, triggeringMessage: userMessage, ...callbacks } = params;
    
    if (!this.messages[channelId]) this.messages[channelId] = [];
    this.messages[channelId].push(userMessage);
    
    const channel = this.channels.find(c => c.id === channelId);
    if (!channel) return;
    
    channel.messageCounter = (channel.messageCounter || 0) + 1;

    const minionsInChannel = this.minionConfigs.filter(minion => 
      channel.members.includes(minion.name) && minion.role === 'standard'
    );

    if (minionsInChannel.length === 0 && userMessage.senderType === MessageSender.User) {
       await this._checkForRegulatorAction(channel, callbacks.onRegulatorReport, callbacks.onSystemMessage);
       this.saveChannels(); // Save potential message counter changes
       return;
    }
    
    
    // Generate base history without per-minion filtering for initial setup
    const initialChatHistory = formatChatHistoryForLLM(this.messages[channelId], channelId);
    
    await this._runAgentLoop({
      channel,
      minionsInChannel,
      initialChatHistory,
      lastSenderName: userMessage.senderName,
      ...callbacks
    });

    await this._checkForRegulatorAction(channel, callbacks.onRegulatorReport, callbacks.onSystemMessage);
    this.saveChannels(); // Save potential message counter changes
    this.saveMessages(); // Save new messages
  }

  private async _getPerceptionPlan(minion: MinionConfig, channelId: string, lastSenderName: string, channelType: ChannelType, dynamicHistoryForMinion?: string) {
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

    // Use minion-specific dynamic history if provided, otherwise generate filtered history
    const chatHistory = dynamicHistoryForMinion || formatChatHistoryForLLM(this.messages[channelId] || [], channelId, 25, minion.name);

    const prompt = PERCEPTION_AND_PLANNING_PROMPT_TEMPLATE( minion.name, minion.system_prompt_persona, JSON.stringify(minion.lastDiaryState || {}), JSON.stringify(minion.opinionScores, null, 2), chatHistory, lastSenderName, channelType, availableTools );
    const { data: plan, error, usage } = await callLiteLLMApiForJson<PerceptionPlan>(prompt, minion.model_id, minion.params.temperature, keyInfo.key);
    if (usage) this._updateUsage(minion.id, usage);
    return { minion, plan, error };
  }

  private async _checkForRegulatorAction(channel: Channel, onRegulatorReport: (reportMsg: ChatMessageData) => void, onSystemMessage: (msg: ChatMessageData) => void, force: boolean = false) {
    const regulators = this.minionConfigs.filter(m => m.role === 'regulator' && channel.members.includes(m.name));
    for (const regulator of regulators) {
      if (force || (channel.messageCounter || 0) >= (regulator.regulationInterval || 10)) {
        onSystemMessage({ id: `sys-reg-${Date.now()}`, channelId: channel.id, senderType: MessageSender.System, senderName: 'System', content: `Regulator ${regulator.name} is generating a status report...`, timestamp: Date.now() });
        const history = formatChatHistoryForLLM(this.messages[channel.id] || [], channel.id, 50, regulator.name);
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

  async triggerNextAutoChatTurn(channelId: string, ...callbacks: [ (m: ChatMessageData) => void, (cid: string, mid: string, c: string) => void, (n: string, p: boolean) => void, (m: ChatMessageData) => void, (m: ChatMessageData) => void, (m: ChatMessageData) => void ]): Promise<void> {
    const [onMinionResponse, onMinionResponseChunk, onMinionProcessingUpdate, onSystemMessage, onRegulatorReport, onToolUpdate] = callbacks;
    
    const channel = this.channels.find(c => c.id === channelId);
    if (!channel || !channel.isAutoModeActive) return;

    const minionsInChannel = this.minionConfigs.filter(m => channel.members.includes(m.name) && m.role === 'standard');
    if (minionsInChannel.length < 1) {
      onSystemMessage({ id: `sys-auto-err-${Date.now()}`, channelId, senderType: MessageSender.System, senderName: 'System', content: `Auto-mode paused. Requires at least 1 standard minion in the channel.`, timestamp: Date.now(), isError: true });
      return;
    }
    
    const currentMessages = this.messages[channelId] || [];
    const lastMessage = currentMessages[currentMessages.length - 1];
    if (!lastMessage) {
      await this._checkForRegulatorAction(channel, onRegulatorReport, onSystemMessage);
      this.saveChannels(); // Save potential message counter changes
      return;
    }

    const initialChatHistory = formatChatHistoryForLLM(currentMessages, channelId);
    
    await this._runAgentLoop({
      channel,
      minionsInChannel,
      initialChatHistory,
      lastSenderName: lastMessage.senderName,
      isAutoChat: true,
      onMinionResponse,
      onMinionResponseChunk,
      onMinionProcessingUpdate,
      onSystemMessage,
      onRegulatorReport,
      onToolUpdate
    });

    await this._checkForRegulatorAction(channel, onRegulatorReport, onSystemMessage);
    this.saveChannels(); // Save potential message counter changes
    this.saveMessages(); // Save new messages
  }

  private async _runAgentLoop(params: {
    channel: Channel;
    minionsInChannel: MinionConfig[];
    initialChatHistory: string;
    lastSenderName: string;
    isAutoChat?: boolean;
    onMinionResponse: (message: ChatMessageData) => void;
    onMinionResponseChunk: (channelId: string, messageId: string, chunk: string) => void;
    onMinionProcessingUpdate: (minionName: string, isProcessing: boolean) => void;
    onSystemMessage: (systemMessage: ChatMessageData) => void;
    onRegulatorReport: (reportMsg: ChatMessageData) => void;
    onToolUpdate: (message: ChatMessageData) => void;
  }): Promise<void> {
    const { channel, minionsInChannel, initialChatHistory, lastSenderName, isAutoChat = false, onMinionResponse, onMinionResponseChunk, onMinionProcessingUpdate, onSystemMessage, onRegulatorReport, onToolUpdate } = params;
    const channelId = channel.id;
    
    // Track per-minion dynamic histories instead of shared history
    const dynamicHistoryPerMinion = new Map<string, string>();
    minionsInChannel.forEach(minion => {
      dynamicHistoryPerMinion.set(minion.name, initialChatHistory);
    });
    
    const MAX_TURNS = 10; // Safety break for tool use loops

    for (let turn = 0; turn < MAX_TURNS; turn++) {
      const perceptionPromises = minionsInChannel.map(minion => {
        if (isAutoChat && minion.name === lastSenderName && minionsInChannel.length > 1) {
          return Promise.resolve({ minion, plan: null, error: "Cannot respond to self in auto-chat." });
        }
        const minionSpecificHistory = dynamicHistoryPerMinion.get(minion.name);
        return this._getPerceptionPlan(minion, channelId, lastSenderName, channel.type, minionSpecificHistory);
      });

      const perceptionResults = await Promise.all(perceptionPromises);
      
      for (const { minion, plan, error } of perceptionResults) {
        if (error) { onSystemMessage({ id: `sys-err-${minion.id}-${Date.now()}`, channelId, senderType: MessageSender.System, senderName: 'System', content: `Error for ${minion.name}: ${error}`, timestamp: Date.now(), isError: true }); }
        if (plan) { this.updateMinionState(minion.id, plan); }
      }

      const actors = perceptionResults
        .filter((r): r is { minion: MinionConfig; plan: PerceptionPlan; error: undefined } => !!r.plan && (r.plan.action === 'SPEAK' || r.plan.action === 'USE_TOOL'))
        .sort((a, b) => a.plan.predictedResponseTime - b.plan.predictedResponseTime);

      if (actors.length === 0) {
        onSystemMessage({ id: `sys-no-action-${Date.now()}`, channelId, senderType: MessageSender.System, senderName: 'System', content: 'No minions chose to act.', timestamp: Date.now() });
        return; // End of the line, no one is acting.
      }

      // In user-triggered turns, all actors can respond. In auto-chat, only the first one does.
      const actorsToProcess = isAutoChat ? actors.slice(0, 1) : actors;
      let aToolWasUsedThisTurn = false;
      
      for (const { minion, plan } of actorsToProcess) {
        onMinionProcessingUpdate(minion.name, true);

        if (plan.action === 'USE_TOOL' && plan.toolCall) {
          aToolWasUsedThisTurn = true;

          // If the minion wants to speak before using the tool, let it.
          if (plan.speakWhileTooling) {
            const preToolMessage: ChatMessageData = {
              id: `ai-${minion.id}-${Date.now()}-pretool`,
              channelId,
              senderType: MessageSender.AI,
              senderName: minion.name,
              content: plan.speakWhileTooling,
              timestamp: Date.now(),
              isProcessing: false,
              senderRole: 'standard'
            };
            onMinionResponse(preToolMessage);
            this.messages[channelId].push(preToolMessage);
            
            // Update ALL minions' histories with the speech (public message)
            dynamicHistoryPerMinion.forEach((history, minionName) => {
              dynamicHistoryPerMinion.set(minionName, history + `\n[MINION ${minion.name}]: ${plan.speakWhileTooling}`);
            });
          }

          const toolOutput = await this._executeMcpTool(channelId, minion.name, plan.toolCall, onSystemMessage, onToolUpdate);
          
          // PRIVACY FIX: Only update THIS minion's history with tool info
          const currentHistory = dynamicHistoryPerMinion.get(minion.name) || '';
          const updatedHistory = currentHistory + 
            `\n[TOOL CALL] Minion ${minion.name} used tool: ${plan.toolCall.name}(${JSON.stringify(plan.toolCall.arguments)})` +
            `\n[TOOL OUTPUT] ${toolOutput}` +
            `\n[SYSTEM REMINDER]: You have just received the output from your tool call. Analyze this output and the conversation history to decide your next action. If the task is not yet complete, prioritize using another tool. Only choose to 'SPEAK' when you have all the information needed to provide a final answer.`;
          dynamicHistoryPerMinion.set(minion.name, updatedHistory);
          
          onMinionProcessingUpdate(minion.name, false); // Tool use is quick
        }
        
        if (plan.action === 'SPEAK') {
          const tempMessageId = `ai-${minion.id}-${Date.now()}`;
          onMinionResponse({ id: tempMessageId, channelId, senderType: MessageSender.AI, senderName: minion.name, content: "", timestamp: Date.now(), isProcessing: true, senderRole: 'standard' });
          
          const isFirstMessage = !minion.chatColor;
          const otherMinionColors = this.minionConfigs
            .filter(m => m.id !== minion.id && m.chatColor && m.fontColor)
            .map(m => ({ name: m.name, chatColor: m.chatColor!, fontColor: m.fontColor! }));

          const minionSpecificHistory = dynamicHistoryPerMinion.get(minion.name) || '';
          const responseGenPrompt = RESPONSE_GENERATION_PROMPT_TEMPLATE(
            minion.name,
            minion.system_prompt_persona,
            minionSpecificHistory,
            plan,
            undefined, // toolOutput
            isFirstMessage,
            otherMinionColors,
            '#FAFAFA' // Correct background color
          );
          const keyInfo = this._selectApiKey(minion);
          await this.runStreamingResponse(channelId, tempMessageId, minion, plan, responseGenPrompt, keyInfo, onMinionResponse, onMinionResponseChunk, onSystemMessage);
          
          const finalMessage = (this.messages[channelId] || []).find(m => m.id === tempMessageId);
          if (finalMessage) {
            // Update ALL minions' histories with this public speech
            dynamicHistoryPerMinion.forEach((history, minionName) => {
              dynamicHistoryPerMinion.set(minionName, history + `\n[MINION ${minion.name}]: ${finalMessage.content}`);
            });
            if(channel) channel.messageCounter = (channel.messageCounter || 0) + 1;
          }
          onMinionProcessingUpdate(minion.name, false);
          // If this is an auto-chat turn, we break after the first speaker.
          if (isAutoChat) return; 
        }
      }

      // After processing all actors for this iteration, decide whether to continue the loop.
      if (aToolWasUsedThisTurn) {
        // If a tool was used, we must loop again to get the next action plan.
        continue;
      } else {
        // If no tools were used, it means everyone who was going to act has spoken. The turn is over.
        return;
      }
    }
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
                      let finalContent = accumulatedContent.trim();
                      const colorTagRegex = /<colors\s+chatColor=\"([^\"]+)\"\s+fontColor=\"([^\"]+)\"\s*\/>/;
                      const match = finalContent.match(colorTagRegex);

                      if (match) {
                          const chatColor = match[1];
                          const fontColor = match[2];
                          
                          const minionToUpdate = this.minionConfigs.find(m => m.id === minion.id);
                          if (minionToUpdate) {
                              const updatedMinion = { ...minionToUpdate, chatColor, fontColor };
                              this.updateMinion(updatedMinion);
                          }
                          finalContent = finalContent.replace(colorTagRegex, '').trim();
                      }

                      const finalMessage: ChatMessageData = { id: messageId, channelId, senderType: MessageSender.AI, senderName: minion.name, content: finalContent, timestamp: Date.now(), internalDiary: plan, isProcessing: false, senderRole: 'standard', _skipContentUpdate: true };
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

  async deleteMessage(channelId: string, messageId: string): Promise<void> { this.messages[channelId] = (this.messages[channelId] || []).filter(m => m.id !== messageId); this.saveMessages(); }
  async editMessage(channelId: string, messageId: string, newContent: string): Promise<void> { this.messages[channelId] = (this.messages[channelId] || []).map(m => m.id === messageId ? { ...m, content: newContent } : m); this.saveMessages(); }
  
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

      // ON-DEMAND STATS CALCULATION
      const quotas = this.modelQuotas[minion.model_id];
      let currentUsage = { rpm: 0, tpm: 0, rpd: 0 };

      if (quotas) {
        const now = Date.now(), oneMinAgo = now - 6e4, oneDayAgo = now - 864e5;
        let requests = minion.usageStats.requests;
        if (quotas.sharedPool) {
          if (!this.sharedPoolUsage[quotas.sharedPool]) this.sharedPoolUsage[quotas.sharedPool] = { requests: [] };
          requests = this.minionConfigs.filter(m => this.modelQuotas[m.model_id]?.sharedPool === quotas.sharedPool).flatMap(m => m.usageStats.requests);
        }
        const requestsLastMinute = requests.filter(r => r.timestamp > oneMinAgo);
        const requestsLastDay = requests.filter(r => r.timestamp > oneDayAgo);
        currentUsage.rpm = requestsLastMinute.length;
        currentUsage.tpm = requestsLastMinute.reduce((s, r) => s + r.totalTokens, 0);
        currentUsage.rpd = requestsLastDay.length;
      }

      return {
          currentUsage: currentUsage,
          quotas: quotas,
          cumulativeStats: cumulativeStats,
      };
  }
}

const legionApiService = new LegionApiService();
export default legionApiService;

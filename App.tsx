import React, { useState, useEffect, useRef, useCallback } from 'react';
import { MinionConfig, ChatMessageData, MessageSender, Channel, ChannelPayload, ApiKey, PromptPreset, ModelOption } from './types';
import ChatMessage from './components/ChatMessage';
import ChatInput from './components/ChatInput';
import MinionsPanel from './components/ConfigPanel';
import ChannelList from './components/ChannelList';
import AutoChatControls from './components/AutoChatControls';
import AnalyticsDashboard from './components/AnalyticsDashboard';
import McpServerManager from './components/McpServerManager';
import { CogIcon, ChartBarIcon, ChevronDoubleDownIcon, ChevronUpIcon } from './components/Icons';
import { APP_TITLE, LEGION_COMMANDER_NAME, ACTIVE_CHANNEL_STORAGE_KEY } from './constants';
import legionApiService from './services/legionApiService';


const App: React.FC = () => {
  const [minionConfigs, setMinionConfigs] = useState<MinionConfig[]>([]);
  const [messages, setMessages] = useState<Record<string, ChatMessageData[]>>({});
  const [channels, setChannels] = useState<Channel[]>([]);
  const [currentChannelId, setCurrentChannelId] = useState<string | null>(null);
  const [apiKeys, setApiKeys] = useState<ApiKey[]>([]);
  const [promptPresets, setPromptPresets] = useState<PromptPreset[]>([]);
  const [modelOptions, setModelOptions] = useState<ModelOption[]>([]);
  
  const [isServiceInitialized, setIsServiceInitialized] = useState(false);
  const [isMinionsPanelOpen, setIsMinionsPanelOpen] = useState(false);
  const [isAnalyticsOpen, setIsAnalyticsOpen] = useState(false);
  const [isMcpManagerOpen, setIsMcpManagerOpen] = useState(false);
  const [isProcessingMessage, setIsProcessingMessage] = useState(false);
  const [isAutoScrollEnabled, setIsAutoScrollEnabled] = useState(true);
  const [activeMinionProcessors, setActiveMinionProcessors] = useState<Record<string, boolean>>({});

  const chatHistoryRef = useRef<HTMLDivElement>(null);
  const autoChatTimeoutRef = useRef<number | null>(null);
  const service = useRef(legionApiService).current;
// Inside App.tsx, around line 35
  const [isChannelSwitching, setIsChannelSwitching] = useState(false);

  // --- Data Loading and Persistence ---
  const loadInitialData = useCallback(async () => {
    if (!isServiceInitialized) return;

    const fetchedModels = await service.getModelOptions();
    setModelOptions(fetchedModels);

    const fetchedMinions = await service.getMinions();
    setMinionConfigs(fetchedMinions);
    
    const fetchedKeys = await service.getApiKeys();
    setApiKeys(fetchedKeys);

    const fetchedPresets = await service.getPromptPresets();
    setPromptPresets(fetchedPresets);

    const fetchedChannels = await service.getChannels();
    setChannels(fetchedChannels);

    // Use electron-store for active channel persistence
    const activeChannelId = await window.electronAPI.invoke('store:get', ACTIVE_CHANNEL_STORAGE_KEY, null);

    if (activeChannelId && fetchedChannels.some(c => c.id === activeChannelId)) {
      await selectChannel(activeChannelId);
    } else if (fetchedChannels.length > 0) {
      await selectChannel(fetchedChannels[0].id);
    } else {
      // This case handles a completely fresh start
      const generalChannel = await service.addOrUpdateChannel({ name: '#general', type: 'user_minion_group', members: [LEGION_COMMANDER_NAME] });
      const updatedChannels = await service.getChannels();
      setChannels(updatedChannels);
      if (updatedChannels.length > 0) {
        await selectChannel(updatedChannels[0].id);
      }
    }
  }, [service, isServiceInitialized]);
  
  // Effect for initializing the service
  useEffect(() => {
    const initializeService = async () => {
      await service.init();
      setIsServiceInitialized(true);
    };
    initializeService();
  }, [service]);

  // Effect for loading data after service is initialized
  useEffect(() => {
    if (isServiceInitialized) {
      loadInitialData();
      
      const statsInterval = setInterval(async () => {
        setMinionConfigs(await service.getMinions());
      }, 5000);
      
      return () => {
        if (autoChatTimeoutRef.current) clearTimeout(autoChatTimeoutRef.current);
        clearInterval(statsInterval);
      };
    }
  }, [isServiceInitialized, loadInitialData]);

  useEffect(() => {
    if (isAutoScrollEnabled && chatHistoryRef.current) {
      chatHistoryRef.current.scrollTop = chatHistoryRef.current.scrollHeight;
    }
  }, [messages, activeMinionProcessors, isAutoScrollEnabled]);

  useEffect(() => {
    if (currentChannelId) {
      // Use electron-store for active channel persistence
      window.electronAPI.invoke('store:set', ACTIVE_CHANNEL_STORAGE_KEY, currentChannelId);
    }
  }, [currentChannelId]);

  // --- API Key, Preset, & Model Management ---
  const handleAddApiKey = async (name: string, key: string) => { await service.addApiKey(name, key); setApiKeys(await service.getApiKeys()); };
  const handleDeleteApiKey = async (id: string) => { await service.deleteApiKey(id); setApiKeys(await service.getApiKeys()); };
  const handleAddPreset = async (name: string, content: string) => { await service.addPromptPreset(name, content); setPromptPresets(await service.getPromptPresets()); };
  const handleDeletePreset = async (id: string) => { await service.deletePromptPreset(id); setPromptPresets(await service.getPromptPresets()); };
  const handleRefreshModels = async () => { await service.refreshModelsFromLiteLLM(); setModelOptions(await service.getModelOptions()); };

  // --- Minion Management ---
  const addMinionConfig = async (config: MinionConfig) => { await service.addMinion(config); setMinionConfigs(await service.getMinions()); setChannels(await service.getChannels()); };
  const updateMinionConfig = async (updatedConfig: MinionConfig) => { await service.updateMinion(updatedConfig); setMinionConfigs(await service.getMinions()); setChannels(await service.getChannels()); };
  const deleteMinionConfig = async (id: string) => { await service.deleteMinion(id); setMinionConfigs(await service.getMinions()); setChannels(await service.getChannels()); };

  // --- Message Management ---
  const handleMessageUpdate = useCallback((channelId: string, messageId: string, updates: Partial<ChatMessageData>) => { setMessages(prev => ({ ...prev, [channelId]: (prev[channelId] || []).map(m => m.id === messageId ? { ...m, ...updates } : m) })); }, []);
  const handleMessageAdd = useCallback((channelId: string, message: ChatMessageData) => { setMessages(prev => ({ ...prev, [channelId]: [...(prev[channelId] || []), message] })); }, []);
  const handleMessageChunk = useCallback((channelId: string, messageId: string, chunk: string) => { setMessages(prev => ({ ...prev, [channelId]: (prev[channelId] || []).map(m => m.id === messageId ? { ...m, content: m.content + chunk } : m)})); }, []);
  const handleMessageUpsert = useCallback((message: ChatMessageData) => {
     setMessages(prevMessages => {
        const channelMessages = prevMessages[message.channelId] || [];
        const existingMsgIndex = channelMessages.findIndex(m => m.id === message.id);
        if (existingMsgIndex > -1) {
            const newChannelMessages = [...channelMessages];
            newChannelMessages[existingMsgIndex] = { ...newChannelMessages[existingMsgIndex], ...message };
            return { ...prevMessages, [message.channelId]: newChannelMessages };
        } else {
            return { ...prevMessages, [message.channelId]: [...channelMessages, message] };
        }
     });
  }, []);
  const deleteMessageFromChannel = async (channelId: string, messageId: string) => { await service.deleteMessage(channelId, messageId); setMessages(prev => ({...prev, [channelId]: (prev[channelId] || []).filter(m => m.id !== messageId) })); };
  const editMessageContent = async (channelId: string, messageId: string, newContent: string) => { await service.editMessage(channelId, messageId, newContent); handleMessageUpdate(channelId, messageId, { content: newContent }); };
  
  // --- Channel Management ---
// Replace the existing selectChannel function in App.tsx
  const selectChannel = async (channelId: string) => {
      // Don't do a goddamn thing if we're not actually changing channels.
      if (channelId === currentChannelId) return;

      // STEP 1: Begin the fade-out.
      setIsChannelSwitching(true);

      // Give the CSS 200ms to do its sexy little fade-out.
      setTimeout(async () => {
          if (autoChatTimeoutRef.current) clearTimeout(autoChatTimeoutRef.current);
          
          // This is your original logic to load messages for the new channel.
          if (!messages[channelId]) {
              const channelMessages = await service.getMessages(channelId);
              setMessages(prev => ({...prev, [channelId]: channelMessages}));
          }
          
          // STEP 2: Now that it's invisible, swap the channel content.
          setCurrentChannelId(channelId);
          
          // STEP 3: Flip the state back to trigger the fade-in.
          setIsChannelSwitching(false);
      }, 500); // This duration MUST match your CSS transition duration.
  };
  const handleAddOrUpdateChannel = async (channelData: ChannelPayload) => { await service.addOrUpdateChannel(channelData); setChannels(await service.getChannels()); };

  // --- Core Message Sending Logic ---
  const processAndDispatchMessage = async (channelId: string, message: ChatMessageData) => {
    setIsProcessingMessage(true);
    setActiveMinionProcessors({});
    
    await service.processMessageTurn({
      channelId: channelId,
      triggeringMessage: message,
      onMinionResponse: handleMessageUpsert,
      onMinionResponseChunk: handleMessageChunk,
      onMinionProcessingUpdate: (minionName, isProcessing) => { setActiveMinionProcessors(prev => ({ ...prev, [minionName]: isProcessing })); },
      onSystemMessage: (systemMessage) => handleMessageAdd(systemMessage.channelId, systemMessage),
      onRegulatorReport: (reportMsg) => handleMessageAdd(reportMsg.channelId, reportMsg),
    });

    setIsProcessingMessage(false);
  }

  const handleSendMessage = async (userInput: string) => {
    if (!currentChannelId || isProcessingMessage) return;
    const userMessage: ChatMessageData = {
      id: `user-${Date.now()}`, channelId: currentChannelId, senderType: MessageSender.User,
      senderName: LEGION_COMMANDER_NAME, content: userInput, timestamp: Date.now(),
    };
    handleMessageAdd(currentChannelId, userMessage);
    await processAndDispatchMessage(currentChannelId, userMessage);
  };
  
  const runAutoChatTurn = useCallback(async () => {
    if (!currentChannelId || isProcessingMessage) return;
    setIsProcessingMessage(true);
    setActiveMinionProcessors({});
    await service.triggerNextAutoChatTurn(
        currentChannelId,
        handleMessageUpsert,
        handleMessageChunk,
        (minionName, isProcessing) => { setActiveMinionProcessors(prev => ({ ...prev, [minionName]: isProcessing })); },
        (systemMessage) => handleMessageAdd(systemMessage.channelId, systemMessage),
        (msg) => handleMessageAdd(msg.channelId, msg) // for regulator reports
    );
    setIsProcessingMessage(false);
  }, [currentChannelId, isProcessingMessage, handleMessageUpsert, handleMessageChunk, handleMessageAdd]);

  useEffect(() => {
    const channel = channels.find(c => c.id === currentChannelId);
    if (channel?.type === 'minion_minion_auto' && channel.isAutoModeActive && !isProcessingMessage) {
      const delay = channel.autoModeDelayType === 'random' 
        ? (Math.random() * ((channel.autoModeRandomDelay?.max || 10) - (channel.autoModeRandomDelay?.min || 3)) + (channel.autoModeRandomDelay?.min || 3)) * 1000
        : (channel.autoModeFixedDelay || 5) * 1000;
      autoChatTimeoutRef.current = window.setTimeout(runAutoChatTurn, delay);
    }
    return () => { if (autoChatTimeoutRef.current) clearTimeout(autoChatTimeoutRef.current); };
  }, [currentChannelId, channels, messages, isProcessingMessage, runAutoChatTurn]);

  const handleTogglePlayPause = (isActive: boolean) => {
    if (!currentChannelId) return;
    const channel = channels.find(c => c.id === currentChannelId);
    if (channel) handleAddOrUpdateChannel({ ...channel, isAutoModeActive: isActive, members: channel.members });
  };
  const handleDelayChange = (type: 'fixed' | 'random', value: number | { min: number, max: number }) => {
    if (!currentChannelId) return;
    const channel = channels.find(c => c.id === currentChannelId);
    if (channel) {
      const updates: Partial<Channel> = { autoModeDelayType: type };
      if (type === 'fixed' && typeof value === 'number') updates.autoModeFixedDelay = value;
      else if (type === 'random' && typeof value === 'object') updates.autoModeRandomDelay = value;
      handleAddOrUpdateChannel({ ...channel, ...updates, members: channel.members });
    }
  };
  
  const currentChannel = channels.find(c => c.id === currentChannelId);
  const currentChannelMessages = messages[currentChannelId || ''] || [];
  const allMinionNames = minionConfigs.map(m => m.name);

  const processingMinionNames = Object.entries(activeMinionProcessors)
    .filter(([name, isProcessing]) => isProcessing && currentChannel?.members.includes(name))
    .map(([name]) => name);

  return (
    <div className="h-screen w-screen flex flex-col bg-zinc-50 text-neutral-600 selection:bg-amber-300 selection:text-neutral-900 overflow-hidden">
      <header className="p-3 bg-zinc-50/80 backdrop-blur-sm border-b border-zinc-200 shadow-sm flex items-center justify-between flex-shrink-0 z-20 electron-drag">
        <div className="flex items-center gap-3 select-none">
          <img src="https://picsum.photos/seed/legionicon/40/40" alt="Legion Icon" className="w-10 h-10 rounded-full ring-2 ring-amber-500" />
          <div>
            <h1 className="text-xl font-bold text-neutral-800">{APP_TITLE}</h1>
            <p className="text-xs text-amber-600">Commander: {LEGION_COMMANDER_NAME}</p>
          </div>
        </div>
        <div className="flex items-center gap-2 electron-no-drag">
           <button onClick={() => setIsAutoScrollEnabled(p => !p)}
            className="p-2 rounded-md text-neutral-500 hover:text-amber-500 hover:bg-zinc-200 transition-colors"
            title={isAutoScrollEnabled ? "Auto-Scroll On" : "Auto-Scroll Off"}>
            {isAutoScrollEnabled ? <ChevronDoubleDownIcon className="w-6 h-6 text-teal-600" /> : <ChevronUpIcon className="w-6 h-6 text-amber-800" />}
          </button>
          <button onClick={() => setIsAnalyticsOpen(true)}
            className="p-2 rounded-md text-neutral-500 hover:text-amber-500 hover:bg-zinc-200 transition-colors" title="Open Analytics Dashboard">
            <ChartBarIcon className="w-6 h-6" />
          </button>
          <button onClick={() => setIsMcpManagerOpen(true)}
            className="p-2 rounded-md text-neutral-500 hover:text-amber-500 hover:bg-zinc-200 transition-colors" title="MCP Server Manager">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 12h14M5 12l4-4m-4 4l4 4" />
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 12l-4-4m4 4l-4 4" />
              <circle cx="12" cy="12" r="3" />
            </svg>
          </button>
          <button onClick={() => setIsMinionsPanelOpen(p => !p)}
            className="p-2 rounded-md text-neutral-500 hover:text-amber-500 hover:bg-zinc-200 transition-colors" title="Toggle Minions Roster">
            <CogIcon className="w-6 h-6 animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;" />
          </button>
        </div>
      </header>

      <div className="flex flex-1 overflow-hidden relative">
        <ChannelList channels={channels} currentChannelId={currentChannelId} onSelectChannel={selectChannel} onAddOrUpdateChannel={handleAddOrUpdateChannel} allMinionNames={allMinionNames}/>
        
        <main className="flex-1 flex flex-col overflow-hidden">
          {currentChannel ? (
            <>
              <div className="p-3 border-b border-zinc-200 bg-zinc-50/60 backdrop-blur-sm flex justify-between items-center electron-drag">
                <div className="select-none">
                  <h3 className="text-lg font-semibold text-neutral-800">{currentChannel.name}</h3>
                  <p className="text-xs text-neutral-500">{currentChannel.description}</p>
                </div>
                {currentChannel.type === 'minion_minion_auto' && (
                  <div className="electron-no-drag">
                    <AutoChatControls channel={currentChannel} onTogglePlayPause={handleTogglePlayPause} onDelayChange={handleDelayChange} />
                  </div>
                )}
              </div>
                <div
                  ref={chatHistoryRef}
                  className={`flex-1 p-4 space-y-2 overflow-y-auto scrollbar-thin scrollbar-thumb-neutral-400 scrollbar-track-zinc-200 transition-opacity duration-500 ${isChannelSwitching ? 'opacity-0' : 'opacity-100'}`}
                >                
                {currentChannelMessages.length === 0 && (<div className="text-center text-neutral-500 pt-10"><p>No messages in <span className="font-semibold">{currentChannel.name}</span> yet.</p></div>)}
                {currentChannelMessages.map(msg => (<ChatMessage key={msg.id} message={msg} onDelete={deleteMessageFromChannel} onEdit={editMessageContent} isProcessing={msg.isProcessing}/> ))}
                 {processingMinionNames
                    .filter(name => !currentChannelMessages.some(m => m.senderName === name && m.isProcessing))
                    .map(name => (<ChatMessage key={`proc-${name}`} message={{ id: `proc-${name}`, channelId: currentChannelId!, senderName: name, senderType: MessageSender.AI, content: '', timestamp: Date.now(), isProcessing: true, senderRole: minionConfigs.find(m => m.name === name)?.role || 'standard' }} onDelete={()=>{}} onEdit={()=>{}} />
                    ))}
              </div>
              <ChatInput onSendMessage={handleSendMessage} isSending={isProcessingMessage} disabled={currentChannel.type === 'minion_minion_auto' && currentChannel.isAutoModeActive} />
            </>
          ) : (
            <div className="flex-1 flex items-center justify-center text-neutral-500">
              <p>{isServiceInitialized ? 'Select or create a channel to begin.' : 'Initializing Legion Service...'}</p>
            </div>
          )}
        </main>

        <MinionsPanel 
            minionConfigs={minionConfigs} apiKeys={apiKeys} promptPresets={promptPresets}
            modelOptions={modelOptions}
            onAddMinion={addMinionConfig} onUpdateMinion={updateMinionConfig} onDeleteMinion={deleteMinionConfig} 
            onAddApiKey={handleAddApiKey} onDeleteApiKey={handleDeleteApiKey}
            onAddPreset={handleAddPreset} onDeletePreset={handleDeletePreset}
            onRefreshModels={handleRefreshModels}
            isOpen={isMinionsPanelOpen} onToggle={() => setIsMinionsPanelOpen(p => !p)} 
        />

        <AnalyticsDashboard
          isOpen={isAnalyticsOpen}
          onClose={() => setIsAnalyticsOpen(false)}
          minionConfigs={minionConfigs}
        />

        <McpServerManager
          isOpen={isMcpManagerOpen}
          onClose={() => setIsMcpManagerOpen(false)}
        />
      </div>
    </div>
  );
};

export default App;

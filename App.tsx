import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import { MinionConfig, ChatMessageData, Channel, ChannelPayload, ApiKey, PromptPreset, ModelOption, MessageSender } from './types';
import ChatMessage from './components/ChatMessage';
import { motion, AnimatePresence, LayoutGroup } from 'motion/react';
import ChatInput from './components/ChatInput';
import MinionsPanel from './components/ConfigPanel';
import Modal from './components/Modal';
import MinionConfigForm from './components/LLMConfigForm';
import ChannelList from './components/ChannelList';
import AutoChatControls from './components/AutoChatControls';
import AnalyticsDashboard from './components/AnalyticsDashboard';
import McpServerManager from './components/McpServerManager';
import { CogIcon, ChartBarIcon, ChevronDoubleDownIcon, ChevronUpIcon } from './components/Icons';
import { APP_TITLE, LEGION_COMMANDER_NAME, ACTIVE_CHANNEL_STORAGE_KEY } from './constants';
import legionApiService from './services/legionApiService';
import { useChannelMessages, useHasMoreMessages, useProcessingState, useAutoScrollEnabled, useActiveMinionProcessors, useMessageStore, useSelectionMode, useSelectedMessages, useBulkDiaryVisible } from './stores/messageStore';
import SelectionHeader from './components/SelectionHeader';


const App: React.FC = () => {
  const [minionConfigs, setMinionConfigs] = useState<MinionConfig[]>([]);
  const chatHistoryRef = useRef<HTMLDivElement | null>(null);
  const [channels, setChannels] = useState<Channel[]>([]);
  const [currentChannelId, setCurrentChannelId] = useState<string | null>(null);
  const [apiKeys, setApiKeys] = useState<ApiKey[]>([]);
  const [promptPresets, setPromptPresets] = useState<PromptPreset[]>([]);
  const [modelOptions, setModelOptions] = useState<ModelOption[]>([]);
  
  const [isServiceInitialized, setIsServiceInitialized] = useState(false);
  const [isMinionsPanelOpen, setIsMinionsPanelOpen] = useState(false);
  const [isConfigModalOpen, setIsConfigModalOpen] = useState(false);
  const [editingMinion, setEditingMinion] = useState<MinionConfig | undefined>(undefined);
  const [isAnalyticsOpen, setIsAnalyticsOpen] = useState(false);
  const [isMcpManagerOpen, setIsMcpManagerOpen] = useState(false);
  
  // Message store hooks - using selective subscriptions to prevent re-render cascade
  const currentChannelMessages = useChannelMessages(currentChannelId);
  const hasMoreMessagesInChannel = useHasMoreMessages(currentChannelId);
  const isProcessingMessage = useMessageStore((state) => state.isProcessingMessage);
  const isAutoScrollEnabled = useAutoScrollEnabled();
  
  // Get store actions without subscribing to state changes
  const messageStoreActions = useRef(useMessageStore.getState()).current;
  
  // Selection mode state
  const isSelectionMode = useSelectionMode();
  const selectedMessageIds = useSelectedMessages();
  const bulkDiaryVisible = useBulkDiaryVisible();

  const autoChatTimeoutRef = useRef<number | null>(null);
  const scrollTimeoutRef = useRef<number | null>(null);
  const service = useRef(legionApiService).current;

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
        const newConfigs = await service.getMinions();
        // Use a more robust comparison to prevent unnecessary re-renders
        setMinionConfigs(prev => {
          // Quick length check first
          if (prev.length !== newConfigs.length) return newConfigs;
          
          // Deep comparison of relevant fields that would affect UI
          const hasChanged = prev.some((prevConfig, index) => {
            const newConfig = newConfigs[index];
            return !newConfig || 
                   prevConfig.id !== newConfig.id ||
                   prevConfig.name !== newConfig.name ||
                   prevConfig.role !== newConfig.role ||
                   prevConfig.chatColor !== newConfig.chatColor ||
                   prevConfig.fontColor !== newConfig.fontColor ||
                   JSON.stringify(prevConfig.usageStats) !== JSON.stringify(newConfig.usageStats);
          });
          
          return hasChanged ? newConfigs : prev;
        });
      }, 60000);
      
      return () => {
        if (autoChatTimeoutRef.current) clearTimeout(autoChatTimeoutRef.current);
        if (scrollTimeoutRef.current) clearTimeout(scrollTimeoutRef.current);
        clearInterval(statsInterval);
      };
    }
  }, [isServiceInitialized, loadInitialData]);

  // Auto-scroll effect for chat history
  useEffect(() => {
    if (isAutoScrollEnabled && chatHistoryRef.current && currentChannelId && currentChannelMessages.length > 0) {
      requestAnimationFrame(() => {
        if (chatHistoryRef.current) {
          chatHistoryRef.current.scrollTop = chatHistoryRef.current.scrollHeight;
        }
      });
    }
  }, [currentChannelMessages, isAutoScrollEnabled, currentChannelId]);

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
  
  const handleOpenEditMinion = (minion: MinionConfig) => {
    setEditingMinion(minion);
    setIsConfigModalOpen(true);
  };

  const handleOpenAddNewMinion = () => {
    setEditingMinion(undefined);
    setIsConfigModalOpen(true);
  };

  const handleSaveConfig = (config: MinionConfig) => {
    if (editingMinion) {
      updateMinionConfig(config);
    } else {
      addMinionConfig(config);
    }
    setIsConfigModalOpen(false);
    setEditingMinion(undefined);
  };
  const deleteMinionConfig = async (id: string) => { await service.deleteMinion(id); setMinionConfigs(await service.getMinions()); setChannels(await service.getChannels()); };
  const handleBulkRemoveMinionFromChannels = async (minionName: string, excludeChannels: string[]) => { 
    const result = await service.bulkRemoveMinionFromChannels(minionName, excludeChannels); 
    setChannels(await service.getChannels()); 
    return result;
  };

  // Function to extract and apply chat name from minion response
  const extractAndApplyChatName = async (channelId: string, minionResponse: string) => {
    const chatNameMatch = minionResponse.match(/Chat Name:\s*(.+)$/im);
    if (chatNameMatch && chatNameMatch[1]) {
      const suggestedName = chatNameMatch[1].trim();
      const channel = channels.find(c => c.id === channelId);
      if (channel && channel.type === 'minion_buddy_chat' && channel.name === 'New Chat') {
        // Update the channel name
        const updatedChannelData: ChannelPayload = {
          ...channel,
          name: suggestedName,
          members: channel.members
        };
        await handleAddOrUpdateChannel(updatedChannelData);
      }
    }
  };

  // --- Message Management ---
  const handleMessageUpdate = useCallback((channelId: string, messageId: string, updates: Partial<ChatMessageData>) => { 
    messageStoreActions.updateMessage(channelId, messageId, updates);
  }, [messageStoreActions]);
  
  const handleMessageAdd = useCallback((channelId: string, message: ChatMessageData) => { 
    messageStoreActions.addMessage(channelId, message);
    // Cleanup old messages periodically to prevent memory bloat - throttled to every 10 messages
    const currentMessages = messageStoreActions.getChannelMessages(channelId);
    if (currentMessages.length % 10 === 0) {
      requestAnimationFrame(() => service.cleanupOldMessages(channelId, 500));
    }
  }, [messageStoreActions, service]);
  // Throttle chunk processing to prevent excessive renders
  const handleMessageChunk = useCallback((channelId: string, messageId: string, chunk: string) => {
    messageStoreActions.processMessageChunk(channelId, messageId, chunk);
  }, [messageStoreActions]);
  const handleMessageUpsert = useCallback((message: ChatMessageData) => {
    messageStoreActions.upsertMessage(message);
    
    // Check for chat naming in minion buddy chats
    if (message.senderType === MessageSender.AI && message.content) {
      const channel = channels.find(c => c.id === message.channelId);
      if (channel?.type === 'minion_buddy_chat' && channel.name === 'New Chat') {
        extractAndApplyChatName(message.channelId, message.content);
      }
    }
  }, [messageStoreActions, channels, extractAndApplyChatName]);

  const handleToolUpdate = useCallback((updatedMessage: ChatMessageData) => {
    messageStoreActions.upsertMessage(updatedMessage);
  }, [messageStoreActions]);
  
  const deleteMessageFromChannel = useCallback(async (channelId: string, messageId: string) => { 
    await service.deleteMessage(channelId, messageId); 
    messageStoreActions.deleteMessage(channelId, messageId);
  }, [service, messageStoreActions]);

  const editMessageContent = useCallback(async (channelId: string, messageId: string, newContent: string) => { 
    await service.editMessage(channelId, messageId, newContent); 
    handleMessageUpdate(channelId, messageId, { content: newContent }); 
  }, [service, handleMessageUpdate]);

  // Selection mode handlers
  const handleEnterSelectionMode = useCallback(() => {
    messageStoreActions.toggleSelectionMode();
  }, [messageStoreActions]);

  const handleToggleSelection = useCallback((messageId: string, shiftKey: boolean) => {
    if (shiftKey && messageStoreActions.lastSelectedMessageId) {
      messageStoreActions.selectMessageRange(
        messageStoreActions.lastSelectedMessageId,
        messageId,
        currentChannelMessages
      );
    } else {
      messageStoreActions.selectMessage(messageId);
    }
  }, [messageStoreActions, currentChannelMessages]);

  const handleDeleteSelected = useCallback(async () => {
    if (!currentChannelId) return;
    const selectedIds = Array.from(selectedMessageIds);
    
    // Delete from service first
    await Promise.all(selectedIds.map(id => service.deleteMessage(currentChannelId, id)));
    
    // Then delete from store
    messageStoreActions.deleteSelectedMessages(currentChannelId);
  }, [currentChannelId, selectedMessageIds, service, messageStoreActions]);

  const handleToggleBulkDiary = useCallback(() => {
    const selectedIds = Array.from(selectedMessageIds);
    messageStoreActions.toggleBulkDiary(selectedIds);
  }, [selectedMessageIds, messageStoreActions]);

  const handleExitSelectionMode = useCallback(() => {
    messageStoreActions.toggleSelectionMode();
    messageStoreActions.clearSelection();
  }, [messageStoreActions]);

  // Load more messages when scrolling up
  const loadMoreMessages = useCallback(async () => {
    if (!currentChannelId || !hasMoreMessagesInChannel) return;
    
    if (currentChannelMessages.length === 0) return;
    
    const oldestMessage = currentChannelMessages[0];
    const result = await service.getMessages(currentChannelId, 50, oldestMessage.id);
    
    if (result.messages.length > 0) {
      const scrollElement = chatHistoryRef.current;
      const previousScrollHeight = scrollElement?.scrollHeight || 0;
      
      messageStoreActions.prependMessages(currentChannelId, result.messages, result.hasMore);
      
      // Maintain scroll position after loading older messages
      requestAnimationFrame(() => {
        if (scrollElement) {
          const newScrollHeight = scrollElement.scrollHeight;
          scrollElement.scrollTop = newScrollHeight - previousScrollHeight;
        }
      });
    } else {
      messageStoreActions.setMessages(currentChannelId, currentChannelMessages, result.hasMore);
    }
  }, [currentChannelId, hasMoreMessagesInChannel, currentChannelMessages, service, messageStoreActions]);
  
  // Handle scroll events for infinite scroll
  const handleScroll = useCallback((e: React.UIEvent<HTMLDivElement>) => {
    const element = e.currentTarget;
    if (element.scrollTop === 0 && hasMoreMessagesInChannel) {
      loadMoreMessages();
    }

    // Show scrollbar while scrolling
    document.body.classList.add('is-scrolling');
    if (scrollTimeoutRef.current) {
      clearTimeout(scrollTimeoutRef.current);
    }
    scrollTimeoutRef.current = window.setTimeout(() => {
      document.body.classList.remove('is-scrolling');
    }, 100);
  }, [loadMoreMessages, hasMoreMessagesInChannel]);
  
  // --- Channel Management ---
  const selectChannel = async (channelId: string) => {
      // Don't do a goddamn thing if we're not actually changing channels.
      if (channelId === currentChannelId) return;

      // Clear any auto-chat timeouts
      if (autoChatTimeoutRef.current) clearTimeout(autoChatTimeoutRef.current);
      
      // Cleanup old messages from the previous channel to free memory
      if (currentChannelId) {
        requestAnimationFrame(() => service.cleanupOldMessages(currentChannelId, 500));
      }
      
      // Load messages for the new channel if not already loaded
      if (messageStoreActions.getChannelMessages(channelId).length === 0) {
          const result = await service.getMessages(channelId, 50); // Load last 50 messages
          messageStoreActions.setMessages(channelId, result.messages, result.hasMore);
      }
      
      // Just switch the channel immediately
      setCurrentChannelId(channelId);
  };
  const handleAddOrUpdateChannel = async (channelData: ChannelPayload) => { await service.addOrUpdateChannel(channelData); setChannels(await service.getChannels()); };
  
  const handleDeleteChannel = async (channelId: string) => { 
    await service.deleteChannel(channelId); 
    setChannels(await service.getChannels());
    // If we deleted the current channel, switch to the first available channel
    if (channelId === currentChannelId) {
      const updatedChannels = await service.getChannels();
      if (updatedChannels.length > 0) {
        await selectChannel(updatedChannels[0].id);
      } else {
        setCurrentChannelId(null);
      }
    }
  };

  const handleCreateNewMinionChat = async (minionName: string) => {
    const timestamp = Date.now();
    const channelData: ChannelPayload = {
      name: `New Chat`, // This will be renamed by the minion
      type: 'minion_buddy_chat',
      members: [LEGION_COMMANDER_NAME, minionName],
      description: `Private chat with ${minionName}`
    };
    
    const newChannel = await service.addOrUpdateChannel(channelData);
    setChannels(await service.getChannels());
    await selectChannel(newChannel.id);
  };


  // --- Core Message Sending Logic ---
  const processAndDispatchMessage = async (channelId: string, message: ChatMessageData) => {
    messageStoreActions.setProcessingMessage(true);
    messageStoreActions.clearActiveMinionProcessors();
    
    await service.processMessageTurn({
      channelId: channelId,
      triggeringMessage: message,
      onMinionResponse: handleMessageUpsert,
      onMinionResponseChunk: handleMessageChunk,
      onMinionProcessingUpdate: (minionName, isProcessing) => { messageStoreActions.setActiveMinionProcessor(minionName, isProcessing); },
      onSystemMessage: (systemMessage) => handleMessageAdd(systemMessage.channelId, systemMessage),
      onRegulatorReport: (reportMsg) => handleMessageAdd(reportMsg.channelId, reportMsg),
      onToolUpdate: handleToolUpdate,
    });

    messageStoreActions.setProcessingMessage(false);
  }

  const handleManualRegulatorCall = useCallback(async () => {
      if (!currentChannelId) return;
      await service.manuallyTriggerRegulator(
          currentChannelId,
          (msg) => handleMessageAdd(msg.channelId, msg),
          (msg) => handleMessageAdd(msg.channelId, msg)
      );
  }, [currentChannelId, service, handleMessageAdd]);

  const handleSendMessage = async (userInput: string) => {
    if (!currentChannelId || isProcessingMessage) return;
    
    // Check if this is the first message in a minion buddy chat
    const currentMessages = messageStoreActions.getChannelMessages(currentChannelId);
    const isFirstMessageInBuddyChat = currentMessages.length === 0 && 
      currentChannel?.type === 'minion_buddy_chat';
    
    let messageContent = userInput;
    if (isFirstMessageInBuddyChat) {
      // Add auto-naming instructions to the first message
      messageContent = `${userInput}

[SYSTEM INSTRUCTION: This is the first message in a new private chat session. Please respond to the user's message above, and at the end of your response, suggest a brief, descriptive name for this conversation based on the topic. Format it like this: "Chat Name: [Your suggested name]"]`;
    }
    
    const userMessage: ChatMessageData = {
      id: `user-${Date.now()}`,
      channelId: currentChannelId,
      senderType: MessageSender.User,
      senderName: LEGION_COMMANDER_NAME,
      content: messageContent,
      timestamp: Date.now(),
    };
    handleMessageAdd(currentChannelId, userMessage);
    await processAndDispatchMessage(currentChannelId, userMessage);
  };
  
  const runAutoChatTurn = useCallback(async () => {
    if (!currentChannelId || isProcessingMessage) return;
    messageStoreActions.setProcessingMessage(true);
    messageStoreActions.clearActiveMinionProcessors();
    await service.triggerNextAutoChatTurn(
        currentChannelId,
        handleMessageUpsert,
        handleMessageChunk,
        (minionName, isProcessing) => { messageStoreActions.setActiveMinionProcessor(minionName, isProcessing); },
        (systemMessage) => handleMessageAdd(systemMessage.channelId, systemMessage),
        (msg) => handleMessageAdd(msg.channelId, msg), // for regulator reports
        handleToolUpdate
    );
    messageStoreActions.setProcessingMessage(false);
  }, [currentChannelId, isProcessingMessage, handleMessageUpsert, handleMessageChunk, handleMessageAdd, messageStoreActions]);

  useEffect(() => {
    const channel = channels.find(c => c.id === currentChannelId);
    if (channel?.type === 'minion_minion_auto' && channel.isAutoModeActive && !isProcessingMessage) {
      const delay = channel.autoModeDelayType === 'random' 
        ? (Math.random() * ((channel.autoModeRandomDelay?.max || 10) - (channel.autoModeRandomDelay?.min || 3)) + (channel.autoModeRandomDelay?.min || 3)) * 1000
        : (channel.autoModeFixedDelay || 5) * 1000;
      autoChatTimeoutRef.current = window.setTimeout(runAutoChatTurn, delay);
    }
    return () => { if (autoChatTimeoutRef.current) clearTimeout(autoChatTimeoutRef.current); };
  }, [currentChannelId, channels, isProcessingMessage, runAutoChatTurn]);

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
  const allMinionNames = minionConfigs.map(m => m.name);
  const activeMinionProcessors = useActiveMinionProcessors();
  
  // Selection mode computed values
  const selectedCount = selectedMessageIds.size;
  const selectedMessages = currentChannelMessages.filter(m => selectedMessageIds.has(m.id));
  const hasSelectedMinions = selectedMessages.some(m => m.senderType === MessageSender.AI && m.senderRole !== 'regulator');
  
  // Filter processing minions for current channel (pure component logic, not selector)
  const processingMinionNames = useMemo(() => {
    const channelMembers = currentChannel?.members || [];
    const processing = Object.entries(activeMinionProcessors)
      .filter(([name, isProcessing]) => isProcessing && channelMembers.includes(name))
      .map(([name]) => name);
    return processing;
  }, [activeMinionProcessors, currentChannel?.id]); // Use channel id instead of members array

  // Memoize the minion config map with stable dependencies to prevent unnecessary recalculation
  const minionConfigMap = useMemo(() => {
    const map = new Map<string, MinionConfig>();
    for (const config of minionConfigs) {
      map.set(config.name, config);
    }
    return map;
  }, [minionConfigs.map(c => `${c.id}-${c.name}-${c.chatColor}-${c.fontColor}`).join('|')]);


  return (
    <div className="h-screen w-screen flex flex-col bg-gradient-to-tl from-zinc-100 to-zinc-50 overflow-hidden text-neutral-600 selection:bg-amber-300 selection:text-neutral-900">
      <header className="p-3 bg-zinc-100/100 border-b border-zinc-200 shadow-sm flex items-center justify-between flex-shrink-0 z-20 electron-drag">
        <div className="flex ml-20 items-center gap-3 select-none">
          <img src="https://picsum.photos/seed/legionicon/40/40" alt="Legion Icon" className="w-10 h-10 rounded-full ring-2 ring-amber-500" />
          <div>
            <h1 className="text-xl font-semibold text-neutral-800">{APP_TITLE}</h1>
            <p className="text-xs text-amber-600">Commander: {LEGION_COMMANDER_NAME}</p>
          </div>
        </div>
        <div className="flex items-center gap-2 electron-no-drag">
           <button onClick={() => messageStoreActions.setAutoScrollEnabled(!isAutoScrollEnabled)}
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
          <button onClick={handleManualRegulatorCall}
            className="p-2 rounded-md text-neutral-500 hover:text-red-500 hover:bg-red-100 transition-colors" title="Manually Trigger Regulator">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-6 h-6">
            <path strokeLinecap="round" strokeLinejoin="round" d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0" />
            </svg>
          </button>
          <button onClick={() => setIsMinionsPanelOpen(p => !p)}
            className="p-2 rounded-md text-neutral-500 hover:text-amber-500 hover:bg-zinc-200 transition-colors" title="Toggle Minions Roster">
            <CogIcon className="w-6 h-6 animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;" />
          </button>
        </div>
      </header>

      <div className="flex flex-1 overflow-hidden relative">
        {/* Selection Header */}
        <SelectionHeader
          isVisible={isSelectionMode && selectedCount > 0}
          selectedCount={selectedCount}
          onDelete={handleDeleteSelected}
          onShowDiary={handleToggleBulkDiary}
          onDone={handleExitSelectionMode}
          hasMinions={hasSelectedMinions}
        />
        <ChannelList 
          channels={channels} 
          currentChannelId={currentChannelId} 
          onSelectChannel={selectChannel} 
          onAddOrUpdateChannel={handleAddOrUpdateChannel} 
          onDeleteChannel={handleDeleteChannel}
          onCreateNewMinionChat={handleCreateNewMinionChat}
          allMinionNames={allMinionNames}
          minionConfigs={minionConfigs}
        />
        
        <main className="flex-1 flex flex-col overflow-hidden">
          {currentChannel ? (
            <>
              <div className="p-3 border-b border-zinc-200 bg-zinc-50/60 opacity-60 flex justify-between items-center">
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
                className="flex-1 overflow-y-auto p-4 flex justify-center"
                onScroll={handleScroll}
              >
                <div className="w-full max-w-6xl space-y-3">
                {hasMoreMessagesInChannel && (
                  <div className="text-center py-2">
                    <button 
                      onClick={loadMoreMessages}
                      className="px-3 py-1 text-sm text-neutral-500 hover:text-neutral-700 transition-colors"
                    >
                      Load older messages...
                    </button>
                  </div>
                )}
                <AnimatePresence initial={false}>
                  {currentChannelMessages.map((message) => (
                    <ChatMessage
                      key={message.id}
                      message={message}
                      minionConfig={minionConfigMap.get(message.senderName)}
                      channelType={currentChannel?.type}
                      onDelete={() => deleteMessageFromChannel(message.channelId, message.id)}
                      onEdit={(content) => editMessageContent(message.channelId, message.id, content)}
                      isProcessing={processingMinionNames.includes(message.senderName)}
                      isSelectionMode={isSelectionMode}
                      isSelected={selectedMessageIds.has(message.id)}
                      onToggleSelection={handleToggleSelection}
                      onEnterSelectionMode={handleEnterSelectionMode}
                      isBulkDiaryVisible={bulkDiaryVisible.has(message.id)}
                    />
                  ))}
                </AnimatePresence>
                </div>
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
            minionConfigs={minionConfigs} apiKeys={apiKeys} channels={channels}
            onDeleteMinion={deleteMinionConfig} 
            onAddApiKey={handleAddApiKey} onDeleteApiKey={handleDeleteApiKey}
            onBulkRemoveMinionFromChannels={handleBulkRemoveMinionFromChannels}
            isOpen={isMinionsPanelOpen} onToggle={() => setIsMinionsPanelOpen(p => !p)} 
            onEditMinion={handleOpenEditMinion}
            onAddNewMinion={handleOpenAddNewMinion}
        />

        <Modal
          isOpen={isConfigModalOpen}
          onClose={() => setIsConfigModalOpen(false)}
          title={editingMinion ? `Configure Minion: ${editingMinion.name}` : 'Deploy New Minion'}
          size="2xl"
        >
          <MinionConfigForm
            initialConfig={editingMinion}
            onSave={handleSaveConfig}
            onCancel={() => setIsConfigModalOpen(false)}
            existingNames={minionConfigs.map(c => c.name).filter(name => !editingMinion || name !== editingMinion.name)}
            apiKeys={apiKeys}
            promptPresets={promptPresets}
            modelOptions={modelOptions}
            onAddPreset={handleAddPreset}
            onDeletePreset={handleDeletePreset}
            onRefreshModels={handleRefreshModels}
          />
        </Modal>

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
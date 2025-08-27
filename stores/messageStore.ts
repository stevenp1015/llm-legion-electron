import { create } from 'zustand';
import { subscribeWithSelector } from 'zustand/middleware';
import { shallow } from 'zustand/shallow';
import { ChatMessageData } from '../types';

// Stable constants to prevent infinite re-renders
const EMPTY_MESSAGES: ChatMessageData[] = [];
const EMPTY_PROCESSORS: Record<string, boolean> = {};

export interface MessageState {
  // Core message state
  messages: Record<string, ChatMessageData[]>;
  hasMoreMessages: Record<string, boolean>;
  isProcessingMessage: boolean;
  isAutoScrollEnabled: boolean;
  activeMinionProcessors: Record<string, boolean>;
  
  // Selection mode state
  isSelectionMode: boolean;
  selectedMessageIds: Set<string>;
  lastSelectedMessageId: string | null;
  bulkDiaryVisible: Set<string>;
  
  // Chunk processing state
  chunkQueue: Map<string, string[]>;
  isProcessingQueue: Map<string, boolean>;
}

export interface MessageActions {
  // Message CRUD operations
  addMessage: (channelId: string, message: ChatMessageData) => void;
  updateMessage: (channelId: string, messageId: string, updates: Partial<ChatMessageData>) => void;
  upsertMessage: (message: ChatMessageData) => void;
  deleteMessage: (channelId: string, messageId: string) => void;
  setMessages: (channelId: string, messages: ChatMessageData[], hasMore: boolean) => void;
  prependMessages: (channelId: string, messages: ChatMessageData[], hasMore: boolean) => void;
  
  // Selection mode operations
  toggleSelectionMode: () => void;
  selectMessage: (messageId: string) => void;
  selectMessageRange: (startId: string, endId: string, messages: ChatMessageData[]) => void;
  clearSelection: () => void;
  deleteSelectedMessages: (channelId: string) => void;
  toggleBulkDiary: (messageIds: string[]) => void;
  
  // Message streaming and chunking
  processMessageChunk: (channelId: string, messageId: string, chunk: string) => void;
  
  // Processing state management
  setProcessingMessage: (isProcessing: boolean) => void;
  setActiveMinionProcessor: (minionName: string, isProcessing: boolean) => void;
  clearActiveMinionProcessors: () => void;
  
  // Auto-scroll management
  setAutoScrollEnabled: (enabled: boolean) => void;
  
  // Channel-specific utilities
  getChannelMessages: (channelId: string) => ChatMessageData[];
  hasMoreMessagesInChannel: (channelId: string) => boolean;
  
  // Internal chunk processing
  _processChunkQueue: (channelId: string, messageId: string) => void;
}

type MessageStore = MessageState & MessageActions;

export const useMessageStore = create<MessageStore>()(
  subscribeWithSelector((set, get) => ({
    // Initial state
    messages: {},
    hasMoreMessages: {},
    isProcessingMessage: false,
    isAutoScrollEnabled: true,
    activeMinionProcessors: {},
    
    // Selection mode state
    isSelectionMode: false,
    selectedMessageIds: new Set(),
    lastSelectedMessageId: null,
    bulkDiaryVisible: new Set(),
    
    chunkQueue: new Map(),
    isProcessingQueue: new Map(),

    // Message CRUD operations
    addMessage: (channelId: string, message: ChatMessageData) => {
      set((state) => ({
        messages: {
          ...state.messages,
          [channelId]: [...(state.messages[channelId] || []), message]
        }
      }));
    },

    updateMessage: (channelId: string, messageId: string, updates: Partial<ChatMessageData>) => {
      set((state) => ({
        messages: {
          ...state.messages,
          [channelId]: (state.messages[channelId] || []).map(m => 
            m.id === messageId ? { ...m, ...updates } : m
          )
        }
      }));
    },

    upsertMessage: (message: ChatMessageData) => {
      set((state) => {
        const channelMessages = state.messages[message.channelId] || [];
        const existingMsgIndex = channelMessages.findIndex(m => m.id === message.id);
        
        if (existingMsgIndex > -1) {
          const newChannelMessages = [...channelMessages];
          newChannelMessages[existingMsgIndex] = { ...newChannelMessages[existingMsgIndex], ...message };
          return {
            messages: {
              ...state.messages,
              [message.channelId]: newChannelMessages
            }
          };
        } else {
          return {
            messages: {
              ...state.messages,
              [message.channelId]: [...channelMessages, message]
            }
          };
        }
      });
    },

    deleteMessage: (channelId: string, messageId: string) => {
      set((state) => ({
        messages: {
          ...state.messages,
          [channelId]: (state.messages[channelId] || []).filter(m => m.id !== messageId)
        }
      }));
    },

    setMessages: (channelId: string, messages: ChatMessageData[], hasMore: boolean) => {
      set((state) => ({
        messages: {
          ...state.messages,
          [channelId]: messages
        },
        hasMoreMessages: {
          ...state.hasMoreMessages,
          [channelId]: hasMore
        }
      }));
    },

    prependMessages: (channelId: string, messages: ChatMessageData[], hasMore: boolean) => {
      set((state) => ({
        messages: {
          ...state.messages,
          [channelId]: [...messages, ...(state.messages[channelId] || [])]
        },
        hasMoreMessages: {
          ...state.hasMoreMessages,
          [channelId]: hasMore
        }
      }));
    },

    // Chunk processing
    processMessageChunk: (channelId: string, messageId: string, chunk: string) => {
      const messageKey = `${channelId}-${messageId}`;
      const { chunkQueue, isProcessingQueue } = get();
      
      if (!chunkQueue.has(messageKey)) {
        chunkQueue.set(messageKey, []);
      }
      chunkQueue.get(messageKey)!.push(chunk);

      if (!isProcessingQueue.get(messageKey)) {
        isProcessingQueue.set(messageKey, true);
        requestAnimationFrame(() => get()._processChunkQueue(channelId, messageId));
      }
    },

    _processChunkQueue: (channelId: string, messageId: string) => {
      const messageKey = `${channelId}-${messageId}`;
      const { chunkQueue, isProcessingQueue } = get();
      const queue = chunkQueue.get(messageKey);

      if (!queue || queue.length === 0) {
        isProcessingQueue.set(messageKey, false);
        chunkQueue.delete(messageKey);
        isProcessingQueue.delete(messageKey);
        return;
      }

      const aggregatedChunk = queue.join('');
      chunkQueue.set(messageKey, []);

      set((state) => ({
        messages: {
          ...state.messages,
          [channelId]: (state.messages[channelId] || []).map(m => {
            if (m.id === messageId) {
              return { ...m, content: m.content + aggregatedChunk };
            }
            return m;
          })
        }
      }));

      requestAnimationFrame(() => get()._processChunkQueue(channelId, messageId));
    },

    // Processing state management
    setProcessingMessage: (isProcessing: boolean) => {
      set({ isProcessingMessage: isProcessing });
    },

    setActiveMinionProcessor: (minionName: string, isProcessing: boolean) => {
      set((state) => ({
        activeMinionProcessors: {
          ...state.activeMinionProcessors,
          [minionName]: isProcessing
        }
      }));
    },

    clearActiveMinionProcessors: () => {
      set({ activeMinionProcessors: {} });
    },

    // Auto-scroll management
    setAutoScrollEnabled: (enabled: boolean) => {
      set({ isAutoScrollEnabled: enabled });
    },

    // Selection mode operations
    toggleSelectionMode: () => {
      set((state) => ({
        isSelectionMode: !state.isSelectionMode,
        selectedMessageIds: new Set(),
        lastSelectedMessageId: null
      }));
    },

    selectMessage: (messageId: string) => {
      set((state) => {
        const newSelected = new Set(state.selectedMessageIds);
        if (newSelected.has(messageId)) {
          newSelected.delete(messageId);
        } else {
          newSelected.add(messageId);
        }
        return {
          selectedMessageIds: newSelected,
          lastSelectedMessageId: messageId
        };
      });
    },

    selectMessageRange: (startId: string, endId: string, messages: ChatMessageData[]) => {
      const startIndex = messages.findIndex(m => m.id === startId);
      const endIndex = messages.findIndex(m => m.id === endId);
      
      if (startIndex === -1 || endIndex === -1) return;
      
      const min = Math.min(startIndex, endIndex);
      const max = Math.max(startIndex, endIndex);
      
      set((state) => {
        const newSelected = new Set(state.selectedMessageIds);
        for (let i = min; i <= max; i++) {
          newSelected.add(messages[i].id);
        }
        return { selectedMessageIds: newSelected };
      });
    },

    clearSelection: () => {
      set({ selectedMessageIds: new Set(), lastSelectedMessageId: null });
    },

    deleteSelectedMessages: (channelId: string) => {
      set((state) => {
        const selectedIds = Array.from(state.selectedMessageIds);
        const filteredMessages = (state.messages[channelId] || []).filter(
          m => !selectedIds.includes(m.id)
        );
        return {
          messages: {
            ...state.messages,
            [channelId]: filteredMessages
          },
          selectedMessageIds: new Set(),
          lastSelectedMessageId: null
        };
      });
    },

    toggleBulkDiary: (messageIds: string[]) => {
      set((state) => {
        const newBulkDiary = new Set(state.bulkDiaryVisible);
        const allVisible = messageIds.every(id => newBulkDiary.has(id));
        
        if (allVisible) {
          messageIds.forEach(id => newBulkDiary.delete(id));
        } else {
          messageIds.forEach(id => newBulkDiary.add(id));
        }
        
        return { bulkDiaryVisible: newBulkDiary };
      });
    },

    // Utility functions
    getChannelMessages: (channelId: string) => {
      const { messages } = get();
      return messages[channelId] || EMPTY_MESSAGES;
    },

    hasMoreMessagesInChannel: (channelId: string) => {
      const { hasMoreMessages } = get();
      return hasMoreMessages[channelId] || false;
    }
  }))
);

// Stable selector hooks - CRITICAL: These must return stable references
export const useChannelMessages = (channelId: string | null) => 
  useMessageStore((state) => channelId ? state.messages[channelId] || EMPTY_MESSAGES : EMPTY_MESSAGES);

export const useHasMoreMessages = (channelId: string | null) => 
  useMessageStore((state) => channelId ? state.hasMoreMessages[channelId] || false : false);

export const useProcessingState = () => 
  useMessageStore((state) => ({
    isProcessingMessage: state.isProcessingMessage,
    activeMinionProcessors: state.activeMinionProcessors
  }));

export const useAutoScrollEnabled = () => 
  useMessageStore((state) => state.isAutoScrollEnabled);

// Get raw processing state - let component do the filtering
export const useActiveMinionProcessors = () => 
  useMessageStore((state) => state.activeMinionProcessors);

// Selection mode hooks
export const useSelectionMode = () => 
  useMessageStore((state) => state.isSelectionMode);

export const useSelectedMessages = () => 
  useMessageStore((state) => state.selectedMessageIds);

export const useBulkDiaryVisible = () => 
  useMessageStore((state) => state.bulkDiaryVisible);
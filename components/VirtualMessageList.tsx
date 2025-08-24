import React, { useCallback, useRef, useEffect, forwardRef, useState } from 'react';
import { VariableSizeList as List } from 'react-window';
import { ChatMessageData, MinionConfig, ChannelType, MessageSender } from '../types';
import ChatMessage from './ChatMessage';
import { motion, AnimatePresence } from 'framer-motion';
import { getAnimationConfig } from '../animations/config';

interface VirtualMessageListProps {
  messages: ChatMessageData[];
  minionConfigMap: Map<string, MinionConfig>;
  channelType?: ChannelType;
  onDelete: (channelId: string, messageId: string) => void;
  onEdit: (channelId: string, messageId: string, content: string) => void;
  processingMinions: string[];
  currentChannelId: string;
  onLoadMore?: () => Promise<void>;
  hasMore?: boolean;
  isAutoScrollEnabled: boolean;
}

// Cache for row heights - persists across re-renders
const rowHeightCache = new Map<string, number>();
const MIN_ROW_HEIGHT = 80; // Minimum height for any message

const VirtualMessageList: React.FC<VirtualMessageListProps> = ({
  messages,
  minionConfigMap,
  channelType,
  onDelete,
  onEdit,
  processingMinions,
  currentChannelId,
  onLoadMore,
  hasMore = false,
  isAutoScrollEnabled
}) => {
  const listRef = useRef<List>(null);
  const outerRef = useRef<HTMLDivElement>(null);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const lastScrollTop = useRef(0);

  // Generate virtual messages for processing indicators
  const virtualProcessingMessages = processingMinions
    .filter(name => !messages.some(m => m.senderName === name && m.isProcessing))
    .map(name => {
      const minionConfig = minionConfigMap.get(name);
      return {
        id: `proc-${name}`,
        channelId: currentChannelId,
        senderName: name,
        senderType: MessageSender.AI,
        content: '',
        timestamp: Date.now(),
        isProcessing: true,
        senderRole: minionConfig?.role || 'standard'
      } as ChatMessageData;
    });

  const allMessages = [...messages, ...virtualProcessingMessages];

  // Get cached height or estimate
  const getItemSize = useCallback((index: number) => {
    const message = allMessages[index];
    if (!message) return MIN_ROW_HEIGHT;
    
    const cached = rowHeightCache.get(message.id);
    if (cached) return cached;
    
    // Estimate based on content length and type
    const baseHeight = 80;
    const contentLength = message.content.length;
    const lineEstimate = Math.ceil(contentLength / 80); // ~80 chars per line
    const estimatedHeight = baseHeight + (lineEstimate * 20);
    
    return Math.min(Math.max(estimatedHeight, MIN_ROW_HEIGHT), 600); // Cap at 600px
  }, [allMessages]);

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    if (isAutoScrollEnabled && listRef.current && allMessages.length > 0) {
      requestAnimationFrame(() => {
        listRef.current?.scrollToItem(allMessages.length - 1, 'end');
      });
    }
  }, [allMessages.length, isAutoScrollEnabled]);

  // Handle scroll for loading more messages
  const handleScroll = useCallback(async ({ scrollOffset }: { scrollOffset: number }) => {
    lastScrollTop.current = scrollOffset;
    
    // Load more when scrolled to top
    if (scrollOffset < 100 && hasMore && !isLoadingMore && onLoadMore) {
      setIsLoadingMore(true);
      const previousHeight = outerRef.current?.scrollHeight || 0;
      
      await onLoadMore();
      
      // Maintain scroll position after loading
      requestAnimationFrame(() => {
        if (outerRef.current) {
          const newHeight = outerRef.current.scrollHeight;
          const heightDiff = newHeight - previousHeight;
          listRef.current?.scrollTo(scrollOffset + heightDiff);
        }
      });
      
      setIsLoadingMore(false);
    }
  }, [hasMore, isLoadingMore, onLoadMore]);

  // Row renderer with height measurement
  const Row = ({ index, style }: { index: number; style: React.CSSProperties }) => {
    const message = allMessages[index];
    const rowRef = useRef<HTMLDivElement>(null);
    
    useEffect(() => {
      if (rowRef.current && message) {
        const height = rowRef.current.getBoundingClientRect().height;
        const cachedHeight = rowHeightCache.get(message.id);
        
        // Update cache if height changed significantly
        if (!cachedHeight || Math.abs(cachedHeight - height) > 10) {
          rowHeightCache.set(message.id, height);
          
          // Reset the item to trigger re-measurement
          if (Math.abs((cachedHeight || 0) - height) > 10) {
            listRef.current?.resetAfterIndex(index);
          }
        }
      }
    }, [message?.content, index]);
    
    if (!message) return null;
    
    return (
      <div ref={rowRef} style={style}>
        <AnimatePresence mode="wait">
          <motion.div
            key={message.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={getAnimationConfig('gentle')}
          >
            <ChatMessage
              message={message}
              minionConfig={minionConfigMap.get(message.senderName)}
              channelType={channelType}
              onDelete={onDelete}
              onEdit={onEdit}
              isProcessing={message.isProcessing}
            />
          </motion.div>
        </AnimatePresence>
      </div>
    );
  };

  return (
    <div className="flex-1 relative">
      {isLoadingMore && (
        <div className="absolute top-0 left-0 right-0 z-10 bg-gradient-to-b from-white to-transparent p-4">
          <div className="flex justify-center">
            <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-teal-600"></div>
          </div>
        </div>
      )}
      
      <List
        ref={listRef}
        outerRef={outerRef}
        height={window.innerHeight - 200} // Adjust based on your layout
        itemCount={allMessages.length}
        itemSize={getItemSize}
        width="100%"
        onScroll={handleScroll}
        className="scrollbar-thin scrollbar-thumb-neutral-400 scrollbar-track-zinc-200"
        overscanCount={3} // Render 3 items outside visible area for smoother scrolling
      >
        {Row}
      </List>
    </div>
  );
};

export default VirtualMessageList;

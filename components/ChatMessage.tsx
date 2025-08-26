import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { ChatMessageData, MessageSender, RegulatorReport, MinionConfig, ToolCall } from '../types';
import { LEGION_COMMANDER_NAME } from '../constants';
import { TrashIcon, PencilIcon, BookOpenIcon, UserCircleIcon, SaveIcon, XMarkIcon, ExclamationTriangleIcon, TerminalIcon, ChevronDoubleDownIcon } from './Icons';
import TypingIndicator from './TypingIndicator';
import RegulatorReportCard from './RegulatorReportCard';
import { parseJsonFromMarkdown } from '../services/geminiService';
import MinionIcon from './MinionIcon';
import StreamingText from './StreamingText';
import { getAnimationConfig } from '../animations/config';

const DiaryCard: React.FC<{ diary: any }> = ({ diary }) => {
  const renderOpinionUpdates = () => (
    <ul className="list-none pl-0 space-y-1">
      {diary.opinionUpdates.map((update: any, index: number) => (
        <li key={index} className="flex items-center text-xs">
          <span className="font-semibold w-16">{update.participantName}:</span>
          <span className={`font-bold w-8 text-right pr-2 ${update.newScore > 50 ? 'text-green-400' : 'text-red-400'}`}>{update.newScore}</span>
          <span className="text-gray-400 italic">({update.reasonForChange})</span>
        </li>
      ))}
    </ul>
  );

  return (
    <div className="space-y-2 text-sm">
      <div className="p-2 bg-gray-900/50 rounded">
        <p className="text-xs text-gray-400 font-semibold mb-1">Perception</p>
        <p className="text-gray-300 italic">"{diary.perceptionAnalysis}"</p>
      </div>
      <div className="grid grid-cols-2 gap-2">
        <div className="p-2 bg-gray-900/50 rounded">
          <p className="text-xs text-gray-400 font-semibold mb-1">Action</p>
          <p className="font-mono font-bold text-amber-300">{diary.action}</p>
        </div>
        <div className="p-2 bg-gray-900/50 rounded">
          <p className="text-xs text-gray-400 font-semibold mb-1">Response Mode</p>
          <p className="font-semibold text-cyan-300">{diary.selectedResponseMode}</p>
        </div>
      </div>
      <div className="p-2 bg-gray-900/50 rounded">
        <p className="text-xs text-gray-400 font-semibold mb-1">Response Plan</p>
        <p className="text-gray-300">{diary.responsePlan || 'N/A'}</p>
      </div>
      {diary.toolCall && (
        <div className="p-2 bg-gray-900/50 rounded">
            <p className="text-xs text-gray-400 font-semibold mb-1">Tool Call</p>
            <pre className="text-xs text-cyan-200 whitespace-pre-wrap">
                {diary.toolCall.name}({JSON.stringify(diary.toolCall.arguments, null, 2)})
            </pre>
        </div>
      )}
      <div className="p-2 bg-gray-900/50 rounded">
        <p className="text-xs text-gray-400 font-semibold mb-1">Opinion Updates</p>
        {renderOpinionUpdates()}
      </div>
    </div>
  );
};

const ToolCallBubble: React.FC<{ toolCall: ToolCall, minionName: string }> = ({ toolCall, minionName }) => (
  <div className="mt-1 p-2.5 rounded-lg bg-zinc-200 border border-zinc-300 tool-call-bubble">
    <div className="flex items-center gap-2 text-xs text-zinc-600">
      <TerminalIcon className="w-4 h-4 flex-shrink-0" />
      <span className="font-semibold">{minionName}</span>
      <span>is using tool:</span>
      <span className="font-mono font-semibold text-teal-700">{toolCall.name}</span>
    </div>
  </div>
);

const ToolOutputBubble: React.FC<{ toolOutput: string, toolName: string }> = ({ toolOutput, toolName }) => {
  const [isExpanded, setIsExpanded] = useState(false);
  return (
    <div className="mt-1 p-2.5 rounded-lg bg-zinc-200 border border-zinc-300 tool-output-bubble">
      <button onClick={() => setIsExpanded(!isExpanded)} className="w-full flex items-center justify-between text-xs text-zinc-600">
        <div className="flex items-center gap-2">
          <span className="font-semibold">[TOOL OUTPUT]</span>
          <span>Results for</span>
          <span className="font-mono font-semibold text-teal-700">{toolName}</span>
        </div>
        <ChevronDoubleDownIcon className={`w-4 h-4 transition-transform ${isExpanded ? 'rotate-180' : ''}`} />
      </button>
      <AnimatePresence>
        {isExpanded && (
          <motion.div 
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className="overflow-hidden"
          >
            <div className="mt-2 pt-2 border-t border-zinc-300">
              <div className="prose prose-sm max-w-none">
                <ReactMarkdown remarkPlugins={[remarkGfm]}>{toolOutput}</ReactMarkdown>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};


import { ChannelType } from '../types';

interface ChatMessageProps {
  message: ChatMessageData;
  minionConfig?: MinionConfig;
  channelType?: ChannelType;
  onDelete: (channelId: string, messageId: string) => void;
  onEdit: (channelId: string, messageId: string, newContent: string) => void;
  isProcessing?: boolean; 
}

const ChatMessage: React.FC<ChatMessageProps> = ({ message, minionConfig, channelType, onDelete, onEdit, isProcessing }) => {
  const [isEditing, setIsEditing] = useState(false);
  const [editedContent, setEditedContent] = useState(message.content);
  const [showDiary, setShowDiary] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const isUser = message.senderType === MessageSender.User;
  const isMinion = message.senderType === MessageSender.AI;
  const isSystem = message.senderType === MessageSender.System;
  const isTool = message.senderType === MessageSender.Tool;
  const isRegulator = isMinion && message.senderRole === 'regulator';

  const bubbleStyle: React.CSSProperties = {};
  const nameStyle: React.CSSProperties = {};
  const timeStyle: React.CSSProperties = {};

  if (isMinion && !isRegulator && minionConfig?.chatColor) {
    bubbleStyle.backgroundColor = minionConfig.chatColor;
    bubbleStyle.color = minionConfig.fontColor || '#FFFFFF'; 
  }
  if (isMinion && !isRegulator && (minionConfig?.fontColor || minionConfig?.chatColor)) {
    const fontColor = minionConfig.fontColor || '#FFFFFF';
    nameStyle.color = fontColor;
    timeStyle.color = fontColor;
    timeStyle.opacity = 0.8;
  }

  const getBubbleClasses = () => {
    const base = 'px-4 pb-3 pt-2.5 rounded-2xl shadow w-full';
    if (isUser) {
      switch (channelType) {
        case 'dm':
          return `${base} bg-teal-600 text-white rounded-br-none`;
        case 'minion_minion_auto':
        case 'user_minion_group':
        default:
          return `${base} bg-amber-500 text-white rounded-br-none`;
      }
    }
    if (isRegulator) return `${base} bg-teal-50 border border-teal-200 text-neutral-800 rounded-bl-none`;
    if (isMinion && minionConfig?.chatColor) return `${base} rounded-bl-none`;
    return `${base} bg-zinc-100 text-neutral-800 rounded-bl-none border border-zinc-200`;
  };

  const getNameClasses = () => {
    const base = 'text-xs font-semibold';
    if (isUser) return `${base} text-amber-100`;
    if (isRegulator) return `${base} text-teal-700`;
    if (isMinion && !isRegulator && minionConfig?.fontColor) return base;
    return `${base} text-teal-600`;
  };

  const getTimeClasses = () => {
    const base = 'text-xs ml-2';
    if (isUser) return `${base} text-amber-100`;
    if (isMinion && !isRegulator && (minionConfig?.fontColor || minionConfig?.chatColor)) return base;
    return `${base} text-neutral-400`;
  };

  const getContentClasses = () => {
    return 'text-sm whitespace-pre-wrap break-words';
  };

  const handleEdit = () => {
    if (editedContent.trim() !== message.content) {
      onEdit(message.channelId, message.id, editedContent.trim());
    }
    setIsEditing(false);
  };

  const handleCancelEdit = () => {
    setEditedContent(message.content);
    setIsEditing(false);
  };

  useEffect(() => {
    if (isEditing && textareaRef.current) {
      textareaRef.current.focus();
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = `${textareaRef.current.scrollHeight}px`;
    }
  }, [isEditing]);
  
  const handleTextareaChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setEditedContent(e.target.value);
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = `${textareaRef.current.scrollHeight}px`;
    }
  };

  const formatTimestamp = (timestamp: number) => {
    return new Date(timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };
  
  if (isSystem) {
    const style = message.isError 
      ? "px-4 py-2 text-center text-xs text-red-600 bg-red-100" 
      : "px-4 py-2 text-center text-xs text-neutral-500";
      
    return (
      <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className={style}>
        <span className="italic">{message.content}</span>
      </motion.div>
    );
  }

  if (message.senderType === MessageSender.Tool) {
    return (
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0 }}
        className="flex items-end gap-3 p-3"
      >
        <div className="flex-shrink-0">
          <MinionIcon name={message.senderName} />
        </div>
        <div className="w-full max-w-[80%] flex flex-col items-start">
          {message.isToolCall && message.toolCall && (
            <ToolCallBubble toolCall={message.toolCall} minionName={message.senderName} />
          )}
          {message.isToolOutput && message.toolCall && message.toolOutput && (
            <ToolOutputBubble toolOutput={message.toolOutput} toolName={message.toolCall.name} />
          )}
        </div>
      </motion.div>
    );
  }

  const avatar = isUser ? (
    <UserCircleIcon className="w-8 h-8 text-amber-500" title={LEGION_COMMANDER_NAME} />
  ) : (
    <MinionIcon name={message.senderName} />
  );

  const senderNameDisplay = isUser ? LEGION_COMMANDER_NAME : message.senderName;
  
  if (isMinion && isProcessing && message.content.trim() === '') {
    return (
      <motion.div 
        initial={{ opacity: 0, y: 10 }} 
        animate={{ opacity: 1, y: 0 }} 
        exit={{ opacity: 0, y: -10 }} 
        transition={getAnimationConfig('gentle')}
        className="flex items-end gap-3 p-3">
        <div className="flex-shrink-0">{avatar}</div>
        <div className={`w-full max-w-[70%] flex flex-col items-start`}>
            <span className="text-xs text-neutral-500 ml-2 mb-0.5">{message.senderName}</span>
            <div className={`relative px-4 py-2 rounded-xl shadow bg-zinc-100 text-neutral-800 rounded-bl-none border border-zinc-200`}>
                 <TypingIndicator />
            </div>
        </div>
      </motion.div>
    );
  }

  const regulatorReport = isRegulator ? parseJsonFromMarkdown<RegulatorReport>(message.content) : null;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20, scale: 0.95 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, y: -10, scale: 0.95 }}
      transition={getAnimationConfig('gentle')}
      className={`flex items-end gap-3 p-3 ${isUser ? 'justify-end' : ''}`}>
      {!isUser && <div className="flex-shrink-0 self-end">{avatar}</div>}
      
      <div className={`w-full max-w-[80%] flex flex-col ${isUser ? 'items-end' : 'items-start'}`}>
        <div className="relative group/message w-full">
            <AnimatePresence>
              {showDiary && isMinion && !isRegulator && message.internalDiary && (
                <motion.div
                  layout
                  initial={{ opacity: 0, y: 20, height: 0 }}
                  animate={{ opacity: 1, y: 0, height: 'auto', marginBottom: '0.5rem' }}
                  exit={{ opacity: 0, y: 20, height: 0, marginBottom: 0 }}
                  transition={getAnimationConfig('bouncy')}
                  className="w-full origin-bottom"
                >
                  <div className="p-3 bg-gray-800 text-gray-200 border border-gray-700 rounded-md shadow-lg">
                    <h4 className="text-xs font-semibold text-teal-400 mb-2">Internal Diary ({message.senderName})</h4>
                    <DiaryCard diary={message.internalDiary} />
                  </div>
                </motion.div>
              )}
            </AnimatePresence>

          <div 
            className={`absolute top-0 z-10 flex items-center gap-2 transition-opacity duration-150 ${ isUser ? 'flex-row-reverse left-0 -translate-x-full pr-2' : 'flex-row right-0 translate-x-full pl-2'} ${isEditing ? 'opacity-0' : 'opacity-0 group-hover/message:opacity-100'}`}>
              {isUser && (
                <button onClick={() => setIsEditing(true)} className="p-1 text-neutral-400 hover:text-amber-500" title="Edit">
                  <PencilIcon className="w-4 h-4" />
                </button>
              )}
              {isMinion && !isRegulator && message.internalDiary && (
                <button onClick={() => setShowDiary(!showDiary)} className="p-1 text-neutral-400 hover:text-teal-500" title={`Toggle ${message.senderName}'s Diary`}>
                  <BookOpenIcon className="w-4 h-4" />
                </button>
              )}
              <button onClick={() => onDelete(message.channelId, message.id)} className="p-1 text-neutral-400 hover:text-red-500" title="Delete">
                <TrashIcon className="w-4 h-4" />
              </button>
          </div>

          <div style={bubbleStyle} className={getBubbleClasses()}>
            <div className="flex items-center justify-between mb-1">
              <span style={nameStyle} className={getNameClasses()}>
                {senderNameDisplay} {isRegulator && '(Regulator)'}
              </span>
              <span style={timeStyle} className={getTimeClasses()}>{formatTimestamp(message.timestamp)}</span>
            </div>

            {isEditing ? (
              <div className="mt-1">
                <textarea
                  ref={textareaRef}
                  value={editedContent}
                  onChange={handleTextareaChange}
                  className="w-full p-2 text-sm bg-zinc-100 text-neutral-900 border border-zinc-300 rounded-md resize-none focus:ring-2 focus:ring-amber-500 focus:border-amber-500 outline-none"
                  rows={3}
                />
                <div className="flex justify-end gap-2 mt-2">
                  <button onClick={handleCancelEdit} className="px-3 py-1 text-xs bg-neutral-400 hover:bg-neutral-500 text-white rounded-md transition-colors">
                    <XMarkIcon className="w-4 h-4"/>
                  </button>
                  <button onClick={handleEdit} className="px-3 py-1 text-xs bg-amber-500 hover:bg-amber-600 text-white rounded-md transition-colors">
                    <SaveIcon className="w-4 h-4"/>
                  </button>
                </div>
              </div>
            ) : (
              <div className={getContentClasses()}>
                  {isRegulator && regulatorReport ? (
                      <RegulatorReportCard report={regulatorReport} minionName={message.senderName} />
                  ) : (
                    <StreamingText 
                      content={message.content} 
                      isProcessing={!!isProcessing}
                      textColor={isMinion && !isRegulator ? minionConfig?.fontColor : undefined}
                      isMinion={isMinion}
                    />
                  )}
              </div>
            )}
            
            {message.isError && !message.isToolOutput && (
              <div className="mt-2 p-2 bg-red-100 border border-red-300 rounded text-xs text-red-800 flex items-start gap-1">
                <ExclamationTriangleIcon className="w-4 h-4 text-red-500 flex-shrink-0 mt-0.5" />
                <span>{message.content}</span>
              </div>
            )}
          </div>
        </div>
      </div>

      {isUser && <div className="flex-shrink-0 self-end">{avatar}</div>}
    </motion.div>
  );
};

// Custom comparison function to prevent unnecessary re-renders
const areEqual = (prevProps: ChatMessageProps, nextProps: ChatMessageProps) => {
  // Compare message data (most important)
  if (
    prevProps.message.id !== nextProps.message.id ||
    prevProps.message.content !== nextProps.message.content ||
    prevProps.message.timestamp !== nextProps.message.timestamp ||
    prevProps.message.isProcessing !== nextProps.message.isProcessing ||
    prevProps.message.isError !== nextProps.message.isError ||
    prevProps.message.senderName !== nextProps.message.senderName ||
    prevProps.message.senderType !== nextProps.message.senderType
  ) {
    return false;
  }

  // Compare processing state
  if (prevProps.isProcessing !== nextProps.isProcessing) {
    return false;
  }

  // Compare channel type
  if (prevProps.channelType !== nextProps.channelType) {
    return false;
  }

  // Compare minion config (only relevant fields)
  const prevConfig = prevProps.minionConfig;
  const nextConfig = nextProps.minionConfig;
  
  if (prevConfig?.id !== nextConfig?.id ||
      prevConfig?.name !== nextConfig?.name ||
      prevConfig?.chatColor !== nextConfig?.chatColor ||
      prevConfig?.fontColor !== nextConfig?.fontColor) {
    return false;
  }

  // Compare function references (though these should be stable with useCallback)
  if (prevProps.onDelete !== nextProps.onDelete || prevProps.onEdit !== nextProps.onEdit) {
    return false;
  }

  // If we made it here, props are equal enough
  return true;
};

export default React.memo(ChatMessage, areEqual);

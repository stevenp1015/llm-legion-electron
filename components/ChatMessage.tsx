import React, { useState, useEffect, useRef, memo, useMemo } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Streamdown } from 'streamdown';
import { ChatMessageData, MessageSender, RegulatorReport, MinionConfig, ToolCall } from '../types';
import { LEGION_COMMANDER_NAME } from '../constants';
import { TrashIcon, PencilIcon, BookOpenIcon, UserCircleIcon, SaveIcon, XMarkIcon, ExclamationTriangleIcon, TerminalIcon } from './Icons';
import TypingIndicator from './TypingIndicator';
import RegulatorReportCard from './RegulatorReportCard';
import { parseJsonFromMarkdown } from '../services/geminiService';
import MinionIcon from './MinionIcon';
import StreamingText from './StreamingText';
import { getAnimationConfig, ANIMATION_VARIANTS } from '../animations/config';
import { hexToRgb, formatTimestamp } from '../utils/colorUtils';

const DiaryCard: React.FC<{ diary: any }> = memo(({ diary }) => {
  const renderOpinionUpdates = () => (
    <ul className="list-none pl-0 space-y-1">
      {diary.opinionUpdates.map((update: any, index: number) => (
        <li key={index} className="flex items-center text-sm">
          <span className="font-semibold w-16">{update.participantName}:</span>
          <span className={`w-8 text-right pl-2 pr-3 self-end -translate-y-1/2 ${update.newScore > 50 ? 'text-green-400 font-bold' : 'text-red-400 font-black text-2xl'}`}>{update.newScore}</span>
          <span className="text-slate-300/80 italic">({update.reasonForChange})</span>
        </li>
      ))}
    </ul>
  );

  return (
    <div className="space-y-2 p-2 shadow-ok rounded-xl text-sm">
      <div className="p-2 shadow-ok-inner bg-gradient-to-br from-zinc-800/80 to-zinc-900/80 rounded-xl">
        <p className="text-sm text-zinc-300 font-semibold mb-1">Perception</p>
        <p className="text-gray-300 italic">"{diary.perceptionAnalysis}"</p>
      </div>
      <div className="grid grid-cols-2 gap-2">
        <div className="p-2 shadow-ok-inner bg-gradient-to-br from-zinc-800/80 to-zinc-900/80 border-zinc-600 border rounded-xl">
          <p className="text-sm text-zinc-300 font-semibold mb-1">Action</p>
          <p className="font-mono font-bold text-amber-300">{diary.action}</p>
        </div>
        <div className="p-2 shadow-ok-inner bg-gradient-to-br from-zinc-800/80 to-zinc-900/80 border-zinc-600 border rounded-xl">
          <p className="text-sm text-zinc-300 font-semibold mb-1">Response Mode</p>
          <p className="font-semibold text-cyan-300">{diary.selectedResponseMode}</p>
        </div>
      </div>
      <div className="p-2 shadow-ok-inner bg-gradient-to-br from-zinc-800/80 to-zinc-900/80 border-zinc-600 border rounded-xl">
        <p className="text-sm text-zinc-300 font-semibold mb-1">Response Plan</p>
        <p className="text-gray-300">{diary.responsePlan || 'N/A'}</p>
      </div>
      {diary.toolCall && (
        <div className="p-2 shadow-ok-inner bg-gradient-to-br from-zinc-800/80 to-zinc-900/80 rounded-xl border-zinc-600 border">
            <p className="text-sm text-zinc-300 font-semibold mb-1">Tool Call</p>
            <pre className="text-sm text-cyan-200 whitespace-pre-wrap">
                {diary.toolCall.name}({JSON.stringify(diary.toolCall.arguments, null, 2)})
            </pre>
        </div>
      )}
      {diary.opinionUpdates.map((update: any, index: number) => (
        <div className={`p-2 bg-gradient-to-br from-zinc-800/80 to-zinc-900/80 rounded-xl border ${update.newScore > 50 ? 'shadow-ok-inner-green border-emerald-800/80' : 'shadow-ok-inner-red border-red-800/80'}`}>
          <p className="text-sm text-zinc-300 font-semibold mb-1">Opinion Updates</p>
          {renderOpinionUpdates()}
        </div>
      ))}
    </div>
  );
});

DiaryCard.displayName = 'DiaryCard';

const ToolCallBubble: React.FC<{ toolCall: ToolCall, minionName: string, minionConfig?: MinionConfig }> = memo(({ toolCall, minionName, minionConfig }) => {
  const [isExpanded, setIsExpanded] = useState(false);
  const [isShimmering, setIsShimmering] = useState(false);
  
  const handleClick = () => {
    setIsExpanded(!isExpanded);
    setIsShimmering(true);
    setTimeout(() => setIsShimmering(false), 300);
  };
  
  // Memoize RGB calculations to prevent recalculation on every render
  const { rgb, lightBgColor } = useMemo(() => {
    const minionColor = minionConfig?.chatColor || '#3B82F6';
    const rgbResult = hexToRgb(minionColor) || { r: 59, g: 130, b: 246 };
    return {
      rgb: rgbResult,
      lightBgColor: `rgba(${rgbResult.r}, ${rgbResult.g}, ${rgbResult.b}, 0.02)`
    };
  }, [minionConfig?.chatColor]);
  
  return (
    <div className="mt-1 max-w-full">
      <motion.button 
        onClick={handleClick}
        className="w-full p-2.5 rounded-lg border border-opacity-30 tool-call-bubble relative overflow-hidden cursor-pointer group transition-all duration-300"
        style={{ 
          backgroundColor: lightBgColor,
          borderColor: `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.3)`
        }}
        layout={false}
      >
        <div className="flex items-center gap-2 text-sm text-zinc-600 relative z-10">
          <TerminalIcon className="w-4 h-4 flex-shrink-0" />
          <span className="font-semibold">{minionName}</span>
          <span>is using tool:</span>
          <span className="font-mono font-semibold text-teal-700">{toolCall.name}</span>
        </div>
        
        {/* Dynamic feathered glow effect at bottom */}
        <div 
          className="absolute bottom-0 left-0 right-0 h-6 rounded-b-lg opacity-50 group-hover:opacity-80 transition-opacity duration-300"
          style={{
            background: `linear-gradient(to top, rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.4), rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.2), transparent)`
          }}
        />
        <div 
          className="absolute bottom-0 left-0 right-0 h-4 rounded-b-lg opacity-20 group-hover:opacity-60 transition-opacity duration-300"
          style={{
            background: `linear-gradient(to top, rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.6), rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.3), transparent)`
          }}
        />
        
        {/* Sliding shimmer effect */}
        {isShimmering && (
          <motion.div
            className="absolute inset-0 rounded-lg"
            style={{
              background: `linear-gradient(90deg, transparent, rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.4), transparent)`
            }}
            initial={{ x: '-100%' }}
            animate={{ x: '100%' }}
            transition={{ duration: 0.1, ease: 'linear' }}
          />
        )}
      </motion.button>
      
      <AnimatePresence>
        {isExpanded && (
          <motion.div 
            initial={{ scaleY: 0, opacity: 0 }}
            animate={{ scaleY: 1, opacity: 1 }}
            exit={{ scaleY: 0, opacity: 0 }}
            transition={{ duration: 0.1, ease: 'linear' }}
            className="mt-2 origin-top"
            style={{ width: '100%', transformOrigin: 'top' }}
          >
            <div className="p-3 bg-zinc-100 border border-zinc-300 rounded-lg text-sm">
              <div className="font-semibold text-sm text-teal-700 mb-2">Tool Parameters:</div>
              <pre className="text-zinc-700 whitespace-pre-wrap font-mono text-sm break-all">
                {JSON.stringify(toolCall.arguments, null, 2)}
              </pre>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
});

ToolCallBubble.displayName = 'ToolCallBubble';

const ToolOutputBubble: React.FC<{ toolOutput: string, toolName: string, minionConfig?: MinionConfig }> = memo(({ toolOutput, toolName, minionConfig }) => {
  const [isExpanded, setIsExpanded] = useState(false);
  const [isShimmering, setIsShimmering] = useState(false);
  
  const handleClick = () => {
    setIsExpanded(!isExpanded);
    setIsShimmering(true);
    setTimeout(() => setIsShimmering(false), 300);
  };
  
  // Memoize RGB calculations to prevent recalculation on every render
  const { darkerRgb } = useMemo(() => {
    const minionColor = minionConfig?.chatColor || '#10B981';
    const rgbResult = hexToRgb(minionColor) || { r: 16, g: 185, b: 129 };
    // Make it darker by reducing RGB values by 10%
    return {
      darkerRgb: {
        r: Math.round(rgbResult.r * 0.9),
        g: Math.round(rgbResult.g * 0.9),
        b: Math.round(rgbResult.b * 0.9)
      }
    };
  }, [minionConfig?.chatColor]);
  
  return (
    <div className="mt-1 relative">
      <button 
        onClick={handleClick} 
        className="w-full p-2.5 rounded-lg tool-output-bubble relative overflow-hidden cursor-pointer group"
      >
        <div className="flex items-center gap-2 text-sm text-zinc-600">
          <span className="font-semibold">[TOOL OUTPUT]</span>
          <span>Results for</span>
          <span className="font-mono font-semibold text-teal-700">{toolName}</span>
        </div>
        
        {/* Dynamic feathered glow effect at bottom - darker for "completion" feel */}
        <div 
          className="absolute bottom-0 left-0 right-0 h-6 rounded-t-lg opacity-50 group-hover:opacity-80 transition-opacity duration-300"
          style={{
            background: `linear-gradient(to top, rgba(${darkerRgb.r}, ${darkerRgb.g}, ${darkerRgb.b}, 0.5), rgba(${darkerRgb.r}, ${darkerRgb.g}, ${darkerRgb.b}, 0.25), transparent)`
          }}
        />
        <div 
          className="absolute bottom-0 left-0 right-0 h-4 rounded-t-lg opacity-20 group-hover:opacity-60 transition-opacity duration-300"
          style={{
            background: `linear-gradient(to top, rgba(${darkerRgb.r}, ${darkerRgb.g}, ${darkerRgb.b}, 0.7), rgba(${darkerRgb.r}, ${darkerRgb.g}, ${darkerRgb.b}, 0.4), transparent)`
          }}
        />
        
        {/* Sliding shimmer effect */}
        {isShimmering && (
          <motion.div
            className="absolute inset-0 rounded-lg"
            style={{
              background: `linear-gradient(90deg, transparent, rgba(${darkerRgb.r}, ${darkerRgb.g}, ${darkerRgb.b}, 0.5), transparent)`
            }}
            initial={{ x: '-100%' }}
            animate={{ x: '100%' }}
            transition={{ duration: 0.1, ease: 'linear' }}
          />
        )}
      </button>
      
      <AnimatePresence>
        {isExpanded && (
          <motion.div 
            initial={{ scaleY: 0, opacity: 0 }}
            animate={{ scaleY: 1, opacity: 1 }}
            exit={{ scaleY: 0, opacity: 0 }}
            transition={{ duration: 0.1, ease: 'linear' }}
            className="mt-2 origin-top"
            style={{ width: '100%', transformOrigin: 'top' }}
          >
            <div className="p-3 bg-zinc-100 border border-zinc-300 rounded-lg">
              <div className="prose prose-sm max-w-none break-words">
                <Streamdown>{toolOutput}</Streamdown>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
});

ToolOutputBubble.displayName = 'ToolOutputBubble';


import { ChannelType } from '../types';

interface ChatMessageProps {
  message: ChatMessageData;
  minionConfig?: MinionConfig;
  channelType?: ChannelType;
  onDelete: (channelId: string, messageId: string) => void;
  onEdit: (channelId: string, messageId: string, newContent: string) => void;
  isProcessing?: boolean;
  
  // Selection mode props
  isSelectionMode?: boolean;
  isSelected?: boolean;
  onToggleSelection?: (messageId: string, shiftKey: boolean) => void;
  onEnterSelectionMode?: () => void;
  isBulkDiaryVisible?: boolean;
}

const ChatMessage: React.FC<ChatMessageProps> = ({ 
  message, 
  minionConfig, 
  channelType, 
  onDelete, 
  onEdit, 
  isProcessing,
  isSelectionMode = false,
  isSelected = false,
  onToggleSelection,
  onEnterSelectionMode,
  isBulkDiaryVisible = false
}) => {
  const [isEditing, setIsEditing] = useState(false);
  const [editedContent, setEditedContent] = useState(message.content);
  const [showDiary, setShowDiary] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const isUser = message.senderType === MessageSender.User;
  const isMinion = message.senderType === MessageSender.AI;
  const isSystem = message.senderType === MessageSender.System;
  const isTool = message.senderType === MessageSender.Tool;
  const isRegulator = isMinion && message.senderRole === 'regulator';

  // Memoize regulator report parsing to prevent re-parsing on every render
  // MUST be called before any conditional returns to satisfy Rules of Hooks
  const regulatorReport = useMemo(() => 
    isRegulator ? parseJsonFromMarkdown<RegulatorReport>(message.content) : null,
    [isRegulator, message.content]
  );

  // Use bulk diary state when in selection mode, individual state otherwise
  const isDiaryVisible = isSelectionMode ? isBulkDiaryVisible : showDiary;

  // Handle right-click on minion chat bubbles for diary toggle
  const handleContextMenu = (e: React.MouseEvent) => {
    if (isMinion && !isRegulator && message.internalDiary && !isSelectionMode) {
      e.preventDefault();
      setShowDiary(!showDiary);
    }
  };

  // Handle avatar click to enter selection mode
  const handleAvatarClick = () => {
    if (!isSelectionMode && onEnterSelectionMode) {
      onEnterSelectionMode();
    }
  };

  // Handle bubble click in selection mode
  const handleBubbleClick = (e: React.MouseEvent) => {
    if (isSelectionMode && onToggleSelection) {
      onToggleSelection(message.id, e.shiftKey);
    }
  };

  // Handle double-click to edit user messages
  const handleDoubleClick = () => {
    if (isUser && !isSelectionMode) {
      setIsEditing(true);
    }
  };

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
    const base = 'px-4 pb-3 pt-2.5 rounded-2xl shadow-ok w-full';
    if (isUser) {
      switch (channelType) {
        case 'dm':
          return `${base} bg-teal-600 text-white rounded-br-none`;
        case 'minion_minion_auto':
        case 'user_minion_group':
        default:
          return `${base} bg-gradient-to-br from-amber-400 to-amber-600 text-white rounded-br-none`;
      }
    }
    if (isRegulator) return `${base} bg-teal-50 border border-teal-200 text-neutral-800 rounded-bl-none`;
    if (isMinion && minionConfig?.chatColor) return `${base} rounded-bl-none left-light top-light`;
    return `${base} bg-zinc-100 text-neutral-800 rounded-bl-none border border-zinc-200`;
  };

  const getNameClasses = () => {
    const base = 'text-sm font-semibold';
    if (isUser) return `${base} text-amber-100`;
    if (isRegulator) return `${base} text-teal-700`;
    if (isMinion && !isRegulator && minionConfig?.fontColor) return base;
    return `${base} text-teal-600`;
  };

  const getTimeClasses = () => {
    const base = 'text-sm ml-2';
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


  if (isSystem) {
    const style = message.isError 
      ? "px-4 py-2 text-center text-sm text-red-600 bg-red-100 rounded-md" 
      : "px-4 py-2 text-center text-sm text-neutral-500 bg-neutral-100/50 rounded-md";
      
    return (
      <motion.div 
        initial={{ opacity: 0, scale: 0.9, y: 10 }} 
        animate={{ opacity: 1, scale: 1, y: 0 }} 
        exit={{ opacity: 0, scale: 0.9, y: -5 }}
        transition={getAnimationConfig('gentle')}
        className={style}
      >
        <motion.span 
          className="italic"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.1 }}
        >
          {message.content}
        </motion.span>
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
            <ToolCallBubble toolCall={message.toolCall} minionName={message.senderName} minionConfig={minionConfig} />
          )}
          {message.isToolOutput && message.toolCall && message.toolOutput && (
            <ToolOutputBubble toolOutput={message.toolOutput} toolName={message.toolCall.name} minionConfig={minionConfig} />
          )}
        </div>
      </motion.div>
    );
  }

  const avatar = isUser ? (
    <motion.button
      onClick={handleAvatarClick}
      className="w-8 h-8 text-amber-500 relative after:content-[''] after:absolute after:top-0 after:left-0 after:w-full after:h-full after:bg-radial-[50%_50%] after:from-amber-400/30 after:to-amber-200/30 after:rounded-full after:z-10"
      title={LEGION_COMMANDER_NAME}
      disabled={isSelectionMode}
      whileHover={!isSelectionMode ? { scale: 1.1 } : undefined}
      whileTap={!isSelectionMode ? { scale: 0.95 } : undefined}
    >
      <UserCircleIcon className="w-full h-full" />
      {/* Selection circle for user messages */}
      {isSelectionMode && (
        <motion.div
          className={`absolute -right-3 top-1/2 w-4 h-4 rounded-full border-2 transition-colors ${
            isSelected 
              ? 'bg-amber-500 border-amber-600' 
              : 'bg-transparent border-amber-400'
          }`}
          initial={{ scale: 1, opacity: 0, y: '-50%', x: '100%' }}
          animate={{ scale: 1, opacity: 1, y: '-50%', x: '100%' }}
        />
      )}
    </motion.button>
  ) : (
    <motion.button
      onClick={handleAvatarClick}
      className="w-8 h-8 relative"
      title={message.senderName}
      disabled={isSelectionMode}
      whileHover={!isSelectionMode ? { scale: 1.1 } : undefined}
      whileTap={!isSelectionMode ? { scale: 0.9 } : undefined}
    >
      <MinionIcon name={message.senderName} />
      {/* Selection circle for minion messages */}
      {isSelectionMode && (
        <motion.div
          className={`absolute -left-3 top-1/2 w-4 h-4 rounded-full border-2 ${
            isSelected 
              ? 'bg-teal-500 border-teal-600'
              : 'bg-transparent border-teal-400'
          }`}
          initial={{ scale: 1, opacity: 0, y: '-50%', x: '-100%' }}
          animate={{ scale: 1, opacity: 1, y: '-50%', x: '-100%' }}
        />
      )}
    </motion.button>
  );

  const senderNameDisplay = isUser ? LEGION_COMMANDER_NAME : message.senderName;
  
  if (isMinion && isProcessing && message.content.trim() === '') {
    return (
      <motion.div 
        variants={ANIMATION_VARIANTS.messageEntry}
        initial="hidden"
        animate="visible" 
        exit="exit"
        layout={false}
        className="flex items-end gap-3 p-3">
        <motion.div 
          className="flex-shrink-0"
          initial={{ scale: 0.8, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ delay: 0.1, ...getAnimationConfig('bouncy') }}
          >
          {avatar}
        </motion.div>
        <div className={`w-full max-w-[70%] flex flex-col items-start`}>
            <motion.span 
              className="text-sm text-neutral-500 ml-2 mb-0.5"
              initial={{ opacity: 0, y: 5 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2, ...getAnimationConfig('gentle') }}
            >
              {message.senderName}
            </motion.span>
            <motion.div 
              className={`relative px-4 py-2 rounded-xl shadow bg-zinc-100 text-neutral-800 rounded-bl-none border border-zinc-200 overflow-hidden`}
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ 
                scale: 1, 
                opacity: 1,

              }}
              transition={{ 
                delay: 0.3, 
                ...getAnimationConfig('slide'),

              }}
            >
              {/* Subtle shimmer effect while typing */}
              <motion.div
                className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent"
                initial={{ x: '-100%' }}
                animate={{ x: '100%' }}
                transition={{ duration: 2, repeat: Infinity, ease: 'linear' }}
              />
              <TypingIndicator />
            </motion.div>
        </div>
      </motion.div>
    );
  }

  return (
    <motion.div
      variants={ANIMATION_VARIANTS.messageEntry}
      initial="hidden"
      animate={{
        ...ANIMATION_VARIANTS.messageEntry.visible,
        // Selection mode slide animations
        x: isSelectionMode ? (isUser ? -20 : 20) : 0
      }}
      exit="exit"
      layout={false}
      transition={getAnimationConfig('elastic')}
      className={`flex items-end gap-3 p-3 ${isUser ? 'justify-end' : ''}`}>
      {!isUser && (
        <motion.div 
          className="flex-shrink-0 self-end"
          initial={{ scale: 0.8, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ delay: 0.1, ...getAnimationConfig('bouncy') }}
        >
          {avatar}
        </motion.div>
      )}
      
      <div className={`w-full max-w-[80%] flex flex-col ${isUser ? 'items-end' : 'items-start'}`}>
        <div className="relative group/message w-full origin-bottom">
            <AnimatePresence>
              {isMinion && !isRegulator && message.internalDiary && 
                isDiaryVisible ? (
                <motion.div
                  layout={false}
                  initial={{ opacity: 0, y: 0, scaleY: 0 }}
                  animate={{ opacity: 1, y: 15, scaleY: 1 }}
                  exit={{ opacity: 0, y: 0, scaleY: 0 }}
                  transition={getAnimationConfig('slide')}
                  className="w-full origin-bottom"
                  >
                  <div className="px-3 w-[98%] translate-x-[1%] py-4 bg-gradient-to-br from-zinc-600 from-[-10%] via-zinc-700 to-zinc-800 text-gray-200 border-2 border-zinc-400 rounded-b-none rounded-t-3xl origin-bottom shadow-ok"
                        onContextMenu={handleContextMenu}>
                    <h4 className="text-sm font-bold pl-3 tracking-widest -translate-y-1.5 text-teal-400">
                      Internal Diary ({message.senderName})
                    </h4>
                    <DiaryCard diary={message.internalDiary} />
                  </div>
                </motion.div>
              ) : null}
            </AnimatePresence>

          {/* Selection mode: no hover buttons, use right-click and selection actions */}

          <motion.div 
            style={bubbleStyle} 
            className={`${getBubbleClasses()} ${isSelected ? 'ring-2 ring-amber-400 ring-offset-2' : ''} ${isSelectionMode ? 'cursor-pointer' : ''}`}
            onContextMenu={handleContextMenu}
            onClick={handleBubbleClick}
            onDoubleClick={handleDoubleClick}
            whileHover={isSelectionMode ? { scale: 1.02 } : undefined}
            transition={getAnimationConfig('gentle')}
          >
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
                <motion.div 
                  className="flex justify-end gap-2 mt-2"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.1, ...getAnimationConfig('gentle') }}
                >
                  <motion.button 
                    onClick={handleCancelEdit} 
                    className="px-3 py-1 text-sm bg-neutral-400 text-white rounded-md"
                    variants={ANIMATION_VARIANTS.button}
                    initial="idle"
                    whileTap="tap"
                    whileHover={{
                      backgroundColor: 'rgb(115, 115, 115)',
                      ...ANIMATION_VARIANTS.button.hover
                    }}
                  >
                    <motion.div
                      animate={{ rotate: 0 }}
                      whileHover={{ rotate: 90 }}
                      transition={{ duration: 0.2 }}
                    >
                      <XMarkIcon className="w-4 h-4"/>
                    </motion.div>
                  </motion.button>
                  <motion.button 
                    onClick={handleEdit} 
                    className="px-3 py-1 text-sm bg-amber-500 text-white rounded-md"
                    variants={ANIMATION_VARIANTS.button}
                    initial="idle"
                    whileTap="tap"
                    whileHover={{
                      backgroundColor: 'rgb(217, 119, 6)',
                      ...ANIMATION_VARIANTS.button.hover
                    }}
                  >
                    <motion.div
                      animate={{ scale: 1 }}
                      whileHover={{ scale: [1, 0.9, 1.1, 1] }}
                      transition={{ duration: 0.3 }}
                    >
                      <SaveIcon className="w-4 h-4"/>
                    </motion.div>
                  </motion.button>
                </motion.div>
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
              <div className="mt-2 p-2 bg-red-100 border border-red-300 rounded text-sm text-red-800 flex items-start gap-1">
                <ExclamationTriangleIcon className="w-4 h-4 text-red-500 flex-shrink-0 mt-0.5" />
                <span>{message.content}</span>
              </div>
            )}
          </motion.div>
        </div>
      </div>

      {isUser && (
        <motion.div 
          className="flex-shrink-0 self-end"
          initial={{ scale: 0.8, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ delay: 0.1, ...getAnimationConfig('bouncy') }}
        >
          {avatar}
        </motion.div>
      )}
    </motion.div>
  );
};

// Custom comparison function to prevent unnecessary re-renders
const areEqual = (prevProps: ChatMessageProps, nextProps: ChatMessageProps) => {
  const prev = prevProps.message;
  const next = nextProps.message;
  
  // Fast path: if it's the same message object and no selection state changed
  if (prev === next && 
      prevProps.isProcessing === nextProps.isProcessing &&
      prevProps.isSelectionMode === nextProps.isSelectionMode &&
      prevProps.isSelected === nextProps.isSelected &&
      prevProps.isBulkDiaryVisible === nextProps.isBulkDiaryVisible) {
    return true;
  }
  
  // Critical fields that affect rendering
  if (
    prev.id !== next.id ||
    prev.content !== next.content ||
    prev.senderName !== next.senderName ||
    prev.senderType !== next.senderType ||
    prev.isError !== next.isError ||
    prevProps.isProcessing !== nextProps.isProcessing ||
    prevProps.isSelectionMode !== nextProps.isSelectionMode ||
    prevProps.isSelected !== nextProps.isSelected ||
    prevProps.isBulkDiaryVisible !== nextProps.isBulkDiaryVisible
  ) {
    return false;
  }
  
  // Only check minion config if it's a minion message
  if (next.senderType === MessageSender.AI) {
    const prevConfig = prevProps.minionConfig;
    const nextConfig = nextProps.minionConfig;
    
    if (prevConfig?.chatColor !== nextConfig?.chatColor ||
        prevConfig?.fontColor !== nextConfig?.fontColor) {
      return false;
    }
  }
  
  return true;
};

export default React.memo(ChatMessage, areEqual);
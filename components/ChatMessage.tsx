import React, { useState, useEffect, useRef } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { ChatMessageData, MessageSender, RegulatorReport, MinionDiaryState, PerceptionPlan } from '../types';
import { LEGION_COMMANDER_NAME } from '../constants';
import { TrashIcon, PencilIcon, BookOpenIcon, UserCircleIcon, SaveIcon, XMarkIcon, ExclamationTriangleIcon, TerminalIcon } from './Icons';
import TypingIndicator from './TypingIndicator';
import RegulatorReportCard from './RegulatorReportCard';
import { parseJsonFromMarkdown } from '../services/geminiService';
import MinionIcon from './MinionIcon';

const DiaryCard: React.FC<{ diary: PerceptionPlan }> = ({ diary }) => {
  const renderOpinionUpdates = () => (
    <ul className="list-none pl-0 space-y-1">
      {diary.opinionUpdates.map((update, index) => (
        <li key={index} className="flex items-center text-xs">
          <span className="font-semibold w-16 truncate">{update.participantName}:</span>
          <span className={`font-bold w-8 text-right pr-2 ${update.newScore > 50 ? 'text-green-400' : 'text-red-400'}`}>{update.newScore}</span>
          <span className="text-gray-400 italic truncate">({update.reasonForChange})</span>
        </li>
      ))}
    </ul>
  );

  return (
    <div className="space-y-3 text-sm">
      <div className="p-2 bg-gray-900/50 rounded">
        <p className="text-xs text-gray-400 font-semibold mb-1">Perception</p>
        <p className="text-gray-300 italic">"{diary.perceptionAnalysis}"</p>
      </div>
      <div className="grid grid-cols-2 gap-3">
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

interface ChatMessageProps {
  message: ChatMessageData;
  onDelete: (channelId: string, messageId: string) => void;
  onEdit: (channelId: string, messageId: string, newContent: string) => void;
  isProcessing?: boolean; 
}

const ChatMessage: React.FC<ChatMessageProps> = ({ message, onDelete, onEdit, isProcessing }) => {
  const [isEditing, setIsEditing] = useState(false);
  const [editedContent, setEditedContent] = useState(message.content);
  const [showDiary, setShowDiary] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const isUser = message.senderType === MessageSender.User;
  const isMinion = message.senderType === MessageSender.AI;
  const isSystem = message.senderType === MessageSender.System;
  const isTool = message.senderType === MessageSender.Tool;
  const isRegulator = isMinion && message.senderRole === 'regulator';

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
      <div className={style}>
        <span className="italic">{message.content}</span>
      </div>
    );
  }

  if (isTool) {
    return (
        <div className="px-4 py-1 text-xs text-neutral-500 font-mono-tool flex items-center gap-2">
            <TerminalIcon className="w-4 h-4 text-teal-500 flex-shrink-0" />
            <span className="italic whitespace-pre-wrap">{message.content}</span>
        </div>
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
      <div className="flex items-end gap-3 p-3">
        <div className="flex-shrink-0">{avatar}</div>
        <div className={`w-full max-w-[80%] flex flex-col items-start`}>
            <span className="text-xs text-neutral-500 ml-2 mb-0.5">{message.senderName}</span>
            <div className={`relative px-4 py-2 rounded-xl shadow bg-zinc-100 text-neutral-800 rounded-bl-none border border-zinc-200`}>
                 <TypingIndicator />
            </div>
        </div>
      </div>
    );
  }

  const regulatorReport = isRegulator ? parseJsonFromMarkdown<RegulatorReport>(message.content) : null;

  return (
    <div className={`flex items-end gap-3 p-3 ${isUser ? 'justify-end' : ''}`}>
      {!isUser && <div className="flex-shrink-0 self-end">{avatar}</div>}
      
      <div className={`w-full max-w-[80%] flex flex-col ${isUser ? 'items-end' : 'items-start'}`}>
        <div className="relative group/message">
          <div 
            className={`flex items-center gap-2 transition-opacity duration-150 ${ isUser ? 'flex-row-reverse -mr-8' : 'flex-row -ml-8'} ${isEditing ? 'opacity-0' : 'opacity-0 group-hover/message:opacity-100'}`}
          >
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

          <div 
            className={`px-4 py-2 rounded-xl shadow w-full ${
            isUser ? 'bg-amber-500 text-zinc-50 rounded-br-none' : isRegulator ? 'bg-teal-50 border border-teal-200 text-neutral-800 rounded-bl-none' : 'bg-zinc-100 text-neutral-800 rounded-bl-none border border-zinc-200'
          }`}>
            <div className="flex items-center justify-between mb-1">
              <span className={`text-xs font-semibold ${isUser ? 'text-amber-100' : isRegulator ? 'text-teal-700' : 'text-teal-600'}`}>
                {senderNameDisplay} {isRegulator && '(Regulator)'}
              </span>
              <span className={`text-xs ml-2 ${isUser ? 'text-amber-100' : 'text-neutral-400'}`}>{formatTimestamp(message.timestamp)}</span>
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
              <div className={`text-sm whitespace-pre-wrap break-words prose ${isProcessing ? 'streaming-text' : ''}`}>
                  {isRegulator && regulatorReport ? (
                      <RegulatorReportCard report={regulatorReport} minionName={message.senderName} />
                  ) : (
                      <>
                        <ReactMarkdown remarkPlugins={[remarkGfm]}>{message.content}</ReactMarkdown>
                        {isProcessing && message.content && <span className="typing-caret" />}
                      </>
                  )}
              </div>
            )}
            
            {message.isError && (
              <div className="mt-2 p-2 bg-red-100 border border-red-300 rounded text-xs text-red-800 flex items-start gap-1">
                <ExclamationTriangleIcon className="w-4 h-4 text-red-500 flex-shrink-0 mt-0.5" />
                <span>{message.content}</span>
              </div>
            )}
          </div>
        </div>
        
        {isMinion && !isRegulator && message.internalDiary && (
          <div className={`w-full transition-all duration-500 ease-in-out overflow-hidden ${showDiary ? 'max-h-[500px] mt-2' : 'max-h-0'}`}>
            <div className="p-3 bg-gray-800 text-gray-200 border border-gray-700 rounded-md shadow-lg">
                <h4 className="text-xs font-semibold text-teal-400 mb-2">Internal Diary ({message.senderName})</h4>
                <DiaryCard diary={message.internalDiary as PerceptionPlan} />
            </div>
          </div>
        )}
      </div>

      {isUser && <div className="flex-shrink-0 self-end">{avatar}</div>}
    </div>
  );
};

export default ChatMessage;

import React, { useState, useRef, useEffect } from 'react';
import { PaperAirplaneIcon } from './Icons';

interface ChatInputProps {
  onSendMessage: (content: string) => void;
  isSending: boolean;
  disabled?: boolean;
}

const ChatInput: React.FC<ChatInputProps> = ({ onSendMessage, isSending, disabled = false }) => {
  const [inputValue, setInputValue] = useState('');
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const handleSubmit = () => {
    if (inputValue.trim() && !isSending && !disabled) {
      onSendMessage(inputValue.trim());
      setInputValue('');
      if (textareaRef.current) {
        textareaRef.current.style.height = 'auto'; // Reset height
        textareaRef.current.focus();
      }
    }
  };

  const handleKeyDown = (event: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      handleSubmit();
    }
  };

  const handleTextareaInput = (event: React.FormEvent<HTMLTextAreaElement>) => {
    setInputValue(event.currentTarget.value);
    if (textareaRef.current) {
      textareaRef.current.style.height = '25px';
      textareaRef.current.style.height = `${event.currentTarget.scrollHeight}px`;
    }
  };
  
  useEffect(() => {
    if (textareaRef.current) {
        // Adjust initial height if needed, or keep it minimal
        textareaRef.current.style.height = '25px'; // Approx 1 line height + padding
    }
  }, []);


  return (
    <div className={`p-4 bg-zinc-100/80 backdrop-blur-sm border-t border-zinc-200 ${disabled ? 'opacity-50' : ''}`}>
      <div className="flex items-end gap-2 bg-zinc-50 rounded-lg p-1 shadow-sm">
        <textarea
          ref={textareaRef}
          value={inputValue}
          onChange={handleTextareaInput}
          onKeyDown={handleKeyDown}
          placeholder={disabled ? "Pause autonomous mode to send a message..." : "Type something..."}
          className="flex-grow p-1.5 bg-transparent text-neutral-800 placeholder-neutral-500 border-none rounded-lg resize-none focus:ring-0 outline-none max-h-25 overflow-y-auto scrollbar-thin scrollbar-thumb-neutral-400/0 scrollbar-track-zinc-200/0"
          rows={1}
          disabled={isSending || disabled}
        />
        <button
          onClick={handleSubmit}
          disabled={isSending || !inputValue.trim() || disabled}
          className="p-2.5 bg-amber-500 text-white rounded-lg hover:bg-amber-600 disabled:bg-neutral-400 disabled:cursor-not-allowed transition-colors focus:outline-none focus:ring-2 focus:ring-amber-500"
          aria-label="Send message"
        >
          {isSending ? (
            <svg className="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          ) : (
            <PaperAirplaneIcon className="w-5 h-5" />
          )}
        </button>
      </div>
    </div>
  );
};

export default ChatInput;

import React, { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { PaperAirplaneIcon } from './Icons';
import { getAnimationConfig, ANIMATION_VARIANTS } from '../animations/config';

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
      // Maintain height stability during submit
      requestAnimationFrame(() => {
        if (textareaRef.current) {
          textareaRef.current.style.height = '36px'; // Fixed reset height
          textareaRef.current.focus();
        }
      });
    }
  };

  const handleKeyDown = (event: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      handleSubmit();
    }
  };

  const handleTextareaInput = () => {
    if (!textareaRef.current) return;

    const target = textareaRef.current;
    setInputValue(target.value);

    // Reset height to shrink if text is deleted
    target.style.height = '36px';

    // Calculate the new height
    const minHeight = 36;
    const maxHeight = 300; // Limit max height
    const scrollHeight = target.scrollHeight;
    const newHeight = Math.min(Math.max(scrollHeight, minHeight), maxHeight);

    target.style.height = `${newHeight}px`;
  };

  useEffect(() => {
    if (textareaRef.current) {
        // Adjust initial height if needed, or keep it minimal
        textareaRef.current.style.height = '36px'; // Approx 1 line height + padding
    }
  }, []);


  return (
    <div className={`px-3 py-3 bg-zinc-100/45 border-t border-zinc-200 ${disabled ? 'opacity-50' : ''}`}>
      <div className="flex items-center gap-3 bg-zinc-50/30 border border-zinc-100 rounded-md p-0.5">
        <textarea
          ref={textareaRef}
          value={inputValue}
          onInput={handleTextareaInput}
          onKeyDown={handleKeyDown}
          placeholder={disabled ? "Pause autonomous mode to send a message..." : "Type something..."}
          className="chat-input-textarea 
          flex-grow
          p-1.5
          bg-zinc-50 
          text-black 
          text-sm 
          placeholder-neutral-500 
          border-0
          resize-none
          rounded-sm
          focus:ring-0
          outline-none 
          max-h-36
          overflow-y-auto
          scrollbar-thin 
          scrollbar-thumb-neutral-400/0 
          scrollbar-track-zinc-200/0"
          rows={1}
          disabled={disabled}
        />
        <motion.button
          onClick={handleSubmit}
          disabled={isSending || !inputValue.trim() || disabled}
          className="p-2.5 bg-amber-500 text-white rounded-lg focus:outline-none relative overflow-hidden"
          aria-label="Send message"
          variants={ANIMATION_VARIANTS.button}
          initial="idle"
          whileTap={!(isSending || !inputValue.trim() || disabled) ? "tap" : undefined}
          animate={{
            backgroundColor: disabled 
              ? 'rgba(245, 158, 11, 0.3)' 
              : isSending 
                ? 'rgb(217, 119, 6)' 
                : 'rgb(245, 158, 11)',
            boxShadow: disabled 
              ? 'none'
              : isSending
                ? '0 0 0 2px rgba(245, 158, 11, 0.3), 0 0 20px rgba(245, 158, 11, 0.2)'
                : '0 2px 4px rgba(0,0,0,0.1)'
          }}
          whileHover={{
            backgroundColor: disabled ? undefined : 'rgb(217, 119, 6)',
            boxShadow: disabled ? undefined : '0 4px 12px rgba(245, 158, 11, 0.3)',
            ...ANIMATION_VARIANTS.button.hover
          }}
          transition={getAnimationConfig('haptic')}
        >
          {/* Loading shimmer effect */}
          {isSending && (
            <motion.div
              className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent"
              initial={{ x: '-100%' }}
              animate={{ x: '100%' }}
              transition={{ duration: 1, repeat: Infinity, ease: 'linear' }}
            />
          )}
          
          <AnimatePresence mode="wait">
            {isSending ? (
              <motion.div
                key="sending"
                initial={{ opacity: 0, rotate: -90, scale: 0.8 }}
                animate={{ 
                  opacity: 1, 
                  rotate: 0, 
                  scale: 1,
                }}
                exit={{ opacity: 0, rotate: 90, scale: 0.8 }}
                transition={getAnimationConfig('stiff')}
                className="flex items-center justify-center"
              >
                {/* Custom loading dots instead of boring spinner */}
                <div className="flex space-x-1">
                  {[0, 1, 2].map((index) => (
                    <motion.div
                      key={index}
                      className="w-1.5 h-1.5 bg-white rounded-full"
                      animate={{
                        scale: [1, 1.3, 1],
                        opacity: [0.6, 1, 0.6]
                      }}
                      transition={{
                        duration: 0.8,
                        repeat: Infinity,
                        delay: index * 0.15,
                        ease: 'easeInOut'
                      }}
                    />
                  ))}
                </div>
              </motion.div>
            ) : (
              <motion.div
                key="send"
                initial={{ opacity: 0, rotate: 90, scale: 0.8 }}
                animate={{ 
                  opacity: 1, 
                  rotate: 0, 
                  scale: 1 
                }}
                exit={{ opacity: 0, rotate: -90, scale: 0.8 }}
                transition={getAnimationConfig('stiff')}
                whileHover={{ 
                  rotate: -10,
                  scale: 1.1
                }}
              >
                <PaperAirplaneIcon className="w-5 h-5" />
              </motion.div>
            )}
          </AnimatePresence>
        </motion.button>
      </div>
    </div>
  );
};

export default ChatInput;

import React, { useEffect, useRef } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';

interface StreamingTextProps {
  content: string;
  isProcessing: boolean;
  textColor?: string;
  isMinion?: boolean;
}

const StreamingText: React.FC<StreamingTextProps> = ({ content, isProcessing, textColor, isMinion }) => {
  const contentRef = useRef<HTMLDivElement>(null);

  // The 'prose' class sets a default gray color. If a specific textColor is provided (for custom minion bubbles),
  // we need to apply it via inline styles to ensure it overrides the prose defaults.
  // For user messages, we don't apply 'prose' at all.
  const style: React.CSSProperties = textColor ? { color: textColor } : {};
  
  // We only apply the 'prose' class if it's a minion message. User messages have their own simple styling.
  const containerClassName = isMinion ? 'prose' : '';

  return (
    <div ref={contentRef} style={style} className={containerClassName}>
      <ReactMarkdown remarkPlugins={[remarkGfm]}>{content}</ReactMarkdown>
      {isProcessing && content && <span className="typing-caret" />}
    </div>
  );
};

export default StreamingText;

import React, { memo } from 'react';
import { Streamdown } from 'streamdown';

interface StreamingTextProps {
  content: string;
  isProcessing: boolean;
  textColor?: string;
  isMinion?: boolean;
}

/**
 * StreamingText - Markdown renderer optimized for streaming AI content
 * 
 * Uses Streamdown which:
 * - Handles incomplete markdown gracefully during streaming
 * - Has built-in memoization for efficient updates
 * - Provides syntax highlighting with Shiki
 * - Supports GFM (tables, task lists, strikethrough)
 */
const StreamingText: React.FC<StreamingTextProps> = memo(({ 
  content, 
  isProcessing, 
  textColor, 
  isMinion 
}) => {
  // The 'prose' class sets a default gray color. If a specific textColor is provided (for custom minion bubbles),
  // we need to apply it via inline styles to ensure it overrides the prose defaults.
  // For user messages, we don't apply 'prose' at all.
  const style: React.CSSProperties = textColor ? { color: textColor } : {};
  
  // We only apply the 'prose' class if it's a minion message. User messages have their own simple styling.
  const containerClassName = isMinion ? 'prose prose-sm max-w-none' : '';

  return (
    <div style={style} className={containerClassName}>
      <Streamdown>{content}</Streamdown>
      {isProcessing && content && <span className="typing-caret" />}
    </div>
  );
}, (prevProps, nextProps) => {
  // Custom comparison - only re-render if these actually change
  return (
    prevProps.content === nextProps.content &&
    prevProps.isProcessing === nextProps.isProcessing &&
    prevProps.textColor === nextProps.textColor &&
    prevProps.isMinion === nextProps.isMinion
  );
});

StreamingText.displayName = 'StreamingText';

export default StreamingText;

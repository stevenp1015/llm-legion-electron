import React from 'react';

const TypingIndicator: React.FC = () => {
    return (
        <div className="flex items-center justify-center space-x-1.5 p-2">
            <div className="typing-dot" style={{ animationDelay: '0ms' }}></div>
            <div className="typing-dot" style={{ animationDelay: '150ms' }}></div>
            <div className="typing-dot" style={{ animationDelay: '300ms' }}></div>
        </div>
    );
};

export default TypingIndicator;
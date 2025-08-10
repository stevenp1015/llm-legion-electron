import React from 'react';

const TypingIndicator: React.FC = () => {
    return (
        <div className="flex items-center justify-center space-x-1.5 p-2">
            <div className="w-2 h-2 bg-neutral-500 rounded-full animate-bounce [animation-delay:-0.7s]"></div>
            <div className="w-2 h-2 bg-neutral-500 rounded-full animate-bounce [animation-delay:-0.15s]"></div>
            <div className="w-2 h-2 bg-neutral-500 rounded-full animate-bounce"></div>
        </div>
    );
};

export default TypingIndicator;
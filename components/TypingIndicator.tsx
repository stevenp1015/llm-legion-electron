import React from 'react';
import { motion } from 'motion/react';
import { getAnimationConfig } from '../animations/config';

const TypingIndicator: React.FC = () => {
    return (
        <div className="flex items-center justify-center space-x-1.5 p-2">
            {[0, 1, 2].map((index) => (
                <motion.div
                    key={index}
                    className="w-2 h-2 bg-neutral-400 rounded-full"
                    animate={{
                        scale: [1, 1.4, 1],
                        opacity: [0.4, 1, 0.4],
                        y: [0, -4, 0]
                    }}
                    transition={{
                        duration: 1.2,
                        repeat: Infinity,
                        delay: index * 0.2,
                        ease: 'easeInOut',
                        type: 'tween'
                    }}
                    style={{
                        filter: 'drop-shadow(0 1px 2px rgba(0,0,0,0.1))'
                    }}
                />
            ))}
            
            {/* Subtle pulse effect behind the dots */}
            <motion.div
                className="absolute inset-0 bg-gradient-to-r from-transparent via-neutral-300/20 to-transparent rounded-full"
                animate={{
                    opacity: [0, 0.3, 0],
                    scale: [0.8, 1.2, 0.8]
                }}
                transition={{
                    duration: 2,
                    repeat: Infinity,
                    ease: 'easeInOut'
                }}
            />
        </div>
    );
};

export default TypingIndicator;
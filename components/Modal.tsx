import React from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { XMarkIcon } from './Icons';

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
  size?: 'sm' | 'md' | 'lg' | 'xl' | '2xl';
}

const Modal: React.FC<ModalProps> = ({ isOpen, onClose, title, children, size = 'md' }) => {
  const sizeClasses = {
    sm: 'sm:max-w-sm',
    md: 'sm:max-w-md',
    lg: 'sm:max-w-lg',
    xl: 'sm:max-w-xl',
    '2xl': 'sm:max-w-2xl',
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-slate-900/40"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.1 }}
          exit={{ opacity: 0 }}
        >
          <motion.div
            className={`relative w-full p-4 mx-auto bg-white/65 border border-zinc-200 rounded-lg shadow-xl ${sizeClasses[size]} max-h-[90vh] flex flex-col`}
            initial={{ opacity: 1, scale: 0.5 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{
                  type: 'spring', stiffness: 1000, damping: 30, mass: 1
            }}
            exit={{ opacity: 1, scale: 0.5 }}
          >
            <div className="flex items-center justify-between p-4 border-b border-zinc-200">
              <h3 className="text-xl font-semibold text-neutral-900">{title}</h3>
              <button
                onClick={onClose}
                className="text-neutral-500 hover:text-neutral-800 transition-colors"
                aria-label="Close modal"
              >
                <XMarkIcon className="w-6 h-6" />
              </button>
            </div>
            <div className="p-6 overflow-y-auto flex-grow scrollbar-thin scrollbar-thumb-neutral-400 scrollbar-track-zinc-200">
              {children}
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

export default Modal;

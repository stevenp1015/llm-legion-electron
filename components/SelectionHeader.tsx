import React from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { TrashIcon, BookOpenIcon, XMarkIcon } from './Icons';
import { getAnimationConfig } from '../animations/config';

interface SelectionHeaderProps {
  isVisible: boolean;
  selectedCount: number;
  onDelete: () => void;
  onShowDiary: () => void;
  onDone: () => void;
  hasMinions: boolean; // Whether selected messages include minions (for diary button)
}

const SelectionHeader: React.FC<SelectionHeaderProps> = ({
  isVisible,
  selectedCount,
  onDelete,
  onShowDiary,
  onDone,
  hasMinions
}) => {
  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ opacity: 0, y: -60, scale: 0.9 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: -60, scale: 0.9 }}
          transition={getAnimationConfig('bouncy')}
          className="absolute top-4 left-1/2 transform -translate-x-1/2 z-50"
        >
          <div className="bg-amber-500 text-white px-6 py-3 rounded-xl shadow-xl border border-amber-600 flex items-center gap-4">
            <span className="font-semibold text-sm">
              {selectedCount} message{selectedCount !== 1 ? 's' : ''} selected
            </span>
            
            <div className="flex items-center gap-2">
              <motion.button
                onClick={onDelete}
                className="p-2 bg-red-500 hover:bg-red-600 text-white rounded-lg transition-colors"
                title="Delete selected messages"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                <TrashIcon className="w-4 h-4" />
              </motion.button>
              
              {hasMinions && (
                <motion.button
                  onClick={onShowDiary}
                  className="p-2 bg-teal-500 hover:bg-teal-600 text-white rounded-lg transition-colors"
                  title="Toggle diary for selected minion messages"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                >
                  <BookOpenIcon className="w-4 h-4" />
                </motion.button>
              )}
              
              <motion.button
                onClick={onDone}
                className="p-2 bg-gray-600 hover:bg-gray-700 text-white rounded-lg transition-colors"
                title="Exit selection mode"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                <XMarkIcon className="w-4 h-4" />
              </motion.button>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

export default SelectionHeader;
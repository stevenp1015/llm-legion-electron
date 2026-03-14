import React, { useState, useMemo, useCallback } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Channel, MinionConfig } from '../types';
import { HashtagIcon, ChevronRightIcon, PlusIcon, TrashIcon } from './Icons';
import { getAnimationConfig, ANIMATION_VARIANTS } from '../animations/config';
import { LEGION_COMMANDER_NAME } from '../constants';

interface MinionBuddylistProps {
  channels: Channel[];
  minionConfigs: MinionConfig[];
  currentChannelId: string | null;
  onSelectChannel: (channelId: string) => void;
  onCreateNewChat: (minionName: string) => void;
  onDeleteChannel: (channelId: string) => void;
}

interface MinionChatGroup {
  minionName: string;
  minionConfig: MinionConfig;
  chats: Channel[];
}

const MinionBuddylist: React.FC<MinionBuddylistProps> = ({
  channels,
  minionConfigs,
  currentChannelId,
  onSelectChannel,
  onCreateNewChat,
  onDeleteChannel
}) => {
  const [expandedMinions, setExpandedMinions] = useState<Set<string>>(new Set());

  const triggerHaptic = useCallback((pattern: string = 'alignment') => {
    if (window.isElectron && window.electronAPI?.invoke) {
      window.electronAPI.invoke('haptic:perform', pattern);
    }
  }, []);

  // Group minion buddy chats by minion name
  const minionGroups = useMemo(() => {
    const buddyChats = channels.filter(c => c.type === 'minion_buddy_chat');
    const groupMap = new Map<string, Channel[]>();

    // Initialize all minions in the map, even if they have no chats
    minionConfigs.forEach(minion => {
      groupMap.set(minion.name, []);
    });

    // Group existing buddy chats by minion
    buddyChats.forEach(chat => {
      // Extract minion name from channel members (should be [LEGION_COMMANDER_NAME, minionName])
      const minionName = chat.members.find(member => member !== LEGION_COMMANDER_NAME);
      if (minionName && groupMap.has(minionName)) {
        groupMap.get(minionName)!.push(chat);
      }
    });

    // Convert to array and sort chats by timestamp (newest first)
    const groups: MinionChatGroup[] = Array.from(groupMap.entries()).map(([minionName, chats]) => {
      const minionConfig = minionConfigs.find(m => m.name === minionName);
      if (!minionConfig) return null;

      const sortedChats = [...chats].sort((a, b) => {
        // Extract timestamp from channel ID (format is "channel-{timestamp}")
        const aTimestamp = parseInt(a.id.replace('channel-', '') || '0');
        const bTimestamp = parseInt(b.id.replace('channel-', '') || '0');
        return bTimestamp - aTimestamp;
      });

      return {
        minionName,
        minionConfig,
        chats: sortedChats,
      };
    }).filter(Boolean) as MinionChatGroup[];

    return groups.sort((a, b) => a.minionName.localeCompare(b.minionName));
  }, [channels, minionConfigs]);

  const toggleMinionExpansion = (minionName: string) => {
    setExpandedMinions(prev => {
      const newSet = new Set(prev);
      if (newSet.has(minionName)) {
        newSet.delete(minionName);
      } else {
        newSet.add(minionName);
      }
      return newSet;
    });
  };

  if (minionGroups.length === 0) {
    return null;
  }

  return (
    <div>
      <h3 className="px-3 pb-2 text-sm font-bold uppercase text-transparent bg-clip-text bg-gradient-to-br from-slate-200 to-80% to-slate-800 flex items-center gap-2">
        <HashtagIcon className="w-4 h-4 text-slate-500" />
        Buddylist
      </h3>
      <div className="space-y-1">
        {minionGroups.map(group => (
          <div key={group.minionName}>
            {/* Minion Header */}
            <div className="px-4">
              <motion.button
                onClick={() => toggleMinionExpansion(group.minionName)}
                onMouseEnter={() => triggerHaptic('alignment')}
                className="w-full flex items-center justify-between gap-2 px-3 py-1 text-left text-sm rounded-md text-neutral-600 hover:text-neutral-800 hover:bg-zinc-100"
                variants={ANIMATION_VARIANTS.button}
                initial="idle"
                whileHover="hover"
                whileTap="tap"
              >
                <div className="flex justify-between items-center gap-2">
                  <motion.div
                    animate={{ rotate: expandedMinions.has(group.minionName) ? 90 : 0 }}
                    transition={getAnimationConfig('snappy')}
                  >
                  </motion.div>
                
                  <div 
                    className="w-3 h-3 rounded-full relative shadow-[0_0_5px_0px] shadow-slate-800/20"
                    style={{ background: `linear-gradient(135deg, #ffffff -50%, #ffffff -20%, ${group.minionConfig.chatColor} 70%, #555555 200%)` || '#059669' }}
                    >
                    <span className="text-xs text-zinc-600 absolute -left-[18px] font-medium -top-0"> {/* how can i align the text in this entire list to the left? you can do so by using flex justify-between  */}
                      {group.chats.length}
                    </span>
                  </div>
                  <span className={`font-medium text-transparent bg-clip-text bg-gradient-to-br from-zinc-300 from-[0%] via-[${group.minionConfig.chatColor || '#333333'}] to-zinc-900`}>{group.minionName}</span>
                </div>
              </motion.button>
            </div>

            {/* Expandable Chat List */}
            <AnimatePresence initial={false}>
              {expandedMinions.has(group.minionName) && (
                <motion.div
                  initial={{ scaleY: 0, opacity: 0 }}
                  animate={{ scaleY: 1, opacity: 1 }}
                  exit={{ scaleY: 0, opacity: 0 }}
                  transition={getAnimationConfig('gentle')}
                  className="ml-4 space-y-1 origin-top"
                >
                  {/* New Chat Button */}
                  <div className="px-2">
                    <motion.button
                      onClick={() => onCreateNewChat(group.minionName)}
                      className="w-full flex items-center gap-2 px-3 py-1 text-left text-sm rounded-md text-teal-600 hover:text-teal-700 hover:bg-teal-50 transition-colors"
                      variants={ANIMATION_VARIANTS.button}
                      initial="idle"
                      whileHover="hover"
                      whileTap="tap"
                    >
                      <PlusIcon className="w-4 h-4" />
                      <span className="font-medium">New Chat</span>
                    </motion.button>
                  </div>

                  {/* Existing Chats */}
                  {group.chats.map(chat => {
                    const isActive = currentChannelId === chat.id;
                    return (
                      <div key={chat.id} className="relative px-2 group">
                        <motion.button
                          onClick={() => onSelectChannel(chat.id)}
                          className={`w-full flex items-center justify-between gap-2 px-3 py-1 text-left text-sm rounded-md relative overflow-hidden ${
                            isActive ? 'text-white' : 'text-neutral-500'
                          }`}
                          variants={ANIMATION_VARIANTS.button}
                          initial="idle"
                          whileHover={!isActive ? "hover" : undefined}
                          whileTap="tap"
                        >
                          {/* Active background */}
                          {isActive && (
                            <motion.div
                              className="absolute inset-0 rounded-md"
                              style={{ backgroundColor: group.minionConfig.chatColor || '#059669' }}
                              layoutId={`minion-chat-bg-${group.minionName}`}
                              variants={ANIMATION_VARIANTS.channelSelection}
                              initial="inactive"
                              animate="active"
                              exit="inactive"
                            />
                          )}

                          <motion.span 
                            className="relative z-10 flex items-center gap-2 flex-1 truncate"
                            animate={{ 
                              scale: isActive ? 1.02 : 1,
                            }}
                            transition={getAnimationConfig('gentle')}
                          >
                            <HashtagIcon className="w-3 h-3 flex-shrink-0" />
                            <span className="truncate">{chat.name}</span>
                          </motion.span>
                        </motion.button>

                        {/* Delete button */}
                        <motion.button 
                          onClick={(e) => {
                            e.stopPropagation();
                            onDeleteChannel(chat.id);
                          }}
                          className={`absolute right-2 items-center top-1/2 -translate-y-1/2 rounded-md opacity-0 group-hover:opacity-80 transition-opacity ${
                            isActive ? 'text-white hover:text-red-200' : 'text-neutral-400 hover:text-red-500'
                          }`}
                          title={`Delete ${chat.name}`}
                          variants={ANIMATION_VARIANTS.button}
                          initial="idle"
                          whileHover="hover"
                          whileTap="tap"
                        >
                          <TrashIcon className="w-3 h-3 -translate-y-2"/>
                        </motion.button>
                      </div>
                    );
                  })}
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        ))}
      </div>
    </div>
  );
};

export default React.memo(MinionBuddylist);
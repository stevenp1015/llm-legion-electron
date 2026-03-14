import React, { useState, useMemo } from 'react';
import { motion } from 'motion/react';
import { Channel, ChannelPayload, MinionConfig } from '../types';
import { HashtagIcon, PlusIcon, PencilIcon, CogIcon } from './Icons';
import ChannelForm from './ChannelForm';
import MinionBuddylist from './MinionBuddylist';
import { getAnimationConfig, ANIMATION_VARIANTS } from '../animations/config';

interface ChannelListProps {
  channels: Channel[];
  currentChannelId: string | null;
  onSelectChannel: (channelId: string) => void;
  onAddOrUpdateChannel: (channel: ChannelPayload) => void;
  onDeleteChannel: (channelId: string) => void;
  onCreateNewMinionChat: (minionName: string) => void;
  allMinionNames: string[];
  minionConfigs: MinionConfig[];
}

const ChannelSection: React.FC<{
    title: string;
    channels: Channel[];
    icon: React.ReactNode;
    currentChannelId: string | null;
    onSelectChannel: (channelId: string) => void;
    onOpenEdit: (channel: Channel) => void;
}> = ({ title, channels, icon, currentChannelId, onSelectChannel, onOpenEdit }) => {
    if (channels.length === 0) return null;

    return (
        <div>
            <h3 className="left-light px-3 pt-4 pb-2 text-xs font-bold uppercase text-zinc-500 flex items-center gap-2">
                {icon}
                {title}
            </h3>
            <div className="space-y-1">
                {channels.map(channel => {
                    const isActive = currentChannelId === channel.id;
                    const isDm = channel.type === 'dm';
                    
                    return (
                        <div key={channel.id} className="relative px-2 group">
                            <motion.button
                                onClick={() => onSelectChannel(channel.id)}
                                className={`w-full flex items-center gap-2 px-3 py-0.5 text-left text-sm rounded-md relative overflow-hidden ${
                                    isActive ? (isDm ? 'text-white' : 'text-white') : 'text-neutral-500'
                                }`}
                                variants={ANIMATION_VARIANTS.button}
                                initial="idle"
                                whileHover={!isActive ? "hover" : undefined}
                                whileTap="tap"
                                layout={false}
                            >
                                
                                {/* Active background with satisfying entrance */}
                                {isActive && (
                                    <motion.div
                                        className={`absolute inset-0 rounded-md ${isDm ? 'bg-teal-600' : 'bg-amber-500'}`}
                                        layoutId={`channel-bg-${channel.type}`}
                                        variants={ANIMATION_VARIANTS.channelSelection}
                                        initial="inactive"
                                        animate="active"
                                        exit="inactive"
                                        style={{
                                            boxShadow: '0 0 0 1px rgba(255,255,255,0.1), 0 2px 8px rgba(0,0,0,0.1)'
                                        }}
                                    />
                                )}
                                
                                {/* Content with subtle animation */}
                                <motion.span 
                                    className="relative z-10 flex items-center gap-2"
                                    animate={{ 
                                        scale: isActive ? 1.02 : 1,
                                    }}
                                    transition={getAnimationConfig('gentle')}
                                >
                                    <motion.div
                                        animate={{ rotate: isActive ? [0, 5, 0] : 0 }}
                                        transition={{ duration: 0.6, ease: 'easeOut' }}
                                    >
                                        <HashtagIcon className="w-4 h-4 flex-shrink-0" />
                                    </motion.div>
                                    <span className="truncate font-medium">{channel.name}</span>
                                </motion.span>
                            </motion.button>
                             {channel.type !== 'system_log' && (
                                 <motion.button 
                                    onClick={() => onOpenEdit(channel)}
                                    className={`absolute right-2 top-1/2 -translate-y-1/2 p-1 rounded-md ${
                                        isActive ? 'text-white' : 'text-neutral-600'
                                    }`}
                                    title={`Edit ${channel.name}`}
                                    variants={ANIMATION_VARIANTS.button}
                                    initial="idle"
                                    whileHover="hover"
                                    whileTap="tap"
                                    animate={{
                                        opacity: isActive ? 0.8 : 0,
                                        scale: isActive ? 1 : 0.8
                                    }}
                                    whileInView={{
                                        opacity: isActive ? 0.8 : 0
                                    }}
                                    transition={getAnimationConfig('haptic')}
                                    style={{
                                        backgroundColor: isActive ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.1)'
                                    }}
                                >
                                    <motion.div
                                        animate={{ rotate: isActive ? 0 : 180 }}
                                        transition={{ duration: 0.3, ease: 'easeOut' }}
                                    >
                                        <PencilIcon className="w-4 h-4"/>
                                    </motion.div>
                                </motion.button>
                            )}
                        </div>
                    );
                })}
            </div>
        </div>
    );
};


const ChannelList: React.FC<ChannelListProps> = ({ 
  channels, 
  currentChannelId, 
  onSelectChannel, 
  onAddOrUpdateChannel, 
  onDeleteChannel,
  onCreateNewMinionChat,
  allMinionNames, 
  minionConfigs 
}) => {
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingChannel, setEditingChannel] = useState<Channel | undefined>(undefined);
    
    const handleOpenCreate = () => {
        setEditingChannel(undefined);
        setIsModalOpen(true);
    };

    const handleOpenEdit = (channel: Channel) => {
        setEditingChannel(channel);
        setIsModalOpen(true);
    };

    const { dmChannels, groupChannels, autoChannels, systemChannels } = useMemo(() => {
        const dmChannels = channels.filter(c => c.type === 'dm');
        const groupChannels = channels.filter(c => c.type === 'user_minion_group');
        const autoChannels = channels.filter(c => c.type === 'minion_minion_auto');
        const systemChannels = channels.filter(c => c.type === 'system_log');
        return { dmChannels, groupChannels, autoChannels, systemChannels };
    }, [channels]);

    return (
        <>
            <div className="w-64 bg-gradient-to-b from-[#fbf7fc] to-[#e7e3e7] border-r border-zinc-200 flex-shrink-0 flex flex-col shadow-[0px_0px_10px_0px_rgba(0,0,0,0.3)]">
                <div className="px-4 pt-3 pb-1 flex justify-between items-center electron-drag">
                {/* shadow-[inset_0px_-8px_4px_-9px_rgba(0,0,0,0.3),0px_5px_4px_-7px_rgba(25,25,25,0.3),0px_4px_5px_0px_rgba(255,255,255,0.4),inset_0px_-4px_10px_-4px_rgba(100,170,235,.3)] */}
                    <h2 className="text-[2rem] pl-3 font-bold text-transparent bg-clip-text bg-gradient-to-b from-zinc-400/40  to-zinc-900">Channels</h2>
                    <motion.button 
                        onClick={handleOpenCreate}
                        className="p-1.5 text-zinc-500 rounded-md electron-no-drag"
                        title="Create New Channel"
                        variants={ANIMATION_VARIANTS.button}
                        initial="idle"
                        whileTap="tap"
                        >
                        <motion.div
                            animate={{ rotate: 0, scale: 1 }}
                            whileHover={{ rotate: 180, scale: 1.4 }}
                            transition={{ duration: 0.5, ease: 'backInOut' }}
                        >
                            <PlusIcon className="w-5 h-5" />
                        </motion.div>
                    </motion.button>
                </div>
                    <div className="h-24 w-56 bg-[radial-gradient(70%_25%_at_52%_20%,_var(--tw-gradient-stops))] from-slate-500/30  to-transparent to-80%"></div>
                <div className="flex-grow p-0 overflow-y-auto scrollbar-none">
                    <MinionBuddylist
                        channels={channels}
                        minionConfigs={minionConfigs}
                        currentChannelId={currentChannelId}
                        onSelectChannel={onSelectChannel}
                        onCreateNewChat={onCreateNewMinionChat}
                        onDeleteChannel={onDeleteChannel}
                    />
                    <ChannelSection 
                        title="Direct Messages"
                        channels={dmChannels}
                        icon={<HashtagIcon className="w-4 h-4" />}
                        currentChannelId={currentChannelId}
                        onSelectChannel={onSelectChannel}
                        onOpenEdit={handleOpenEdit}
                    />
                    <ChannelSection 
                        title="Group Chats"
                        channels={groupChannels}
                        icon={<HashtagIcon className="w-4 h-4" />}
                        currentChannelId={currentChannelId}
                        onSelectChannel={onSelectChannel}
                        onOpenEdit={handleOpenEdit}
                    />
                    <ChannelSection 
                        title="Autonomous"
                        channels={autoChannels}
                        icon={<CogIcon className="w-4 h-4" />}
                        currentChannelId={currentChannelId}
                        onSelectChannel={onSelectChannel}
                        onOpenEdit={handleOpenEdit}
                    />
                </div>
            </div>
            <ChannelForm 
                isOpen={isModalOpen}
                onClose={() => setIsModalOpen(false)}
                onSave={onAddOrUpdateChannel}
                initialChannel={editingChannel}
                allMinionNames={allMinionNames}
            />
        </>
    );
};

export default React.memo(ChannelList);

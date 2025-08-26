import React, { useState, useMemo } from 'react';
import { motion } from 'motion/react';
import { Channel, ChannelPayload } from '../types';
import { HashtagIcon, PlusIcon, PencilIcon, CogIcon } from './Icons';
import ChannelForm from './ChannelForm';
import { getAnimationConfig, ANIMATION_VARIANTS } from '../animations/config';

interface ChannelListProps {
  channels: Channel[];
  currentChannelId: string | null;
  onSelectChannel: (channelId: string) => void;
  onAddOrUpdateChannel: (channel: ChannelPayload) => void;
  allMinionNames: string[];
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
            <h3 className="px-3 pt-4 pb-2 text-xs font-bold uppercase text-neutral-500 flex items-center gap-2">
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
                                className={`w-full flex items-center gap-2 px-3 py-1.5 text-left rounded-md relative overflow-hidden ${
                                    isActive ? (isDm ? 'text-white' : 'text-white') : 'text-neutral-500'
                                }`}
                                variants={ANIMATION_VARIANTS.button}
                                initial="idle"
                                whileHover={!isActive ? "hover" : undefined}
                                whileTap="tap"
                                layout
                            >
                                {/* Hover background for inactive channels */}
                                {!isActive && (
                                    <motion.div
                                        className="absolute inset-0 bg-zinc-200 rounded-md"
                                        initial={{ opacity: 0, scale: 0.8 }}
                                        whileHover={{ 
                                            opacity: 1, 
                                            scale: 1,
                                            transition: getAnimationConfig('haptic')
                                        }}
                                        exit={{ 
                                            opacity: 0, 
                                            scale: 0.8,
                                            transition: getAnimationConfig('snappy')
                                        }}
                                    />
                                )}
                                
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
                                        filter: isActive ? 'drop-shadow(0 1px 2px rgba(0,0,0,0.2))' : 'none'
                                    }}
                                    transition={getAnimationConfig('gentle')}
                                >
                                    <motion.div
                                        animate={{ rotate: isActive ? [0, 5, 0] : 0 }}
                                        transition={{ duration: 0.6, ease: 'easeOut' }}
                                    >
                                        <HashtagIcon className="w-5 h-5 flex-shrink-0" />
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


const ChannelList: React.FC<ChannelListProps> = ({ channels, currentChannelId, onSelectChannel, onAddOrUpdateChannel, allMinionNames }) => {
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
            <div className="w-64 bg-zinc-100/50 backdrop-blur-md border-r border-zinc-200 flex-shrink-0 flex flex-col">
                <div className="p-3 border-b border-zinc-200 flex justify-between items-center electron-drag">
                    <h2 className="text-lg font-semibold text-neutral-700">Channels</h2>
                    <motion.button 
                        onClick={handleOpenCreate}
                        className="p-1.5 text-neutral-500 rounded-md electron-no-drag"
                        title="Create New Channel"
                        variants={ANIMATION_VARIANTS.button}
                        initial="idle"
                        whileHover="hover"
                        whileTap="tap"
                        style={{
                            backgroundColor: 'transparent'
                        }}
                        whileHover={{
                            backgroundColor: 'rgba(0, 150, 136, 0.1)',
                            color: 'rgb(20, 184, 166)',
                            ...ANIMATION_VARIANTS.button.hover
                        }}
                    >
                        <motion.div
                            animate={{ rotate: 0 }}
                            whileHover={{ rotate: 90 }}
                            transition={{ duration: 0.3, ease: 'easeOut' }}
                        >
                            <PlusIcon className="w-5 h-5" />
                        </motion.div>
                    </motion.button>
                </div>
                <div className="flex-grow p-2 overflow-y-auto scrollbar-thin scrollbar-thumb-neutral-300 scrollbar-track-transparent">
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

export default ChannelList;

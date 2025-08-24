import React, { useState, useMemo } from 'react';
import { motion } from 'motion/react';
import { Channel, ChannelPayload } from '../types';
import { HashtagIcon, PlusIcon, PencilIcon, CogIcon } from './Icons';
import ChannelForm from './ChannelForm';
import { getAnimationConfig } from '../animations/config';

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
                            <button
                                onClick={() => onSelectChannel(channel.id)}
                                className={`w-full flex items-center gap-2 px-3 py-1.5 text-left rounded-md transition-colors duration-100 relative ${
                                    isActive ? (isDm ? 'text-white' : 'text-white') : 'text-neutral-500 hover:bg-zinc-200 hover:text-neutral-800'
                                }`}
                            >
                                {isActive && (
                                    <motion.div
                                        className={`absolute inset-0 z-0 rounded-md ${isDm ? 'bg-teal-600' : 'bg-amber-500'}`}
                                        initial={{ opacity: 0 }}
                                        animate={{ opacity: 1 }}
                                        exit={{ opacity: 0 }}
                                        transition={getAnimationConfig('snappy')}
                                    />
                                )}
                                <span className="relative z-10 flex items-center gap-2">
                                    <HashtagIcon className="w-5 h-5 flex-shrink-0" />
                                    <span className="truncate">{channel.name}</span>
                                </span>
                            </button>
                             {channel.type !== 'system_log' && (
                                 <button 
                                    onClick={() => onOpenEdit(channel)}
                                    className={`absolute right-2 top-1/2 -translate-y-1/2 p-1 rounded-md transition-opacity ${
                                        isActive ? 'opacity-80 hover:opacity-100 hover:bg-white/20' : 'opacity-0 group-hover:opacity-70 hover:opacity-100 hover:bg-zinc-300'
                                    }`}
                                    title={`Edit ${channel.name}`}
                                >
                                    <PencilIcon className={`w-4 h-4 ${isActive ? 'text-white' : 'text-neutral-600'}`}/>
                                </button>
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
                    <button 
                        onClick={handleOpenCreate}
                        className="p-1.5 text-neutral-500 hover:bg-zinc-200 hover:text-teal-600 transition-colors rounded-md electron-no-drag"
                        title="Create New Channel"
                    >
                        <PlusIcon className="w-5 h-5" />
                    </button>
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

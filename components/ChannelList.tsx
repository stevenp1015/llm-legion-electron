import React, { useState } from 'react';
import { Channel, ChannelPayload, MinionConfig } from '../types';
import { HashtagIcon, PlusIcon, PencilIcon } from './Icons';
import ChannelForm from './ChannelForm';

interface ChannelListProps {
  channels: Channel[];
  currentChannelId: string | null;
  onSelectChannel: (channelId: string) => void;
  onAddOrUpdateChannel: (channel: ChannelPayload) => void;
  allMinionNames: string[];
}

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

    return (
        <>
            <div className="w-64 bg-zinc-50/75 backdrop-blur-md border-r border-zinc-200 flex-shrink-0 flex flex-col">
                <div className="p-4 border-b border-zinc-200 flex justify-between items-center">
                    <h2 className="text-lg font-semibold text-green-500">Channels</h2>
                    <button 
                        onClick={handleOpenCreate}
                        className="p-1.5 text-teal-600 hover:bg-teal-600 hover:text-white transition-colors rounded-md"
                        title="Create New Channel"
                    >
                        <PlusIcon className="w-6 h-6" />
                    </button>
                </div>
                <div className="flex-grow p-2 space-y-1 overflow-y-auto scrollbar-thin scrollbar-thumb-neutral-400 scrollbar-track-zinc-200">
                    {channels.map(channel => (
                        <div key={channel.id} className={`group w-full flex items-center rounded-md transition-colors ${
                            currentChannelId === channel.id ? 'bg-amber-500' : 'hover:bg-zinc-200'
                        }`}>
                            <button
                                onClick={() => onSelectChannel(channel.id)}
                                className={`flex-grow flex items-center gap-2 px-3 py-2 text-left rounded-md ${
                                currentChannelId === channel.id ? 'text-white font-semibold' : 'text-neutral-600 group-hover:text-neutral-900'
                                }`}
                            >
                                <HashtagIcon className="w-5 h-5 flex-shrink-0" />
                                <span className="truncate">{channel.name}</span>
                            </button>
                            {channel.type !== 'system_log' && (
                                 <button 
                                    onClick={() => handleOpenEdit(channel)}
                                    className={`p-1.5 mr-1 rounded-md opacity-0 group-hover:opacity-100 transition-opacity ${
                                        currentChannelId === channel.id ? 'opacity-100' : ''
                                    } ${
                                        currentChannelId === channel.id ? 'hover:bg-amber-200' : 'hover:bg-zinc-300'
                                    }`}
                                    title={`Edit ${channel.name}`}
                                >
                                    <PencilIcon className="w-4 h-4"/>
                                </button>
                            )}
                        </div>
                    ))}
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
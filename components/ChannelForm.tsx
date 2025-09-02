import React, { useState, useEffect } from 'react';
import { Channel, ChannelPayload, ChannelType, MinionConfig } from '../types';
import Modal from './Modal';
import { UserCircleIcon } from './Icons';
import { LEGION_COMMANDER_NAME } from '../constants';
import MinionIcon from './MinionIcon';

interface ChannelFormProps {
    isOpen: boolean;
    onClose: () => void;
    onSave: (channel: ChannelPayload) => void;
    initialChannel?: Channel;
    allMinionNames: string[];
}

const ChannelForm: React.FC<ChannelFormProps> = ({ isOpen, onClose, onSave, initialChannel, allMinionNames }) => {
    const [name, setName] = useState('');
    const [description, setDescription] = useState('');
    const [type, setType] = useState<ChannelType>('user_minion_group');
    const [selectedMembers, setSelectedMembers] = useState<string[]>([]);

    useEffect(() => {
        if (isOpen) {
            if (initialChannel) {
                setName(initialChannel.name);
                setDescription(initialChannel.description || '');
                setType(initialChannel.type);
                setSelectedMembers(initialChannel.members || []);
            } else {
                setName('');
                setDescription('');
                setType('user_minion_group');
                setSelectedMembers([LEGION_COMMANDER_NAME, ...allMinionNames]);
            }
        }
    // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [initialChannel, isOpen]);

    const handleMemberToggle = (memberName: string) => {
        setSelectedMembers(prev =>
            prev.includes(memberName)
                ? prev.filter(m => m !== memberName)
                : [...prev, memberName]
        );
    };

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        if (!name.trim()) return;

        const payload: ChannelPayload = {
            id: initialChannel?.id,
            name: name.startsWith('#') ? name : `#${name}`,
            description,
            type,
            members: type === 'system_log' ? [] : Array.from(new Set(selectedMembers)),
        };
        onSave(payload);
        onClose();
    };

    const typeDescriptions: Record<ChannelType, string> = {
        user_minion_group: "Standard chat with Commander and selected Minions.",
        minion_minion_auto: "Autonomous chat between selected Minions, started by a Commander prompt.",
        system_log: "Read-only logs from the Legion System. No members.",
        dm: "A direct message channel between the Commander and one Minion.",
        minion_buddy_chat: "Private chat with a specific Minion, created from the buddylist."
    };

    return (
        <Modal isOpen={isOpen} onClose={onClose} title={initialChannel ? `Edit Channel: ${initialChannel.name}` : 'Create New Channel'}>
            <form onSubmit={handleSubmit} className="space-y-3">
                <div>
                    <label htmlFor="channel-name" className="block text-sm font-medium text-neutral-600">Channel Name</label>
                    <input id="channel-name" type="text" value={name} onChange={(e) => setName(e.target.value)}
                        className="mt-1 block w-full bg-white border border-zinc-300 rounded-md shadow-sm py-1.5 px-3 focus:outline-none focus:ring-amber-500 focus:border-amber-500 sm:text-sm text-neutral-900"
                        placeholder="#strategy-discussion" required />
                </div>
                <div>
                    <label htmlFor="channel-description" className="block text-sm font-medium text-neutral-600">Description</label>
                    <input id="channel-description" type="text" value={description} onChange={(e) => setDescription(e.target.value)}
                        className="mt-1 block w-full bg-white border border-zinc-300 rounded-md shadow-sm py-1.5 px-3 focus:outline-none focus:ring-amber-500 focus:border-amber-500 sm:text-sm text-neutral-900"
                        placeholder="What is this channel for?" />
                </div>
                <div>
                    <label htmlFor="channel-type" className="block text-sm font-medium text-neutral-600">Channel Type</label>
                    <select id="channel-type" value={type} onChange={(e) => setType(e.target.value as ChannelType)}
                        className="mt-1 block w-full bg-white border border-zinc-300 rounded-md shadow-sm py-1.5 px-3 focus:outline-none focus:ring-amber-500 focus:border-amber-500 sm:text-sm text-neutral-900">
                        <option value="user_minion_group">Group Chat</option>
                        <option value="dm">Direct Message (DM)</option>
                        <option value="minion_minion_auto">Autonomous Swarm</option>
                        <option value="system_log">System Log</option>
                    </select>
                    <p className="mt-2 text-xs text-neutral-500">{typeDescriptions[type]}</p>
                </div>

                {type !== 'system_log' && (
                    <div>
                        <label className="block text-sm font-medium text-neutral-600">Channel Members</label>
                        <div className="mt-2 p-3 bg-zinc-100/70 rounded-md max-h-96 overflow-y-auto space-y-1">
                            {/* Commander is always a member and cannot be removed */}
                            <div className="flex items-center">
                                <input id="member-commander" type="checkbox" checked={selectedMembers.includes(LEGION_COMMANDER_NAME)} onChange={() => handleMemberToggle(LEGION_COMMANDER_NAME)} className="h-4 w-4 rounded border-zinc-400 text-amber-600 focus:ring-amber-500 cursor-pointer" />
                                <label htmlFor="member-commander" className="ml-3 flex items-center gap-2 text-sm text-neutral-700 cursor-pointer">
                                    <UserCircleIcon className="w-5 h-5 text-teal-600" /> {LEGION_COMMANDER_NAME} (Commander)
                                </label>
                            </div>
                            {allMinionNames.map(minionName => (
                                <div key={minionName} className="flex items-center">
                                    <input id={`member-${minionName}`} type="checkbox"
                                        checked={selectedMembers.includes(minionName)}
                                        onChange={() => handleMemberToggle(minionName)}
                                        className="h-4 w-4 rounded border-zinc-400 text-amber-600 focus:ring-amber-500 cursor-pointer" />
                                    <label htmlFor={`member-${minionName}`} className="ml-3 flex items-center gap-2 text-sm text-neutral-700 cursor-pointer">
                                        <MinionIcon name={minionName} className="w-5 h-5" /> {minionName}
                                    </label>
                                </div>
                            ))}
                        </div>
                    </div>
                )}

                <div className="flex justify-end gap-3 pt-4">
                    <button type="button" onClick={onClose} className="px-4 py-2 text-sm font-medium text-neutral-700 bg-neutral-200 hover:bg-neutral-300 rounded-md">
                        Cancel
                    </button>
                    <button type="submit" className="px-4 py-2 text-sm font-medium text-white bg-amber-500 hover:bg-amber-600 rounded-md">
                        {initialChannel ? 'Save Changes' : 'Create Channel'}
                    </button>
                </div>
            </form>
        </Modal>
    );
};

export default ChannelForm;
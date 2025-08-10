import React from 'react';
import { PromptPreset } from '../types';
import { TrashIcon } from './Icons';

interface PromptPresetManagerProps {
    presets: PromptPreset[];
    onDelete: (id: string) => void;
}

const PromptPresetManager: React.FC<PromptPresetManagerProps> = ({ presets, onDelete }) => {
    return (
        <div className="text-neutral-700">
            <p className="text-sm text-neutral-500 mb-4">
                Manage your saved persona presets. These can be selected when creating or editing any Minion.
            </p>
            
            <div className="space-y-2 max-h-80 overflow-y-auto pr-2 scrollbar-thin scrollbar-thumb-neutral-400 scrollbar-track-zinc-200">
                {presets.length === 0 ? (
                    <p className="text-sm text-neutral-500 text-center py-4">No presets saved yet.</p>
                ) : (
                    presets.map(preset => (
                        <div key={preset.id} className="flex items-start justify-between p-3 bg-zinc-100 rounded-md">
                            <div className="flex-1 overflow-hidden">
                                <p className="font-semibold text-neutral-800 truncate" title={preset.name}>{preset.name}</p>
                                <p className="text-xs text-neutral-500 mt-1 line-clamp-2" title={preset.content}>{preset.content}</p>
                            </div>
                            <button
                                onClick={() => onDelete(preset.id)}
                                className="ml-4 p-1.5 text-neutral-500 hover:text-red-500 transition-colors flex-shrink-0"
                                title={`Delete preset "${preset.name}"`}
                            >
                                <TrashIcon className="w-4 h-4" />
                            </button>
                        </div>
                    ))
                )}
            </div>
        </div>
    );
};

export default PromptPresetManager;
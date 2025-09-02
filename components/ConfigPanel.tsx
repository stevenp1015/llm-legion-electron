import React, { useState } from 'react';
import { MinionConfig, ApiKey, Channel } from '../types';
import { PlusIcon, PencilIcon, TrashIcon, XMarkIcon as CloseIcon, KeyIcon, HashtagIcon } from './Icons';
import ApiKeyManager from './ApiKeyManager';
import MinionIcon from './MinionIcon';
import Modal from './Modal';

interface MinionsPanelProps {
  minionConfigs: MinionConfig[];
  apiKeys: ApiKey[];
  channels: Channel[];
  onDeleteMinion: (id: string) => void;
  onAddApiKey: (name: string, key: string) => Promise<void>;
  onDeleteApiKey: (id: string) => Promise<void>;
  onBulkRemoveMinionFromChannels: (minionName: string, excludeChannels: string[]) => Promise<{ removedFromCount: number, affectedChannels: string[] }>;
  isOpen: boolean;
  onToggle: () => void;
  onEditMinion: (minion: MinionConfig) => void;
  onAddNewMinion: () => void;
}

const MinionsPanel: React.FC<MinionsPanelProps> = ({
  minionConfigs, apiKeys, channels,
  onDeleteMinion,
  onAddApiKey, onDeleteApiKey,
  onBulkRemoveMinionFromChannels,
  isOpen, onToggle,
  onEditMinion, onAddNewMinion
}) => {
  const [isApiKeyModalOpen, setIsApiKeyModalOpen] = useState(false);
  const [isBulkRemovalModalOpen, setIsBulkRemovalModalOpen] = useState(false);
  const [selectedMinionForBulkRemoval, setSelectedMinionForBulkRemoval] = useState<string | null>(null);
  const [excludeChannels, setExcludeChannels] = useState<string[]>([]);
  const [bulkRemovalResult, setBulkRemovalResult] = useState<{ removedFromCount: number, affectedChannels: string[] } | null>(null);
  
  const handleDelete = (id: string) => {
    if (window.confirm(`Are you sure you want to DESTROY Minion: ${minionConfigs.find(m=>m.id===id)?.name || id}? This action cannot be undone.`)) {
        onDeleteMinion(id);
    }
  };

  const handleBulkRemovalOpen = (minionName: string) => {
    setSelectedMinionForBulkRemoval(minionName);
    // Pre-select channels where we typically want to keep minions
    setExcludeChannels(['#general']);
    setBulkRemovalResult(null);
    setIsBulkRemovalModalOpen(true);
  };

  const handleBulkRemoval = async () => {
    if (!selectedMinionForBulkRemoval) return;
    
    try {
      const result = await onBulkRemoveMinionFromChannels(selectedMinionForBulkRemoval, excludeChannels);
      setBulkRemovalResult(result);
    } catch (error) {
      console.error('Bulk removal failed:', error);
      alert('Failed to remove minion from channels');
    }
  };

  const toggleChannelExclusion = (channelName: string) => {
    setExcludeChannels(prev => 
      prev.includes(channelName) 
        ? prev.filter(name => name !== channelName)
        : [...prev, channelName]
    );
  };

  const getChannelsWithMinion = (minionName: string) => {
    return channels.filter(channel => channel.members.includes(minionName));
  };

  return (
    <>
      <div
        className={`fixed inset-0 bg-zinc-600 z-10 transition-opacity duration-1000 ease-in-out ${
          isOpen ? 'opacity-40 pointer-events-auto' : 'opacity-0 pointer-events-none'
        }`}
        onClick={onToggle}
      ></div>      
      <div className={`fixed top-0 right-0 h-full w-full max-w-sm bg-zinc-50/75 backdrop-blur-xl shadow-2xl z-40 transform transition-transform duration-500 ease-in-out border-l border-amber-500 rounded-tl-2xl rounded-bl-2xl ${isOpen ? 'translate-x-0' : 'translate-x-full'}`}>
        <div className="flex flex-col h-full">
          <div className="p-4 bg-white border-b border-zinc-200 rounded-tl-2xl flex justify-between items-center flex-shrink-0">
            <h2 className="text-xl font-semibold text-neutral-700">Roster & Tools</h2>
            <button onClick={onToggle} className="p-1 text-neutral-500 hover:text-neutral-900">
              <CloseIcon className="w-6 h-6"/>
            </button>
          </div>

          <div className="flex-grow p-4 space-y-4 overflow-y-auto scrollbar-thin scrollbar-thumb-neutral-400 scrollbar-track-zinc-200">
            
            {/* Minions Section */}
            <div className="space-y-3">
              <h3 className="text-md font-semibold text-neutral-700">Minion Roster</h3>
              {minionConfigs.length === 0 && (
                <p className="text-sm text-neutral-500 text-center py-4">No Minions deployed. Add one to begin operations!</p>
              )}
              {minionConfigs.map(config => (
                <div key={config.id} className={`p-3 bg-white/70 rounded-lg shadow hover:shadow-md transition-shadow border-l-4 ${config.role === 'regulator' ? 'border-amber-500' : 'border-teal-600'}`}>
                  <div className="flex items-start justify-between">
                    <div className="flex items-center gap-3 overflow-hidden">
                      <MinionIcon name={config.name} className="w-10 h-10" />
                      <div className="overflow-hidden">
                        <h3 className="text-md font-semibold text-neutral-800 truncate" title={config.name}>{config.name}</h3>
                        <p className="text-xs text-neutral-500 truncate" title={config.model_id}>{config.model_name || config.model_id}</p>
                        <p className="text-xs font-bold uppercase tracking-wider mt-1" style={{color: config.role === 'regulator' ? '#f59e0b' : '#0d9488'}}>{config.role}</p>
                      </div>
                    </div>
                    <div className="flex gap-2 flex-shrink-0">
                      <button onClick={() => onEditMinion(config)} className="p-1.5 text-neutral-500 hover:text-amber-500 transition-colors" title={`Edit ${config.name}'s Configuration`}>
                        <PencilIcon className="w-4 h-4" />
                      </button>
                      <button onClick={() => handleBulkRemovalOpen(config.name)} className="p-1.5 text-neutral-500 hover:text-orange-500 transition-colors" title={`Remove ${config.name} from channels`}>
                        <HashtagIcon className="w-4 h-4" />
                      </button>
                      <button onClick={() => handleDelete(config.id)} className="p-1.5 text-neutral-500 hover:text-red-500 transition-colors" title={`Decommission ${config.name}`}>
                        <TrashIcon className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="p-4 border-t border-zinc-200 rounded-l-2xl space-y-3 flex-shrink-0 bg-zinc-50/50 backdrop-blur-sm">
             <button
              onClick={() => setIsApiKeyModalOpen(true)}
              className="w-full flex items-center justify-center gap-2 px-4 py-2.5 text-sm font-medium text-neutral-700 bg-neutral-200 hover:bg-neutral-300 rounded-md shadow-sm transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-white focus:ring-amber-500"
            >
              <KeyIcon className="w-5 h-5" />
              Manage API Keys
            </button>
            <button
              onClick={onAddNewMinion}
              className="w-full flex items-center justify-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-amber-500 hover:bg-amber-600 rounded-md shadow-sm transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-white focus:ring-amber-500"
            >
              <PlusIcon className="w-5 h-5" />
              Deploy New Minion
            </button>
          </div>
        </div>
      </div>
      
      <Modal
        isOpen={isApiKeyModalOpen}
        onClose={() => setIsApiKeyModalOpen(false)}
        title="Manage API Keys"
        size="md"
      >
        <ApiKeyManager
            apiKeys={apiKeys}
            onAddApiKey={onAddApiKey}
            onDeleteApiKey={onDeleteApiKey}
        />
      </Modal>

      <Modal
        isOpen={isBulkRemovalModalOpen}
        onClose={() => setIsBulkRemovalModalOpen(false)}
        title={`Remove ${selectedMinionForBulkRemoval} from Channels`}
        size="lg"
      >
        {selectedMinionForBulkRemoval && (
          <div className="space-y-4">
            {bulkRemovalResult ? (
              <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                <h3 className="text-lg font-semibold text-green-800 mb-2">✅ Removal Complete!</h3>
                <p className="text-green-700 mb-2">
                  Removed <strong>{selectedMinionForBulkRemoval}</strong> from <strong>{bulkRemovalResult.removedFromCount}</strong> channels.
                </p>
                {bulkRemovalResult.affectedChannels.length > 0 && (
                  <div className="mt-2">
                    <p className="text-sm text-green-600 font-medium">Affected channels:</p>
                    <div className="flex flex-wrap gap-1 mt-1">
                      {bulkRemovalResult.affectedChannels.map(channelName => (
                        <span key={channelName} className="inline-block px-2 py-1 text-xs bg-green-100 text-green-700 rounded">
                          {channelName}
                        </span>
                      ))}
                    </div>
                  </div>
                )}
                <button 
                  onClick={() => setIsBulkRemovalModalOpen(false)}
                  className="mt-4 px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors"
                >
                  Done
                </button>
              </div>
            ) : (
              <>
                <div className="mb-4">
                  <p className="text-sm text-neutral-600 mb-2">
                    <strong>{selectedMinionForBulkRemoval}</strong> is currently in <strong>{getChannelsWithMinion(selectedMinionForBulkRemoval).length}</strong> channels.
                  </p>
                  <p className="text-sm text-neutral-500">
                    Select channels to <strong>keep</strong> {selectedMinionForBulkRemoval} in. They will be removed from all other channels.
                  </p>
                </div>

                <div className="space-y-2 max-h-64 overflow-y-auto">
                  <h4 className="text-sm font-semibold text-neutral-700">Channels to KEEP {selectedMinionForBulkRemoval} in:</h4>
                  {getChannelsWithMinion(selectedMinionForBulkRemoval).map(channel => (
                    <label key={channel.id} className="flex items-center space-x-3 p-2 hover:bg-neutral-50 rounded cursor-pointer">
                      <input
                        type="checkbox"
                        checked={excludeChannels.includes(channel.name)}
                        onChange={() => toggleChannelExclusion(channel.name)}
                        className="w-4 h-4 text-amber-500 border-neutral-300 rounded focus:ring-amber-500"
                      />
                      <div className="flex items-center space-x-2">
                        <HashtagIcon className="w-4 h-4 text-neutral-400" />
                        <span className="text-sm text-neutral-700">{channel.name}</span>
                        <span className="text-xs text-neutral-500">({channel.type})</span>
                      </div>
                    </label>
                  ))}
                </div>

                <div className="flex gap-3 pt-4 border-t">
                  <button
                    onClick={() => setIsBulkRemovalModalOpen(false)}
                    className="flex-1 px-4 py-2 text-neutral-600 bg-neutral-200 hover:bg-neutral-300 rounded-md transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={handleBulkRemoval}
                    className="flex-1 px-4 py-2 bg-red-500 text-white hover:bg-red-600 rounded-md transition-colors"
                    disabled={excludeChannels.length === getChannelsWithMinion(selectedMinionForBulkRemoval).length}
                  >
                    Remove from {getChannelsWithMinion(selectedMinionForBulkRemoval).length - excludeChannels.length} channels
                  </button>
                </div>
              </>
            )}
          </div>
        )}
      </Modal>
    </>
  );
};

export default MinionsPanel;

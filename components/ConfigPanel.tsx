import React, { useState } from 'react';
import { MinionConfig, ApiKey } from '../types';
import { PlusIcon, PencilIcon, TrashIcon, XMarkIcon as CloseIcon, KeyIcon } from './Icons';
import ApiKeyManager from './ApiKeyManager';
import MinionIcon from './MinionIcon';
import Modal from './Modal';

interface MinionsPanelProps {
  minionConfigs: MinionConfig[];
  apiKeys: ApiKey[];
  onDeleteMinion: (id: string) => void;
  onAddApiKey: (name: string, key: string) => Promise<void>;
  onDeleteApiKey: (id: string) => Promise<void>;
  isOpen: boolean;
  onToggle: () => void;
  onEditMinion: (minion: MinionConfig) => void;
  onAddNewMinion: () => void;
}

const MinionsPanel: React.FC<MinionsPanelProps> = ({
  minionConfigs, apiKeys,
  onDeleteMinion,
  onAddApiKey, onDeleteApiKey,
  isOpen, onToggle,
  onEditMinion, onAddNewMinion
}) => {
  const [isApiKeyModalOpen, setIsApiKeyModalOpen] = useState(false);
  
  const handleDelete = (id: string) => {
    if (window.confirm(`Are you sure you want to DESTROY Minion: ${minionConfigs.find(m=>m.id===id)?.name || id}? This action cannot be undone.`)) {
        onDeleteMinion(id);
    }
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
    </>
  );
};

export default MinionsPanel;

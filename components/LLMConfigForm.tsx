import React, { useState, useEffect } from 'react';
import { MinionConfig, ApiKey, PromptPreset, ModelOption, McpTool } from '../types';
import { REGULATOR_SYSTEM_PROMPT } from '../constants';
import Modal from './Modal';
import PromptPresetManager from './PromptPresetManager';
import { RefreshIcon, ToolIcon } from './Icons';
import Spinner from './Spinner';
import { mcpElectronService } from '../services/mcpElectronService';

interface MinionConfigFormProps {
  initialConfig?: MinionConfig;
  onSave: (config: MinionConfig) => void;
  onCancel: () => void;
  existingNames: string[];
  apiKeys: ApiKey[];
  promptPresets: PromptPreset[];
  onAddPreset: (name: string, content: string) => void;
  onDeletePreset: (id: string) => void;
  modelOptions: ModelOption[];
  onRefreshModels: () => Promise<void>;
}

const MinionConfigForm: React.FC<MinionConfigFormProps> = ({ 
    initialConfig, onSave, onCancel, existingNames, apiKeys,
    promptPresets, onAddPreset, onDeletePreset,
    modelOptions, onRefreshModels
}) => {
  const [config, setConfig] = useState<MinionConfig>(
    initialConfig || {
      id: `minion-${Date.now()}`,
      name: '',
      provider: 'google',
      role: 'standard',
      model_id: modelOptions[0]?.id || '',
      model_name: modelOptions[0]?.name || '',
      system_prompt_persona: 'You are an AI minion created by Steven, the Commander of the Gemini Legion of which you are a member. You are not a boring ass sterile AI assistant, you aim to mimic real authentic human dialogue and conversation flow naturally. Keep your messages relatively brief, like a real-time chat.',
      params: { temperature: 0.7 },
      opinionScores: {},
      usageStats: { requests: [] },
      status: 'Pending Configuration',
      regulationInterval: 10,
      mcpTools: [],
    }
  );
  
  const [selectedDropdownModel, setSelectedDropdownModel] = useState(modelOptions[0]?.id || '');
  const [nameError, setNameError] = useState<string | null>(null);
  const [isPresetModalOpen, setIsPresetModalOpen] = useState(false);
  const [newPresetName, setNewPresetName] = useState('');
  const [isRefreshingModels, setIsRefreshingModels] = useState(false);
  const [availableMcpTools, setAvailableMcpTools] = useState<McpTool[]>([]);

  useEffect(() => {
    const defaultModelId = modelOptions.length > 0 ? modelOptions[0].id : '';
    if (initialConfig) {
      const isStandardModel = modelOptions.some(opt => opt.id === initialConfig.model_id && opt.id !== 'custom-model-entry');
      if (isStandardModel) {
        setSelectedDropdownModel(initialConfig.model_id);
      } else {
        setSelectedDropdownModel('custom-model-entry');
      }
      setConfig(prev => ({
        mcpTools: [], // Ensure mcpTools is initialized
        ...prev, 
        ...initialConfig
      }));
    } else {
        // Reset to default for new minion
        const defaultConfig: MinionConfig = {
            id: `minion-${Date.now()}`, name: '', provider: 'google', role: 'standard',
            model_id: defaultModelId,
            model_name: defaultModelId,
            system_prompt_persona: 'You are an AI minion created by Steven, the Commander of the Gemini Legion of which you are a member. You are not a boring ass sterile AI assistant, you aim to mimic real authentic human dialogue and conversation flow naturally. Keep your messages relatively brief, like a real-time chat.',
            params: { temperature: 0.7 },
            opinionScores: {}, usageStats: { requests: [] }, status: 'Pending Configuration',
            regulationInterval: 10,
            mcpTools: [],
        };
        setConfig(defaultConfig);
        setSelectedDropdownModel(defaultConfig.model_id);
    }
  }, [initialConfig, modelOptions]);

  useEffect(() => {
    const fetchTools = async () => {
      if (mcpElectronService.isElectronAvailable()) {
        const servers = await mcpElectronService.getAvailableTools(config.id);
        const allTools = servers.flatMap(server => 
          server.tools.map(tool => ({ ...tool, serverId: server.serverId, serverName: server.serverName }))
        );
        setAvailableMcpTools(allTools);
      }
    };
    fetchTools();
  }, [config.id]);


  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    if (name === 'temperature') {
      setConfig(prev => ({ ...prev, params: { ...prev.params, temperature: parseFloat(value) } }));
    } else if (name === 'name') {
      setConfig(prev => ({ ...prev, [name]: value }));
      if (!initialConfig || (initialConfig && initialConfig.name !== value)) {
        if (existingNames.includes(value)) {
          setNameError('This Minion name is already in use. Please choose a unique name.');
        } else {
          setNameError(null);
        }
      } else {
        setNameError(null);
      }
    } else if (name === 'regulationInterval') {
        setConfig(prev => ({ ...prev, regulationInterval: parseInt(value, 10) }));
    } else if (name === 'role') {
        const newRole = value as 'standard' | 'regulator';
        setConfig(prev => ({ 
            ...prev, 
            role: newRole,
            system_prompt_persona: newRole === 'regulator' ? REGULATOR_SYSTEM_PROMPT : prev.system_prompt_persona === REGULATOR_SYSTEM_PROMPT ? '' : prev.system_prompt_persona
        }));
    } else {
      setConfig(prev => ({ ...prev, [name]: value }));
    }
  };
  
  const handleSelectChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const { name, value } = e.target;
    if (name === 'apiKeyId') {
      setConfig(prev => ({ ...prev, apiKeyId: value === "default" ? undefined : value }));
    } else if (name === 'model_id_select') {
        setSelectedDropdownModel(value);
        if (value === 'custom-model-entry') {
            setConfig(prev => ({...prev, model_id: '', model_name: ''}));
        } else {
            const model = modelOptions.find(m => m.id === value);
            setConfig(prev => ({...prev, model_id: model!.id, model_name: model!.name}));
        }
    } else if (name === 'promptPreset') {
        if (value === 'default') return;
        const preset = promptPresets.find(p => p.id === value);
        if (preset) {
            setConfig(prev => ({...prev, system_prompt_persona: preset.content}));
        }
    }
  };

  const handleToggleMcpTool = (toolName: string) => {
    setConfig(prev => {
        const currentTools = prev.mcpTools || [];
        const isSelected = currentTools.some(t => t.toolName === toolName);
        if (isSelected) {
            return { ...prev, mcpTools: currentTools.filter(t => t.toolName !== toolName) };
        } else {
            return { ...prev, mcpTools: [...currentTools, { toolName }] };
        }
    });
  };
  
  const handleSavePreset = () => {
    if (newPresetName.trim() && config.system_prompt_persona.trim()) {
        onAddPreset(newPresetName, config.system_prompt_persona);
        setNewPresetName(''); // Clear input after saving
    } else {
        alert('Preset name and persona content cannot be empty.');
    }
  };
  
  const handleRefreshModels = async () => {
    setIsRefreshingModels(true);
    try {
        await onRefreshModels();
    } catch(e) {
        alert(`Failed to refresh models: ${e}`);
    } finally {
        setIsRefreshingModels(false);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (nameError) return;
    if (!config.name.trim()) {
      setNameError("Minion Name cannot be empty.");
      return;
    }
    if (selectedDropdownModel === 'custom-model-entry' && !config.model_id.trim()) {
      alert("Custom Model ID cannot be empty.");
      return;
    }
    onSave(config);
  };

  return (
    <>
    <form onSubmit={handleSubmit} className="space-y-5 text-neutral-700">
      <div className="grid grid-cols-2 gap-4">
        <div>
            <label htmlFor="name" className="block text-sm font-medium text-neutral-600 mb-1">Minion Name (Unique)</label>
            <input type="text" name="name" id="name" value={config.name} onChange={handleChange}
            className="w-full px-3 py-1 bg-white text-neutral-900 border border-zinc-300 rounded-md shadow-sm focus:border-amber-500 sm:text-sm placeholder-neutral-400"
            placeholder="e.g., Alpha" required />
            {nameError && <p className="mt-1 text-xs text-red-500">{nameError}</p>}
        </div>
        <div>
            <label htmlFor="role" className="block text-sm font-medium text-neutral-600 mb-1">Role</label>
            <select name="role" id="role" value={config.role} onChange={handleChange}
            className="w-full px-3 py-1 bg-white text-neutral-900 border border-zinc-300 rounded-md shadow-sm focus:ring-amber-500 focus:border-amber-500 sm:text-sm">
                <option value="standard">Standard</option>
                <option value="regulator">Regulator</option>
            </select>
        </div>
      </div>
      
       <div>
        <label htmlFor="apiKeyId" className="block text-sm font-medium text-neutral-600 mb-1">Assigned API Key</label>
        <select name="apiKeyId" id="apiKeyId" value={config.apiKeyId || "default"} onChange={handleSelectChange}
          className="w-full px-3 py-1 bg-white text-neutral-900 border border-zinc-300 rounded-md shadow-sm focus:ring-amber-500 focus:border-amber-500 sm:text-sm"
          disabled={apiKeys.length === 0}>
          <option value="default">Default (Load Balanced)</option>
          {apiKeys.map(key => (
            <option key={key.id} value={key.id}>{key.name}</option>
          ))}
        </select>
        {apiKeys.length === 0 && <p className="mt-1 text-xs text-neutral-500">Add keys in the Minion Roster to assign them.</p>}
      </div>
      
      <div>
        <label htmlFor="model_id_select" className="block text-sm font-medium text-neutral-600 mb-1">Model</label>
        <div className="flex items-center gap-2">
            <select name="model_id_select" id="model_id_select" value={selectedDropdownModel} onChange={handleSelectChange}
            className="flex-grow w-full px-3 py-1 bg-white text-neutral-900 border border-zinc-300 rounded-md shadow-sm focus:ring-amber-500 focus:border-amber-500 sm:text-sm">
            {modelOptions.map(model => (
                <option key={model.id} value={model.id}>{model.name}</option>
            ))}
            </select>
            <button type="button" onClick={handleRefreshModels} disabled={isRefreshingModels} className="p-2.5 bg-neutral-500 hover:bg-neutral-600 rounded-md transition-colors disabled:opacity-50 disabled:cursor-wait" title="Refresh Model List">
                {isRefreshingModels ? <Spinner size="sm" color="text-white"/> : <RefreshIcon className="w-5 h-5 text-zinc-50"/>}
            </button>
        </div>
      </div>

      {selectedDropdownModel === 'custom-model-entry' && (
        <div className="space-y-4 p-4 border border-zinc-300 rounded-md bg-zinc-100/70">
           <div>
              <label htmlFor="model_id" className="block text-sm font-medium text-neutral-600 mb-1">Custom Model ID</label>
              <input type="text" name="model_id" id="model_id" value={config.model_id} onChange={handleChange}
                className="w-full px-3 py-1 bg-white text-neutral-900 border border-zinc-300 rounded-md shadow-sm focus:ring-amber-500 focus:border-amber-500 sm:text-sm placeholder-neutral-400"
                placeholder="Enter exact 'model_name' from LiteLLM config" required />
           </div>
           <div>
              <label htmlFor="model_name" className="block text-sm font-medium text-neutral-600 mb-1">Custom Model Name (Optional)</label>
              <input type="text" name="model_name" id="model_name" value={config.model_name || ''} onChange={handleChange}
                className="w-full px-3 py-1 bg-white text-neutral-900 border border-zinc-300 rounded-md shadow-sm focus:ring-amber-500 focus:border-amber-500 sm:text-sm placeholder-neutral-400"
                placeholder="e.g., My Custom GPT-4o" />
           </div>
        </div>
      )}

      {config.role === 'regulator' && (
         <div className="p-4 border border-teal-300 rounded-md bg-teal-50/70">
            <label htmlFor="regulationInterval" className="block text-sm font-medium text-teal-700 mb-1">Regulation Interval</label>
            <input type="number" name="regulationInterval" id="regulationInterval" value={config.regulationInterval} onChange={handleChange}
              className="w-full px-3 py-1 bg-white text-neutral-900 border border-zinc-300 rounded-md shadow-sm focus:ring-amber-500 focus:border-amber-500 sm:text-sm placeholder-neutral-400"
              min="2" />
             <p className="mt-1 text-xs text-neutral-500">Regulator will post a report after this many messages.</p>
         </div>
      )}

      {config.role === 'standard' && availableMcpTools.length > 0 && (
         <div className="p-4 border border-gray-300 rounded-md bg-gray-100/70">
            <label className="block text-sm font-medium text-gray-700 mb-2">Available MCP Tools</label>
            <div className="space-y-2 max-h-32 overflow-y-auto pr-2">
                {availableMcpTools.map(tool => (
                    <div key={`${tool.serverId}-${tool.name}`} className="flex items-center">
                        <input
                            type="checkbox"
                            id={`tool-${tool.name}`}
                            checked={config.mcpTools?.some(t => t.toolName === tool.name) || false}
                            onChange={() => handleToggleMcpTool(tool.name)}
                            className="h-4 w-4 rounded border-gray-400 text-amber-600 focus:ring-amber-500"
                        />
                        <label htmlFor={`tool-${tool.name}`} className="ml-2 text-sm text-gray-700">
                            <span className="font-semibold">{tool.name}</span>
                            <span className="text-gray-500 ml-2">({tool.serverName})</span>
                            {tool.description && <p className="text-xs text-gray-500">{tool.description}</p>}
                        </label>
                    </div>
                ))}
            </div>
         </div>
      )}


      <div>
        <label htmlFor="system_prompt_persona" className="block text-sm font-medium text-neutral-600 mb-1">System Prompt</label>
        <div className="flex gap-2 mb-2">
            <select name="promptPreset" id="promptPreset" onChange={handleSelectChange} defaultValue="default"
              className="flex-grow w-full px-3 py-1 bg-white text-neutral-900 border border-zinc-300 rounded-md shadow-sm focus:ring-amber-500 focus:border-amber-500 sm:text-sm">
              <option value="default" disabled>Load a preset...</option>
              {promptPresets.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
            </select>
            <button type="button" onClick={() => setIsPresetModalOpen(true)} className="px-3 py-2 text-sm bg-neutral-200 hover:bg-neutral-300 rounded-md text-neutral-700">Manage</button>
        </div>
        <textarea name="system_prompt_persona" id="system_prompt_persona" value={config.system_prompt_persona} onChange={handleChange} rows={8}
          className="w-full px-3 py-1 bg-white text-neutral-900 border border-zinc-300 rounded-md shadow-sm focus:ring-amber-500 focus:border-amber-500 sm:text-sm placeholder-neutral-400"
          placeholder="Describe the Minion's personality, core directives, skills, quirks, etc." />
         <div className="flex gap-2 mt-2">
            <input 
                type="text"
                value={newPresetName}
                onChange={(e) => setNewPresetName(e.target.value)}
                placeholder="New Preset Name"
                className="flex-grow w-full px-3 py-1 bg-white text-neutral-900 border border-zinc-300 rounded-md shadow-sm focus:ring-amber-500 focus:border-amber-500 sm:text-sm placeholder-neutral-400"
            />
            <button 
                type="button" 
                onClick={handleSavePreset} 
                disabled={!newPresetName.trim() || !config.system_prompt_persona.trim()}
                className="px-4 py-1 text-sm text-white bg-teal-600 hover:bg-teal-700 rounded-md disabled:bg-neutral-300 disabled:cursor-not-allowed transition-colors"
            >
                Save Preset
            </button>
        </div>
      </div>

      <div>
        <label htmlFor="temperature" className="block text-sm font-medium text-neutral-700 mb-1">Temperature: {config.params.temperature.toFixed(2)}</label>
        <input type="range" name="temperature" id="temperature" min="0" max="1" step="0.01" value={config.params.temperature} onChange={handleChange}
          className="w-full h-2 bg-neutral-200 rounded-lg appearance-none cursor-pointer accent-amber-500" />
      </div>
      
      <div className="flex justify-end gap-3 pt-4">
        <button type="button" onClick={onCancel} className="px-4 py-1 text-sm font-medium text-neutral-700 bg-neutral-200 hover:bg-neutral-300 rounded-md shadow-sm transition-colors">Cancel</button>
        <button type="submit" disabled={!!nameError || !config.name.trim()} className="px-4 py-1 text-sm font-medium text-zinc-50 bg-amber-500 hover:bg-amber-600 rounded-md shadow-sm transition-colors disabled:opacity-50 disabled:cursor-not-allowed">Save Minion Configuration</button>
      </div>
    </form>
    <Modal isOpen={isPresetModalOpen} onClose={() => setIsPresetModalOpen(false)} title="Manage Persona Presets" size="md">
        <PromptPresetManager presets={promptPresets} onDelete={onDeletePreset} />
    </Modal>
    </>
  );
};

export default MinionConfigForm;

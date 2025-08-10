import React, { useState, useEffect } from 'react';
import { mcpElectronService, McpServerConfig, McpServerProcess } from '../services/mcpElectronService';

interface McpServerManagerProps {
  isOpen: boolean;
  onClose: () => void;
}

const McpServerManager: React.FC<McpServerManagerProps> = ({ isOpen, onClose }) => {
  const [servers, setServers] = useState<McpServerProcess[]>([]);
  const [configs, setConfigs] = useState<McpServerConfig[]>([]);
  const [isAddingServer, setIsAddingServer] = useState(false);
  const [newServerForm, setNewServerForm] = useState({
    name: '',
    command: [''],
    args: [''],
    env: {} as Record<string, string>,
    enabled: true,
    description: ''
  });
  const [envInput, setEnvInput] = useState('');

  useEffect(() => {
    if (isOpen) {
      loadServers();
      setupEventListeners();
    }
    return () => {
      cleanupEventListeners();
    };
  }, [isOpen]);

  const loadServers = async () => {
    try {
      const data = await mcpElectronService.getServers();
      setServers(data.servers);
      setConfigs(data.configs);
    } catch (error) {
      console.error('Failed to load MCP servers:', error);
    }
  };

  const setupEventListeners = () => {
    mcpElectronService.addEventListener('mcp:server-status-changed', handleServerStatusChange);
    mcpElectronService.addEventListener('mcp:server-added', handleServerAdded);
    mcpElectronService.addEventListener('mcp:server-removed', handleServerRemoved);
    mcpElectronService.addEventListener('mcp:server-tools-updated', handleToolsUpdated);
  };

  const cleanupEventListeners = () => {
    mcpElectronService.removeEventListener('mcp:server-status-changed', handleServerStatusChange);
    mcpElectronService.removeEventListener('mcp:server-added', handleServerAdded);
    mcpElectronService.removeEventListener('mcp:server-removed', handleServerRemoved);
    mcpElectronService.removeEventListener('mcp:server-tools-updated', handleToolsUpdated);
  };

  const handleServerStatusChange = (data: any) => {
    setServers(prev => prev.map(server => 
      server.id === data.serverId 
        ? { ...server, status: data.status, lastError: data.error }
        : server
    ));
  };

  const handleServerAdded = (server: McpServerProcess) => {
    setServers(prev => [...prev, server]);
  };

  const handleServerRemoved = (data: any) => {
    setServers(prev => prev.filter(server => server.id !== data.serverId));
  };

  const handleToolsUpdated = (data: any) => {
    setServers(prev => prev.map(server => 
      server.id === data.serverId 
        ? { ...server, tools: data.tools }
        : server
    ));
  };

  const handleAddServer = async () => {
    try {
      const env: Record<string, string> = {};
      if (envInput.trim()) {
        envInput.split('\n').forEach(line => {
          const [key, value] = line.split('=', 2);
          if (key && value) {
            env[key.trim()] = value.trim();
          }
        });
      }

      if (!newServerForm.name.trim()) {
        alert('Server name is required');
        return;
      }
      
      const commandArray = newServerForm.command.filter(cmd => cmd.trim());
      if (commandArray.length === 0) {
        alert('Command is required');
        return;
      }

      const config: Omit<McpServerConfig, 'id'> = {
        name: newServerForm.name.trim(),
        command: commandArray,
        args: newServerForm.args.filter(arg => arg.trim()),
        env,
        enabled: newServerForm.enabled,
        metadata: {
          description: newServerForm.description.trim()
        }
      };

      await mcpElectronService.addServer(config);
      setIsAddingServer(false);
      resetForm();
      loadServers();
    } catch (error) {
      console.error('Failed to add MCP server:', error);
    }
  };

  const handleStartStop = async (serverId: string, currentStatus: string) => {
    try {
      if (currentStatus === 'running') {
        await mcpElectronService.stopServer(serverId);
      } else {
        await mcpElectronService.startServer(serverId);
      }
    } catch (error) {
      console.error('Failed to start/stop server:', error);
    }
  };

  const handleRemoveServer = async (serverId: string) => {
    if (confirm('Are you sure you want to remove this MCP server?')) {
      try {
        await mcpElectronService.removeServer(serverId);
        loadServers();
      } catch (error) {
        console.error('Failed to remove server:', error);
      }
    }
  };

  const resetForm = () => {
    setNewServerForm({
      name: '',
      command: [''],
      args: [''],
      env: {},
      enabled: true,
      description: ''
    });
    setEnvInput('');
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'running': return 'text-green-600';
      case 'starting': return 'text-yellow-500';
      case 'stopping': return 'text-orange-500';
      case 'error': return 'text-red-600';
      default: return 'text-neutral-500';
    }
  };

  const getStatusDot = (status: string) => {
    switch (status) {
      case 'running': return 'bg-green-500';
      case 'starting': return 'bg-yellow-400 animate-pulse';
      case 'stopping': return 'bg-orange-400 animate-pulse';
      case 'error': return 'bg-red-500';
      default: return 'bg-neutral-400';
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-zinc-50 text-neutral-800 rounded-lg w-full max-w-4xl h-3/4 flex flex-col">
        <div className="p-4 border-b border-zinc-200">
          <div className="flex justify-between items-center">
            <h2 className="text-xl font-bold text-neutral-900">MCP Server Manager</h2>
            <button
              onClick={onClose}
              className="text-neutral-500 hover:text-neutral-800 text-2xl"
            >
              ×
            </button>
          </div>
        </div>

        <div className="flex-1 p-4 overflow-y-auto scrollbar-thin scrollbar-thumb-neutral-400 scrollbar-track-zinc-200">
          <div className="mb-4">
            <button
              onClick={() => setIsAddingServer(true)}
              className="bg-amber-500 hover:bg-amber-600 text-white px-4 py-2 rounded-md"
            >
              + Add MCP Server
            </button>
          </div>

          {isAddingServer && (
            <div className="bg-zinc-100 rounded-lg p-4 mb-4">
              <h3 className="text-lg font-semibold text-neutral-800 mb-3">Add New MCP Server</h3>
              
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-neutral-600 mb-1">Server Name</label>
                  <input
                    type="text"
                    value={newServerForm.name}
                    onChange={(e) => setNewServerForm(prev => ({ ...prev, name: e.target.value }))}
                    className="w-full bg-white text-neutral-900 border-zinc-300 px-3 py-2 rounded-md"
                    placeholder="e.g., Filesystem Server"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-neutral-600 mb-1">Description</label>
                  <input
                    type="text"
                    value={newServerForm.description}
                    onChange={(e) => setNewServerForm(prev => ({ ...prev, description: e.target.value }))}
                    className="w-full bg-white text-neutral-900 border-zinc-300 px-3 py-2 rounded-md"
                    placeholder="Brief description"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-neutral-600 mb-1">Command</label>
                  <input
                    type="text"
                    value={newServerForm.command.join(' ')}
                    onChange={(e) => setNewServerForm(prev => ({ 
                      ...prev, 
                      command: e.target.value.split(' ').filter(cmd => cmd.trim())
                    }))}
                    className="w-full bg-white text-neutral-900 border-zinc-300 px-3 py-2 rounded-md"
                    placeholder="e.g., node server.js"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-neutral-600 mb-1">Arguments</label>
                  <input
                    type="text"
                    value={newServerForm.args.join(' ')}
                    onChange={(e) => setNewServerForm(prev => ({ 
                      ...prev, 
                      args: e.target.value.split(' ').filter(arg => arg.trim())
                    }))}
                    className="w-full bg-white text-neutral-900 border-zinc-300 px-3 py-2 rounded-md"
                    placeholder="Additional arguments"
                  />
                </div>
              </div>

              <div className="mt-4">
                <label className="block text-sm font-medium text-neutral-600 mb-1">Environment Variables</label>
                <textarea
                  value={envInput}
                  onChange={(e) => setEnvInput(e.target.value)}
                  className="w-full bg-white text-neutral-900 border-zinc-300 px-3 py-2 rounded-md h-20"
                  placeholder={`KEY1=value1
KEY2=value2`}
                />
              </div>

              <div className="mt-4 flex items-center">
                <input
                  type="checkbox"
                  id="enabled"
                  checked={newServerForm.enabled}
                  onChange={(e) => setNewServerForm(prev => ({ ...prev, enabled: e.target.checked }))}
                  className="mr-2 h-4 w-4 rounded text-amber-600 focus:ring-amber-500"
                />
                <label htmlFor="enabled" className="text-neutral-700">Start automatically</label>
              </div>

              <div className="mt-4 flex space-x-2">
                <button
                  onClick={handleAddServer}
                  className="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-md"
                >
                  Add Server
                </button>
                <button
                  onClick={() => {
                    setIsAddingServer(false);
                    resetForm();
                  }}
                  className="bg-neutral-500 hover:bg-neutral-600 text-white px-4 py-2 rounded-md"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}

          <div className="space-y-3">
            {servers.map(server => (
              <div key={server.id} className="bg-white rounded-lg p-4 shadow-sm">
                <div className="flex justify-between items-start">
                  <div className="flex-1">
                    <div className="flex items-center space-x-2 mb-2">
                      <div className={`w-3 h-3 rounded-full ${getStatusDot(server.status)}`}></div>
                      <h3 className="text-lg font-semibold text-neutral-800">{server.name}</h3>
                      <span className={`text-sm ${getStatusColor(server.status)} capitalize`}>
                        {server.status}
                      </span>
                    </div>
                    
                    <div className="text-sm text-neutral-600 space-y-1">
                      <p><strong>Command:</strong> {server.command.join(' ')} {server.args.join(' ')}</p>
                      {server.pid && <p><strong>PID:</strong> {server.pid}</p>}
                      {server.tools.length > 0 && (
                        <p><strong>Tools:</strong> {server.tools.map(t => t.name).join(', ')}</p>
                      )}
                      {server.lastError && (
                        <p className="text-red-500"><strong>Error:</strong> {server.lastError}</p>
                      )}
                    </div>
                  </div>

                  <div className="flex space-x-2">
                    <button
                      onClick={() => handleStartStop(server.id, server.status)}
                      disabled={server.status === 'starting' || server.status === 'stopping'}
                      className={`px-3 py-1 rounded-md text-sm ${
                        server.status === 'running'
                          ? 'bg-red-600 hover:bg-red-700 text-white'
                          : 'bg-green-600 hover:bg-green-700 text-white'
                      } disabled:opacity-50`}
                    >
                      {server.status === 'running' ? 'Stop' : 'Start'}
                    </button>
                    <button
                      onClick={() => handleRemoveServer(server.id)}
                      className="bg-red-600 hover:bg-red-700 text-white px-3 py-1 rounded-md text-sm"
                    >
                      Remove
                    </button>
                  </div>
                </div>
              </div>
            ))}

            {servers.length === 0 && (
              <div className="text-center text-neutral-500 py-8">
                <p>No MCP servers configured.</p>
                <p className="text-sm">Click "Add MCP Server" to get started.</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default McpServerManager;
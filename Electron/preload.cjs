const { contextBridge, ipcRenderer } = require('electron');

// Expose protected methods that allow the renderer process to use
// the ipcRenderer without exposing the entire object
contextBridge.exposeInMainWorld('electronAPI', {
  // MCP Server Management
  invoke: (channel, ...args) => {
    // Whitelist channels for security
    const validChannels = [
      'mcp:get-servers',
      'mcp:add-server',
      'mcp:update-server',
      'mcp:remove-server',
      'mcp:start-server',
      'mcp:stop-server',
      'mcp:get-available-tools',
      'mcp:call-tool',
      'store:get',
      'store:set',
      'store:migrate'
    ];
    
    if (validChannels.includes(channel)) {
      return ipcRenderer.invoke(channel, ...args);
    }
  },

  // Event listeners for MCP events
  onMcpEvent: (callback) => {
    const validEventChannels = [
      'mcp:server-status-changed',
      'mcp:server-tools-updated',
      'mcp:server-added',
      'mcp:server-removed'
    ];

    // Set up listeners for all valid MCP event channels
    validEventChannels.forEach(channel => {
      ipcRenderer.on(channel, (event, ...args) => {
        callback(channel, ...args);
      });
    });

    // Return cleanup function
    return () => {
      validEventChannels.forEach(channel => {
        ipcRenderer.removeAllListeners(channel);
      });
    };
  },

  // Platform info
  platform: process.platform,
  
  // App version info (if needed)
  getAppVersion: () => ipcRenderer.invoke('app:get-version')
});

// Also expose a global flag so the app knows it's running in Electron
contextBridge.exposeInMainWorld('isElectron', true);

const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const { spawn } = require('child_process');
const fs = require('fs').promises;
const { EventEmitter } = require('events');
const contextMenu = require('electron-context-menu');



// MCP Server Management
class McpProcessManager extends EventEmitter {
  constructor() {
    super();
    this.servers = new Map();
    this.processCleanupHandlers = new Map();
  }

  async addServer(config) {
    const server = {
      id: config.id || `mcp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      name: config.name,
      command: config.command,
      args: config.args || [],
      env: { ...process.env, ...config.env },
      enabled: config.enabled ?? true,
      status: 'stopped',
      tools: [],
      permissions: config.permissions || { allowedLLMs: [], toolPermissions: {} }
    };

    this.servers.set(server.id, server);
    this.emit('server-added', server);
    
    if (server.enabled) {
      await this.startServer(server.id);
    }
    
    return server.id;
  }

  async startServer(serverId) {
    const server = this.servers.get(serverId);
    if (!server || server.status === 'running' || server.status === 'starting') return;

    server.status = 'starting';
    this.emit('server-status-changed', serverId, 'starting');

    try {
      // Validate and extract command
      if (!server.command || (Array.isArray(server.command) && server.command.length === 0)) {
        throw new Error('No command specified for MCP server');
      }
      
      const command = Array.isArray(server.command) ? server.command[0] : server.command;
      const commandArgs = Array.isArray(server.command) ? server.command.slice(1) : [];
      const allArgs = [...commandArgs, ...(server.args || [])];
      
      if (!command || command.trim() === '') {
        throw new Error('Empty command specified for MCP server');
      }
      
      console.log(`Starting MCP server "${server.name}": ${command} ${allArgs.join(' ')}`);
      
      const childProcess = spawn(command.trim(), allArgs, {
        stdio: ['pipe', 'pipe', 'pipe'],
        env: { ...process.env, ...server.env },
        detached: false,
        cwd: process.cwd() // Use the app's working directory
      });

      server.process = childProcess;
      server.pid = childProcess.pid;

      // Set up process cleanup
      const cleanup = () => {
        server.process = undefined;
        server.pid = undefined;
        server.status = 'stopped';
        this.emit('server-status-changed', serverId, 'stopped');
      };

      this.processCleanupHandlers.set(serverId, cleanup);

      childProcess.on('error', (error) => {
        server.lastError = error.message;
        server.status = 'error';
        this.emit('server-status-changed', serverId, 'error', error.message);
        cleanup();
      });

      childProcess.on('exit', (code, signal) => {
        if (server.status !== 'stopping') {
          server.lastError = `Process exited with code ${code}, signal ${signal}`;
          server.status = 'error';
          this.emit('server-status-changed', serverId, 'error', server.lastError);
        }
        cleanup();
      });

      // Try to connect via MCP SDK to discover actual tools
      setTimeout(async () => {
        try {
          // Import MCP SDK dynamically since this is CommonJS
          const { Client } = await import('@modelcontextprotocol/sdk/client/index.js');
          const { StdioClientTransport } = await import('@modelcontextprotocol/sdk/client/stdio.js');
          
          // Create MCP client
          const client = new Client({
            name: "Legion C&C Client",
            version: "1.0.0"
          });
          
          // Create stdio transport with command and args instead of process
          const transport = new StdioClientTransport({
            command: command.trim(),
            args: allArgs
          });
          
          // Connect to the MCP server  
          await client.connect(transport);
          
          // Discover tools
          const toolsResult = await client.listTools();
          server.tools = toolsResult.tools || [];
          server.client = client;
          server.transport = transport;
          
          server.status = 'running';
          this.emit('server-status-changed', serverId, 'running');
          this.emit('server-tools-updated', serverId, server.tools);
          
        } catch (error) {
          console.error(`Failed to connect to MCP server ${server.name}:`, error);
          // Fallback - assume it's running but no tools discovered
          server.tools = [];
          server.status = 'running';
          server.lastError = `Failed to discover tools: ${error.message}`;
          this.emit('server-status-changed', serverId, 'running');
        }
      }, 2000);

    } catch (error) {
      server.lastError = error.message;
      server.status = 'error';
      this.emit('server-status-changed', serverId, 'error', server.lastError);
    }
  }

  async stopServer(serverId) {
    const server = this.servers.get(serverId);
    if (!server || server.status === 'stopped' || server.status === 'stopping') return;

    server.status = 'stopping';
    this.emit('server-status-changed', serverId, 'stopping');

    const cleanup = this.processCleanupHandlers.get(serverId);
    if (server.process && !server.process.killed) {
      server.process.kill('SIGTERM');
      
      // Force kill after 5 seconds if it doesn't exit gracefully
      setTimeout(() => {
        if (server.process && !server.process.killed) {
          server.process.kill('SIGKILL');
        }
      }, 5000);
    }

    if (cleanup) {
      cleanup();
      this.processCleanupHandlers.delete(serverId);
    }
  }

  async callTool(serverId, toolCall) {
    const server = this.servers.get(serverId);
    if (!server) {
      throw new Error(`MCP server ${serverId} not found`);
    }
    
    if (server.status !== 'running' || !server.client) {
      throw new Error(`MCP server ${serverId} is not running or client not available`);
    }
    
    try {
      const result = await server.client.callTool(toolCall);
      return result;
    } catch (error) {
      console.error(`Error calling tool on MCP server ${serverId}:`, error);
      throw error;
    }
  }

  async removeServer(serverId) {
    await this.stopServer(serverId);
    this.servers.delete(serverId);
    this.emit('server-removed', serverId);
  }

  getServerList() {
    return Array.from(this.servers.values());
  }

  getServerById(serverId) {
    return this.servers.get(serverId);
  }

  async gracefulShutdown() {
    const shutdownPromises = Array.from(this.servers.keys()).map(id => this.stopServer(id));
    await Promise.all(shutdownPromises);
  }
}

// Configuration Management
class McpConfigManager {
  constructor() {
    const userDataPath = app.getPath('userData');
    this.configPath = path.join(userDataPath, 'mcp-servers.json');
    this.configs = new Map();
  }

  async loadConfigs() {
    try {
      const data = await fs.readFile(this.configPath, 'utf-8');
      const configs = JSON.parse(data);
      
      for (const config of configs) {
        if (!config.id) {
          config.id = `mcp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        }
        this.configs.set(config.id, config);
      }
    } catch (error) {
      if (error.code !== 'ENOENT') {
        console.error('Failed to load MCP configs:', error);
      }
    }
  }

  async saveConfigs() {
    const configArray = Array.from(this.configs.values());
    await fs.writeFile(this.configPath, JSON.stringify(configArray, null, 2));
  }

  async addConfig(config) {
    const id = `mcp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const fullConfig = { ...config, id };
    this.configs.set(id, fullConfig);
    await this.saveConfigs();
    return id;
  }

  async updateConfig(id, updates) {
    const existing = this.configs.get(id);
    if (!existing) throw new Error(`Config ${id} not found`);
    
    this.configs.set(id, { ...existing, ...updates });
    await this.saveConfigs();
  }

  async removeConfig(id) {
    this.configs.delete(id);
    await this.saveConfigs();
  }

  getConfig(id) {
    return this.configs.get(id);
  }

  getAllConfigs() {
    return Array.from(this.configs.values());
  }
}

// Global instances
let mainWindow;
let mcpProcessManager;
let mcpConfigManager;
let store;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 800,
    minHeight: 600,
    titleBarStyle: 'hiddenInset',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      enableRemoteModule: false,
      preload: path.join(__dirname, 'preload.cjs')
    },
    show: false
  });

  // Load the app
  const isDev = process.env.NODE_ENV === 'development';
  if (isDev) {
    // Try different dev server ports
    const ports = [5173, 5174, 5175, 3000];
    let currentPortIndex = 0;
    
    const tryLoadDevServer = () => {
      if (currentPortIndex >= ports.length) {
        console.error('Could not connect to dev server on any port');
        return;
      }
      
      const port = ports[currentPortIndex];
      mainWindow.loadURL(`http://localhost:${port}`);
      
      mainWindow.webContents.once('did-fail-load', () => {
        currentPortIndex++;
        setTimeout(tryLoadDevServer, 1000);
      });
    };
    
    tryLoadDevServer();
  } else {
    mainWindow.loadFile(path.join(__dirname, '../dist/index.html'));
  }

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  // Handle external links
  mainWindow.webContents.setWindowOpenHandler(() => {
    return { action: 'deny' };
  });

  mainWindow.webContents.on('will-navigate', (event, url) => {
    if (url !== mainWindow.webContents.getURL()) {
      event.preventDefault();
    }
  });
}

// IPC Handlers
function setupIpcHandlers() {
  // MCP Server Management
  ipcMain.handle('mcp:get-servers', () => {
    // Serialize objects to avoid cloning issues
    const servers = mcpProcessManager.getServerList().map(server => ({
      id: server.id,
      name: server.name,
      command: server.command,
      args: server.args,
      env: server.env,
      enabled: server.enabled,
      status: server.status,
      lastError: server.lastError,
      tools: server.tools,
      permissions: server.permissions,
      pid: server.pid
    }));
    
    const configs = mcpConfigManager.getAllConfigs().map(config => ({
      id: config.id,
      name: config.name,
      command: config.command,
      args: config.args,
      env: config.env,
      enabled: config.enabled,
      permissions: config.permissions,
      metadata: config.metadata
    }));
    
    return { servers, configs };
  });

  ipcMain.handle('mcp:add-server', async (_, config) => {
    try {
      const configId = await mcpConfigManager.addConfig(config);
      const serverId = await mcpProcessManager.addServer({ ...config, id: configId });
      return { configId, serverId };
    } catch (error) {
      console.error('Error adding server:', error);
      throw new Error(`Failed to add server: ${error.message}`);
    }
  });

  ipcMain.handle('mcp:update-server', async (_, id, updates) => {
    await mcpConfigManager.updateConfig(id, updates);
    // Restart server if it's running to pick up changes
    const server = mcpProcessManager.getServerById(id);
    if (server && server.status === 'running') {
      await mcpProcessManager.stopServer(id);
      const updatedConfig = mcpConfigManager.getConfig(id);
      if (updatedConfig) {
        await mcpProcessManager.addServer(updatedConfig);
      }
    }
    return true;
  });

  ipcMain.handle('mcp:remove-server', async (_, id) => {
    await mcpProcessManager.removeServer(id);
    await mcpConfigManager.removeConfig(id);
    return true;
  });

  ipcMain.handle('mcp:start-server', async (_, id) => {
    await mcpProcessManager.startServer(id);
    return true;
  });

  ipcMain.handle('mcp:stop-server', async (_, id) => {
    await mcpProcessManager.stopServer(id);
    return true;
  });

  ipcMain.handle('mcp:get-available-tools', (_, llmId) => {
    const servers = mcpProcessManager.getServerList();
    const availableTools = [];

    for (const server of servers) {
      if (server.status === 'running' && server.tools.length > 0) {
        let tools = server.tools;
        if (llmId) {
          const hasAccess = server.permissions.allowedLLMs.length === 0 || 
                          server.permissions.allowedLLMs.includes(llmId);
          if (hasAccess) {
            tools = server.tools.filter(tool => 
              server.permissions.toolPermissions[tool.name] !== false
            );
          } else {
            tools = [];
          }
        }

        if (tools.length > 0) {
          availableTools.push({
            serverId: server.id,
            serverName: server.name,
            tools
          });
        }
      }
    }

    return availableTools;
  });

  // Add IPC handler for calling MCP tools
  ipcMain.handle('mcp:call-tool', async (_, toolCall) => {
    const { name, arguments: args } = toolCall;
    
    // Find which server has this tool
    let targetServer = null;
    
    const servers = mcpProcessManager.getServerList();
    for (const server of servers) {
      if (server.status === 'running' && server.tools) {
        const hasTool = server.tools.some(tool => tool.name === name);
        if (hasTool) {
          targetServer = server;
          break;
        }
      }
    }
    
    if (!targetServer) {
      throw new Error(`Tool "${name}" not found in any connected MCP server`);
    }
    
    // Call the tool on the MCP server through the process manager
    try {
      const result = await mcpProcessManager.callTool(targetServer.id, { name, arguments: args });
      return result;
    } catch (error) {
      console.error(`Error calling tool "${name}" on server "${targetServer.id}":`, error);
      throw error;
    }
  });

  // Electron Store IPC Handlers
  ipcMain.handle('store:get', (_, key, defaultValue) => {
    return store.get(key, defaultValue);
  });

  ipcMain.handle('store:set', (_, key, value) => {
    store.set(key, value);
  });

  ipcMain.handle('store:migrate', (_, data) => {
    // This is a simple migration. For a real app, you might want more robust versioning.
    if (store.get('migration_complete_v1')) {
      return { success: true, message: 'Migration already completed.' };
    }
    try {
      for (const [key, value] of Object.entries(data)) {
        if (value !== null) { // Only migrate if data exists
          store.set(key, value);
        }
      }
      store.set('migration_complete_v1', true);
      return { success: true, message: 'Migration successful.' };
    } catch (error) {
      console.error('Migration from localStorage failed:', error);
      return { success: false, message: error.message };
    }
  });
}

// Event forwarding
function setupEventForwarding() {
  mcpProcessManager.on('server-status-changed', (serverId, status, error) => {
    mainWindow.webContents.send('mcp:server-status-changed', { 
      serverId: String(serverId), 
      status: String(status), 
      error: error ? String(error) : undefined 
    });
  });

  mcpProcessManager.on('server-tools-updated', (serverId, tools) => {
    mainWindow.webContents.send('mcp:server-tools-updated', { 
      serverId: String(serverId), 
      tools: Array.isArray(tools) ? tools.map(t => ({
        name: String(t.name),
        description: t.description ? String(t.description) : undefined
      })) : []
    });
  });

  mcpProcessManager.on('server-added', (server) => {
    const serializedServer = {
      id: String(server.id),
      name: String(server.name),
      command: Array.isArray(server.command) ? server.command.map(String) : [],
      args: Array.isArray(server.args) ? server.args.map(String) : [],
      env: server.env && typeof server.env === 'object' ? server.env : {},
      enabled: Boolean(server.enabled),
      status: String(server.status),
      lastError: server.lastError ? String(server.lastError) : undefined,
      tools: Array.isArray(server.tools) ? server.tools : [],
      permissions: server.permissions || { allowedLLMs: [], toolPermissions: {} },
      pid: server.pid ? Number(server.pid) : undefined
    };
    mainWindow.webContents.send('mcp:server-added', serializedServer);
  });

  mcpProcessManager.on('server-removed', (serverId) => {
    mainWindow.webContents.send('mcp:server-removed', { serverId: String(serverId) });
  });
}

// App lifecycle
app.whenReady().then(async () => {
  // Initialize managers
  const { default: Store } = await import('electron-store');
  store = new Store();
  mcpProcessManager = new McpProcessManager();
  mcpConfigManager = new McpConfigManager();
  
  // Load saved configs and start enabled servers
  await mcpConfigManager.loadConfigs();
  const configs = mcpConfigManager.getAllConfigs();
  for (const config of configs) {
    if (config.enabled) {
      await mcpProcessManager.addServer(config);
    }
  }

  setupIpcHandlers();
  createWindow();
  setupEventForwarding();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
contextMenu({
    window: mainWindow,
    showCopyImage: true,
    showSaveImageAs: true,
    showSaveImage: true,
    showSearchWithGoogle: true,
    showInspectElement: process.env.NODE_ENV === 'development'
});

setupEventForwarding();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('before-quit', async (event) => {
  event.preventDefault();
  console.log('Initiating graceful shutdown...');
  await mcpProcessManager.gracefulShutdown();
  console.log('All MCP servers stopped. Exiting...');
  app.exit(0);
});

// Handle various termination signals
process.on('SIGINT', async () => {
  await mcpProcessManager.gracefulShutdown();
  app.exit(0);
});

process.on('SIGTERM', async () => {
  await mcpProcessManager.gracefulShutdown();
  app.exit(0);
});
// MCP Electron Service - Handles communication between React app and Electron main process

interface McpServerConfig {
  id?: string;
  name: string;
  command: string[];
  args?: string[];
  env?: Record<string, string>;
  enabled?: boolean;
  permissions?: McpServerPermissions;
  metadata?: {
    description?: string;
    version?: string;
    author?: string;
    tags?: string[];
  };
}

interface McpServerPermissions {
  allowedLLMs: string[];
  toolPermissions: Record<string, boolean>;
}

interface McpServerProcess {
  id: string;
  name: string;
  command: string[];
  args: string[];
  env: Record<string, string>;
  enabled: boolean;
  status: 'stopped' | 'starting' | 'running' | 'error' | 'stopping';
  lastError?: string;
  tools: McpTool[];
  permissions: McpServerPermissions;
  pid?: number;
}

interface McpTool {
  name: string;
  description?: string;
  inputSchema?: any;
  serverId?: string;
  serverName?: string;
}

class McpElectronService {
  private eventListeners: Map<string, Set<Function>> = new Map();
  private cleanupFunction?: () => void;

  constructor() {
    if (typeof window !== 'undefined' && window.isElectron) {
      this.setupEventListeners();
    }
  }

  private setupEventListeners(): void {
    if (!window.electronAPI?.onMcpEvent) return;

    // Listen for main process events
    this.cleanupFunction = window.electronAPI.onMcpEvent((channel: string, data: any) => {
      const listeners = this.eventListeners.get(channel);
      if (listeners) {
        listeners.forEach(listener => listener(data));
      }
    });
  }

  addEventListener(event: string, listener: Function): void {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, new Set());
    }
    this.eventListeners.get(event)!.add(listener);
  }

  removeEventListener(event: string, listener: Function): void {
    const listeners = this.eventListeners.get(event);
    if (listeners) {
      listeners.delete(listener);
    }
  }

  async getServers(): Promise<{servers: McpServerProcess[], configs: McpServerConfig[]}> {
    if (!this.isElectronAvailable()) {
      return { servers: [], configs: [] };
    }
    return await window.electronAPI.invoke('mcp:get-servers');
  }

  async addServer(config: Omit<McpServerConfig, 'id'>): Promise<{configId: string, serverId: string}> {
    if (!this.isElectronAvailable()) {
      throw new Error('Electron API not available');
    }
    return await window.electronAPI.invoke('mcp:add-server', config);
  }

  async updateServer(id: string, updates: Partial<McpServerConfig>): Promise<boolean> {
    if (!this.isElectronAvailable()) {
      return false;
    }
    return await window.electronAPI.invoke('mcp:update-server', id, updates);
  }

  async removeServer(id: string): Promise<boolean> {
    if (!this.isElectronAvailable()) {
      return false;
    }
    return await window.electronAPI.invoke('mcp:remove-server', id);
  }

  async startServer(id: string): Promise<boolean> {
    if (!this.isElectronAvailable()) {
      return false;
    }
    return await window.electronAPI.invoke('mcp:start-server', id);
  }

  async stopServer(id: string): Promise<boolean> {
    if (!this.isElectronAvailable()) {
      return false;
    }
    return await window.electronAPI.invoke('mcp:stop-server', id);
  }

  async getAvailableTools(llmId?: string): Promise<Array<{serverId: string, serverName: string, tools: McpTool[]}>> {
    if (!this.isElectronAvailable()) {
      return [];
    }
    return await window.electronAPI.invoke('mcp:get-available-tools', llmId);
  }

  async callTool(toolCall: { name: string; arguments: any }): Promise<any> {
    if (!this.isElectronAvailable()) {
      throw new Error('MCP service only available in Electron environment');
    }
    return await window.electronAPI.invoke('mcp:call-tool', toolCall);
  }

  isElectronAvailable(): boolean {
    return typeof window !== 'undefined' && 
           window.isElectron && 
           !!window.electronAPI?.invoke;
  }

  // Cleanup method
  destroy(): void {
    if (this.cleanupFunction) {
      this.cleanupFunction();
    }
    this.eventListeners.clear();
  }
}

// Global instance
export const mcpElectronService = new McpElectronService();

// Type declarations for window object
declare global {
  interface Window {
    isElectron?: boolean;
    electronAPI?: {
      invoke: (channel: string, ...args: any[]) => Promise<any>;
      onMcpEvent: (callback: (channel: string, data: any) => void) => () => void;
      platform: string;
      getAppVersion: () => Promise<string>;
    };
  }
}

export type { McpServerConfig, McpServerProcess, McpTool, McpServerPermissions };

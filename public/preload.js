import { contextBridge, ipcRenderer } from 'electron';

// Expose protected methods that allow the renderer process to use
// the ipcRenderer without exposing the entire object
contextBridge.exposeInMainWorld('electronAPI', {
  // Window controls
  minimize: () => ipcRenderer.invoke('window-minimize'),
  maximize: () => ipcRenderer.invoke('window-maximize'),
  close: () => ipcRenderer.invoke('window-close'),
  
  // App info
  getVersion: () => ipcRenderer.invoke('app-version'),
  getPlatform: () => process.platform,
  
  // File system (if needed later)
  openFile: () => ipcRenderer.invoke('dialog-open-file'),
  saveFile: (content) => ipcRenderer.invoke('dialog-save-file', content),
  
  // System info
  getSystemInfo: () => ipcRenderer.invoke('get-system-info'),
  
  // Environment detection
  isDev: () => process.env.NODE_ENV === 'development',
  
  // Event listeners for renderer
  onAppUpdate: (callback) => ipcRenderer.on('app-update', callback),
  onAppError: (callback) => ipcRenderer.on('app-error', callback),
  
  // Remove listeners
  removeAllListeners: (channel) => ipcRenderer.removeAllListeners(channel)
});

// Expose Node.js process info safely
contextBridge.exposeInMainWorld('nodeAPI', {
  process: {
    platform: process.platform,
    arch: process.arch,
    versions: process.versions
  }
});

// Add some security logging
console.log('Preload script loaded successfully');

// Prevent any additional context bridge usage
Object.freeze(contextBridge);
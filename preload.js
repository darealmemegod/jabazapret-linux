const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('zapret', {
  // Window controls
  minimize: () => ipcRenderer.send('window-minimize'),
  maximize: () => ipcRenderer.send('window-maximize'),
  close:    () => ipcRenderer.send('window-close'),

  // Core
  getInterfaces:  () => ipcRenderer.invoke('get-interfaces'),
  getStrategies:  () => ipcRenderer.invoke('get-strategies'),
  checkNfqws:     () => ipcRenderer.invoke('check-nfqws'),
  downloadNfqws:  () => ipcRenderer.invoke('download-nfqws'),
  getStatus:      () => ipcRenderer.invoke('get-status'),

  start: (opts) => ipcRenderer.invoke('start-zapret', opts),
  stop:  ()     => ipcRenderer.invoke('stop-zapret'),

  // Service
  serviceInstall: (opts) => ipcRenderer.invoke('service-install', opts),
  serviceRemove:  ()     => ipcRenderer.invoke('service-remove'),
  serviceStatus:  ()     => ipcRenderer.invoke('service-status'),

  // Diagnostics
  runDiagnostics: () => ipcRenderer.invoke('run-diagnostics'),

  // Events
  onLog:    (cb) => ipcRenderer.on('log',    (_, d) => cb(d)),
  onStatus: (cb) => ipcRenderer.on('status', (_, d) => cb(d)),

  // Misc
  openUrl: (url) => ipcRenderer.send('open-url', url),
});

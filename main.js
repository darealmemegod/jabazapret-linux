const { app, BrowserWindow, ipcMain, shell } = require('electron');
const path = require('path');
const { spawn, exec } = require('child_process');
const fs = require('fs');
const os = require('os');

const APP_DIR = app.isPackaged
  ? path.dirname(process.execPath)
  : __dirname;

const SCRIPTS_DIR = path.join(APP_DIR, 'scripts');
const LISTS_DIR = path.join(APP_DIR, 'lists');
const BIN_DIR = path.join(APP_DIR, 'bin');

let mainWindow;
let nfqwsProcess = null;
let currentStrategy = null;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1100,
    height: 740,
    minWidth: 900,
    minHeight: 600,
    frame: false,
    titleBarStyle: 'hidden',
    backgroundColor: '#0a0c0f',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    icon: path.join(__dirname, 'renderer', 'icon.png'),
  });

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));
}

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  stopZapret(() => {});
  if (process.platform !== 'darwin') app.quit();
});

// ─── Window controls ───────────────────────────────────────────────────────────
ipcMain.on('window-minimize', () => mainWindow.minimize());
ipcMain.on('window-maximize', () => {
  mainWindow.isMaximized() ? mainWindow.unmaximize() : mainWindow.maximize();
});
ipcMain.on('window-close', () => {
  stopZapret(() => mainWindow.close());
});

// ─── Helpers ──────────────────────────────────────────────────────────────────
function sendLog(line, level = 'info') {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('log', { line, level, ts: Date.now() });
  }
}

function sendStatus(status) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('status', status);
  }
}

function runSudo(cmd, args, opts = {}) {
  // Try pkexec first (graphical sudo), fallback to sudo
  const sudoCmd = 'pkexec';
  return spawn(sudoCmd, [cmd, ...args], {
    ...opts,
    env: { ...process.env, ...opts.env }
  });
}

// ─── Get network interfaces ────────────────────────────────────────────────────
ipcMain.handle('get-interfaces', async () => {
  return new Promise((resolve) => {
    exec("ip -o link show | awk -F': ' '{print $2}' | grep -v lo", (err, stdout) => {
      if (err) {
        resolve(['eth0', 'wlan0', 'enp0s3', 'wlp2s0']);
        return;
      }
      const ifaces = stdout.trim().split('\n').map(s => s.trim()).filter(Boolean);
      resolve(ifaces.length ? ifaces : ['eth0']);
    });
  });
});

// ─── Get strategies ───────────────────────────────────────────────────────────
ipcMain.handle('get-strategies', async () => {
  const strats = [];
  try {
    const files = fs.readdirSync(SCRIPTS_DIR);
    for (const f of files) {
      if (f.startsWith('strategy-') && f.endsWith('.sh')) {
        const name = f.replace('strategy-', '').replace('.sh', '');
        const filepath = path.join(SCRIPTS_DIR, f);
        const content = fs.readFileSync(filepath, 'utf8');
        const descMatch = content.match(/^# DESC: (.+)$/m);
        const desc = descMatch ? descMatch[1] : name.toUpperCase();
        strats.push({ id: name, name: desc, file: filepath });
      }
    }
  } catch (e) {
    sendLog(`Error reading strategies: ${e.message}`, 'error');
  }
  return strats;
});

// ─── Check nfqws binary ───────────────────────────────────────────────────────
ipcMain.handle('check-nfqws', async () => {
  const binary = path.join(BIN_DIR, 'nfqws');
  const exists = fs.existsSync(binary);
  if (exists) {
    try { fs.chmodSync(binary, '755'); } catch {}
  }
  // Also check system-wide
  return new Promise((resolve) => {
    exec('which nfqws', (err, stdout) => {
      resolve({
        local: exists,
        system: !err && !!stdout.trim(),
        path: exists ? binary : (stdout || '').trim() || null
      });
    });
  });
});

// ─── Start zapret ─────────────────────────────────────────────────────────────
ipcMain.handle('start-zapret', async (event, { strategy, iface, gameFilter, ipsetFilter }) => {
  if (nfqwsProcess) {
    sendLog('Already running. Stop first.', 'warn');
    return { ok: false };
  }

  const scriptPath = path.join(SCRIPTS_DIR, `strategy-${strategy}.sh`);
  if (!fs.existsSync(scriptPath)) {
    sendLog(`Strategy script not found: ${scriptPath}`, 'error');
    return { ok: false };
  }

  currentStrategy = strategy;

  // Make executable
  try { fs.chmodSync(scriptPath, '755'); } catch {}

  const env = {
    ZAPRET_DIR: APP_DIR,
    BIN_DIR,
    LISTS_DIR,
    IFACE: iface || 'auto',
    GAME_FILTER: gameFilter ? '1' : '0',
    IPSET_FILTER: ipsetFilter || 'none',
  };

  sendLog(`Starting strategy: ${strategy}`, 'info');
  sendLog(`Interface: ${iface || 'auto'}`, 'info');
  sendStatus({ running: false, starting: true, strategy });

  const proc = spawn('bash', [scriptPath], {
    env: { ...process.env, ...env },
    stdio: ['ignore', 'pipe', 'pipe']
  });

  nfqwsProcess = proc;

  proc.stdout.on('data', (d) => {
    d.toString().split('\n').filter(Boolean).forEach(l => sendLog(l, 'info'));
  });

  proc.stderr.on('data', (d) => {
    d.toString().split('\n').filter(Boolean).forEach(l => {
      const lvl = l.toLowerCase().includes('error') ? 'error' :
                  l.toLowerCase().includes('warn') ? 'warn' : 'info';
      sendLog(l, lvl);
    });
  });

  proc.on('close', (code) => {
    nfqwsProcess = null;
    sendLog(`Process exited (code ${code})`, code === 0 ? 'info' : 'error');
    sendStatus({ running: false, starting: false, strategy: null });
  });

  proc.on('error', (err) => {
    sendLog(`Failed to start: ${err.message}`, 'error');
    nfqwsProcess = null;
    sendStatus({ running: false, starting: false, strategy: null });
  });

  // Give it a second then report running
  await new Promise(r => setTimeout(r, 1500));
  if (nfqwsProcess) {
    sendStatus({ running: true, starting: false, strategy });
    sendLog('✓ Zapret is active', 'success');
  }

  return { ok: true };
});

// ─── Stop zapret ──────────────────────────────────────────────────────────────
function stopZapret(cb) {
  const cleanup = path.join(SCRIPTS_DIR, 'cleanup.sh');
  exec(`bash "${cleanup}"`, () => {
    if (nfqwsProcess) {
      try { process.kill(-nfqwsProcess.pid, 'SIGTERM'); } catch {}
      try { nfqwsProcess.kill('SIGTERM'); } catch {}
      nfqwsProcess = null;
    }
    sendStatus({ running: false, starting: false, strategy: null });
    sendLog('Zapret stopped. Firewall rules cleaned.', 'info');
    if (cb) cb();
  });
}

ipcMain.handle('stop-zapret', async () => {
  return new Promise((resolve) => stopZapret(() => resolve({ ok: true })));
});

// ─── Service management ───────────────────────────────────────────────────────
ipcMain.handle('service-install', async (event, { strategy, iface }) => {
  const scriptPath = path.join(SCRIPTS_DIR, 'service-install.sh');
  exec(`bash "${scriptPath}" "${strategy}" "${iface || 'auto'}" "${APP_DIR}"`, (err, out, errout) => {
    sendLog(out || errout || (err ? err.message : 'Service installed'), err ? 'error' : 'success');
  });
  return { ok: true };
});

ipcMain.handle('service-remove', async () => {
  const scriptPath = path.join(SCRIPTS_DIR, 'service-remove.sh');
  exec(`bash "${scriptPath}"`, (err, out, errout) => {
    sendLog(out || errout || (err ? err.message : 'Service removed'), err ? 'error' : 'info');
  });
  return { ok: true };
});

ipcMain.handle('service-status', async () => {
  return new Promise((resolve) => {
    exec('systemctl is-active zapret 2>/dev/null || echo "inactive"', (err, out) => {
      resolve({ status: (out || 'inactive').trim() });
    });
  });
});

// ─── Diagnostics ──────────────────────────────────────────────────────────────
ipcMain.handle('run-diagnostics', async () => {
  const scriptPath = path.join(SCRIPTS_DIR, 'diagnostics.sh');
  const proc = spawn('bash', [scriptPath], {
    env: { ...process.env, BIN_DIR, LISTS_DIR, ZAPRET_DIR: APP_DIR }
  });
  proc.stdout.on('data', d => d.toString().split('\n').filter(Boolean).forEach(l => sendLog(l, 'info')));
  proc.stderr.on('data', d => d.toString().split('\n').filter(Boolean).forEach(l => sendLog(l, 'warn')));
  return { ok: true };
});

// ─── Download nfqws ───────────────────────────────────────────────────────────
ipcMain.handle('download-nfqws', async () => {
  const scriptPath = path.join(SCRIPTS_DIR, 'download-nfqws.sh');
  if (!fs.existsSync(scriptPath)) {
    sendLog('Download script not found', 'error');
    return { ok: false };
  }
  const proc = spawn('bash', [scriptPath], {
    env: { ...process.env, BIN_DIR }
  });
  proc.stdout.on('data', d => d.toString().split('\n').filter(Boolean).forEach(l => sendLog(l, 'info')));
  proc.stderr.on('data', d => d.toString().split('\n').filter(Boolean).forEach(l => sendLog(l, 'warn')));
  proc.on('close', (code) => {
    sendLog(code === 0 ? '✓ nfqws downloaded successfully' : '✗ Download failed', code === 0 ? 'success' : 'error');
  });
  return { ok: true };
});

// ─── Open external URL ────────────────────────────────────────────────────────
ipcMain.on('open-url', (event, url) => {
  shell.openExternal(url);
});

// ─── Get status ───────────────────────────────────────────────────────────────
ipcMain.handle('get-status', async () => {
  return {
    running: nfqwsProcess !== null,
    strategy: currentStrategy,
    platform: os.platform(),
    arch: os.arch(),
  };
});

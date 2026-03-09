# JabaZapret — Linux

**Linux port of [jabazapret](https://github.com/darealmemegod/jabazapret) / [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube)**

Electron GUI app for running [zapret](https://github.com/bol-van/zapret) (nfqws) DPI bypass on Linux.
Bypasses DPI restrictions on Discord, YouTube, and other blocked services.

---

## Requirements

| Requirement | Install |
|---|---|
| Node.js ≥ 18 | https://nodejs.org |
| nftables | `sudo apt install nftables` |
| curl | usually pre-installed |
| sudo access | needed for nft rules |

---

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/darealmemegod/jabazapret
cd jabazapret

# 2. Copy this Linux folder
cp -r linux-port/ ~/jabazapret-linux
cd ~/jabazapret-linux

# 3. Install Node dependencies
npm install

# 4. Launch the app
npm start

# 5. In the app: click "Download nfqws" if not already installed
# 6. Select a strategy, interface, and click LAUNCH
```

---

## How It Works

On **Windows**, the original tool uses `winws.exe` + WinDivert to intercept packets.

On **Linux**, we use:
- `nfqws` — the Linux-native DPI bypass engine from [bol-van/zapret](https://github.com/bol-van/zapret)
- `nftables` — to redirect traffic to nfqws via NFQUEUE
- The same strategy parameters work on both platforms

### nftables flow:
```
Your app → TCP/UDP port 443 → nftables QUEUE rule → nfqws modifies packets → Server
```

---

## Strategies

| Strategy | Description |
|---|---|
| `general` | Main strategy with multisplit + QUIC fake |
| `alt` | Alternative with md5sig fooling |
| `alt2` | multidisorder + badseq |
| `alt3` | fakedsplit + ts fooling |
| `fake-tls-auto` | Fake TLS with auto-TTL |
| `simple-fake` | Basic fake packet strategy |

If one strategy doesn't work, try others. Different ISPs respond to different methods.

---

## Domain Lists

Edit files in `lists/` to add custom domains:
- `list-general.txt` — domains to bypass
- `list-exclude.txt` — domains to exclude
- `list-general-user.txt` — your custom additions
- `ipset-all.txt` — IP ranges

---

## Service (Auto-start)

Use the **Service** tab in the app to install zapret as a systemd service.
It will auto-start on boot.

Manual management:
```bash
sudo systemctl start zapret
sudo systemctl stop zapret
sudo systemctl status zapret
```

---

## Troubleshooting

1. **Enable Secure DNS** in your browser (Chrome: Settings → Privacy → Security → Use secure DNS)
2. Run **Diagnostics** from the Service tab
3. Try all strategies until one works
4. Check the Log tab for errors

---

## Credits

- [bol-van/zapret](https://github.com/bol-van/zapret) — nfqws engine
- [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) — strategy configs
- [darealmemegod/jabazapret](https://github.com/darealmemegod/jabazapret) — original fork

MIT License

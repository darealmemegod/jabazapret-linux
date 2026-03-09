# bin/

Place the following binaries here (Linux x86_64 builds):

- `nfqws`                           — main DPI bypass engine
- `quic_initial_www_google_com.bin` — fake QUIC packet payload
- `tls_clienthello_www_google_com.bin` — fake TLS ClientHello payload

## Getting nfqws

Download from: https://github.com/bol-van/zapret/releases

Or use the "Download nfqws" button in the app.

## Getting fake payloads

Download from the original jabazapret/Flowseal repository:
https://github.com/darealmemegod/jabazapret/tree/main/bin
https://github.com/Flowseal/zapret-discord-youtube/tree/main/bin

The .bin files from the Windows version work on Linux too (they're just binary data).

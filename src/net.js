// Thin WebSocket client. Connects to same-origin /ws, or ?server=wss://host/ws.
export class Net {
  constructor(handlers) { this.h = handlers; this.ws = null; this.online = false; }
  connect(hello) {
    const q = new URLSearchParams(location.search).get('server');
    const url = q || `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.hostname}:${location.port === '5173' ? 8787 : location.port || (location.protocol === 'https:' ? 443 : 80)}/ws`;
    return new Promise((res, rej) => {
      const ws = new WebSocket(url); this.ws = ws; const to = setTimeout(() => { ws.close(); rej(new Error('timeout')); }, 5000);
      ws.onopen = () => ws.send(JSON.stringify({ t: 'hello', ...hello }));
      ws.onmessage = (e) => { const m = JSON.parse(e.data); if (m.t === 'welcome') { clearTimeout(to); this.online = true; res(m); } else this.h[m.t]?.(m); };
      ws.onerror = () => { clearTimeout(to); rej(new Error('connect failed')); };
      ws.onclose = () => { if (this.online) this.h.disconnect?.(); this.online = false; };
    });
  }
  send(m) { if (this.online && this.ws.readyState === 1) this.ws.send(JSON.stringify(m)); }
}

# PlynxConnector for TypeScript

🚧 **Coming Soon**

TypeScript/JavaScript client library for Plynx (Blynk Legacy) server.
Works in browser (WebSocket) and Node.js (TCP).

## Planned Features

- Browser support via WebSocket
- Node.js support via TCP/TLS
- TypeScript types included
- Promise-based async API
- Event emitter pattern
- Auto-reconnection

## Planned Usage

```typescript
import { PlynxConnector } from 'plynx-connector';

const plynx = new PlynxConnector({
  host: '192.168.1.100',
  port: 9443,  // TCP for Node.js
  // port: 8080,  // WebSocket for browser
});

await plynx.connect({
  email: 'user@example.com',
  password: 'password',
  appName: 'MyWebApp',
});

// Listen for events
plynx.on('virtualPinUpdate', ({ dashId, deviceId, pin, values }) => {
  console.log(`V${pin} = ${values}`);
});

// Write to virtual pin
await plynx.send({
  type: 'writeVirtualPin',
  dashId: 1,
  deviceId: 0,
  pin: 1,
  value: '255',
});
```

## Browser Usage

```html
<script type="module">
  import { PlynxConnector } from 'https://cdn.jsdelivr.net/npm/plynx-connector/dist/browser.js';
  
  const plynx = new PlynxConnector({ host: '192.168.1.100', port: 8080, websocket: true });
  // ...
</script>
```

## License

**© 2025 NickP005. All Rights Reserved.**

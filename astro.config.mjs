import { defineConfig } from 'astro/config';
import { networkInterfaces } from 'node:os';
import qrcode from 'qrcode-terminal';

export default defineConfig({
  site: 'https://gridzero.win',
  output: 'static',
  devToolbar: { enabled: false },
  vite: { define: { __GRIDZERO_BUILD__: JSON.stringify(`gridzero-play-${Date.now()}`) } },
  trailingSlash: 'always',
  build: { inlineStylesheets: 'never' },
  integrations: [{
    name: 'lan-qr',
    hooks: {
      'astro:server:start': ({ address }) => {
        const hosts = new Set(Object.entries(networkInterfaces())
          .filter(([name]) => !/^utun\d+$/.test(name))
          .flatMap(([, addresses]) => (addresses ?? [])
            .filter(info => info.family === 'IPv4' && !info.internal)
            .map(info => info.address)));
        for (const host of hosts) {
          const url = `http://${host}:${address.port}/`;
          console.log(`\nScan on the same Wi-Fi: ${url}`);
          qrcode.generate(url, { small: true });
        }
      },
    },
  }],
});

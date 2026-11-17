import { defineConfig } from 'astro/config';
import { networkInterfaces } from 'node:os';
import qrcode from 'qrcode-terminal';

export default defineConfig({
  site: 'https://gridzero.win',
  output: 'static',
  trailingSlash: 'always',
  build: { inlineStylesheets: 'never' },
  integrations: [{
    name: 'lan-qr',
    hooks: {
      'astro:server:start': ({ address }) => {
        const hosts = new Set(Object.values(networkInterfaces()).flat()
          .filter(info => info && info.family === 'IPv4' && !info.internal)
          .map(info => info.address));
        for (const host of hosts) {
          const url = `http://${host}:${address.port}/play/`;
          console.log(`\nScan on the same Wi-Fi: ${url}`);
          qrcode.generate(url, { small: true });
        }
      },
    },
  }],
});

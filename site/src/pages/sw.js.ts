import type { APIRoute } from 'astro';
// Generated per build: the previous version remains active if installation fails.
const version = __GRIDZERO_BUILD__;
export const GET: APIRoute = () => new Response(`
const CACHE = ${JSON.stringify(version)};
const CORE = ['/', '/play/', '/about/', '/privacy/', '/support/', '/credits/', '/assets/Puzzle-LICENSE.txt', '/assets/mark.svg', '/assets/apple-touch-icon.png', '/assets/icon-192.png', '/assets/icon-512.png', '/manifest.webmanifest'];
self.addEventListener('install', event => event.waitUntil((async () => {
  const cache = await caches.open(CACHE);
  try {
  await cache.addAll(CORE.map(url => new Request(url, { cache: 'reload' })));
   const html = (await Promise.all(CORE.filter(p => p.endsWith('/')).map(async p => (await cache.match(p)).text()))).join('\\n');
  const assets = [...new Set([...html.matchAll(/(?:src|href)="([^" ]+)"/g)].map(m => m[1]).filter(p => p.startsWith('/_astro/')))];
  await cache.addAll(assets.map(url => new Request(url, { cache: 'reload' })));
  // The generator is emitted as a separate hashed worker referenced by JS.
  for (const asset of assets.filter(p => p.endsWith('.js'))) {
    const js = await (await cache.match(asset)).text();
    const workers = [...new Set([...js.matchAll(/(?:["'\\x60])([^"'\\x60]*generator\\.worker[^"'\\x60]*\\.js)(?:["'\\x60])/g)].map(m => new URL(m[1], self.location.origin + asset).pathname))];
    await cache.addAll(workers.map(url => new Request(url, { cache: 'reload' })));
  }
  } catch (error) { await caches.delete(CACHE); throw error; }
})()));
self.addEventListener('activate', event => event.waitUntil((async () => {
  await self.clients.claim();
})()));
self.addEventListener('message', event => {
  if (!event.source || !['ACTIVATE_UPDATE', 'CLIENT_READY'].includes(event.data?.type)) return;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    // A second open window may still be playing or using the older app. Let the
    // normal worker lifecycle handle that case rather than disrupting it.
    if (!windows.every(client => client.id === event.source.id)) return;
    if (event.data.type === 'ACTIVATE_UPDATE') {
      await self.skipWaiting();
    } else if (event.data.build === CACHE) {
      // Only a page from this build may release the older caches. A user who
      // started playing while activation finished can safely keep the old page.
      const currentBuild = Number(CACHE.split('-').at(-1));
      for (const key of await caches.keys()) {
        const cachedBuild = Number(key.split('-').at(-1));
        // Never delete a newer worker's in-progress or waiting installation.
        if (key.startsWith('gridzero-play-') && cachedBuild < currentBuild) await caches.delete(key);
      }
    }
    event.ports[0]?.postMessage({ type: 'UPDATE_HANDLED' });
  })());
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin) return;
  if (!url.pathname.startsWith('/_astro/') && !CORE.includes(url.pathname)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const cached = await cache.match(event.request);
    if (cached) return cached;
    if (url.pathname.startsWith('/_astro/')) {
      for (const key of await caches.keys()) {
        if (!key.startsWith('gridzero-play-') || key === CACHE) continue;
        const previous = await (await caches.open(key)).match(event.request);
        if (previous) return previous;
      }
    }
    const response = await fetch(event.request);
    if (response.ok) await cache.put(event.request, response.clone());
    return response;
  })());
});
`, { headers: { 'Content-Type': 'application/javascript', 'Cache-Control': 'no-cache' } });

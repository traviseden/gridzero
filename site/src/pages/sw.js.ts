import type { APIRoute } from 'astro';
// Generated per build: the previous version remains active if installation fails.
const version = `gridzero-play-${Date.now()}`;
export const GET: APIRoute = () => new Response(`
const CACHE = ${JSON.stringify(version)};
const CORE = ['/', '/play/', '/about/', '/privacy/', '/support/', '/credits/', '/assets/Puzzle-LICENSE.txt', '/assets/mark.svg', '/assets/apple-touch-icon.png', '/assets/icon-192.png', '/assets/icon-512.png', '/manifest.webmanifest'];
self.addEventListener('install', event => event.waitUntil((async () => {
  const cache = await caches.open(CACHE);
  await cache.addAll(CORE);
   const html = (await Promise.all(CORE.filter(p => p.endsWith('/')).map(async p => (await cache.match(p)).text()))).join('\\n');
  const assets = [...new Set([...html.matchAll(/(?:src|href)="([^" ]+)"/g)].map(m => m[1]).filter(p => p.startsWith('/_astro/')))];
  await cache.addAll(assets);
  // The generator is emitted as a separate hashed worker referenced by JS.
  for (const asset of assets.filter(p => p.endsWith('.js'))) {
    const js = await (await cache.match(asset)).text();
    const workers = [...new Set([...js.matchAll(/(?:["'\\x60])([^"'\\x60]*generator\\.worker[^"'\\x60]*\\.js)(?:["'\\x60])/g)].map(m => new URL(m[1], self.location.origin + asset).pathname))];
    await cache.addAll(workers);
  }
})()));
self.addEventListener('activate', event => event.waitUntil((async () => {
  for (const key of await caches.keys()) if (key.startsWith('gridzero-play-') && key !== CACHE) await caches.delete(key);
  await self.clients.claim();
})()));
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin) return;
  if (!url.pathname.startsWith('/_astro/') && !CORE.includes(url.pathname)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const cached = await cache.match(event.request);
    if (cached) return cached;
    const response = await fetch(event.request);
    if (response.ok) await cache.put(event.request, response.clone());
    return response;
  })());
});
`, { headers: { 'Content-Type': 'application/javascript', 'Cache-Control': 'no-cache' } });

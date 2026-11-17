// Update only during an untouched startup. No prompts, reloads during play, or
// requirement to clear site data. Old assets remain usable by older open pages.
export async function watchForUpdates(beforeReload: () => boolean) {
  if (!('serviceWorker' in navigator)) return;
  const build = document.querySelector<HTMLMetaElement>('meta[name="gridzero-build"]')?.content;
  let interacted = false, requested = false, reloading = false;
  const markInteraction = () => { interacted = true; };
  for (const event of ['pointerdown', 'keydown', 'input', 'change']) {
    document.addEventListener(event, markInteraction, { capture: true, once: true });
  }
  const ready = () => navigator.serviceWorker.controller?.postMessage({ type: 'CLIENT_READY', build });
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (requested && !interacted && !document.hidden && !reloading && beforeReload()) {
      reloading = true;
      location.reload();
    } else {
      ready();
    }
  });
  try {
    const registration = await navigator.serviceWorker.register('/sw.js', { scope: '/', updateViaCache: 'none' });
    const activate = () => {
      if (!navigator.serviceWorker.controller || !registration.waiting || interacted || document.hidden || requested) return;
      requested = true;
      registration.waiting.postMessage({ type: 'ACTIVATE_UPDATE' });
    };
    const watchInstalling = () => {
      const installing = registration.installing;
      installing?.addEventListener('statechange', () => {
        if (installing.state === 'installed') activate();
      });
    };
    registration.addEventListener('updatefound', watchInstalling);
    watchInstalling();
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden) void registration.update().then(activate).catch(() => {});
    });
    activate();
    ready();
    // Explicitly check every fresh startup, even when the browser's automatic
    // registration check would reuse its last result.
    await registration.update();
    activate();
  } catch {
    // Offline, failed download, or unavailable workers: keep the current app.
  }
}

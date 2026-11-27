// Service worker de Serevix: permite instalar la app y abrirla sin conexión.
const CACHE = 'serevix-v1';
const ASSETS = [
  './', './index.html', './config.js', './manifest.webmanifest',
  './vendor/three.min.js', './vendor/supabase.js',
  './icons/icon-192.png', './icons/icon-512.png', './icons/apple-touch-icon.png'
];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
const save = (req, res) => { if (res && res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); } return res; };
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin === location.origin) {
    // La página y la configuración: primero la red (para recibir actualizaciones) y, sin conexión, la copia guardada.
    if (req.mode === 'navigate' || url.pathname.endsWith('/index.html') || url.pathname.endsWith('/config.js')) {
      e.respondWith(fetch(req).then(r => save(req, r)).catch(() => caches.match(req).then(m => m || caches.match('./index.html'))));
      return;
    }
    e.respondWith(caches.match(req).then(m => m || fetch(req).then(r => save(req, r))));
    return;
  }
  if (url.hostname === 'fonts.googleapis.com' || url.hostname === 'fonts.gstatic.com') {
    e.respondWith(caches.match(req).then(m => m || fetch(req).then(r => save(req, r))));
  }
});

// 펫 서바이버 오프라인 캐시 (PWA) — 네트워크 우선, 오프라인일 때만 캐시 사용
const CACHE = 'petsurv-v5';
self.addEventListener('install', e => { self.skipWaiting(); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(keys => Promise.all(keys.map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const url = e.request.url;
  if (!url.startsWith(self.location.origin) && !url.includes('fonts.g') && !url.includes('jsdelivr')) return; // 랭킹 서버 등은 건드리지 않음
  e.respondWith(fetch(e.request, { cache: 'no-store' }).then(res => {
    if (res && res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); }
    return res;
  }).catch(() => caches.match(e.request)));
});

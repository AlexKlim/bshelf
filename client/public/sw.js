const CACHE = "bshelf-shell-__BUILD__";
const SERVER_PATHS = /^\/(api|oauth|mcp|up|\.well-known)(\/|$)/;
// The build replaces the empty list with every emitted chunk, so lazy screens open offline after the first visit.
const ASSETS = /* __ASSETS__ */ [];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => Promise.all([cache.add("/"), ...ASSETS.map((url) => cache.add(url).catch(() => {}))]))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
  );
  self.clients.claim();
});

function cacheable(request, response) {
  if (!response.ok || /no-store/i.test(response.headers.get("Cache-Control") ?? "")) return false;
  return request.mode !== "navigate" || (response.headers.get("Content-Type") ?? "").startsWith("text/html");
}

// Network first so a deploy is picked up immediately; the cache only covers offline launches.
self.addEventListener("fetch", (event) => {
  const { request } = event;
  const url = new URL(request.url);
  if (request.method !== "GET" || url.origin !== self.location.origin || SERVER_PATHS.test(url.pathname)) return;

  const key = request.mode === "navigate" ? "/" : request;
  event.respondWith(
    fetch(request)
      .then((response) => {
        if (cacheable(request, response)) {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(key, copy));
        }
        return response;
      })
      .catch(() => caches.match(key))
  );
});

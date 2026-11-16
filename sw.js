const CACHE='pontal-serra-app-v01';
const STATIC=['./','./index.html','./style.css','./app.js','./config.js','./manifest.webmanifest','./assets/icon.svg','./assets/icon-192.png','./assets/icon-512.png'];
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(STATIC))));
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k))))));
self.addEventListener('fetch',e=>{
 if(e.request.method!=='GET')return;
 const u=new URL(e.request.url); if(u.origin!==self.location.origin)return;
 // Interface pode ficar no cache; dados privados são carregados pela API e nunca são armazenados por este service worker.
 e.respondWith(fetch(e.request).then(r=>{if(r.ok && STATIC.some(x=>u.pathname.endsWith(x.replace('./','')))){const copy=r.clone();caches.open(CACHE).then(c=>c.put(e.request,copy));}return r;}).catch(()=>caches.match(e.request)));
});

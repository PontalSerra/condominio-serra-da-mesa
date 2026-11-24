const CACHE='pontal-serra-app-v036';
const STATIC=['./','./index.html','./style.css','./app.js','./finance.js','./rateios.js','./admin-config.js','./acesso.js','./dados-importacao.js','./transparencia.js','./relatorios.js','./atualizacoes.js','./gestao-acessos.js','./melhorias.js','./seguranca.js','./fechamento.js','./vida-pontal.js','./instalar.html','./guia.css','./recuperar-acesso.html','./config.js','./manifest.webmanifest','./vendor/qrcode.min.js','./vendor/xlsx.full.min.js','./vendor/supabase.js','./assets/icon.svg','./assets/Pontal_da_Serra.ico','./assets/icon-192.png','./assets/icon-512.png','./assets/apple-touch-icon.png','./assets/condominio.webp'];
const staticURLs=new Set(STATIC.map(path=>new URL(path,self.registration.scope).href));
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(STATIC))));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith('pontal-serra-app-')&&key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim())));
self.addEventListener('message',event=>{if(event.data?.type==='ACTIVATE_UPDATE')event.waitUntil(self.skipWaiting());});
self.addEventListener('fetch',event=>{
 if(event.request.method!=='GET'||!staticURLs.has(event.request.url))return;
 // Somente arquivos públicos da interface. Dados financeiros e APIs nunca entram neste cache.
 // Uma janela usa todos os arquivos da mesma versão. A nova aguarda o botão Atualizar.
 event.respondWith(caches.open(CACHE).then(async cache=>(await cache.match(event.request,{ignoreSearch:false}))||fetch(event.request)));
});

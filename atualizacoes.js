/* Atualização por decisão do usuário, mantendo o conjunto de arquivos da versão. */
export function watchUpdates({navigator:nav=globalThis.navigator,window:win=globalThis.window,document:doc=globalThis.document,version='0.3.5',notify=()=>{}}={}) {
 let registration=null,reloading=false,requested=false,prompt=null;
 const dirty=()=>!!doc.querySelector('form[data-dirty="true"]');
 const banner=()=>{let box=doc.getElementById('app-update');if(!box){box=doc.createElement('aside');box.id='app-update';box.className='update-banner no-print';box.setAttribute('role','status');doc.body.appendChild(box);}return box;};
 const show=(text,action,label)=>{const box=banner();box.replaceChildren();const span=doc.createElement('span');span.textContent=text;box.append(span);if(action){const button=doc.createElement('button');button.className='btn sm primary';button.textContent=label;button.onclick=action;box.append(button);}};
 const reload=()=>{if(dirty()&&!win.confirm('Há alterações ainda não salvas. Deseja descartá-las e atualizar?'))return false;reloading=true;win.location.reload();return true;};
 const apply=()=>{if(!registration?.waiting)return;if(dirty()&&!win.confirm('Há alterações ainda não salvas. Deseja descartá-las e atualizar?'))return;requested=true;show('Aplicando atualização…');registration.waiting.postMessage({type:'ACTIVATE_UPDATE'});};
 const checkWaiting=()=>{if(registration?.waiting)show('Uma nova versão está pronta.',apply,'Atualizar aplicativo');};
 doc.addEventListener('input',e=>{if(e.target.form&&!e.target.readOnly)e.target.form.dataset.dirty='true';});
 doc.addEventListener('change',e=>{if(e.target.form&&!e.target.readOnly)e.target.form.dataset.dirty='true';});
 nav.serviceWorker?.addEventListener('controllerchange',()=>{if(reloading)return;if(requested){reloading=true;win.location.reload();}else if(!dirty())reload();else show('A atualização foi aplicada em outra janela. Salve suas alterações e recarregue.',reload,'Recarregar');});
 win.addEventListener('beforeinstallprompt',e=>{e.preventDefault();prompt=e;win.dispatchEvent(new Event('pontal-install-ready'));});
 win.addEventListener('appinstalled',()=>{prompt=null;notify('Aplicativo instalado.');});
 async function check(){
  if(!nav.onLine){notify('Conecte-se à internet para verificar atualizações.');return;}
  if(!registration){notify('A atualização fica disponível no site publicado com conexão segura.');return;}
  try{await registration.update();checkWaiting();if(!registration.waiting&&!registration.installing)notify(`Versão ${version}. Nenhuma atualização pronta neste momento.`);}catch{notify('Não foi possível verificar atualizações. Tente novamente com conexão.');}
 }
 async function start(){
  if(!nav.serviceWorker||!/^https:$/.test(win.location.protocol))return;
  try{registration=await nav.serviceWorker.register('./sw.js',{updateViaCache:'none'});checkWaiting();
   const track=()=>{const worker=registration.installing;worker?.addEventListener('statechange',()=>{if(worker.state==='installed')checkWaiting();if(worker.state==='redundant')notify('A nova versão não foi baixada por completo. Tente novamente.');});};
   registration.addEventListener('updatefound',track);track();
   win.addEventListener('online',()=>registration.update().catch(()=>{}));
   doc.addEventListener('visibilitychange',()=>{if(doc.visibilityState==='visible'&&nav.onLine)registration.update().catch(()=>{});});
  }catch{notify('Não foi possível preparar a atualização do aplicativo. A página continua disponível online.');}
 }
 return {start,check,apply,hasInstallPrompt:()=>!!prompt,async install(){if(!prompt){win.location.href='instalar.html';return;}const p=prompt;prompt=null;await p.prompt();await p.userChoice;}};
}

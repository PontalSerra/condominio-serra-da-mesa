/* Pontal da Serra Web v0.1 - sem dados reais ou credenciais no código */
const CONFIG=window.PONTAL_CONFIG||{};
const DEMO=!(CONFIG.supabaseUrl&&CONFIG.supabaseAnonKey);
const LS='pontal_da_serra_demo_v01';
const $=s=>document.querySelector(s);
const h=s=>String(s??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
const brl=n=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(n)||0);
const nf=n=>new Intl.NumberFormat('pt-BR',{maximumFractionDigits:3}).format(Number(n)||0);
const num=v=>Number(v)||0;
const round=v=>Math.round((num(v)+Number.EPSILON)*100)/100;
const uuid=()=>crypto.randomUUID();
const ymDate=s=>{const [y,m]=s.split('-').map(Number);return new Date(y,m-1,1)};
const labelMonth=s=>ymDate(s).toLocaleDateString('pt-BR',{month:'long',year:'numeric'}).replace(/^./,x=>x.toUpperCase());
const nextYm=s=>{const d=ymDate(s);d.setMonth(d.getMonth()+1);return d.toISOString().slice(0,7)};
const prevYm=s=>{const d=ymDate(s);d.setMonth(d.getMonth()-1);return d.toISOString().slice(0,7)};
const due=s=>nextYm(s)+'-10';
const fmtDate=s=>s?String(s).slice(0,10).split('-').reverse().join('/'):'—';
const monthToday=()=>new Date().toISOString().slice(0,7);
const isNum=x=>x!==''&&x!==null&&x!==undefined&&Number.isFinite(Number(x));
const asMoney=x=>round(num(x));
const sum=(arr,fn=x=>x)=>arr.reduce((n,x)=>n+num(fn(x)),0);
const toInputNum=v=>v===null||v===undefined?'':v;
const csvLine=arr=>arr.map(x=>'"'+String(x??'').replace(/"/g,'""')+'"').join(';');
const periodColumns=['energy_rate','general_prev','general_curr','general_invoice','pump_prev','pump_curr','pump_invoice','water_divisor','caretaker','lighting','provision','extra_amount','solar_per_lot'];
let sb=null,role='admin',active='dashboard',periodId='2026-11',currentOwnerId=null,remoteUser=null,store={},modalOpen=false;

function freshDemo(){
 const a=uuid(),b=uuid(),c=uuid(),d=uuid(),e=uuid(),l1=uuid(),l2=uuid(),l3=uuid(),l4=uuid(),l5=uuid(),l6=uuid();
 return {owners:[
   {id:a,name:'CONDÔMINO EXEMPLO A',whatsapp:'',whatsapp_opt_in:false,login_user_id:null,opening_balance:0},
   {id:b,name:'CONDÔMINO EXEMPLO B',whatsapp:'',whatsapp_opt_in:false,login_user_id:null,opening_balance:0},
   {id:c,name:'CONDÔMINO EXEMPLO C',whatsapp:'',whatsapp_opt_in:false,login_user_id:null,opening_balance:120},
   {id:d,name:'CONDÔMINO EXEMPLO D',whatsapp:'',whatsapp_opt_in:false,login_user_id:null,opening_balance:0},
   {id:e,name:'CONDÔMINO EXEMPLO E',whatsapp:'',whatsapp_opt_in:false,login_user_id:null,opening_balance:0}],
  lots:[{id:l1,number:'4',owner_id:a,built:true,solar_opt_in:true},{id:l2,number:'5',owner_id:a,built:false,solar_opt_in:true},{id:l3,number:'9-A',owner_id:b,built:true,solar_opt_in:false},{id:l4,number:'18-B',owner_id:c,built:false,solar_opt_in:false},{id:l5,number:'9-B',owner_id:d,built:false,solar_opt_in:false},{id:l6,number:'18-A',owner_id:e,built:false,solar_opt_in:false}],
  periods:[{id:'2026-11',due_date:'2026-12-10',status:'draft',energy_rate:1.21864,general_prev:23967,general_curr:26486,general_invoice:3069.75,pump_prev:1030,pump_curr:1205,pump_invoice:213.26,water_divisor:1000,caretaker:380,lighting:190,provision:120,extra_amount:0,extra_scope:'built',solar_per_lot:0,notes:'DEMONSTRAÇÃO — substitua pelos valores reais.'}],
  meter_readings:[{id:uuid(),period_id:'2026-11',owner_id:a,energy_prev:9262,energy_curr:9314,water_prev:967516,water_curr:974034},{id:uuid(),period_id:'2026-11',owner_id:b,energy_prev:1010,energy_curr:1036,water_prev:440000,water_curr:441400},{id:uuid(),period_id:'2026-11',owner_id:c,energy_prev:0,energy_curr:0,water_prev:0,water_curr:0},{id:uuid(),period_id:'2026-11',owner_id:d,energy_prev:0,energy_curr:0,water_prev:0,water_curr:0},{id:uuid(),period_id:'2026-11',owner_id:e,energy_prev:0,energy_curr:0,water_prev:0,water_curr:0}],
  invoices:[],payments:[],announcements:[{id:uuid(),title:'Bem-vindo ao Pontal da Serra',body:'Este aviso e todos os dados desta demonstração são fictícios. O aplicativo de produção exige configuração do banco de dados e dos acessos.',category:'geral',audience:'all',target_owner_ids:[],created_at:new Date().toISOString()}],lot_access:[],owner_members:[],whatsapp_log:[],payment_config:[{id:1,pix_key:'',pix_name:'CONDOMINIO PONTAL DA SERRA',pix_city:'NIQUELANDIA',pix_enabled:false}]};
}
function saveDemo(){if(DEMO)localStorage.setItem(LS,JSON.stringify(store))}
async function load(){
 if(DEMO){try{store=JSON.parse(localStorage.getItem(LS))||freshDemo()}catch{store=freshDemo()}currentOwnerId=store.owners[0]?.id||null;return}
 const {data:{session},error}=await sb.auth.getSession();if(error)throw error;
 if(!session){remoteUser=null;renderLogin();return false}
 remoteUser=session.user;
 const {data:adminRow}=await sb.from('app_admins').select('user_id').eq('user_id',remoteUser.id).maybeSingle();
 role=adminRow?'admin':'owner';
 const names=role==='admin'?['owners','lots','periods','meter_readings','invoices','payments','announcements','lot_access','owner_members','payment_config','whatsapp_log']:['owners','lots','meter_readings','invoices','payments','announcements','lot_access','owner_members','payment_config'];
 const fetched=await Promise.all(names.map(async t=>{const {data,error}=await sb.from(t).select('*').limit(2000);if(error)throw new Error(t+': '+error.message);return[t,data||[]]}));
 store=Object.fromEntries(fetched);for(const name of ['owners','lots','periods','meter_readings','invoices','payments','announcements','lot_access','owner_members','payment_config','whatsapp_log'])store[name]??=[];
 currentOwnerId=role==='owner'?(store.owners.find(o=>o.login_user_id===remoteUser.id)?.id||store.owner_members.find(m=>m.user_id===remoteUser.id)?.owner_id):null;
 if(role==='admin'&&!store.periods.length)periodId=monthToday();
 else if(store.periods.length&&!store.periods.some(p=>p.id===periodId))periodId=store.periods.slice().sort((a,b)=>b.id.localeCompare(a.id))[0].id;
 return true;
}
async function saveRow(table,row,conflict){
 if(DEMO){const list=store[table]||(store[table]=[]);const key=table==='periods'?'id':table==='payment_config'?'id':'id';const idx=list.findIndex(x=>x[key]===row[key]);if(idx<0)list.push({...row});else list[idx]={...list[idx],...row};saveDemo();return row}
 const q=sb.from(table).upsert(row,conflict?{onConflict:conflict}:{}).select().single();const {data,error}=await q;if(error)throw Error(error.message);return data;
}
async function saveMany(table,rows,conflict){if(!rows.length)return;if(DEMO){for(const row of rows)await saveRow(table,row);return}
 const {error}=await sb.from(table).upsert(rows,conflict?{onConflict:conflict}:{});if(error)throw Error(error.message);
}
async function deleteRow(table,id){if(DEMO){store[table]=store[table].filter(x=>x.id!==id);saveDemo();return}const {error}=await sb.from(table).delete().eq('id',id);if(error)throw Error(error.message)}
async function refresh(){const ok=await load();if(ok!==false)render()}
function message(t){const old=$('.toast');if(old)old.remove();const toast=document.createElement('div');toast.className='toast';toast.textContent=t;document.body.appendChild(toast);setTimeout(()=>toast.remove(),3500)}
function ownLots(id){return store.lots.filter(l=>l.owner_id===id)}
function permittedLots(id){const linked=new Set((store.lot_access||[]).filter(x=>x.owner_id===id).map(x=>x.lot_id));return store.lots.filter(l=>l.owner_id===id||linked.has(l.id))}
function activePeriod(){return store.periods.find(p=>p.id===periodId)}
function activeReadings(id){return store.meter_readings.find(x=>x.owner_id===id&&x.period_id===periodId)}
function orderedOwners(){return [...store.owners].sort((a,b)=>a.name.localeCompare(b.name,'pt-BR'))}
function monthlyInvoices(month=periodId){return store.invoices.filter(i=>i.period_id===month)}
function ownerInvoices(id){return store.invoices.filter(i=>i.owner_id===id).sort((a,b)=>a.period_id.localeCompare(b.period_id))}
function ownerPayments(id){return store.payments.filter(p=>p.owner_id===id).sort((a,b)=>b.paid_at.localeCompare(a.paid_at))}
function totalCharges(id,upto=null){return sum(store.invoices.filter(i=>i.owner_id===id&&(!upto||i.period_id<=upto)),i=>i.current_amount)}
function totalPayments(id,until=null){return sum(store.payments.filter(p=>p.owner_id===id&&(!until||p.paid_at<=until)),p=>p.amount)}
function ownerBalance(id,upto=null){return round(num(store.owners.find(o=>o.id===id)?.opening_balance)+totalCharges(id,upto)-totalPayments(id))}
function scopedAnnouncements(){return store.announcements.filter(a=>role==='admin'||a.audience==='all'||(a.target_owner_ids||[]).includes(currentOwnerId)).sort((a,b)=>b.created_at.localeCompare(a.created_at))}
function monetaryRow(label,value,detail=''){return{label,amount:round(value),detail}}
function calcMonth(p){
 const owners=orderedOwners(),built=owners.filter(o=>ownLots(o.id).some(l=>l.built)),bCount=built.length,anyCount=owners.filter(o=>ownLots(o.id).length).length,lCount=store.lots.length;
 const energyKwh=num(p.general_curr)-num(p.general_prev),pumpKwh=num(p.pump_curr)-num(p.pump_prev);
 const rate=num(p.energy_rate)>0?num(p.energy_rate):energyKwh>0?num(p.general_invoice)/energyKwh:0;
 const pumpCost=num(p.pump_invoice)>0?num(p.pump_invoice):round(pumpKwh*rate);
 const waterTotal=sum(owners,o=>{const r=store.meter_readings.find(x=>x.owner_id===o.id&&x.period_id===p.id);return r&&isNum(r.water_curr)&&isNum(r.water_prev)?Math.max(0,(num(r.water_curr)-num(r.water_prev))/num(p.water_divisor||1000)):0});
 const waterRate=waterTotal>0?pumpCost/waterTotal:0;
 const result=owners.map(o=>{
   const lots=ownLots(o.id),full=lots.some(l=>l.built),row=store.meter_readings.find(x=>x.owner_id===o.id&&x.period_id===p.id)||{};
   const ekwh=isNum(row.energy_curr)&&isNum(row.energy_prev)?Math.max(0,num(row.energy_curr)-num(row.energy_prev)):0;
   const water=isNum(row.water_curr)&&isNum(row.water_prev)?Math.max(0,(num(row.water_curr)-num(row.water_prev))/num(p.water_divisor||1000)):0;
   const condo=lots.length?(full?75+35*(lots.length-1):35*lots.length):0;
   const shared=full&&bCount?(num(p.caretaker)+num(p.lighting)+num(p.provision))/bCount:0;
   const extraDenom=p.extra_scope==='lot'?lCount:p.extra_scope==='all'?anyCount:bCount;
   const extra=extraDenom?num(p.extra_amount)/(extraDenom)*(p.extra_scope==='lot'?lots.length:p.extra_scope==='all'?lots.length>0?1:0:full?1:0):0;
   const solar=lots.filter(l=>l.solar_opt_in).length*num(p.solar_per_lot);
   const items=[monetaryRow('Energia elétrica',ekwh*rate,`${nf(ekwh)} kWh • ${nf(row.energy_prev)} → ${nf(row.energy_curr)} • R$ ${rate.toFixed(5)}/kWh`),
      monetaryRow('Água (energia da bomba)',water*waterRate,`${nf(water)} m³ • ${nf(row.water_prev)} → ${nf(row.water_curr)}`),
      monetaryRow('Taxa de condomínio',condo,`${full?'1 cota de R$ 75 + adicionais de R$ 35':'R$ 35 por lote sem construção'} • ${lots.map(l=>l.number).join(', ')}`),
      monetaryRow('Caseiro',full&&bCount?num(p.caretaker)/bCount:0,full?'Rateio por proprietário com construção':'Isento — lote vazio'),
      monetaryRow('Iluminação e áreas comuns',full&&bCount?num(p.lighting)/bCount:0,full?'Rateio por proprietário com construção':'Isento — lote vazio'),
      monetaryRow('Provisão férias / 13º',full&&bCount?num(p.provision)/bCount:0,full?'Rateio por proprietário com construção':'Isento — lote vazio'),
      monetaryRow('Despesa extraordinária',extra,`Critério: ${p.extra_scope==='lot'?'por lote':p.extra_scope==='all'?'todos os titulares':'somente proprietários com construção'}`),
      monetaryRow('Energia solar (investimento)',solar,`${lots.filter(l=>l.solar_opt_in).length} lote(s) participante(s)`)];
   // Arredondamento por item para faturas e pagamentos em centavos.
   return {owner:o,lots,row,energyKwh:ekwh,waterM3:water,items,total:round(sum(items,it=>it.amount)),missing:full&&![row.energy_prev,row.energy_curr,row.water_prev,row.water_curr].every(isNum)};
 });
 return {result,rate,pumpCost,waterRate,waterTotal,bCount,energyKwh,pumpKwh,
          missing:result.filter(x=>x.missing),unallocated:pumpCost>0&&waterTotal===0};
}
function monthSummary(){const inv=monthlyInvoices(),monthPay=store.payments.filter(p=>p.paid_at.slice(0,7)===periodId);return {billed:sum(inv,i=>i.current_amount),received:sum(monthPay,p=>p.amount),debt:sum(store.owners,o=>Math.max(0,ownerBalance(o.id))),owners:store.owners.length}}
function navItems(){return role==='admin'?[['dashboard','◈','Painel'],['cobrancas','▤','Fechamento'],['leituras','◷','Leituras'],['cadastros','♙','Cadastros'],['pagamentos','◉','Pagamentos'],['mensagens','✉','Comunicação'],['relatorios','▦','Relatórios'],['ajustes','⚙','Configurações']]:[['inicio','◈','Início'],['faturas','▤','Faturas'],['pagamentos','◉','Pagamentos'],['avisos','✉','Avisos']]}
function titleOf(view){return ({dashboard:'Visão geral',cobrancas:'Fechamento mensal',leituras:'Leituras de medidores',cadastros:'Proprietários e lotes',pagamentos:'Registro de pagamentos',mensagens:'Central de comunicação',relatorios:'Relatórios e prestação de contas',ajustes:'Configurações',inicio:'Minha área',faturas:'Minhas faturas',avisos:'Mural de avisos'})[view]}
function render(){
 const nav=navItems();if(!nav.some(i=>i[0]===active))active=role==='admin'?'dashboard':'inicio';
 const navHtml=mode=>`<nav class="nav ${mode}">${nav.map(([id,ico,title])=>`<button data-action="nav" data-id="${id}" class="${active===id?'active':''}"><span class="ico">${ico}</span>${h(title)}</button>`).join('')}</nav>`;
 const ap=activePeriod();
 $('#app').innerHTML=`<div class="shell"><aside class="sidebar"><div class="brand"><div class="mark">🌊</div><div><strong>PONTAL DA SERRA</strong><small>Serra da Mesa • GO</small></div></div>${navHtml('')}
  <div class="sidefoot"><span class="tag">${DEMO?'DEMONSTRAÇÃO LOCAL':'NUVEM • SUPABASE'}</span><div>${role==='admin'?'Gestão do síndico':'Espaço do condômino'}</div><div>${DEMO?'Dados fictícios de teste':h(remoteUser?.email||'')}</div>${DEMO?'<button data-action="toggle">Alternar visão de teste</button>':'<button data-action="logout">Sair da conta</button>'}</div></aside>
  <div class="main"><div class="top"><div><div class="eyebrow">Condomínio Pontal da Serra</div><h1>${h(titleOf(active))}</h1></div>
  <div class="top-actions">${DEMO?'<span class="chip warn">⚠️ Testes — sem nuvem</span>':`<span class="chip">${role==='admin'?'Síndico':'Acesso individual'}</span>`}
    ${role==='admin'?`<select id="period-select" class="btn outline">${store.periods.slice().sort((a,b)=>b.id.localeCompare(a.id)).map(x=>`<option value="${x.id}" ${x.id===periodId?'selected':''}>${labelMonth(x.id)}</option>`).join('')}</select>`:''}
  </div></div>
  ${DEMO?'<div class="note alert no-print" style="margin-bottom:16px">Este é um protótipo de teste, com dados fictícios salvos apenas neste navegador. NÃO insira dados pessoais reais até configurar o Supabase e os acessos protegidos.</div>':''}
  ${role==='admin'?renderAdminView(ap):renderOwnerView()}
  </div>${navHtml('mobile')}</div><div id="modal-root"></div>`;
 }
function renderAdminView(p){switch(active){case'dashboard':return dashboard(p);case'cobrancas':return closingView(p);case'leituras':return readingsView(p);case'cadastros':return ownersView();case'pagamentos':return paymentsView();case'mensagens':return announcementsView();case'relatorios':return reportsView();case'ajustes':return settingsView();default:return dashboard(p)}}
function renderOwnerView(){switch(active){case'inicio':return portalHome();case'faturas':return portalInvoices();case'pagamentos':return portalPayments();case'avisos':return portalNotices();default:return portalHome()}}
function rowStatus(id){const balance=ownerBalance(id);return `<span class="pill ${balance>0.009?'red':'green'}">${balance>0.009?'Em aberto':'Em dia'}</span>`}
function dashboard(p){const s=monthSummary(),latest=monthlyInvoices().sort((a,b)=>b.current_amount-a.current_amount);
 return `<div class="hero"><div><p>Organização e transparência</p><h2>Seu condomínio, em boas mãos.</h2><div>Controle de água, energia, taxas, pagamentos e comunicados em um só lugar.</div></div><button data-action="newmonth" class="btn gold">＋ Abrir novo mês</button></div>
 <div class="stats"><div class="metric"><small>Condôminos cadastrados</small><div class="num">${store.owners.length}</div><div class="hint">${store.lots.length} lotes vinculados</div></div>
 <div class="metric green"><small>Faturas do período</small><div class="num">${brl(s.billed)}</div><div class="hint">${monthlyInvoices().length} faturas emitidas</div></div>
 <div class="metric gold"><small>Recebido no período</small><div class="num">${brl(s.received)}</div><div class="hint">pagamentos registrados</div></div>
 <div class="metric dark"><small>Saldo total em aberto</small><div class="num">${brl(s.debt)}</div><div class="hint">considera abertura, cobranças e pagamentos</div></div></div>
 <div class="layout two"><section class="card"><div class="sect"><div><h2>Resumo ${h(labelMonth(periodId))}</h2><p>Vencimento em ${fmtDate(p?.due_date)}</p></div><span class="pill ${p?.status==='closed'?'green':'yellow'}">${p?.status==='closed'?'Fechado':'Em preparação'}</span></div>
 <div class="balance-row"><span>Conta geral de energia</span><strong>${brl(p?.general_invoice)}</strong></div><div class="balance-row"><span>Custo de energia da bomba</span><strong>${brl(p?.pump_invoice)}</strong></div><div class="balance-row"><span>Caseiro + iluminação + provisões</span><strong>${brl(num(p?.caretaker)+num(p?.lighting)+num(p?.provision))}</strong></div><div class="balance-row"><span>Extraordinárias</span><strong>${brl(p?.extra_amount)}</strong></div><div class="actions" style="margin-top:18px"><button data-action="nav" data-id="cobrancas" class="btn primary">Abrir fechamento →</button><button data-action="nav" data-id="leituras" class="btn light">Conferir leituras</button></div></section>
 <section class="card"><div class="sect"><h2>Pendências de cobrança</h2><span class="pill red">${store.owners.filter(o=>ownerBalance(o.id)>0.009).length} em aberto</span></div>
 ${store.owners.filter(o=>ownerBalance(o.id)>0.009).sort((a,b)=>ownerBalance(b.id)-ownerBalance(a.id)).slice(0,6).map(o=>`<div class="balance-row"><div><strong>${h(o.name)}</strong><div class="mini muted">${h(ownLots(o.id).map(l=>l.number).join(', ')||'Sem lote')}</div></div><strong>${brl(ownerBalance(o.id))}</strong></div>`).join('')||'<div class="empty">Nenhum débito em aberto.</div>'}
 <div class="actions" style="margin-top:18px"><button data-action="nav" data-id="pagamentos" class="btn outline">Registrar recebimento</button></div></section></div>`}
function closingView(p){if(!p)return `<div class="card"><h2>Comece criando um mês</h2><button class="btn primary" data-action="newmonth">＋ Novo mês</button></div>`;
 const calc=calcMonth(p),closed=p.status==='closed',invoices=monthlyInvoices(),isRate=calc.rate>0;
 return `<div class="sect"><div><p>Cadastro dos custos gerais, apuração do consumo, rateios e emissão das faturas.</p></div><div class="actions"><span class="pill ${closed?'green':'yellow'}">${closed?'Mês fechado':'Rascunho'}</span><button class="btn light" data-action="newmonth">＋ Novo mês</button></div></div>
 <section class="card"><div class="sect"><h2>1. Dados do período</h2><span class="mini muted">Vencimento: ${fmtDate(p.due_date)}</span></div>
 <form id="period-form"><div class="form-grid four">
 ${field('due_date','Data de vencimento',p.due_date,'date',closed)}
 ${field('energy_rate','Tarifa manual (R$/kWh)',p.energy_rate,'number',closed,'step="0.00001" min="0"')}
 ${field('general_prev','Medidor geral — anterior',p.general_prev,'number',closed,'step="0.001" min="0"')}
 ${field('general_curr','Medidor geral — atual',p.general_curr,'number',closed,'step="0.001" min="0"')}
 ${field('general_invoice','Valor da conta de energia geral (R$)',p.general_invoice,'number',closed,'step="0.01" min="0"')}
 ${field('pump_prev','Medidor bomba — anterior',p.pump_prev,'number',closed,'step="0.001" min="0"')}
 ${field('pump_curr','Medidor bomba — atual',p.pump_curr,'number',closed,'step="0.001" min="0"')}
 ${field('pump_invoice','Conta/custo da bomba (R$)',p.pump_invoice,'number',closed,'step="0.01" min="0"')}
 ${field('caretaker','Salário e despesas do caseiro (R$)',p.caretaker,'number',closed,'step="0.01" min="0"')}
 ${field('lighting','Iluminação/áreas comuns (R$)',p.lighting,'number',closed,'step="0.01" min="0"')}
 ${field('provision','Provisão férias/13º (R$)',p.provision,'number',closed,'step="0.01" min="0"')}
 ${field('solar_per_lot','Energia solar — por lote aderente (R$)',p.solar_per_lot,'number',closed,'step="0.01" min="0"')}
 ${field('extra_amount','Outras despesas extraordinárias (R$)',p.extra_amount,'number',closed,'step="0.01" min="0"')}
 <div class="field"><label>Quem participa do rateio extra?</label><select name="extra_scope" ${closed?'disabled':''}><option value="built" ${p.extra_scope==='built'?'selected':''}>Apenas proprietários com construção</option><option value="all" ${p.extra_scope==='all'?'selected':''}>Todos os proprietários</option><option value="lot" ${p.extra_scope==='lot'?'selected':''}>Por lote</option></select></div>
 ${field('water_divisor','Unidades brutas por m³ de água',p.water_divisor,'number',closed,'min="1" step="1"')}
 <div class="field full"><label>Observações do mês</label><textarea name="notes" ${closed?'disabled':''}>${h(p.notes||'')}</textarea></div></div>
 <div class="actions" style="margin-top:17px">${closed?'<span class="pill green">✓ Lançamentos fechados: preservados para o histórico</span>':'<button class="btn primary" type="submit">Salvar custos e leituras gerais</button>'}</div></form>
 <div class="note" style="margin-top:18px">Consumo de água: diferença entre medidores individuais ÷ <b>${nf(p.water_divisor)}</b>. Custo da água: despesa da bomba ÷ consumo total de água. Caseiro, iluminação e provisão são rateados somente entre proprietários com construção, uma cota por proprietário. Lotes vazios pagam só R$ 35 por lote, salvo despesa extraordinária deliberada com outro critério.</div></section>
 <div class="stats" style="margin-top:18px;grid-template-columns:repeat(3,minmax(0,1fr))"><div class="metric"><small>Tarifa utilizada</small><div class="num">${brl(calc.rate)}<span class="mini muted">/kWh</span></div></div><div class="metric"><small>Custo da bomba</small><div class="num">${brl(calc.pumpCost)}</div></div><div class="metric"><small>Preço da água</small><div class="num">${brl(calc.waterRate)}<span class="mini muted">/m³</span></div></div></div>
 <section class="card" style="margin-top:17px"><div class="sect"><div><h2>2. Prévia das faturas</h2><p>${closed?'Faturas emitidas e preservadas':'Confira os valores antes de fechar definitivamente.'}</p></div>${closed?`<button class="btn light" data-action="nav" data-id="mensagens">Enviar faturas</button>`:`<button class="btn primary" data-action="closemonth">✓ Fechar mês e emitir faturas</button>`}</div>
 ${!closed&&calc.missing.length?`<div class="note alert">Faltam leituras para: ${h(calc.missing.map(x=>x.owner.name).join(', '))}. O fechamento será bloqueado até completar os campos.</div>`:''}
 ${!closed&&calc.unallocated?'<div class="note red">Não há volume de água medido para distribuir o custo informado da bomba. Confira as leituras.</div>':''}
 <div class="table-wrap" style="margin-top:14px"><table><thead><tr><th>Condômino</th><th>Lotes</th><th class="right">Energia</th><th class="right">Água</th><th class="right">Condomínio</th><th class="right">Compartilhado</th><th class="right">Total mês</th><th class="right">Débito anterior</th><th></th></tr></thead><tbody>
 ${calc.result.map(r=>{const invoice=invoices.find(x=>x.owner_id===r.owner.id),items=invoice?.items||r.items,current=invoice?invoice.current_amount:r.total,prior=invoice?invoice.previous_balance_at_issue:Math.max(0,ownerBalance(r.owner.id));return `<tr><td><strong>${h(r.owner.name)}</strong></td><td>${h(r.lots.map(l=>l.number).join(', '))}</td><td class="amount">${brl(items[0]?.amount)}</td><td class="amount">${brl(items[1]?.amount)}</td><td class="amount">${brl(items[2]?.amount)}</td><td class="amount">${brl(sum(items.slice(3,6),x=>x.amount))}</td><td class="amount">${brl(current)}</td><td class="amount">${brl(prior)}</td><td>${invoice?`<button class="btn sm light" data-action="invoice" data-id="${invoice.id}">Fatura</button>`:''}</td></tr>`}).join('')}
 </tbody></table></div></section>`}
function field(name,label,value,type='text',disabled=false,extras=''){return `<div class="field"><label>${h(label)}</label><input name="${name}" type="${type}" value="${h(toInputNum(value))}" ${extras} ${disabled?'disabled':''}></div>`}
function readingsView(p){if(!p)return '<div class="note">Crie um mês primeiro.</div>';
 return `<div class="sect"><p>Lance as leituras que o zelador encaminha. O nome do proprietário aparece ao lado do lote.</p><button data-action="importxlsx" class="btn outline">⬆ Importar planilha existente</button></div>
 <section class="card"><div class="sect"><h2>Leituras de ${h(labelMonth(periodId))}</h2><span class="pill ${p.status==='closed'?'green':'yellow'}">${p.status==='closed'?'Fechado':'Em preenchimento'}</span></div>
 <form id="readings-form"><div class="table-wrap"><table><thead><tr><th>Proprietário</th><th>Lotes</th><th class="right">Energia anterior</th><th class="right">Energia atual</th><th class="right">Água anterior</th><th class="right">Água atual</th></tr></thead><tbody>${orderedOwners().map(o=>{const r=activeReadings(o.id)||{};return `<tr><td><strong>${h(o.name)}</strong></td><td>${h(ownLots(o.id).map(x=>x.number).join(', '))}</td>${['energy_prev','energy_curr','water_prev','water_curr'].map(k=>`<td><input data-owner="${o.id}" data-col="${k}" type="number" min="0" step="0.001" value="${h(toInputNum(r[k]))}" ${p.status==='closed'?'disabled':''} style="width:115px;max-width:100%;border:1px solid #d5e0e1;border-radius:8px;padding:9px"></td>`).join('')}</tr>`}).join('')}</tbody></table></div>
 ${p.status==='closed'?'<p class="note" style="margin-top:15px">As leituras ficam bloqueadas após o fechamento.</p>':'<div class="actions" style="margin-top:17px"><button class="btn primary" type="submit">Salvar todas as leituras</button></div>'}</form></section>`}
function ownersView(){return `<div class="sect"><p>Cadastre os titulares de cobrança, os lotes e os números do WhatsApp.</p><div class="actions"><button class="btn light" data-action="importxlsx">⬆ Importar Excel do síndico</button><button class="btn primary" data-action="ownernew">＋ Condômino</button><button class="btn gold" data-action="lotnew">＋ Lote</button></div></div>
 <section class="card"><div class="sect"><h2>Proprietários e responsáveis</h2><span class="pill">${store.owners.length} cadastros</span></div><div class="table-wrap"><table><thead><tr><th>Nome</th><th>Lotes</th><th>WhatsApp</th><th class="right">Saldo histórico</th><th>Permissão</th><th>Ação</th></tr></thead><tbody>
 ${orderedOwners().map(o=>`<tr><td><strong>${h(o.name)}</strong></td><td>${h(ownLots(o.id).map(l=>l.number).join(', ')||'—')}</td><td>${h(o.whatsapp||'Não cadastrado')}</td><td class="amount">${brl(ownerBalance(o.id))}</td><td>${o.login_user_id?'<span class="pill green">Conta vinculada</span>':'<span class="pill gray">Sem login</span>'}</td><td><button class="btn sm light" data-action="owneredit" data-id="${o.id}">Editar</button> <button class="btn sm outline" data-action="members" data-id="${o.id}">Acessos</button></td></tr>`).join('')}
 </tbody></table></div></section><section class="card"><div class="sect"><h2>Cadastro de lotes</h2><span class="mini muted">Inclui 9-A, 9-B, 18-A e 18-B quando cadastrados</span></div>
 <div class="table-wrap"><table><thead><tr><th>Lote</th><th>Responsável financeiro</th><th>Construção</th><th>Energia solar</th><th></th></tr></thead><tbody>${[...store.lots].sort((a,b)=>a.number.localeCompare(b.number,'pt-BR',{numeric:true})).map(l=>`<tr><td><strong>${h(l.number)}</strong></td><td>${h(store.owners.find(o=>o.id===l.owner_id)?.name||'')}</td><td>${l.built?'<span class="pill green">Sim</span>':'<span class="pill gray">Vazio</span>'}</td><td>${l.solar_opt_in?'Participa':'Não'}</td><td><button class="btn sm light" data-action="lotedit" data-id="${l.id}">Editar</button> <button class="btn sm outline" data-action="lotaccess" data-id="${l.id}">Coproprietários</button></td></tr>`).join('')}</tbody></table></div></section>
 <div class="note alert" style="margin-top:15px">Se duas pessoas são proprietárias do mesmo lote, cadastre um titular responsável pela cobrança. O segundo coproprietário pode ser autorizado a consultar os dados daquele lote, sem acesso às cobranças pessoais do titular. A vinculação de usuários é feita por UID do Supabase após a criação da conta.</div>`}
function paymentsView(){return `<div class="sect"><p>Todos os recebimentos são registrados com data, valor e identificação do pagador.</p>${role==='admin'?'<button class="btn primary" data-action="paymentnew">＋ Registrar pagamento</button>':''}</div>
 <section class="card"><div class="sect"><h2>Histórico de recebimentos</h2><span class="pill">${store.payments.length} registros</span></div><div class="table-wrap"><table><thead><tr><th>Data</th><th>Proprietário</th><th>Meio</th><th>Referência</th><th class="right">Valor</th></tr></thead><tbody>${[...store.payments].sort((a,b)=>b.paid_at.localeCompare(a.paid_at)).map(p=>`<tr><td>${fmtDate(p.paid_at)}</td><td>${h(store.owners.find(o=>o.id===p.owner_id)?.name||'')}</td><td>${h(p.method)}</td><td>${h(p.reference||'')}</td><td class="amount">${brl(p.amount)}</td></tr>`).join('')||'<tr><td colspan="5" class="empty">Nenhum pagamento lançado.</td></tr>'}</tbody></table></div></section>`}
function announcementsView(){return `<div class="sect"><p>Comunicados sobre pagamentos, uso do porto, área de banho, convivência e obras.</p><button class="btn primary" data-action="noticenew">＋ Novo comunicado</button></div><section class="card"><div class="sect"><h2>Comunicados registrados</h2><span class="pill">${store.announcements.length}</span></div>
 ${scopedAnnouncements().map(a=>`<div class="listitem notice"><span class="circle">✉</span><div><div class="spaced"><strong>${h(a.title)}</strong><span class="mini muted">${fmtDate(a.created_at)}</span></div><p class="muted" style="margin:8px 0;white-space:pre-wrap">${h(a.body)}</p><span class="pill gray">${a.audience==='all'?'Todos':'Destinatários selecionados'}</span> <button class="btn sm light" data-action="noticewa" data-id="${a.id}">Preparar envios por WhatsApp</button></div></div>`).join('')||'<div class="empty">Nenhum comunicado.</div>'}</section>
 <section class="card"><div class="sect"><h2>Faturas e lembretes por WhatsApp</h2><span class="pill yellow">Integração oficial exige configuração</span></div>
 <p>O envio manual abre o WhatsApp com a mensagem pronta. O disparo automático real será feito pela API oficial do WhatsApp Business, após configurar o serviço e os modelos aprovados.</p>
 <div class="note">Programação prevista: emissão das faturas após o fechamento e lembrete no dia <b>9</b>, para quem ainda tiver saldo a pagar, antes do vencimento no dia <b>10</b> do mês seguinte ao consumo.</div>
 <div class="actions" style="margin-top:15px"><button data-action="downloadwa" class="btn light">⬇ Lista de mensagens individuais</button><button data-action="sendcloud" data-kind="invoice" class="btn primary" ${DEMO?'disabled':''}>Enviar faturas via integração</button><button data-action="sendcloud" data-kind="reminder" class="btn outline" ${DEMO?'disabled':''}>Enviar lembretes pela integração</button></div>
 <div class="table-wrap" style="margin-top:18px"><table><thead><tr><th>Proprietário</th><th>Telefone cadastrado</th><th>Consentimento</th><th class="right">Saldo</th><th>WhatsApp assistido</th></tr></thead><tbody>${orderedOwners().map(o=>`<tr><td>${h(o.name)}</td><td>${h(o.whatsapp||'—')}</td><td>${o.whatsapp_opt_in?'Sim':'Não confirmado'}</td><td class="amount">${brl(ownerBalance(o.id))}</td><td><button class="btn sm light" data-action="whatsapp" data-id="${o.id}" ${!o.whatsapp?'disabled':''}>Abrir conversa</button></td></tr>`).join('')}</tbody></table></div></section>`}
function reportsView(){const s=monthSummary();return `<div class="sect"><p>Relatórios administrativos completos e balancete coletivo para o grupo.</p></div>
 <div class="stats" style="grid-template-columns:repeat(3,minmax(0,1fr))"><div class="metric"><small>Cobrado no mês</small><div class="num">${brl(s.billed)}</div></div><div class="metric green"><small>Recebido no mês</small><div class="num">${brl(s.received)}</div></div><div class="metric gold"><small>Saldo global</small><div class="num">${brl(s.debt)}</div></div></div>
 <section class="card"><h2>Arquivos para prestação de contas</h2><p class="muted">Use o relatório resumido para o grupo e mantenha o controle nominal apenas na administração.</p><div class="actions"><button class="btn primary" data-action="export" data-type="aggregate">⬇ Balancete para grupo (CSV)</button><button class="btn outline" data-action="export" data-type="full">⬇ Planilha administrativa (CSV)</button><button class="btn light" data-action="copygroup">▣ Copiar resumo para WhatsApp</button></div>
 <div class="note alert" style="margin-top:18px">O arquivo administrativo identifica pessoas e débitos. Evite sua divulgação no grupo sem uma finalidade justificada e informação adequada aos condôminos.</div></section>`}
function settingsView(){const c=store.payment_config?.[0]||{};return `<section class="card"><h2>Recebimento por Pix</h2><p class="muted">O Pix Copia e Cola é gerado com o valor da fatura. Verifique a titularidade da chave antes de liberar o pagamento.</p>
 <form id="pix-form"><div class="form-grid">${field('pix_key','Chave Pix do condomínio',c.pix_key||'')}${field('pix_name','Nome do recebedor (até 25 letras)',c.pix_name||'')}${field('pix_city','Cidade do recebedor',c.pix_city||'')}
 <div class="field full"><label><input type="checkbox" name="pix_enabled" ${c.pix_enabled?'checked':''}> Confirmo que a chave pertence ao recebedor correto e autorizo gerar os códigos Pix.</label></div></div><button class="btn primary" type="submit" style="margin-top:17px">Salvar configurações</button></form></section>
 <section class="card"><h2>Segurança e usuários</h2><p>A visão do condômino funciona com contas individuais do Supabase, vinculadas ao UID do usuário no cadastro. As regras de segurança também são aplicadas no banco de dados, não apenas na interface.</p>
 <p class="note">Não coloque chaves privadas nem tokens de WhatsApp no GitHub. A chave pública do Supabase pode ficar no arquivo config.js; as chaves de serviço devem ser guardadas apenas no Supabase.</p></section>`}
function portalHome(){const o=store.owners.find(x=>x.id===currentOwnerId);if(!o)return '<div class="note alert">Sua conta ainda não está vinculada a um cadastro de condômino. Solicite o vínculo ao síndico.</div>';
 const inv=ownerInvoices(o.id).slice().reverse(),last=inv[0],bal=ownerBalance(o.id);
 return `<div class="hero"><div><p>Bem-vindo ao seu espaço</p><h2>${h(o.name)}</h2><div>Consulte suas faturas, pagamentos e avisos a qualquer momento.</div></div><button class="btn gold" data-action="nav" data-id="faturas">Ver minhas faturas →</button></div>
 <div class="stats" style="grid-template-columns:repeat(3,minmax(0,1fr))"><div class="metric"><small>Meus lotes</small><div class="num">${permittedLots(o.id).map(l=>h(l.number)).join(' / ')||'—'}</div></div><div class="metric ${bal>0?'gold':'green'}"><small>Saldo em aberto</small><div class="num">${brl(Math.max(0,bal))}</div></div><div class="metric"><small>Última fatura</small><div class="num">${last?brl(last.current_amount):'—'}</div><div class="hint">${last?labelMonth(last.period_id):'Aguardando emissão'}</div></div></div>
 <div class="layout two"><section class="card"><div class="sect"><h2>Minhas faturas</h2><button data-action="nav" data-id="faturas" class="btn sm light">Ver todas</button></div>${inv.slice(0,4).map(i=>`<div class="balance-row"><div><strong>${h(labelMonth(i.period_id))}</strong><div class="mini muted">Vencimento ${fmtDate(i.due_date)}</div></div><button class="btn sm outline" data-action="invoice" data-id="${i.id}">${brl(i.current_amount)} →</button></div>`).join('')||'<div class="empty">Ainda não há faturas emitidas.</div>'}</section>
 <section class="card"><div class="sect"><h2>Últimos avisos</h2><button data-action="nav" data-id="avisos" class="btn sm light">Ver mural</button></div>${scopedAnnouncements().slice(0,4).map(a=>`<div class="listitem"><strong>${h(a.title)}</strong><div class="mini muted">${fmtDate(a.created_at)}</div><p style="margin:7px 0 0">${h(a.body.slice(0,120))}${a.body.length>120?'…':''}</p></div>`).join('')||'<div class="empty">Nenhum aviso no momento.</div>'}</section></div>`}
function portalInvoices(){const id=currentOwnerId;if(!id)return '<div class="note">Conta não vinculada.</div>';return `<section class="card"><div class="sect"><h2>Histórico de faturas</h2><span class="pill">Somente seus dados</span></div><div class="table-wrap"><table><thead><tr><th>Competência</th><th>Vencimento</th><th class="right">Valor do mês</th><th class="right">Saldo anterior na emissão</th><th></th></tr></thead><tbody>${ownerInvoices(id).slice().reverse().map(i=>`<tr><td><strong>${h(labelMonth(i.period_id))}</strong></td><td>${fmtDate(i.due_date)}</td><td class="amount">${brl(i.current_amount)}</td><td class="amount">${brl(i.previous_balance_at_issue)}</td><td><button class="btn sm primary" data-action="invoice" data-id="${i.id}">Abrir fatura</button></td></tr>`).join('')||'<tr><td colspan="5" class="empty">Não há faturas.</td></tr>'}</tbody></table></div></section>`}
function portalPayments(){const id=currentOwnerId;if(!id)return '<div class="note">Conta não vinculada.</div>';return `<div class="stats" style="grid-template-columns:1fr 1fr"><div class="metric green"><small>Pagamento total registrado</small><div class="num">${brl(totalPayments(id))}</div></div><div class="metric gold"><small>Saldo em aberto</small><div class="num">${brl(Math.max(0,ownerBalance(id)))}</div></div></div><section class="card"><h2>Meu histórico de pagamentos</h2><div class="table-wrap"><table><thead><tr><th>Data</th><th>Meio</th><th>Referência</th><th class="right">Valor</th></tr></thead><tbody>${ownerPayments(id).map(p=>`<tr><td>${fmtDate(p.paid_at)}</td><td>${h(p.method)}</td><td>${h(p.reference||'—')}</td><td class="amount">${brl(p.amount)}</td></tr>`).join('')||'<tr><td colspan="4" class="empty">Nenhum pagamento registrado.</td></tr>'}</tbody></table></div></section>`}
function portalNotices(){return `<section class="card"><h2>Comunicados do condomínio</h2>${scopedAnnouncements().map(a=>`<div class="listitem notice"><div class="circle">✉</div><div><strong>${h(a.title)}</strong><div class="mini muted">${fmtDate(a.created_at)} • ${h(a.category)}</div><p style="white-space:pre-wrap;margin-top:10px">${h(a.body)}</p></div></div>`).join('')||'<div class="empty">Nenhum comunicado.</div>'}</section>`}
function showModal(title,body,wide=false){const root=$('#modal-root');if(!root)return;root.innerHTML=`<div class="modal-back" id="modal-back"><div class="modal ${wide?'wide':''}" role="dialog" aria-modal="true"><header><h2>${h(title)}</h2><button data-action="closemodal" aria-label="Fechar" class="close">×</button></header>${body}</div></div>`;modalOpen=true;}
function hideModal(){const root=$('#modal-root');if(root)root.innerHTML='';modalOpen=false}
function showOwnerForm(id){const o=store.owners.find(x=>x.id===id)||{id:uuid(),name:'',whatsapp:'',whatsapp_opt_in:false,opening_balance:0,login_user_id:''};showModal(id?'Editar condômino':'Cadastrar condômino',`<form id="owner-form"><input name="id" type="hidden" value="${o.id}"><div class="form-grid two">${field('name','Nome do condômino / titular',o.name)}${field('whatsapp','WhatsApp (DDD + número)',o.whatsapp||'')}
 ${field('opening_balance','Saldo inicial anterior ao sistema (R$)',o.opening_balance||0,'number',false,'min="0" step="0.01"')}${field('login_user_id','UID da conta no Supabase (opcional)',o.login_user_id||'')}
 <div class="field full"><label><input name="whatsapp_opt_in" type="checkbox" ${o.whatsapp_opt_in?'checked':''}> Titular autorizou mensagens automáticas pelo WhatsApp</label></div></div>
 <div class="note alert" style="margin:15px 0">O saldo inicial deve vir de registros conferidos. A vinculação de login só deve ser feita após criar o usuário no Supabase Authentication e confirmar o UID.</div>
 <div class="actions"><button class="btn primary" type="submit">Salvar condômino</button><button class="btn outline" type="button" data-action="closemodal">Cancelar</button></div></form>`)}
function showLotForm(id){const l=store.lots.find(x=>x.id===id)||{id:uuid(),number:'',owner_id:store.owners[0]?.id||'',built:false,solar_opt_in:false};showModal(id?'Editar lote':'Cadastrar lote',`<form id="lot-form"><input name="id" type="hidden" value="${l.id}"><div class="form-grid two">${field('number','Número do lote (ex.: 9-A)',l.number)}<div class="field"><label>Responsável pela cobrança</label><select name="owner_id">${orderedOwners().map(o=>`<option value="${o.id}" ${o.id===l.owner_id?'selected':''}>${h(o.name)}</option>`).join('')}</select></div>
 <div class="field"><label><input name="built" type="checkbox" ${l.built?'checked':''}> Há construção / rancho no lote</label></div><div class="field"><label><input name="solar_opt_in" type="checkbox" ${l.solar_opt_in?'checked':''}> Participa do investimento solar</label></div></div>
 <p class="formhelp">Se houver mais de um lote do mesmo titular com construção, apenas um deles gera taxa cheia (R$ 75); os demais geram R$ 35.</p><div class="actions" style="margin-top:15px"><button class="btn primary" type="submit">Salvar lote</button></div></form>`)}
function showNewMonth(){const recommended=store.periods.length?nextYm([...store.periods].sort((a,b)=>b.id.localeCompare(a.id))[0].id):monthToday();showModal('Abrir novo mês',`<form id="newmonth-form"><div class="field"><label>Competência do novo mês</label><input type="month" required name="id" value="${recommended}"></div>
 <p class="note" style="margin-top:14px">O aplicativo preparará o mês com vencimento no dia 10 do mês seguinte. As leituras anteriores serão preenchidas com as últimas leituras atuais disponíveis. Nenhum mês anterior será apagado.</p><button type="submit" class="btn primary" style="margin-top:18px">Criar novo mês</button></form>`)}
function showMembers(id){const o=store.owners.find(x=>x.id===id);if(!o)return;const users=(store.owner_members||[]).filter(x=>x.owner_id===id);
 showModal('Logins adicionais: '+o.name,`<p class="note">Permite que dois ou mais coproprietários acessem a mesma fatura com logins próprios. Crie os usuários no Supabase Authentication e informe o UID correto. Não compartilhe senhas.</p>
 ${users.map(u=>`<div class="balance-row"><span class="break">${h(u.user_id)}</span><button class="btn sm red" data-action="removemember" data-owner="${id}" data-id="${u.user_id}">Remover</button></div>`).join('')}
 <form id="member-form"><input type="hidden" name="owner_id" value="${id}"><div class="field" style="margin:12px 0"><label>UID do usuário adicional</label><input name="user_id" required placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"></div><button class="btn primary" type="submit">Autorizar este usuário</button></form>`);
}
function showLotAccess(id){const l=store.lots.find(x=>x.id===id);if(!l)return;const other=(store.lot_access||[]).filter(x=>x.lot_id===id);
 showModal('Coproprietários do lote '+l.number,`<p class="note">Um lote tem um responsável financeiro principal. Outros condôminos autorizados podem consultar a identificação do lote, mas não veem cobranças de terceiros.</p>
 ${other.map(a=>`<div class="balance-row"><span>${h(store.owners.find(o=>o.id===a.owner_id)?.name||'')}</span><button class="btn sm red" data-action="removelotaccess" data-id="${id}" data-owner="${a.owner_id}">Remover</button></div>`).join('')}
 <form id="lotaccess-form"><input type="hidden" name="lot_id" value="${id}"><div class="field" style="margin:12px 0"><label>Acrescentar coproprietário cadastrado</label><select name="owner_id">${store.owners.filter(o=>o.id!==l.owner_id&&!other.some(a=>a.owner_id===o.id)).map(o=>`<option value="${o.id}">${h(o.name)}</option>`).join('')}</select></div><button class="btn primary" type="submit">Adicionar acesso ao lote</button></form>`);
}
function showPaymentForm(){showModal('Registrar pagamento',`<form id="payment-form"><div class="form-grid two"><div class="field full"><label>Condômino</label><select name="owner_id" required>${orderedOwners().map(o=>`<option value="${o.id}">${h(o.name)}</option>`).join('')}</select></div>
 ${field('paid_at','Data do recebimento',new Date().toLocaleDateString('en-CA'),'date')}${field('amount','Valor recebido (R$)','0','number',false,'required min="0.01" step="0.01"')}
 <div class="field"><label>Forma de pagamento</label><select name="method"><option value="pix">Pix</option><option value="transferencia">Transferência</option><option value="dinheiro">Dinheiro</option><option value="outro">Outro</option></select></div>${field('reference','Observação / identificação do comprovante','')}
 </div><div class="actions" style="margin-top:18px"><button class="btn primary" type="submit">Registrar recebimento</button></div></form>`)}
function showNoticeForm(){showModal('Novo comunicado',`<form id="notice-form"><div class="form-grid two">${field('title','Assunto','')}
 <div class="field"><label>Categoria</label><select name="category">${['geral','convivência','área de banho','porto','obras','financeiro','emergência'].map(x=>`<option>${x}</option>`).join('')}</select></div>
 <div class="field"><label>Público</label><select name="audience" id="notice-audience"><option value="all">Todos os condôminos</option><option value="selected">Somente selecionados</option></select></div>
 <div class="field"><label>Destinatários individuais (para envio selecionado)</label><select name="target_owner_ids" multiple size="6">${orderedOwners().map(o=>`<option value="${o.id}">${h(o.name)}</option>`).join('')}</select><div class="formhelp">Use Ctrl no Windows para selecionar vários.</div></div>
 <div class="field full"><label>Mensagem</label><textarea name="body" required placeholder="Escreva o aviso com linguagem simples."></textarea></div></div><div class="actions" style="margin-top:18px"><button class="btn primary" type="submit">Publicar no mural</button></div></form>`)}

// BR Code estático com valor definido, padrão EMV/Pix e CRC-16/CCITT-FALSE.
// Pix emitido localmente: não confirma recebimento, nem gera cobrança dinâmica registrada no banco.
function tlv(id,v){return id+String(new TextEncoder().encode(v).length).padStart(2,'0')+v}
function ascii(s,lim){return String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^A-Za-z0-9 .-]/g,'').trim().toUpperCase().slice(0,lim)}
function pixCode(value){const c=store.payment_config?.[0]||{};if(!c.pix_enabled||!c.pix_key?.trim()||!c.pix_name?.trim()||!c.pix_city?.trim()||num(value)<=0)return '';
 const key=c.pix_key.trim(),me=tlv('00','br.gov.bcb.pix')+tlv('01',key);
 let payload=tlv('00','01')+tlv('01','11')+tlv('26',me)+tlv('52','0000')+tlv('53','986')+tlv('54',num(value).toFixed(2))+tlv('58','BR')+tlv('59',ascii(c.pix_name,25))+tlv('60',ascii(c.pix_city,15))+tlv('62',tlv('05','***'))+'6304';
 let crc=0xFFFF;const bytes=new TextEncoder().encode(payload);for(const byte of bytes){crc^=byte<<8;for(let i=0;i<8;i++)crc=crc&0x8000?((crc<<1)^0x1021)&0xFFFF:(crc<<1)&0xFFFF}
 return payload+crc.toString(16).toUpperCase().padStart(4,'0');
}
function invoiceHtml(i){const o=store.owners.find(x=>x.id===i.owner_id);if(!o)return '<p>Condômino não encontrado.</p>';
 const currentBalance=Math.max(0,ownerBalance(o.id,i.period_id));
 // O saldo atualizado inclui pagamentos posteriores à emissão, sem duplicar dívidas antigas.
 const issueTotal=round(num(i.current_amount)+num(i.previous_balance_at_issue));
 const pay=store.payments.filter(p=>p.owner_id===o.id&&p.paid_at<=new Date().toISOString().slice(0,10));
 const qr=pixCode(currentBalance);const invoiceKey=`${i.period_id} • ${o.name}`;
 return `<div class="bill" id="fatura-impressao"><div class="bill-head"><div><small>CONDOMÍNIO RURAL • SERRA DA MESA — GO</small><h2>PONTAL DA SERRA</h2><div>Demonstrativo individual de cobrança</div></div><div style="text-align:right"><small>COMPETÊNCIA</small><div style="font:800 22px Manrope">${h(labelMonth(i.period_id))}</div><small>Vence ${fmtDate(i.due_date)}</small></div></div>
 <div class="bill-body"><div class="bill-grid"><div><small>Responsável pela cobrança</small><div style="font-weight:800;font-size:16px">${h(o.name)}</div><div class="muted">Lote(s): ${h(ownLots(o.id).map(l=>l.number).join(', '))}</div></div><div style="text-align:right"><small>Identificação da fatura</small><div class="mini mono">${h(i.id.slice(0,8).toUpperCase())}</div><small>Emissão: ${fmtDate(i.issued_at)}</small></div></div>
 <h3>Detalhamento da cobrança</h3><div class="table-wrap"><table style="min-width:0"><thead><tr><th>Descrição</th><th class="right">Valor</th></tr></thead><tbody>${(i.items||[]).filter(x=>num(x.amount)!==0).map(it=>`<tr><td><strong>${h(it.label)}</strong><div class="mini muted">${h(it.detail||'')}</div></td><td class="amount">${brl(it.amount)}</td></tr>`).join('')}</tbody></table></div>
 <div class="balance-row"><span>Total da competência</span><strong>${brl(i.current_amount)}</strong></div><div class="balance-row"><span>Débito anterior (na emissão)</span><strong>${brl(i.previous_balance_at_issue)}</strong></div><div class="balance-row"><span>Total informado na emissão</span><strong>${brl(issueTotal)}</strong></div>
 <div class="bill-total"><div><small>Saldo atualizado para pagamento</small><div class="mini muted">Considera os pagamentos registrados</div></div><div class="big">${brl(currentBalance)}</div></div>
 ${currentBalance>0.009?(qr?`<div class="qr-area"><canvas id="pix-qrcode" width="160" height="160"></canvas><div style="min-width:0;flex:1"><h3 style="margin:0 0 6px">Pague pelo Pix</h3><p class="mini muted" style="margin:0 0 9px">QR Code e Pix Copia e Cola com o valor exato acima.</p><p class="pixtext" id="pixcode-preview">${h(qr)}</p><button class="btn sm primary no-print" data-action="copy" data-text="${h(qr)}">Copiar código Pix</button></div></div>`:`<div class="note alert">Para emitir Pix com valor, o síndico precisa configurar e confirmar a chave em <b>Configurações</b>.</div>`):'<div class="note">O cadastro não apresenta saldo vencido ou a vencer nesta data. Conserve os recibos de pagamento.</div>'}
 <div class="foot">Esta fatura foi emitida pelo sistema de administração condominial. As leituras, despesas e valores dependem dos lançamentos do síndico. Para dúvidas ou divergências, contate a administração. <b>O Pix não substitui o registro e a conferência do pagamento.</b></div></div></div>
 <div class="actions no-print" style="justify-content:center;margin-top:15px"><button class="btn primary" data-action="print">⬇ Imprimir / salvar PDF</button>${role==='admin'&&o.whatsapp?`<button class="btn light" data-action="whatsapp" data-id="${o.id}">Abrir WhatsApp</button>`:''}</div>`;
}
function showInvoice(id){const i=store.invoices.find(x=>x.id===id);if(!i){message('Fatura não encontrada');return}if(role==='owner'&&i.owner_id!==currentOwnerId){message('Acesso não autorizado');return}showModal('Fatura individual',invoiceHtml(i),true);
 const code=pixCode(Math.max(0,ownerBalance(i.owner_id,i.period_id)));
 if(code&&window.QRCode?.toCanvas){window.QRCode.toCanvas($('#pix-qrcode'),code,{width:160,margin:1,color:{dark:'#123d49',light:'#ffffff'}},err=>{if(err)message('QR Code indisponível; use o Pix Copia e Cola')})}
}
function paymentMessage(o){const i=ownerInvoices(o.id).filter(x=>x.period_id<=periodId).slice(-1)[0];const bal=Math.max(0,ownerBalance(o.id));const code=pixCode(bal);return `Olá, ${o.name}!\n\n*CONDOMÍNIO PONTAL DA SERRA*\n${i?`Fatura: ${labelMonth(i.period_id)}\nVencimento: ${fmtDate(i.due_date)}\n`:''}Saldo atualizado: *${brl(bal)}*\n${code?`\n*Pix Copia e Cola com valor:*\n${code}\n`:'\nPeça a chave Pix à administração.\n'}\nA fatura detalhada está disponível na área individual do Pontal da Serra Web.\n\nAdministração do condomínio.`}
function waLink(o){const phone=String(o.whatsapp||'').replace(/\D/g,'');if(phone.length<10)return null;const dest=phone.startsWith('55')?phone:'55'+phone;return `https://wa.me/${dest}?text=${encodeURIComponent(paymentMessage(o))}`}
function saveCSV(name,rows){const content='\uFEFF'+rows.map(csvLine).join('\r\n');const blob=new Blob([content],{type:'text/csv;charset=utf-8'});const u=URL.createObjectURL(blob);const a=document.createElement('a');a.href=u;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)}
function exportData(type){const s=monthSummary(),p=activePeriod();if(type==='aggregate')return saveCSV(`Pontal_Serra_Balancete_${periodId}.csv`,[['PONTAL DA SERRA - BALANCETE COLETIVO',labelMonth(periodId)],['Faturas emitidas',monthlyInvoices().length],['Total cobrado',round(s.billed)],['Recebido no mês',round(s.received)],['Saldo total em aberto',round(s.debt)],['Data de vencimento',p?.due_date],['Caseiro',p?.caretaker],['Iluminação',p?.lighting],['Provisão',p?.provision],['Outras despesas',p?.extra_amount]]);
 const rows=[['Proprietário','Lotes','Total da competência','Saldo anterior na emissão','Pagamentos totais registrados','Saldo atual','WhatsApp'],...orderedOwners().map(o=>{const i=monthlyInvoices().find(i=>i.owner_id===o.id);return[o.name,ownLots(o.id).map(l=>l.number).join('/'),round(i?.current_amount),round(i?.previous_balance_at_issue),round(totalPayments(o.id)),round(ownerBalance(o.id)),o.whatsapp||'']})];saveCSV(`Pontal_Serra_Controle_Administrativo_${periodId}.csv`,rows)}
function getForm(form){return Object.fromEntries(new FormData(form).entries())}
function fail(e){console.error(e);message('Não foi possível concluir: '+(e?.message||e))}
async function closeMonth(){const p=activePeriod();if(!p||p.status==='closed')return;
 const c=calcMonth(p);
 if(!c.rate){message('Informe a tarifa elétrica ou os dados da conta geral.');return}
 if(c.missing.length){message('Complete as leituras dos ranchos construídos antes de fechar.');return}
 if(c.unallocated){message('A bomba tem custo, mas não há volume de água para rateio.');return}
 if(store.invoices.some(i=>i.period_id>periodId)){message('Feche os meses em ordem cronológica para evitar duplicidade no saldo anterior.');return}
 if(!confirm('Confirma o fechamento de '+labelMonth(periodId)+'? As faturas serão emitidas e os valores ficarão bloqueados.'))return;
 try{
  // Um registro de cobrança por titular, com o saldo anterior capturado na emissão.
  const issued=new Date().toISOString();const rows=c.result.filter(r=>r.lots.length).map(r=>({id:uuid(),period_id:periodId,owner_id:r.owner.id,due_date:p.due_date,items:r.items,current_amount:r.total,previous_balance_at_issue:Math.max(0,ownerBalance(r.owner.id)),issued_at:issued}));
  await saveMany('invoices',rows,'period_id,owner_id');await saveRow('periods',{...p,status:'closed',closed_at:issued});await refresh();message('Mês fechado. Faturas disponíveis para consulta e impressão.');
  if(!DEMO){try{await cloudSend('invoice',true)}catch(sendError){console.warn('Faturas fechadas, mas envio automático não configurado:',sendError.message);message('Faturas emitidas. Envio automático indisponível; verifique o WhatsApp Business.') }}
 }catch(e){fail(e)}
}
async function newMonth(form){const data=getForm(form),id=data.id;if(!/^\d{4}-\d{2}$/.test(id))throw Error('Mês inválido');if(store.periods.some(p=>p.id===id))throw Error('Esse mês já existe');
 const previous=[...store.periods].filter(p=>p.id<id).sort((a,b)=>b.id.localeCompare(a.id))[0];
 const p={id,due_date:due(id),status:'draft',energy_rate:num(previous?.energy_rate)||0,general_prev:num(previous?.general_curr),general_curr:num(previous?.general_curr),general_invoice:0,pump_prev:num(previous?.pump_curr),pump_curr:num(previous?.pump_curr),pump_invoice:0,water_divisor:num(previous?.water_divisor)||1000,caretaker:0,lighting:0,provision:0,extra_amount:0,extra_scope:'built',solar_per_lot:0,notes:''};
 await saveRow('periods',p);
 const readings=store.owners.map(o=>{const r=store.meter_readings.filter(x=>x.owner_id===o.id&&x.period_id<id).sort((a,b)=>b.period_id.localeCompare(a.period_id))[0];return {id:uuid(),period_id:id,owner_id:o.id,energy_prev:r?.energy_curr??null,energy_curr:null,water_prev:r?.water_curr??null,water_curr:null}});
 await saveMany('meter_readings',readings,'period_id,owner_id');periodId=id;hideModal();await refresh();message('Novo mês criado com leituras anteriores preenchidas.');
}
async function saveReadings(form){const p=activePeriod();if(p?.status==='closed')throw Error('Mês fechado. Leituras bloqueadas.');const rows=[];
 for(const o of store.owners){const old=activeReadings(o.id)||{};const cells=[...form.querySelectorAll(`[data-owner="${o.id}"]`)];const fields=Object.fromEntries(cells.map(x=>[x.dataset.col,x.value===''?null:Number(x.value)]));
 const v={id:old.id||uuid(),period_id:periodId,owner_id:o.id,...fields};if((v.energy_curr!==null&&v.energy_prev!==null&&v.energy_curr<v.energy_prev)||(v.water_curr!==null&&v.water_prev!==null&&v.water_curr<v.water_prev))throw Error('A leitura atual de '+o.name+' é inferior à anterior');rows.push(v)}
 await saveMany('meter_readings',rows,'period_id,owner_id');await refresh();message('Leituras salvas.')
}
async function submitForm(e){const form=e.target;if(!form.id)return;
 e.preventDefault();try{
 switch(form.id){
  case 'period-form':{const p=activePeriod();if(p.status==='closed')return;const d=getForm(form);for(const k of periodColumns)d[k]=num(d[k]);if(d.general_curr<d.general_prev||d.pump_curr<d.pump_prev)throw Error('Leitura atual do medidor geral ou da bomba menor que a anterior');if(d.water_divisor<=0)throw Error('Divisor da água inválido');await saveRow('periods',{...p,...d});await refresh();message('Custos gerais salvos.');break}
  case 'newmonth-form':await newMonth(form);break;
  case 'readings-form':await saveReadings(form);break;
  case 'owner-form':{const d=getForm(form);if(!d.name?.trim())throw Error('Informe o nome');d.whatsapp=String(d.whatsapp||'').replace(/\D/g,'');d.whatsapp_opt_in=!!form.elements.whatsapp_opt_in.checked;d.opening_balance=asMoney(d.opening_balance);d.login_user_id=d.login_user_id.trim()||null;
     await saveRow('owners',d);hideModal();await refresh();message('Condômino salvo.');break}
  case 'lot-form':{const d=getForm(form);if(!d.number.trim())throw Error('Informe o lote');d.number=normalizeLot(d.number);d.built=form.elements.built.checked;d.solar_opt_in=form.elements.solar_opt_in.checked;
     await saveRow('lots',d);hideModal();await refresh();message('Lote salvo.');break}
  case 'payment-form':{const d=getForm(form);if(num(d.amount)<=0)throw Error('Valor precisa ser positivo');if(!d.paid_at)throw Error('Informe a data');d.id=uuid();d.amount=asMoney(d.amount);await saveRow('payments',d);hideModal();await refresh();message('Pagamento registrado. Saldo atualizado.');break}
  case 'member-form':{const d=getForm(form);if(!/^[0-9a-f-]{36}$/i.test(d.user_id))throw Error('UID inválido');if(DEMO){store.owner_members.push({owner_id:d.owner_id,user_id:d.user_id});saveDemo()}else{const {error}=await sb.from('owner_members').insert(d);if(error)throw Error(error.message)}hideModal();await refresh();message('Acesso adicional autorizado.');break}
  case 'lotaccess-form':{const d=getForm(form);if(!d.owner_id)throw Error('Selecione um coproprietário');if(DEMO){store.lot_access.push(d);saveDemo()}else{const {error}=await sb.from('lot_access').insert(d);if(error)throw Error(error.message)}hideModal();await refresh();message('Coproprietário autorizado.');break}
  case 'notice-form':{const d=getForm(form);const targets=Array.from(form.elements.target_owner_ids.selectedOptions).map(x=>x.value);if(!d.title.trim()||!d.body.trim())throw Error('Preencha título e texto');if(d.audience==='selected'&&!targets.length)throw Error('Selecione pelo menos um destinatário');
     const row={id:uuid(),title:d.title,body:d.body,category:d.category,audience:d.audience,target_owner_ids:d.audience==='selected'?targets:[],created_at:new Date().toISOString()};await saveRow('announcements',row);hideModal();await refresh();message('Comunicado registrado no mural.');break}
  case 'pix-form':{const d=getForm(form);d.pix_enabled=form.elements.pix_enabled.checked;
    if(d.pix_enabled&&(!d.pix_key||!d.pix_name||!d.pix_city))throw Error('Preencha chave, nome e cidade antes de ativar o Pix');await saveRow('payment_config',{id:1,...d});await refresh();message('Configurações de Pix atualizadas.');break}
 }
 }catch(err){fail(err)}
}
function normalizeLot(s){const v=String(s).toUpperCase().replace(/\s+/g,'').replace(/^(\d+)([AB])$/,'$1-$2');return v}
function parseLots(s){return String(s||'').split(/\s*[/,;]\s*/).map(normalizeLot).filter(Boolean)}
function importXlsx(){if(role!=='admin')return;const input=document.createElement('input');input.type='file';input.accept='.xlsx,.xls';input.addEventListener('change',async()=>{
 const file=input.files?.[0];if(!file)return;
 if(!window.XLSX){message('Biblioteca Excel ainda não carregou; confira a conexão.');return}
 try{
 const wb=window.XLSX.read(await file.arrayBuffer(),{type:'array',cellDates:true});const sheet=wb.Sheets['PLANILHA NOV'];if(!sheet)throw Error('Não encontrei a aba PLANILHA NOV. Envie a planilha mensal original do síndico.');
 const rows=window.XLSX.utils.sheet_to_json(sheet,{header:1,defval:null,raw:true});const parsed=rows.slice(2).filter(r=>r[0]&&r[1]&&typeof r[0]==='string'&& !/TOTAL|CONDOM|PLANILHA|CONDÔMINOS/i.test(String(r[0]))).slice(0,80);
 if(!parsed.length)throw Error('Não encontrei nomes e lotes na planilha.');
 const existingOwnerMap=new Map(store.owners.map(o=>[o.name.trim().toUpperCase(),o]));let newOwners=[],newLots=[],seenLots=new Set(store.lots.map(l=>normalizeLot(l.number)));
 const base=wb.Sheets['PLANILHA BASE'];const baseRows=base?window.XLSX.utils.sheet_to_json(base,{header:1,defval:null}):[];const readings=[];
 for(const row of parsed){const name=String(row[0]).trim();const lots=parseLots(row[1]);if(!lots.length||!/^\d/.test(lots[0]))continue;
  let owner=existingOwnerMap.get(name.toUpperCase());if(!owner){owner={id:uuid(),name,whatsapp:'',whatsapp_opt_in:false,login_user_id:null,opening_balance:Math.max(0,asMoney(row[9]))};newOwners.push(owner);existingOwnerMap.set(name.toUpperCase(),owner)}
  const built=num(row[7])>=75;for(const n of lots){if(!seenLots.has(n)){newLots.push({id:uuid(),number:n,owner_id:owner.id,built,solar_opt_in:false});seenLots.add(n)}}
  const matching=baseRows.slice(3).find(r=>normalizeLot(String(r[1]||''))===normalizeLot(String(row[1]||'')));
  if(matching&&activePeriod()?.status!=='closed'){
    const existing=activeReadings(owner.id)||{};readings.push({id:existing.id||uuid(),owner_id:owner.id,period_id:periodId,energy_prev:isNum(matching[2])?num(matching[2]):null,energy_curr:isNum(matching[3])?num(matching[3]):null,water_prev:isNum(matching[12])?num(matching[12]):null,water_curr:isNum(matching[13])?num(matching[13]):null});
  }
 }
 if(!confirm(`Importar da planilha ${file.name}?\n\n${newOwners.length} proprietários novos, ${newLots.length} lotes novos e ${readings.length} linhas de leituras.\n\nSALDOS INICIAIS serão importados da coluna “Débito anterior” somente para novos titulares. Pagamentos e datas não serão importados automaticamente. Confira antes de usar como dado oficial.`))return;
 await saveMany('owners',newOwners);await saveMany('lots',newLots);await saveMany('meter_readings',readings,'period_id,owner_id');await refresh();message('Importação concluída. Confira todos os dados!');
 }catch(err){fail(err)}
 });input.click()}
async function cloudSend(kind,automatic=false){if(DEMO)throw Error('Somente após configurar Supabase e a API oficial do WhatsApp.');
 if(!automatic&&!confirm('Confirmar envio '+(kind==='invoice'?'das faturas':'dos lembretes')+' de '+labelMonth(periodId)+'? Somente destinatários com consentimento e WhatsApp válido serão processados.'))return;
 const {data:{session}}=await sb.auth.getSession();const res=await fetch(CONFIG.supabaseUrl+'/functions/v1/whatsapp-batch',{method:'POST',headers:{'Authorization':'Bearer '+session.access_token,'Content-Type':'application/json','apikey':CONFIG.supabaseAnonKey},body:JSON.stringify({kind,period_id:periodId})});const r=await res.json();if(!res.ok)throw Error(r.error||JSON.stringify(r));message(`Processamento: ${r.sent||0} enviado(s), ${r.skipped||0} ignorado(s), ${r.failed||0} falha(s).`)}
function downloadNoticeQueue(id){const a=store.announcements.find(x=>x.id===id);if(!a)return;const text=`*PONTAL DA SERRA — ${a.title.toUpperCase()}*\n\n${a.body}\n\nAdministração do condomínio.`;
 const owners=orderedOwners().filter(o=>a.audience==='all'||(a.target_owner_ids||[]).includes(o.id));
 const rows=[['Condômino','WhatsApp','Assunto','Texto preparado','Link WhatsApp'],...owners.map(o=>{const d=String(o.whatsapp||'').replace(/\D/g,'');const f=d.startsWith('55')?d:'55'+d;return[o.name,o.whatsapp,a.title,text,d.length>=10?`https://wa.me/${f}?text=${encodeURIComponent(text)}`:'SEM NÚMERO']})];
 saveCSV(`Pontal_Serra_Comunicado_${a.category}_${Date.now()}.csv`,rows);message('Lista de destinatários e mensagens preparada. O envio assistido é individual.');}
function downloadWhatsappQueue(){const rows=[['Proprietário','Lotes','WhatsApp','Saldo','Mensagem pronta','Link para abrir conversa'],...orderedOwners().map(o=>[o.name,ownLots(o.id).map(l=>l.number).join('/'),o.whatsapp,round(ownerBalance(o.id)),paymentMessage(o),waLink(o)||''])];saveCSV(`Pontal_Serra_WhatsApp_${periodId}.csv`,rows)}
async function copyText(s){try{await navigator.clipboard.writeText(s);message('Copiado!')}catch{message('Não foi possível copiar pelo navegador.') }}
function copyGroup(){const s=monthSummary();copyText(`*PONTAL DA SERRA — BALANCETE ${labelMonth(periodId).toUpperCase()}*\n\nFaturas emitidas: ${monthlyInvoices().length}\nTotal cobrado no período: ${brl(s.billed)}\nRecebido durante o mês: ${brl(s.received)}\nSaldo total em aberto: ${brl(s.debt)}\n\nPara consultar faturas pessoais, acesse o aplicativo com seu usuário e senha.\nAdministração.`)}
async function clickHandler(e){const el=e.target.closest('[data-action]');if(!el)return;const action=el.dataset.action,id=el.dataset.id;
 try{switch(action){case 'nav':active=id;render();break;case 'newmonth':showNewMonth();break;case 'ownernew':showOwnerForm();break;case 'owneredit':showOwnerForm(id);break;case 'members':showMembers(id);break;case 'lotaccess':showLotAccess(id);break;case 'lotnew':showLotForm();break;case 'lotedit':showLotForm(id);break;case 'paymentnew':showPaymentForm();break;case 'noticenew':showNoticeForm();break;case 'removemember':if(!confirm('Retirar o acesso adicional?'))break;if(DEMO){store.owner_members=store.owner_members.filter(m=>!(m.owner_id===el.dataset.owner&&m.user_id===id));saveDemo()}else{const {error}=await sb.from('owner_members').delete().match({owner_id:el.dataset.owner,user_id:id});if(error)throw Error(error.message)}hideModal();await refresh();break;case 'removelotaccess':if(!confirm('Retirar o acesso ao lote?'))break;if(DEMO){store.lot_access=store.lot_access.filter(m=>!(m.lot_id===id&&m.owner_id===el.dataset.owner));saveDemo()}else{const {error}=await sb.from('lot_access').delete().match({lot_id:id,owner_id:el.dataset.owner});if(error)throw Error(error.message)}hideModal();await refresh();break;case 'closemodal':hideModal();break;case 'closemonth':await closeMonth();break;case 'invoice':showInvoice(id);break;case 'print':window.print();break;case 'copy':await copyText(el.dataset.text);break;case 'whatsapp':{const o=store.owners.find(o=>o.id===id);const url=o&&waLink(o);if(url)window.open(url,'_blank','noopener');else message('Número de WhatsApp inválido');break}
 case 'export':exportData(el.dataset.type);break;case 'copygroup':copyGroup();break;case 'downloadwa':downloadWhatsappQueue();break;case 'noticewa':downloadNoticeQueue(id);break;case 'importxlsx':importXlsx();break;case 'sendcloud':await cloudSend(el.dataset.kind);break;
 case 'toggle':role=role==='admin'?'owner':'admin';if(role==='owner'){currentOwnerId=store.owners[0]?.id;active='inicio'}else active='dashboard';render();break;
 case 'logout':await sb.auth.signOut();remoteUser=null;renderLogin();break;
 }}catch(err){fail(err)}
}
function renderLogin(error=''){document.querySelector('#app').innerHTML=`<div class="login"><div class="login-art"><div style="font-size:22px;font-weight:800">≈ PONTAL DA SERRA</div><div><h1>O seu pedaço de tranquilidade, bem cuidado.</h1><p>Água, energia, faturas e avisos do condomínio. Uma plataforma segura para síndico e condôminos.</p></div><small>Serra da Mesa · Niquelândia / Goiás</small></div><div class="login-form"><div class="login-box"><div class="eyebrow">Acesso reservado</div><h2>Entre na sua conta</h2><p class="muted">Cada proprietário vê somente suas informações.</p>${error?`<div class="note red">${h(error)}</div>`:''}<form id="login-form"><div class="field"><label>E-mail</label><input type="email" name="email" required autocomplete="username"></div><div class="field"><label>Senha</label><input type="password" name="password" required autocomplete="current-password"></div><button class="btn primary" type="submit">Entrar no Pontal da Serra →</button></form><p class="mini muted" style="margin-top:22px">Solicite seu acesso ao síndico. Seus dados não são públicos.</p></div></div></div>`}
async function login(e){e.preventDefault();const f=e.target;const {data,error}=await sb.auth.signInWithPassword({email:f.elements.email.value,password:f.elements.password.value});if(error)renderLogin('Confira e-mail e senha.');else await refresh()}
async function boot(){try{
 if(!DEMO){const mod=await import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm');sb=mod.createClient(CONFIG.supabaseUrl,CONFIG.supabaseAnonKey,{auth:{persistSession:true,autoRefreshToken:true}})}
 const ok=await load();if(ok!==false)render();document.addEventListener('click',clickHandler);document.addEventListener('submit',e=>{if(e.target.id==='login-form'){login(e);return}submitForm(e)});
 document.addEventListener('change',e=>{if(e.target.id==='period-select'){periodId=e.target.value;render()}});
 document.addEventListener('keydown',e=>{if(e.key==='Escape'&&modalOpen)hideModal()});
 if('serviceWorker' in navigator&&location.protocol==='https:')navigator.serviceWorker.register('./sw.js').catch(()=>{});
 }catch(err){console.error(err);$('#app').innerHTML=`<div class="login-form" style="min-height:100vh"><div class="card"><h2>Não foi possível abrir o aplicativo</h2><p>${h(err.message)}</p><p>Confira sua conexão e as configurações do banco de dados.</p></div></div>`}}
boot();

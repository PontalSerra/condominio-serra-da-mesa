/**
 * WhatsApp Cloud API — envio de faturas e lembretes.
 * Não é executável sem WhatsApp Business API, templates aprovados e segredos.
 * Deploy: supabase functions deploy whatsapp-batch --no-verify-jwt
 * Chamadas manuais exigem JWT válido de síndico; cron exige X-Cron-Secret.
 * O destinatário recebe template com link para portal autenticado, não PDF aberto ao público.
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={ 'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-cron-secret','Access-Control-Allow-Methods':'POST,OPTIONS' };
const json=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{...cors,'Content-Type':'application/json'}});
const required=(key:string)=>{const val=Deno.env.get(key);if(!val)throw Error(`Falta configurar ${key}`);return val};
const money=(n:number)=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n);
const ymLong=(p:string)=>{const [year,month]=p.split('-').map(Number);return new Intl.DateTimeFormat('pt-BR',{month:'long',year:'numeric',timeZone:'UTC'}).format(new Date(Date.UTC(year,month-1,1)))};
const phone=(v:string)=>{const d=(v||'').replace(/\D/g,'');return d.startsWith('55')?d:`55${d}`};
Deno.serve(async(req)=>{
 if(req.method==='OPTIONS')return new Response(null,{headers:cors});if(req.method!=='POST')return json({error:'Somente POST'},405);
 try{
  const url=required('SUPABASE_URL'),key=required('SUPABASE_SERVICE_ROLE_KEY');
  const db=createClient(url,key,{auth:{autoRefreshToken:false,persistSession:false}});
  const cronKey=req.headers.get('x-cron-secret');const fromCron=!!cronKey&&cronKey===required('CRON_SECRET');
  if(!fromCron){const jwt=(req.headers.get('authorization')||'').replace(/^Bearer /i,'');if(!jwt)return json({error:'Acesso negado'},401);
   const {data:u,error:e}=await db.auth.getUser(jwt);if(e||!u.user)return json({error:'Sessão inválida'},401);
   const {data:admin}=await db.from('app_admins').select('user_id').eq('user_id',u.user.id).maybeSingle();if(!admin)return json({error:'Somente o síndico pode enviar mensagens'},403);
  }
  const requestBody=await req.json();const kind=requestBody.kind;let period_id=requestBody.period_id;
  const localDate=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  if(kind==='reminder'&&!period_id){const year=Number(localDate.slice(0,4)),month=Number(localDate.slice(5,7));const prev=new Date(Date.UTC(year,month-2,1));period_id=prev.toISOString().slice(0,7)}
  if(!['invoice','reminder'].includes(kind)||!/^\d{4}-\d{2}$/.test(String(period_id)))return json({error:'Dados inválidos'},400);
  if(kind==='reminder'&&!localDate.endsWith('-09'))return json({error:'Lembretes automáticos só podem ser enviados no dia 9, em horário de Brasília.'},400);
  const {data:invoices,error:ie}=await db.from('invoices').select('id,period_id,owner_id,due_date,current_amount').eq('period_id',period_id);
  if(ie)throw ie;if(!invoices?.length)return json({error:'Nenhuma fatura emitida neste período'},400);
  const ids=[...new Set(invoices.map(i=>i.owner_id))];const {data:owners,error:oe}=await db.from('owners').select('id,name,whatsapp,whatsapp_opt_in,opening_balance').in('id',ids);if(oe)throw oe;
  const {data:allInvoices,error:ai}=await db.from('invoices').select('owner_id,period_id,current_amount').in('owner_id',ids).lte('period_id',period_id);if(ai)throw ai;
  const {data:allPayments,error:ap}=await db.from('payments').select('owner_id,paid_at,amount').in('owner_id',ids);if(ap)throw ap;
  const {data:logs,error:le}=await db.from('whatsapp_log').select('owner_id').eq('period_id',period_id).eq('kind',kind);if(le)throw le;
  const sentOwners=new Set((logs||[]).map(x=>x.owner_id));let sent=0,skipped=0,failed=0;const failures=[];
  const tpl=kind==='invoice'?required('WHATSAPP_TEMPLATE_INVOICE'):required('WHATSAPP_TEMPLATE_REMINDER');
  const token=required('WHATSAPP_TOKEN'),numberId=required('WHATSAPP_PHONE_NUMBER_ID');
  for(const invoice of invoices){
   const owner=owners?.find(x=>x.id===invoice.owner_id);const dst=phone(owner?.whatsapp||'');
   if(!owner||!owner.whatsapp_opt_in||dst.length<12||sentOwners.has(invoice.owner_id)){skipped++;continue}
   const balance=Math.max(0,Number(owner.opening_balance||0)+
    (allInvoices||[]).filter(i=>i.owner_id===owner.id).reduce((s,i)=>s+Number(i.current_amount),0)-
    (allPayments||[]).filter(p=>p.owner_id===owner.id).reduce((s,p)=>s+Number(p.amount),0));
   if(kind==='reminder'){
     const tomorrow=new Date(localDate+'T12:00:00-03:00');tomorrow.setDate(tomorrow.getDate()+1);
     const next=tomorrow.toLocaleDateString('en-CA',{timeZone:'America/Sao_Paulo'});
     if(invoice.due_date!==next||balance<=.005){skipped++;continue}
   }
   const variables=kind==='invoice'?[owner.name,ymLong(period_id),money(balance),invoice.due_date.split('-').reverse().join('/')]:[owner.name,money(balance),invoice.due_date.split('-').reverse().join('/')];
   const body={messaging_product:'whatsapp',to:dst,type:'template',template:{name:tpl,language:{code:'pt_BR'},components:[{type:'body',parameters:variables.map(text=>({type:'text',text}))}]}};
   const res=await fetch(`https://graph.facebook.com/v23.0/${numberId}/messages`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify(body)});
   const result=await res.json();if(!res.ok){failed++;failures.push({owner:owner.id,error:result?.error?.message||res.status});continue}
   const {error:logError}=await db.from('whatsapp_log').insert({owner_id:owner.id,period_id,kind,provider_message_id:result.messages?.[0]?.id||null});
   if(logError){failed++;failures.push({owner:owner.id,error:'Mensagem enviada, mas falha no registro do envio.'});continue}sent++;
  }
  return json({kind,period_id,sent,skipped,failed,failures});
 }catch(e){return json({error:e instanceof Error?e.message:String(e)},500)}
});

import test from 'node:test';import assert from 'node:assert/strict';
import {supportsPasskeys,passkeyMessage,signInPasskey,registerPasskey,listPasskeys,removePasskey} from '../seguranca.js';
import {reopeningBlockers,simulationHtml} from '../fechamento.js';
import {communityErrors,communityView} from '../vida-pontal.js';
test('chave de acesso exige suporte e autenticação confirmada pelo servidor',async()=>{
 assert.equal(supportsPasskeys({isSecureContext:true,PublicKeyCredential:{},navigator:{credentials:{}}}),true);assert.equal(supportsPasskeys({isSecureContext:false}),false);
 assert.match(passkeyMessage({code:'passkey_disabled'}),/ativado/);assert.match(passkeyMessage({name:'NotAllowedError'}),/cancelada/);
 await assert.rejects(signInPasskey({auth:{signInWithPasskey:async()=>({data:{},error:null})}}),/não foi confirmada/);
 const data={session:{access_token:'ficticio'},user:{id:'u'}};assert.equal(await signInPasskey({auth:{signInWithPasskey:async()=>({data})}}),data);
 await assert.rejects(registerPasskey({auth:{registerPasskey:async()=>({error:{code:'passkey_disabled'}})}}),/ativado/);
 assert.equal((await registerPasskey({auth:{registerPasskey:async()=>({data:{id:'key'}})}})).id,'key');
 let removed;const client={auth:{passkey:{list:async()=>({data:[{id:'key'}]}),delete:async x=>{removed=x;return{};}}}};
 assert.equal((await listPasskeys(client)).length,1);await removePasskey(client,'key');assert.deepEqual(removed,{passkeyId:'key'});
});
test('simulação conserva os dados e distingue resultado provisório de emissão',()=>{
 const p={id:'2026-11',status:'draft'},c={errors:['Conferir medidor'],result:[{owner:{name:'Exemplo'},lots:[{number:'15'}],total:75}]},before=JSON.stringify([p,c]);
 const html=simulationHtml(p,c,{h:s=>s,brl:n=>'R$ '+n});assert.match(html,/sem emissão de faturas/);assert.match(html,/Conferir medidor/);assert.match(html,/75/);assert.equal(JSON.stringify([p,c]),before);
});
test('reabertura considera pagamentos, faturas posteriores, reservas e envios',()=>{
 const p={id:'2026-11',status:'closed',closed_at:'2026-11-24T12:00:00Z'},s={periods:[p],invoices:[{period_id:p.id,owner_id:'a'}],payments:[],employee_payouts:[],whatsapp_log:[]};assert.deepEqual(reopeningBlockers(s,p),[]);
 s.payments.push({owner_id:'a',paid_at:'2026-11-24'});assert.match(reopeningBlockers(s,p).join(),/pagamentos/);s.payments=[];
 s.periods.push({id:'2026-12',status:'closed'});assert.match(reopeningBlockers(s,p).join(),/posterior/);s.periods.pop();
 s.employee_payouts.push({period_id:p.id});assert.match(reopeningBlockers(s,p).join(),/reservas/);s.employee_payouts=[];
 s.whatsapp_log.push({period_id:p.id,kind:'invoice'});assert.match(reopeningBlockers(s,p).join(),/envio/);
});
test('Vida no Pontal valida endereços e oculta rascunhos do condômino',()=>{
 assert.ok(communityErrors({title:'Norma',category:'norma',url:'javascript:alert(1)'}).length);assert.deepEqual(communityErrors({title:'Norma',category:'norma',url:'https://example.invalid/'}),[]);
 const items=[{id:'d',title:'Rascunho confidencial',category:'norma',body:'Em revisão',published:false}],f={h:s=>s,fmtDate:s=>s};assert.doesNotMatch(communityView(items,false,f),/Rascunho confidencial/);assert.match(communityView(items,true,f),/Rascunho confidencial/);assert.match(communityView([],false,f),/não são atualizados automaticamente/);
});

test('documentos separam mês e investimento sem revelar rascunhos',async()=>{
 const {monthlyDocumentsHtml,investmentDocumentsHtml}=await import('../vida-pontal.js'),f={h:s=>s,fmtDate:s=>s};
 const docs=[{id:'m',title:'Conta de novembro',period_id:'2026-11',context:'condominio',document_kind:'conta_energia',published:true},{id:'s',title:'Nota fiscal do solar',context:'solar',published:true},{id:'r',title:'Rascunho da bomba',period_id:'2026-11',context:'condominio',published:false}];
 assert.match(monthlyDocumentsHtml(docs,'2026-11',false,f),/Conta de novembro/);assert.doesNotMatch(monthlyDocumentsHtml(docs,'2026-11',false,f),/Rascunho da bomba|Nota fiscal do solar/);assert.match(investmentDocumentsHtml(docs,false,f),/Nota fiscal do solar/);assert.doesNotMatch(investmentDocumentsHtml(docs,false,f),/Conta de novembro/);
 assert.ok(communityErrors({title:'Foto',category:'documento',document_kind:'leitura_geral'}).length);
});

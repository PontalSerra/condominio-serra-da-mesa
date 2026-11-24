// As funções recebem a API da aplicação para manter interface e persistência juntas.
import {CATEGORIES,defaultSettings,effectiveRule,ruleErrors,allocationDetail} from './rateios.js';
export function allocationPanel(api) {
 const {store,periodId,activePeriod,orderedOwners,ownLots,h,brl,calcMonth}=api;
 const p=activePeriod(),c=p?calcMonth(p):null;
 return `<section class="card"><div class="sect"><div><h2>Regras de cobrança por responsável</h2><p>Taxa mensal, participação e cotas podem ser diferentes em cada despesa.</p></div><span class="pill">${h(periodId)}</span></div>
 <p class="muted">Sem regra individual, o rateio segue o cadastro de construção. Uma regra pode incluir lote vazio, excluir um responsável ou definir outro número de cotas. Água e energia individuais seguem as leituras.</p>
 ${c?`<div class="allocation-counts">${Object.entries(CATEGORIES).map(([key,label])=>`<div><b>${h(label)}</b><span>${c.allocationGroups[key].count} participantes · ${c.allocationGroups[key].quotas} cotas</span></div>`).join('')}</div>`:''}
 <div class="field" style="margin:14px 0"><label>Buscar responsável</label><input data-owner-filter type="search" placeholder="Nome ou lote"></div><div class="table-wrap"><table><thead><tr><th>Responsável / lotes</th><th>Taxa</th>${Object.values(CATEGORIES).map(label=>`<th>${h(label)}</th>`).join('')}</tr></thead><tbody>${orderedOwners().map(owner=>{const rule=effectiveRule(store.allocation_rules,owner.id,periodId);return `<tr><td><b>${h(owner.name)}</b><div class="mini muted">${h(ownLots(owner.id).map(l=>l.number).join(' / '))}${owner.active===false?' · Inativo':''}</div><button class="btn sm outline" style="margin-top:8px" data-action="allocationrule" data-id="${owner.id}">Configurar</button></td><td>${brl(api.feeDue(owner))}</td>${Object.keys(CATEGORIES).map(key=>{const group=c?.allocationGroups[key],weight=group?.weights[owner.id]||0;return `<td>${group?(weight>0?`${weight} cota(s)`:'Não participa'):'—'}<div class="mini muted">${rule?.settings?.[key]?.mode==='auto'||!rule?'Padrão do cadastro':'Regra individual'}</div></td>`}).join('')}</tr>`}).join('')}</tbody></table></div></section>`;
}
export function ruleForm(api,ownerId,ruleId) {
 const {store,periodId,orderedOwners,ownLots,h,field,brl}=api,owner=orderedOwners().find(o=>o.id===ownerId);
 if(!owner)throw Error('Responsável não encontrado.');
 const editing=store.allocation_rules.find(r=>r.id===ruleId&&r.owner_id===ownerId);
 const active=editing||effectiveRule(store.allocation_rules,ownerId,periodId);
 const settings=active?.settings||defaultSettings();
 const maxClosed=store.periods.filter(p=>p.status==='closed').map(p=>p.id).sort().at(-1);
 const start=!editing&&maxClosed&&periodId<=maxClosed?api.nextYm(maxClosed):editing?.start_period||periodId;
 const past=editing&&store.periods.some(p=>p.status==='closed'&&p.id>=editing.start_period&&(!editing.end_period||p.id<=editing.end_period));
 const history=store.allocation_rules.filter(r=>r.owner_id===ownerId).sort((a,b)=>b.start_period.localeCompare(a.start_period));
 return {title:'Regras de cobrança — '+owner.name,body:`<p>Lotes ${h(ownLots(ownerId).map(l=>l.number).join(' / ')||'a vincular')}. A regra mais recente em vigor prevalece. Quando uma exceção temporária termina, a regra anterior volta a valer.</p>
 ${past?'<div class="note">Esta regra alcança faturas fechadas e está disponível somente para consulta. Para mudar, crie uma nova vigência.</div>':''}
 <form id="allocation-rule-form"><input type="hidden" name="id" value="${h(editing?.id||'')}"><input type="hidden" name="owner_id" value="${h(ownerId)}"><div class="form-grid two">
 ${field('start_period','A partir de qual mês?',start,'month',!!past,'required')}${field('end_period','Até qual mês? (opcional)',editing?.end_period||'','month',!!past)}
 ${field('fee_override','Taxa mensal de exceção (R$; vazio = padrão)',active?.fee_override??'','number',!!past,'min="0" step="0.01"')}<div class="field"><label>Taxa pelo cadastro</label><p>${brl(api.feeDue(owner))}. Zero na exceção significa isenção da taxa.</p></div></div>
 <div class="table-wrap"><table><thead><tr><th>Despesa</th><th>Participação</th><th>Número de cotas</th></tr></thead><tbody>${Object.entries(CATEGORIES).map(([key,label])=>`<tr><td>${h(label)}</td><td><select aria-label="Participação em ${h(label)}" name="${key}_mode" ${past?'disabled':''}>${[['auto','Seguir cadastro'],['include','Participa'],['exclude','Não participa']].map(([value,text])=>`<option value="${value}" ${(settings[key]?.mode||'auto')===value?'selected':''}>${text}</option>`).join('')}</select></td><td><input aria-label="Cotas de ${h(label)}" name="${key}_shares" type="number" min="0.01" max="1000" step="0.01" value="${h(settings[key]?.shares??1)}" required ${past?'disabled':''}></td></tr>`).join('')}</tbody></table></div>
 <p class="mini muted">Uma cota é a participação normal. Por exemplo, 0,5 representa meia cota e 2 representa duas cotas. O custo é dividido pela soma das cotas de quem participa. As despesas extraordinárias cadastradas separadamente mantêm seus próprios destinatários.</p>
 <div class="field"><label>Motivo ou deliberação</label><textarea name="reason" required ${past?'disabled':''}>${h(editing?.reason||'')}</textarea></div>
 <div class="actions" style="margin-top:16px">${!past?'<button class="btn primary" type="submit">Salvar regra por vigência</button>':''}<button class="btn light" type="button" data-action="allocationrule" data-id="${ownerId}" data-rule="new">Nova vigência</button></div></form>
 ${history.length?`<details style="margin-top:18px"><summary>Histórico de regras (${history.length})</summary>${history.map(r=>`<div class="balance-row"><div><b>${h(r.start_period)} a ${h(r.end_period||'sem término')}</b><p class="mini muted">${h(r.reason)}</p></div><button class="btn sm light" data-action="allocationrule" data-id="${ownerId}" data-rule="${r.id}">Consultar / editar</button></div>`).join('')}</details>`:''}`};
}
export function parseRuleForm(form,api) {
 const d=Object.fromEntries(new FormData(form)),rule={id:d.id||form.dataset.entryId||(form.dataset.entryId=crypto.randomUUID()),owner_id:d.owner_id,start_period:d.start_period,end_period:d.end_period||null,fee_override:d.fee_override===''?null:Number(d.fee_override),settings:Object.fromEntries(Object.keys(CATEGORIES).map(key=>[key,{mode:d[key+'_mode'],shares:Number(d[key+'_shares'])}])),reason:(d.reason||'').trim()};
 const errors=ruleErrors(rule,api.store.allocation_rules,api.store.periods);if(errors.length)throw Error(errors.join(' '));
 if(!api.ownLots(rule.owner_id).length)throw Error('Vincule um lote ao responsável antes de configurar as cobranças.');
 return rule;
}
export function groupSummary(api,calc) {
 return `<section class="card" style="margin-top:18px"><div class="sect"><h2>Participantes de cada rateio</h2><button class="btn light" data-action="nav" data-id="ajustes">Revisar regras</button></div><div class="table-wrap"><table><thead><tr><th>Despesa</th><th>Valor a distribuir</th><th>Participantes</th><th>Cotas</th><th></th></tr></thead><tbody>${Object.entries(CATEGORIES).map(([key,label])=>{const g=calc.allocationGroups[key];return `<tr><td>${api.h(label)}</td><td>${api.brl(g.amount)}</td><td>${g.count}</td><td>${api.nf(g.quotas)}</td><td><details><summary>Ver participantes</summary>${api.orderedOwners().filter(o=>g.weights[o.id]>0).map(o=>`<p>${api.h(o.name)} — ${api.h(allocationDetail(g,o.id))}</p>`).join('')||'Nenhum participante'}</details></td></tr>`}).join('')}</tbody></table></div></section>`;
}

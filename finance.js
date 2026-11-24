/* Cálculos determinísticos. Não acessa navegador, rede ou banco. */
import {effectiveRule,calculateAllocations,allocationDetail} from "./rateios.js";
export const validNumber = v => v !== null && v !== undefined && v !== '' && Number.isFinite(Number(v));
export const cents = v => Math.round((Number(v) + Number.EPSILON) * 100);
export const money = v => cents(v || 0) / 100;
const total = values => values.reduce((s, v) => s + Number(v || 0), 0);
export const validMonth = s => /^\d{4}-(0[1-9]|1[0-2])$/.test(s || '');
export function provisions(salary) {
  const base = Math.max(0, Number(salary) || 0);
  const all = cents(base * 7 / 36), thirteenth = cents(base / 12);
  return {thirteenth: thirteenth / 100, vacation: (all - thirteenth) / 100, total: all / 100};
}
// Maior resto; desempate por ID estável. A soma das parcelas é o valor exato.
export function allocate(amount, weights) {
  const value = cents(amount), entries = Object.entries(weights).filter(([, w]) => Number(w) > 0).sort(([a], [b]) => a.localeCompare(b));
  const result = Object.fromEntries(Object.keys(weights).map(k => [k, 0]));
  if (!entries.length) return result;
  const denom = total(entries.map(([, w]) => w));
  const parts = entries.map(([id, w]) => { const raw = Math.abs(value) * w / denom; return {id, base: Math.floor(raw), remainder: raw - Math.floor(raw)}; });
  let left = Math.abs(value) - total(parts.map(x => x.base));
  parts.sort((a,b) => b.remainder - a.remainder || a.id.localeCompare(b.id));
  for (const part of parts) { if (left > 0) {part.base++; left--;} result[part.id] = part.base / 100 * Math.sign(value); }
  return result;
}
export function financialLots(data, ownerId) {
  const direct = data.lots.filter(l => l.owner_id === ownerId);
  const extra = (data.financial_links || []).filter(l => l.owner_id === ownerId && !direct.some(d => d.id === l.lot_id)).map(link => {
    const lot = data.lots.find(l => l.id === link.lot_id);
    return lot ? {...lot, owner_id: ownerId, built: link.built, monthly_fee: link.monthly_fee, independent: true} : null;
  }).filter(Boolean);
  return [...direct, ...extra].sort((a,b) => a.number.localeCompare(b.number,'pt-BR',{numeric:true}));
}
export function fee(data, owner, ym) {
  const lots = financialLots(data, owner.id);
  const override = effectiveRule(data.allocation_rules,owner.id,ym);
  const rule = (data.fee_rules || []).filter(r => r.owner_id === owner.id && r.start_period <= ym && (!r.end_period || r.end_period >= ym)).sort((a,b) => b.start_period.localeCompare(a.start_period))[0];
  if (override?.fee_override !== null && override?.fee_override !== undefined && (!rule || override.start_period>=rule.start_period)) return money(override.fee_override);
  if (rule) return money(rule.amount);
  if (validNumber(owner.monthly_fee)) return money(owner.monthly_fee);
  return money(total(lots.map(l => validNumber(l.monthly_fee) ? l.monthly_fee : l.independent ? 0 : l.built ? 75 : 35)));
}
export function balance(data, ownerId, upTo = null, until = null) {
  const owner = data.owners.find(o => o.id === ownerId);
  const charges = total(data.invoices.filter(i => i.owner_id === ownerId && (!upTo || i.period_id <= upTo)).map(i => i.current_amount));
  const payments = total(data.payments.filter(p => p.owner_id === ownerId && (!until || p.paid_at <= until)).map(p => p.amount));
  return money(Number(owner?.opening_balance || 0) + charges - payments);
}
export function expenseValue(expense, ym) {
  if (ym < expense.start_period || ym > expense.end_period) return 0;
  if (expense.mode !== 'installments') return money(expense.amount);
  const index = s => Number(s.slice(0,4))*12 + Number(s.slice(5,7));
  const count = index(expense.end_period) - index(expense.start_period) + 1;
  const raw = cents(expense.amount), part = Math.floor(raw/count), rest = raw % count;
  return (part + (index(ym)-index(expense.start_period) < rest ? 1 : 0)) / 100;
}
export function calculate(data, p) {
  const owners = data.owners.filter(o=>o.active!==false||(data.invoices||[]).some(i=>i.owner_id===o.id&&i.period_id===p.id)).sort((a,b) => a.id.localeCompare(b.id));
  const errors = [], lots = Object.fromEntries(owners.map(o => [o.id, financialLots(data,o.id)]));
  const eligible = owners.filter(o => lots[o.id].some(l => l.built));
  const weights = scope => Object.fromEntries(owners.map(o => [o.id, scope === 'lot' ? data.lots.filter(l => l.owner_id === o.id).length : scope === 'all' ? (lots[o.id].length ? 1 : 0) : eligible.some(x => x.id === o.id) ? 1 : 0]));
  const distribute = (amount, w, title) => {if (cents(amount) && !Object.values(w).some(x => x>0)) errors.push(`${title}: nenhum responsável elegível.`); return allocate(amount,w);};
  if (!validMonth(p.id)) errors.push('Competência inválida.');
  for (const flag of p.review_flags||[]) if(!flag.resolved)errors.push(flag.detail);
  for (const owner of owners) if(owner.opening_balance_reviewed===false) errors.push(`${owner.name}: confira o saldo de abertura importado.`);
  for (const k of ['energy_rate','general_prev','general_curr','general_invoice','pump_prev','pump_curr','pump_invoice','caretaker','solar_per_lot','extra_amount']) {
    if (!validNumber(p[k]) || Number(p[k]) < 0) errors.push(`Valor inválido: ${k}.`);
  }
  const energyKwh = Number(p.general_curr) - Number(p.general_prev), pumpKwh = Number(p.pump_curr) - Number(p.pump_prev);
  if (energyKwh < 0 || pumpKwh < 0) errors.push('Leitura geral ou da bomba inferior à anterior.');
  const rate = Number(p.energy_rate) > 0 ? Number(p.energy_rate) : energyKwh > 0 ? Number(p.general_invoice)/energyKwh : 0;
  if (rate <= 0 && (energyKwh > 0 || Number(p.general_invoice)>0)) errors.push('Informe tarifa ou consumo geral válido.');
  let pumpCost = Number(p.pump_invoice) > 0 ? money(p.pump_invoice) : money(pumpKwh*rate);
  const pumpInside = p.pump_inside_general;
  if (typeof pumpInside !== 'boolean') errors.push('Confirme se a bomba está incluída no medidor geral.');
  const divisor = Number(p.water_divisor);
  if (!(divisor > 0)) errors.push('Fator de conversão da água inválido.');
  const readings = {}, energies = {}, waters = {}, missing = [];
  const caretakerEnergy = validNumber(p.caretaker_energy_prev)&&validNumber(p.caretaker_energy_curr)?Number(p.caretaker_energy_curr)-Number(p.caretaker_energy_prev):0;
  const caretakerWater = validNumber(p.caretaker_water_prev)&&validNumber(p.caretaker_water_curr)&&divisor>0?(Number(p.caretaker_water_curr)-Number(p.caretaker_water_prev))/divisor:0;
  if(caretakerEnergy<0||caretakerWater<0)errors.push('Leitura atual da casa do caseiro inferior à anterior.');
  for(const prefix of ['energy','water']){
    const prev=p['caretaker_'+prefix+'_prev'],curr=p['caretaker_'+prefix+'_curr'];
    if(validNumber(prev)!==validNumber(curr))errors.push('Complete as duas leituras de '+(prefix==='energy'?'energia':'água')+' da casa do caseiro.');
    if([prev,curr].some(x=>validNumber(x)&&Number(x)<0))errors.push('Leitura negativa da casa do caseiro.');
  }
  for (const o of owners) {
    const row = data.meter_readings.find(r => r.owner_id === o.id && r.period_id === p.id) || {};
    readings[o.id] = row;
    const needed = lots[o.id].some(l=>l.built) || ['energy_prev','energy_curr','water_prev','water_curr'].some(k => validNumber(row[k]) && Number(row[k])!==0);
    if (needed && !['energy_prev','energy_curr','water_prev','water_curr'].every(k => validNumber(row[k]))) missing.push(o.id);
    for (const prefix of ['energy','water']) {
      const prev = row[prefix+'_prev'], curr = row[prefix+'_curr'];
      if ([prev,curr].some(v=>validNumber(v) && Number(v)<0) || (validNumber(prev)&&validNumber(curr)&&Number(curr)<Number(prev))) errors.push(`${o.name}: leitura de ${prefix==='energy'?'energia':'água'} inválida.`);
    }
    energies[o.id] = validNumber(row.energy_curr)&&validNumber(row.energy_prev) ? Math.max(0,Number(row.energy_curr)-Number(row.energy_prev)) : 0;
    waters[o.id] = validNumber(row.water_curr)&&validNumber(row.water_prev)&&divisor>0 ? Math.max(0,(Number(row.water_curr)-Number(row.water_prev))/divisor) : 0;
    if (lots[o.id].some(l=>l.independent && !validNumber(l.monthly_fee)) && !validNumber(o.monthly_fee) && !(data.fee_rules||[]).some(r=>r.owner_id===o.id&&r.start_period<=p.id&&(!r.end_period||r.end_period>=p.id))) errors.push(`${o.name}: defina a taxa da unidade independente.`);
  }
  if (missing.length) errors.push('Complete todas as leituras dos responsáveis com consumo ou construção.');
  const individualKwh = total(Object.values(energies));
  const lightingKwh = energyKwh - individualKwh - Math.max(0,caretakerEnergy) - (pumpInside === true ? pumpKwh : 0);
  let lightingCost = money(Math.max(0, lightingKwh)*rate), caretakerEnergyCost=money(Math.max(0,caretakerEnergy)*rate);
  if (lightingKwh < -0.000001) errors.push('Submedidores e bomba superam o consumo geral.');
  const waterTotal = total(Object.values(waters))+Math.max(0,caretakerWater);
  if (p.water_unit_confirmed !== true && (waterTotal>0 || pumpCost>0)) errors.push('Confirme a unidade dos hidrômetros e o fator de conversão.');
  if (pumpCost>0 && waterTotal<=0) errors.push('Bomba com custo e sem consumo de água válido.');
  const rawEnergy = individualKwh*rate;
  let energyAmounts = allocate(rawEnergy,energies);
  const rawExpectedEnergy=rawEnergy+Math.max(0,lightingKwh)*rate+Math.max(0,caretakerEnergy)*rate+(pumpInside===true?pumpCost:0);
  const expectedEnergy = money(rawExpectedEnergy);
  if(Math.abs(Number(p.general_invoice)-rawExpectedEnergy)<=0.010001){
    const components=allocate(p.general_invoice,{individual:rawEnergy,lighting:Math.max(0,lightingKwh)*rate,caretaker:Math.max(0,caretakerEnergy)*rate,...(pumpInside===true?{pump:pumpCost}:{})});
    energyAmounts=allocate(components.individual,energies);lightingCost=components.lighting;caretakerEnergyCost=components.caretaker;if(pumpInside===true)pumpCost=components.pump;
  }
  const energyDifference = money(Number(p.general_invoice)-expectedEnergy);
  if (Math.abs(energyDifference) > 0.01) errors.push('Conta geral e componentes de energia não conciliam. Confira tarifa, bomba, tributos e créditos.');
  if (Number(p.lighting)!==0 && validNumber(p.lighting)) errors.push('Há iluminação manual antiga: revise e confirme sua substituição pelo cálculo automático.');
  if (Number(p.provision)!==0 && validNumber(p.provision)) errors.push('Há provisão manual antiga: revise e confirme sua substituição pelo cálculo automático.');
  const provision = provisions(p.caretaker), salaryCost=p.caretaker_salary_in_fee===true?0:Number(p.caretaker);
  const waterWeights={...waters,'__caretaker__':Math.max(0,caretakerWater)},waterShares=distribute(pumpCost,waterWeights,'Água');
  const caretakerWaterCost=waterShares.__caretaker__||0;
  const allocationLots=owners.flatMap(o=>lots[o.id]);
  const allocations=calculateAllocations(owners,allocationLots,data.allocation_rules||[],p,{caretaker:salaryCost+caretakerEnergyCost+caretakerWaterCost,lighting:lightingCost,provision:provision.total,extra:p.extra_amount||0});
  errors.push(...allocations.errors);
  const groups=allocations.groups,lightingShares=groups.lighting.allocations;
  const salaryShares=distribute(salaryCost,groups.caretaker.weights,'Salário do caseiro');
  const caretakerUtilities=Object.fromEntries(owners.map(o=>[o.id,money(groups.caretaker.allocations[o.id]-salaryShares[o.id])]));
  const provision13=distribute(provision.thirteenth,groups.provision.weights,'13º');
  const vacation=Object.fromEntries(owners.map(o=>[o.id,money(groups.provision.allocations[o.id]-provision13[o.id])]));
  const expenses=(data.expenses||[]).filter(e=>e.start_period<=p.id&&e.end_period>=p.id);
  const extraShares=expenses.map(e=>{const w=e.scope==='selected'?Object.fromEntries(owners.map(o=>[o.id,(e.target_owner_ids||[]).includes(o.id)?1:0])):weights(e.scope);return {expense:e,weights:w,shares:distribute(expenseValue(e,p.id),w,e.title)};});
  const legacyExtra=groups.extra.allocations;
  const result=owners.map(o=>{
    const row=readings[o.id], full=eligible.some(x=>x.id===o.id);
    const item=(code,label,amount,detail='')=>({code,label,amount:money(amount),detail});
    if(Number(p.solar_per_lot)>0&&(data.solar_participants||[]).some(s=>s.owner_id===o.id))errors.push(`${o.name}: há investimento solar próprio e cobrança solar mensal legada; zere o campo legado para evitar duplicidade.`);
    const solar=lots[o.id].some(l=>l.solar_opt_in)?money(p.solar_per_lot):0;
    const items=[item('energy','Energia elétrica',energyAmounts[o.id],`${energies[o.id]} kWh; ${row.energy_prev??'—'} → ${row.energy_curr??'—'}; tarifa ${rate.toFixed(6)}`),
      item('water','Água — energia da bomba',waterShares[o.id],`${waters[o.id]} m³; ${row.water_prev??'—'} → ${row.water_curr??'—'}; divisor ${divisor}`),
      item('fee','Taxa de condomínio',fee(data,o,p.id),`Lotes ${lots[o.id].map(l=>l.number).join(', ')}`),
      item('salary','Salário do caseiro',salaryShares[o.id],p.caretaker_salary_in_fee?'Salário já incluído nas taxas ordinárias':allocationDetail(groups.caretaker,o.id)),
      item('lighting','Iluminação e áreas comuns',lightingShares[o.id],`${lightingKwh} kWh residuais; ${allocationDetail(groups.lighting,o.id)}`),
      item('provision13','Provisão de 13º',provision13[o.id],'1/12 do salário; '+allocationDetail(groups.provision,o.id)),
      item('vacation','Provisão de férias + 1/3',vacation[o.id],'Total das provisões = salário × 7/36; '+allocationDetail(groups.provision,o.id)),
      item('caretakerUtilities','Energia e água da casa do caseiro',caretakerUtilities[o.id],`${caretakerEnergy} kWh e ${caretakerWater} m³; ${allocationDetail(groups.caretaker,o.id)}`),
      ...extraShares.map(({expense:e,weights:w,shares})=>item('expense:'+e.id,e.title,shares[o.id],`${e.mode==='installments'?'Parcela do total':'Valor mensal'}; ${e.start_period} a ${e.end_period}; critério ${e.scope}; ${w[o.id]||0} de ${total(Object.values(w))} cota(s); ${Object.values(w).filter(x=>x>0).length} participante(s)`)),
      item('legacyExtra','Despesa extraordinária do período',legacyExtra[o.id],`Critério ${p.extra_scope}`),
      item('solar','Energia solar — cobrança mensal legada',solar,'Uma cota por responsável participante, independentemente do número de lotes')];
    return {owner:o,lots:lots[o.id],row,energyKwh:energies[o.id],waterM3:waters[o.id],items,total:money(total(items.map(i=>i.amount))),missing:missing.includes(o.id)};
  });
  return {result,rate,pumpCost,waterRate:waterTotal>0?pumpCost/waterTotal:0,waterTotal,bCount:groups.lighting.count,allocationGroups:groups,allocationSnapshot:allocations.snapshot,caretakerEnergy,caretakerWater,caretakerEnergyCost,caretakerWaterCost,energyKwh,pumpKwh,individualKwh,lightingKwh,lightingCost,provisions:provision,expenses,extraGroups:extraShares,missing:result.filter(r=>r.missing),unallocated:pumpCost>0&&waterTotal<=0,lightingError:lightingKwh<0,unallocatedLighting:lightingCost>0&&!groups.lighting.count,expectedEnergy,energyDifference,errors:[...new Set(errors)]};
}
export function solarBalance(participant, transactions) {
  const ts=transactions.filter(t=>t.participant_id===participant.id);
  const due=money(Number(participant.quota)+total(ts.filter(t=>t.kind==='adjustment').map(t=>t.amount)));
  const paid=money(total(ts.filter(t=>t.kind!=='adjustment').map(t=>t.kind==='refund'||t.kind==='reversal'?-Number(t.amount):Number(t.amount))));
  return {due,paid,balance:money(due-paid)};
}

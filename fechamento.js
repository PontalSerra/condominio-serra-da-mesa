export function reopeningBlockers(store,period){
 const errors=[];
 if(!period||period.status!=='closed')return ['O mês não está fechado.'];
 if(!period.closed_at||Number.isNaN(Date.parse(period.closed_at)))return ['Fechamento sem data: precisa de conferência administrativa.'];
 if(store.periods.some(p=>p.id>period.id&&p.status==='closed')||store.invoices.some(i=>i.period_id>period.id))errors.push('Há mês posterior fechado ou com faturas. Reabra do mais recente para o mais antigo.');
 const owners=new Set(store.invoices.filter(i=>i.period_id===period.id).map(i=>i.owner_id));
 const day=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(period.closed_at));
 if(store.payments.some(p=>owners.has(p.owner_id)&&(p.paid_at>=day||p.created_at>=period.closed_at)))errors.push('Há pagamentos que podem estar ligados às faturas. A reabertura automática está bloqueada.');
 if(store.employee_payouts.some(p=>p.period_id>=period.id))errors.push('Há baixas de reservas neste mês ou depois dele.');
 if(store.whatsapp_log.some(l=>l.period_id===period.id&&l.kind==='invoice'))errors.push('Há envio registrado de faturas. É necessária retificação acompanhada.');
 return errors;
}
export function simulationHtml(period,calc,{h,brl}){
 return `<article class="admin-report"><h2>Simulação de fechamento</h2><p><b>${h(period.id)} — somente conferência, sem emissão de faturas.</b></p><p>Usa os últimos dados salvos. A simulação não aprova faturas, não altera saldos e não envia mensagens.</p>${calc.errors.length?`<div class="note alert"><b>Resultado provisório. Pendências:</b><ul>${calc.errors.map(e=>`<li>${h(e)}</li>`).join('')}</ul></div>`:''}<div class="table-wrap"><table><thead><tr><th>Responsável</th><th>Lotes</th><th>Total do mês</th></tr></thead><tbody>${calc.result.map(r=>`<tr><td>${h(r.owner.name)}</td><td>${h(r.lots.map(l=>l.number).join(', '))}</td><td>${brl(r.total)}</td></tr>`).join('')}</tbody><tfoot><tr><th colspan="2">Total simulado</th><th>${brl(calc.result.reduce((sum,r)=>sum+r.total,0))}</th></tr></tfoot></table></div><button class="btn primary no-print" data-action="print">Imprimir / salvar PDF da simulação</button></article>`;
}


/* Relatórios administrativos com finalidade e período explícitos. */
import {balance,money,expenseValue,solarBalance,calculate} from './finance.js';
const previousMonth=ym=>{const [y,m]=ym.split('-').map(Number);return (m===1?y-1:y)+'-'+String(m===1?12:m-1).padStart(2,'0');};
const localDate=value=>String(value||'').includes('T')?new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(value)):String(value||'').slice(0,10);
const sum=values=>money(values.reduce((s,x)=>s+Number(x||0),0));
export const REPORTS={worksheet:'Planilha geral mensal — todas as rubricas',collective:'Resumo coletivo do mês',billing:'Cobranças e saldos por responsável',overdue:'Saldos vencidos e a vencer',readings:'Leituras de água e energia',receipts:'Recebimentos registrados no mês',provisions:'Provisões e baixas do caseiro',expenses:'Despesas extraordinárias previstas',solar:'Conferência do investimento solar',statement:'Extrato individual do responsável'};
export function adminReport(data,kind,ym,today,ownerId=null){
 const invoices=data.invoices||[],payments=(data.payments||[]).filter(p=>p.paid_at<=today),owners=data.owners||[],period=(data.periods||[]).find(p=>p.id===ym);
 const name=id=>owners.find(o=>o.id===id)?.name||'Cadastro não localizado';
 const lots=id=>(data.lots||[]).filter(l=>l.owner_id===id||(data.financial_links||[]).some(f=>f.owner_id===id&&f.lot_id===l.id)).map(l=>l.number).join(' / ');
 const pending=owners.some(o=>o.active!==false&&o.opening_balance_reviewed===false);
 const base={title:REPORTS[kind]||'Relatório',period:ym,privacy:kind==='collective'?'Coletivo sem identificação de devedores':'Administrativo privado',notes:[],headers:[],rows:[]};
 if(kind==='worksheet'){
  const closed=period?.status==='closed',calculation=period&&!closed?calculate(data,period):null;
  const current=invoices.filter(i=>i.period_id===ym),preview=calculation?.result||[];
  const codes=[['energy','Energia (R$)'],['water','Água (R$)'],['lighting','Iluminação (R$)'],['salary','Salário separado (R$)'],['caretakerUtilities','Energia/água caseiro (R$)'],['provision13','13º (R$)'],['vacation','Férias + 1/3 (R$)'],['fee','Taxa condomínio (R$)']];
  const allItems=closed?current.flatMap(i=>i.items||[]):preview.flatMap(r=>r.items),extras=[...new Map(allItems.filter(i=>i.code?.startsWith('expense:')).map(i=>[i.code,i.label])).entries()];
  codes.push(...extras.map(([code,label])=>[code,label+' (R$)']),['legacyExtra','Extra do período (R$)'],['solar','Solar mensal legado (R$)']);
  const known=new Set(codes.map(([k])=>k));if(allItems.some(i=>!known.has(i.code)))codes.push(['__other','Outras rubricas (R$)']);
  base.headers=['Responsável','Lotes',...codes.map(([,label])=>label),'Total do mês (R$)','Saldo anterior na emissão / prévia (R$)','Total na emissão / prévia (R$)','Pagamentos até hoje — todos os meses (R$)','Saldo atual — todos os meses (R$)','Conferência'];
  base.moneyColumns=Array.from({length:codes.length+5},(_,i)=>i+2);
  base.notes=[closed?'Competência encerrada: rubricas e lotes da fatura emitida.':'PRÉVIA — competência em rascunho. As rubricas ainda não foram emitidas e dependem da conferência das pendências.','Uma linha por responsável financeiro; seus lotes ficam reunidos. Responsabilidades independentes do mesmo lote têm linhas próprias. A soma das rubricas não duplica lotes.','Para conferir todas as colunas, use rolagem horizontal, exportação Excel ou impressão em paisagem. Pagamentos e saldo atual abrangem todos os meses, na posição de '+today+'. Podem diferir do total informado na emissão; um pagamento não é atribuído automaticamente a uma competência.'];
  if(pending)base.notes.push('Há saldos de abertura a conferir. Os saldos e totais correspondentes são provisórios.');
  if(calculation?.errors.length)base.notes.push('Pendências do cálculo: '+calculation.errors.join(' '));
  const targets=closed?current.map(i=>({owner:owners.find(o=>o.id===i.owner_id)||{id:i.owner_id,name:i.snapshot?.owner_name||'Cadastro histórico'},invoice:i,items:i.items||[],total:Number(i.current_amount),lots:(i.snapshot?.lot_numbers||[]).join(' / ')||lots(i.owner_id)})):preview.filter(r=>r.lots.length||r.total>0).map(r=>({...r,lots:r.lots.map(l=>l.number).join(' / ')}));
  base.rows=targets.sort((a,b)=>a.owner.name.localeCompare(b.owner.name,'pt-BR')).map(r=>{const o=r.owner,previous=r.invoice?Number(r.invoice.previous_balance_at_issue):balance(data,o.id,previousMonth(ym),today);
   const currentBalance=balance(data,o.id,null,today),paid=sum(payments.filter(p=>p.owner_id===o.id).map(p=>p.amount));
   return [r.invoice?.snapshot?.owner_name||o.name,r.lots,...codes.map(([code])=>sum(r.items.filter(i=>code==='__other'?!known.has(i.code):i.code===code).map(i=>i.amount))),r.total,previous,money(r.total+previous),paid,currentBalance,o.opening_balance_reviewed===false?'Saldo inicial pendente':closed?'Emitido':'Prévia'];
  });
  base.totalRow=['TOTAL','',...base.headers.slice(2,-1).map((_,index)=>sum(base.rows.map(row=>row[index+2]))),''];
 }else if(kind==='collective'){
  base.headers=['Indicador','Valor'];base.blocked=pending;
  base.notes=['Cobranças são competências emitidas; recebimentos são entradas registradas pela data do pagamento. Estes valores não representam saldo bancário nem comprovam pagamento de todas as despesas.'];
  if(pending){base.notes.push('Revise os saldos de abertura antes de divulgar o relatório coletivo.');return base;}
  base.rows=[['Competência',ym],['Situação',period?.status==='closed'?'Encerrado':'Rascunho — valores ainda não emitidos'],['Faturas emitidas no mês',invoices.filter(i=>i.period_id===ym).length],['Valor das faturas emitidas',sum(invoices.filter(i=>i.period_id===ym).map(i=>i.current_amount))],['Recebimentos registrados neste mês',sum(payments.filter(p=>p.paid_at.slice(0,7)===ym).map(p=>p.amount))]];
 }else if(kind==='billing'||kind==='overdue'){
  base.headers=['Responsável','Lotes','Mês emitido','Saldo anterior cadastrado','Pagamentos até a data','Saldo total atual','Parcela vencida estimada','A vencer','Conferência'];
  base.notes=['Posição em '+today+'. Pagamentos abatem o saldo mais antigo para estimar a parcela vencida; não há vinculação automática de cada pagamento a uma fatura. Créditos são mostrados como saldo negativo.'];
  base.rows=owners.filter(o=>o.active!==false||invoices.some(i=>i.owner_id===o.id)).map(o=>{
   const paid=sum(payments.filter(p=>p.owner_id===o.id).map(p=>p.amount)),bal=balance({...data,payments},o.id,null,today);
   const matured=sum(invoices.filter(i=>i.owner_id===o.id&&i.due_date<today).map(i=>i.current_amount));
   const overdue=Math.max(0,Math.min(Math.max(0,bal),money(Number(o.opening_balance||0)+matured-paid)));
   return [o.name,lots(o.id),sum(invoices.filter(i=>i.owner_id===o.id&&i.period_id===ym).map(i=>i.current_amount)),Number(o.opening_balance||0),paid,bal,o.opening_balance_reviewed===false?'A conferir':overdue,o.opening_balance_reviewed===false?'A conferir':Math.max(0,money(bal-overdue)),o.opening_balance_reviewed===false?'Saldo inicial pendente':'Conferido'];
  }).filter(row=>kind!=='overdue'||row[6]==='A conferir'||Number(row[5])>0);
 }else if(kind==='readings'){
  base.headers=['Responsável','Lotes','Energia anterior','Energia atual','kWh','Água anterior','Água atual','Diferença bruta','Divisor por m³','m³'];base.notes=['Células vazias indicam leitura ausente. A conversão só é definitiva após a confirmação da unidade dos hidrômetros.'];
  const delta=(a,b)=>a==null||b==null?null:Number(b)-Number(a);
  base.rows=(data.meter_readings||[]).filter(r=>r.period_id===ym).map(r=>{const w=delta(r.water_prev,r.water_curr);return[name(r.owner_id),lots(r.owner_id),r.energy_prev,r.energy_curr,delta(r.energy_prev,r.energy_curr),r.water_prev,r.water_curr,w,period?.water_divisor??null,w===null||!period?.water_unit_confirmed?null:w/Number(period.water_divisor)];});
 }else if(kind==='receipts'){
  base.headers=['Data','Responsável','Meio','Referência','Valor','Identificador'];base.rows=payments.filter(p=>p.paid_at.slice(0,7)===ym).sort((a,b)=>a.paid_at.localeCompare(b.paid_at)).map(p=>[p.paid_at,name(p.owner_id),p.method,p.reference||'',Number(p.amount),p.id]);base.notes=['Registros da administração. Não substituem a conferência com o extrato bancário. Não se presume a competência paga.'];
 }else if(kind==='expenses'){
  base.headers=['Despesa','Natureza','Modalidade','Início','Fim','Critério','Valor nesta competência','Comprovante cadastrado'];base.rows=(data.expenses||[]).filter(e=>e.start_period<=ym&&e.end_period>=ym).map(e=>[e.title,e.kind,e.mode,e.start_period,e.end_period,e.scope,expenseValue(e,ym),e.receipt_name?'Sim':'Não']);base.notes=['Valores previstos para cobrança; não comprovam saída bancária ou quitação da despesa. Os anexos ficam na administração.'];
 }else if(kind==='provisions'){
  base.headers=['Competência','Provisão de 13º','Provisão de férias + 1/3','Baixas de 13º registradas','Baixas de férias registradas','Reserva acumulada 13º','Reserva acumulada férias'];let reserve13=0,reserveVacation=0;
  const months=[...new Set([...(data.periods||[]).filter(p=>p.status==='closed'&&p.id<=ym).map(p=>p.id),...(data.employee_payouts||[]).filter(p=>p.period_id<=ym&&p.paid_at<=today).map(p=>p.period_id)])].sort();
  base.rows=months.map(month=>{const inv=invoices.filter(i=>i.period_id===month),p=(data.periods||[]).find(p=>p.id===month),get=code=>sum(inv.flatMap(i=>i.items||[]).filter(x=>x.code===code).map(x=>x.amount));
   const a=Number(p?.financial_snapshot?.provisions?.thirteenth??get('provision13')),b=Number(p?.financial_snapshot?.provisions?.vacation??get('vacation')),paid=type=>sum((data.employee_payouts||[]).filter(x=>x.type===type&&x.period_id===month&&x.paid_at<=today).map(x=>x.amount)),c=paid('13'),d=paid('vacation');reserve13=money(reserve13+a-c);reserveVacation=money(reserveVacation+b-d);return[month,a,b,c,d,reserve13,reserveVacation];});
  base.notes=['Provisões somente de competências encerradas, até '+ym+'. Baixas são os pagamentos de reservas registrados até '+today+'. Reservas gerenciais não são saldo bancário.'];
 }else if(kind==='solar'){
  base.headers=['Responsável','Cota ajustada','Pagamentos líquidos informados','Saldo ou crédito','Origem / conferência'];base.rows=(data.solar_participants||[]).map(p=>{const ts=(data.solar_transactions||[]).filter(t=>t.paid_at<=today),s=solarBalance(p,ts);return[name(p.owner_id),s.due,s.paid,s.balance,ts.some(t=>t.participant_id===p.id&&t.source_reported)?'Há valores da planilha de origem; conferir banco':'Lançamentos administrativos'];});base.notes=['Razão separada das taxas ordinárias. Posição até '+today+'. Marcações PAGO da planilha não geram pagamentos fictícios.'];
 }else if(kind==='statement'){
  const owner=owners.find(o=>o.id===ownerId);base.headers=['Data / competência','Descrição','Débito','Crédito','Saldo acumulado'];
  if(!owner){base.notes=['Selecione um responsável para abrir o extrato.'];return base;}
  base.title+=' — '+owner.name;base.notes=[owner.opening_balance_reviewed===false?'SALDO INICIAL EM CONFERÊNCIA. Este extrato é provisório.':'Posição em '+today+'. O saldo inicial pode conter créditos e débitos anteriores.','Pagamentos são lançamentos identificados; não se presume quitação integral de uma competência específica.'];
  let running=Number(owner.opening_balance||0);base.rows=[['Abertura','Saldo anterior cadastrado',Math.max(0,running),Math.max(0,-running),running]];
  const events=[...invoices.filter(i=>i.owner_id===ownerId&&localDate(i.issued_at)<=today).map(i=>({date:localDate(i.issued_at),label:'Fatura '+i.period_id,debit:Number(i.current_amount),credit:0,key:i.id})),...payments.filter(p=>p.owner_id===ownerId).map(p=>({date:p.paid_at,label:'Recebimento — '+(p.reference||p.method),debit:0,credit:Number(p.amount),key:p.id}))].sort((a,b)=>a.date.localeCompare(b.date)||Number(b.debit>0)-Number(a.debit>0)||a.key.localeCompare(b.key));
  for(const e of events){running=money(running+e.debit-e.credit);base.rows.push([e.date,e.label,e.debit,e.credit,running]);}
 }
 const totalColumns={billing:[2,3,4,5,6,7],overdue:[2,3,4,5,6,7],receipts:[4],readings:[4,7,9],expenses:[6],solar:[1,2,3],provisions:[1,2,3,4]}[kind];
 if(totalColumns&&base.rows.length){base.totalRow=base.headers.map((_,index)=>index===0?'TOTAL':totalColumns.includes(index)?sum(base.rows.map(row=>typeof row[index]==='number'?row[index]:0)):'');if(kind==='provisions'){base.totalRow[5]=base.rows.at(-1)[5];base.totalRow[6]=base.rows.at(-1)[6];}}
 return base;
}
export function reportCSV(report){const escape=value=>{let text=typeof value==='number'?value.toLocaleString('pt-BR',{maximumFractionDigits:10,useGrouping:false}):String(value??'');if(typeof value==='string'&&/^[=+\-@\t\r]/.test(text))text="'"+text;return '"'+text.replace(/"/g,'""')+'"';};return '\uFEFF'+[[report.title,report.period],[report.privacy],...report.notes.map(n=>[n]),report.headers,...report.rows,...(report.totalRow?[report.totalRow]:[])].map(row=>row.map(escape).join(';')).join('\r\n');}
export function adminReportHtml(report,{h,brl}){return `<article class="admin-report ${report.moneyColumns?'report-wide':''}"><p class="eyebrow">Pontal da Serra • ${h(report.privacy)}</p><h2>${h(report.title)}</h2><p>Competência selecionada: ${h(report.period)} • Valores monetários em reais (R$).</p>${report.notes.map(n=>`<p class="note">${h(n)}</p>`).join('')}<div class="table-wrap"><table><thead><tr>${report.headers.map(s=>`<th>${h(s)}</th>`).join('')}</tr></thead><tbody>${report.rows.map(row=>`<tr>${row.map(v=>`<td>${h(v===null?'—':typeof v==='number'?v.toLocaleString('pt-BR',{maximumFractionDigits:6}):v)}</td>`).join('')}</tr>`).join('')||`<tr><td colspan="${report.headers.length}" class="empty">${report.blocked?'Relatório bloqueado para revisão dos saldos.':'Sem registros neste período.'}</td></tr>`}</tbody>${report.totalRow?`<tfoot><tr>${report.totalRow.map(v=>`<th>${h(typeof v==='number'?v.toLocaleString('pt-BR',{maximumFractionDigits:2}):v)}</th>`).join('')}</tr></tfoot>`:''}</table></div>${!report.blocked?'<div class="actions no-print"><button data-action="print" class="btn primary">Imprimir / salvar PDF</button><button data-action="reportxlsx" class="btn light">Exportar para Excel (.xlsx)</button><button data-action="reportcsv" class="btn light">Baixar CSV deste relatório</button></div>':''}</article>`;}

export function reportWorkbook(report,XLSX){
 if(report.blocked)throw Error('Este relatório está bloqueado para conferência.');
 const intro=[[report.title,report.period],[report.privacy],...report.notes.map(n=>[n]),[]],headerIndex=intro.length;
 const rows=[...intro,report.headers,...report.rows,...(report.totalRow?[report.totalRow]:[])],sheet=XLSX.utils.aoa_to_sheet(rows);
 sheet['!cols']=report.headers.map((label,i)=>({wch:Math.min(42,Math.max(14,label.length,...report.rows.slice(0,100).map(row=>String(row[i]??'').length)))}));
 sheet['!autofilter']={ref:XLSX.utils.encode_range({r:headerIndex,c:0},{r:headerIndex+report.rows.length,c:report.headers.length-1})};
 for(let r=headerIndex+1;r<rows.length;r++)for(let c=0;c<report.headers.length;c++){const cell=sheet[XLSX.utils.encode_cell({r,c})];if(cell?.t==='n')cell.z=(report.moneyColumns||[]).includes(c)||/R\$|Valor|Saldo|Débito|Crédito|Cota|Pagamento|Provisão|Reserva|Baixa/i.test(report.headers[c])?'#,##0.00;[Red]-#,##0.00':'0.###';}
 const book=XLSX.utils.book_new();XLSX.utils.book_append_sheet(book,sheet,'Relatorio');book.Props={Title:report.title,Subject:'Pontal da Serra - '+report.period,Author:'Administração do condomínio'};return book;
}

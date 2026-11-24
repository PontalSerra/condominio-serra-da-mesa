/* Regras por responsável e competência. Sem acesso a navegador ou banco. */
export const CATEGORIES = Object.freeze({
  caretaker: 'Caseiro',
  lighting: 'Iluminação e áreas comuns',
  provision: 'Provisões de férias e 13º',
  extra: 'Despesas extraordinárias do mês',
});
export const validMonth = value => /^\d{4}-(0[1-9]|1[0-2])$/.test(value || '');
const modes = ['auto', 'include', 'exclude'];
const cents = value => Math.round((Number(value) + Number.EPSILON) * 100);
export const defaultSettings = () => Object.fromEntries(Object.keys(CATEGORIES).map(key => [key, {mode: 'auto', shares: 1}]));

// O início mais recente prevalece. Ao acabar uma exceção temporária, a regra
// anterior volta a valer; não é necessário apagar ou editar o histórico.
export function effectiveRule(rules, ownerId, month) {
  return (rules || []).filter(rule => rule.owner_id === ownerId && rule.start_period <= month && (!rule.end_period || month <= rule.end_period))
    .sort((a, b) => b.start_period.localeCompare(a.start_period) || a.id.localeCompare(b.id))[0] || null;
}

export function ruleErrors(rule, rules = [], periods = []) {
  const errors = [];
  if (!rule.owner_id) errors.push('Selecione o responsável.');
  if (!validMonth(rule.start_period) || (rule.end_period && (!validMonth(rule.end_period) || rule.end_period < rule.start_period))) errors.push('Confira as competências inicial e final.');
  if (!rule.reason?.trim()) errors.push('Informe o motivo ou a deliberação que define a regra.');
  if (rule.fee_override !== null && rule.fee_override !== undefined && (rule.fee_override === '' || !Number.isFinite(Number(rule.fee_override)) || Number(rule.fee_override) < 0 || Number(rule.fee_override) > 99999999999.99)) errors.push('Taxa mensal inválida. Use vazio para o padrão ou zero para isenção.');
  if (!rule.settings || Object.keys(rule.settings).length !== Object.keys(CATEGORIES).length) errors.push('Informe os quatro grupos de despesas.');
  for (const [category, label] of Object.entries(CATEGORIES)) {
    const value = rule.settings?.[category];
    if (!value || !modes.includes(value.mode) || typeof value.shares !== 'number' || !Number.isFinite(value.shares) || value.shares < 0.01 || value.shares > 1000 || Math.abs(value.shares * 100 - Math.round(value.shares * 100)) > 0.000001) errors.push(`${label}: escolha a participação e um número de cotas entre 0,01 e 1.000, com até duas casas decimais.`);
  }
  if ((rules || []).some(r => r.id !== rule.id && r.owner_id === rule.owner_id && r.start_period === rule.start_period)) errors.push('Já existe uma regra para este responsável com esse mês de início. Edite a regra existente.');
  const previous = (rules || []).find(r => r.id === rule.id);
  for (const candidate of [rule, previous].filter(Boolean)) {
    if (periods.some(p => p.status === 'closed' && p.id >= candidate.start_period && (!candidate.end_period || p.id <= candidate.end_period))) {
      errors.push('A regra alcança mês fechado. Crie uma nova vigência posterior ao fechamento.');
      break;
    }
  }
  return [...new Set(errors)];
}

export function monthlyFee(owner, lots, rules, month, fallback) {
  const rule = effectiveRule(rules, owner.id, month);
  return rule?.fee_override !== null && rule?.fee_override !== undefined ? Number(rule.fee_override) : fallback;
}

// Maior resto em centavos; o desempate usa IDs estáveis. A soma das cotas
// sempre corresponde ao custo total, inclusive quando há cotas fracionárias.
export function allocate(amount, weights) {
  const value = cents(amount), entries = Object.entries(weights).filter(([, weight]) => weight > 0).sort(([a], [b]) => a.localeCompare(b));
  const output = Object.fromEntries(Object.keys(weights).map(id => [id, 0]));
  if (!entries.length) return output;
  const denominator = entries.reduce((sum, [, weight]) => sum + weight, 0);
  const parts = entries.map(([id, weight]) => {const raw = Math.abs(value) * weight / denominator; return {id, base: Math.floor(raw), rest: raw % 1};});
  let missing = Math.abs(value) - parts.reduce((sum, part) => sum + part.base, 0);
  parts.sort((a, b) => b.rest - a.rest || a.id.localeCompare(b.id));
  for (const part of parts) {if (missing > 0) {part.base++; missing--;} output[part.id] = Math.sign(value) * part.base / 100;}
  return output;
}

export function calculateAllocations(owners, lots, rules, period, amounts) {
  const groups = {}, errors = [], recorded = period.status === 'closed' ? (period.allocation_snapshot || period.financial_snapshot?.allocations)?.groups : null;
  const applicable = Object.fromEntries(owners.map(owner => [owner.id, effectiveRule(rules, owner.id, period.id)]));
  for (const [category, label] of Object.entries(CATEGORIES)) {
    const weights = {}, decisions = {};
    if (recorded?.[category]) {
      Object.assign(weights, recorded[category].weights);
      Object.assign(decisions, recorded[category].decisions);
    } else for (const owner of owners) {
      const own = lots.filter(lot => lot.owner_id === owner.id), built = own.some(lot => lot.built);
      const rule = applicable[owner.id], setting = rule?.settings?.[category] || {mode: 'auto', shares: 1};
      const base = category === 'extra' && period.extra_scope === 'lot' ? own.length : category === 'extra' && period.extra_scope === 'all' ? Number(own.length > 0) : Number(built);
      let weight = setting.mode === 'exclude' ? 0 : setting.mode === 'include' ? (category === 'extra' && period.extra_scope === 'lot' ? Math.max(1, own.length) : 1) : base;
      weight *= setting.shares;
      if (weight > 0 && !own.length) errors.push(`${owner.name}: vincule um lote antes de incluir no rateio de ${label.toLowerCase()}.`);
      weights[owner.id] = weight;
      decisions[owner.id] = {mode: setting.mode, shares: setting.shares, rule_id: rule?.id || null, reason: rule?.reason || '', start_period: rule?.start_period || null, end_period: rule?.end_period || null};
    }
    const amount = Number(amounts[category] || 0), count = Object.values(weights).filter(value => value > 0).length;
    if (!Number.isFinite(amount) || amount < 0) errors.push(`${label}: valor inválido.`);
    if (cents(amount) && !count) errors.push(`${label}: há despesa sem participantes. Confira as configurações de rateio.`);
    groups[category] = {amount, count, quotas: Object.values(weights).reduce((sum, value) => sum + value, 0), weights, decisions, allocations: allocate(amount, weights)};
  }
  return {groups, errors: [...new Set(errors)], snapshot: {version: 1, groups: Object.fromEntries(Object.entries(groups).map(([key, value]) => [key, {weights: value.weights, decisions: value.decisions}]))}};
}

export function allocationDetail(group, ownerId) {
  const decision = group.decisions[ownerId], weight = group.weights[ownerId] || 0;
  if (!weight) return decision?.mode === 'exclude' ? 'Não participa — regra individual' : 'Não participa — padrão do cadastro';
  return `${weight} cota(s) de ${group.quotas}; ${group.count} participante(s); ${decision?.mode === 'include' ? 'inclusão individual' : 'padrão do cadastro'}`;
}

// Somente lançamentos positivos indicam participação na importação. Zero ou
// célula vazia não demonstram isenção; não se deduz participação pela taxa.
export function settingsFromSpreadsheet(row) {
  const settings = defaultSettings();
  if (Number(row[4]) > 0) {settings.caretaker.mode = 'include'; settings.lighting.mode = 'include';}
  if (Number(row[5]) > 0) settings.provision.mode = 'include';
  return Object.values(settings).some(value => value.mode === 'include') ? settings : null;
}

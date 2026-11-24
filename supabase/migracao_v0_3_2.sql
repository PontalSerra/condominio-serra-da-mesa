-- Transparência coletiva: somente meses encerrados com fatura própria.
-- Não concede SELECT de períodos, submedidores ou regras alheias aos condôminos.
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS general_reading_date date;
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS pump_reading_date date;
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS caretaker_reading_date date;
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS next_reading_date date;

CREATE OR REPLACE FUNCTION public.pontal_capabilities() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;RETURN jsonb_build_object('version','0.3.2','monthly_reports',true);END$$;

CREATE OR REPLACE FUNCTION public.pontal_month_reports() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.periods;r jsonb;output jsonb:='[]';g jsonb;groups jsonb;totals jsonb;extra jsonb;item jsonb;
 k text;weights jsonb;n integer;q numeric;rate numeric;general_kwh numeric;pump_kwh numeric;individual_kwh numeric;
 caretaker_kwh numeric;caretaker_water numeric;water_total numeric;lighting_kwh numeric;pump_cost numeric;
 salary numeric;ce numeric;cw numeric;prov13 numeric;vac numeric;expected numeric;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Autenticação necessária';END IF;
 FOR p IN SELECT z.* FROM public.periods z WHERE z.status='closed' AND
 (public.is_admin() OR EXISTS(SELECT 1 FROM public.invoices i WHERE i.period_id=z.id AND public.can_view_owner(i.owner_id))) ORDER BY z.id DESC LOOP
  SELECT coalesce(jsonb_object_agg(code,amount),'{}') INTO totals FROM
   (SELECT x->>'code' code,sum((x->>'amount')::numeric) amount FROM public.invoices i CROSS JOIN LATERAL jsonb_array_elements(i.items) x WHERE i.period_id=p.id AND x ? 'code' GROUP BY x->>'code') s;
  totals:=totals||jsonb_build_object('other',(SELECT coalesce(sum((x->>'amount')::numeric),0) FROM public.invoices i CROSS JOIN LATERAL jsonb_array_elements(i.items) x WHERE i.period_id=p.id AND NOT coalesce(x->>'code' = ANY(ARRAY['energy','water','fee','salary','lighting','provision13','vacation','caretakerUtilities','legacyExtra','solar']) OR x->>'code' LIKE 'expense:%',false)),'monthly',(SELECT coalesce(sum(current_amount),0) FROM public.invoices WHERE period_id=p.id),
    'expenses',(SELECT coalesce(sum((x->>'amount')::numeric),0) FROM public.invoices i CROSS JOIN LATERAL jsonb_array_elements(i.items) x WHERE i.period_id=p.id AND x->>'code' LIKE 'expense:%'));
  general_kwh:=p.general_curr-p.general_prev;pump_kwh:=p.pump_curr-p.pump_prev;
  rate:=coalesce((p.financial_snapshot->>'rate')::numeric,nullif(p.energy_rate,0),p.general_invoice/nullif(general_kwh,0),0);
  SELECT coalesce(sum(energy_curr-energy_prev),0),coalesce(sum((water_curr-water_prev)/p.water_divisor),0) INTO individual_kwh,water_total FROM public.meter_readings m WHERE m.period_id=p.id AND EXISTS(SELECT 1 FROM public.invoices i WHERE i.period_id=p.id AND i.owner_id=m.owner_id);
  caretaker_kwh:=coalesce(p.caretaker_energy_curr-p.caretaker_energy_prev,0);
  caretaker_water:=coalesce((p.caretaker_water_curr-p.caretaker_water_prev)/p.water_divisor,0);
  water_total:=water_total+caretaker_water;
  lighting_kwh:=general_kwh-individual_kwh-caretaker_kwh-CASE WHEN p.pump_inside_general THEN pump_kwh ELSE 0 END;
  ce:=coalesce((p.financial_snapshot->'transparency'->'caretaker'->>'energy_cost')::numeric,round(caretaker_kwh*rate,2));
  cw:=coalesce((p.financial_snapshot->'transparency'->'caretaker'->>'water_cost')::numeric,round((CASE WHEN p.pump_invoice>0 THEN p.pump_invoice ELSE pump_kwh*rate END)*caretaker_water/nullif(water_total,0),2),0);
  pump_cost:=coalesce((p.financial_snapshot->'transparency'->'energy'->>'pump_cost')::numeric,CASE WHEN p.pump_invoice>0 THEN p.pump_invoice ELSE round(pump_kwh*rate,2) END);
  prov13:=coalesce((p.financial_snapshot->'provisions'->>'thirteenth')::numeric,round(p.caretaker/12,2));
  vac:=coalesce((p.financial_snapshot->'provisions'->>'vacation')::numeric,round(p.caretaker*7/36,2)-prov13);
  salary:=CASE WHEN p.caretaker_salary_in_fee THEN 0 ELSE p.caretaker END;
  expected:=round(individual_kwh*rate+lighting_kwh*rate+caretaker_kwh*rate+CASE WHEN p.pump_inside_general THEN pump_cost ELSE 0 END,2);
  groups:='{}';
  FOREACH k IN ARRAY ARRAY['caretaker','lighting','provision','extra'] LOOP
   weights:=p.financial_snapshot->'allocations'->'groups'->k->'weights';n:=NULL;q:=NULL;
   IF jsonb_typeof(weights)='object' THEN SELECT count(*) FILTER(WHERE value::numeric>0),coalesce(sum(value::numeric),0) INTO n,q FROM jsonb_each_text(weights);END IF;
   g:=jsonb_build_object('count',n,'quotas',q,'amount',CASE k WHEN 'caretaker' THEN coalesce((totals->>'salary')::numeric,0)+coalesce((totals->>'caretakerUtilities')::numeric,0) WHEN 'lighting' THEN coalesce((totals->>'lighting')::numeric,0) WHEN 'provision' THEN coalesce((totals->>'provision13')::numeric,0)+coalesce((totals->>'vacation')::numeric,0) ELSE coalesce((totals->>'legacyExtra')::numeric,0) END);
   groups:=jsonb_set(groups,ARRAY[k],g);
  END LOOP;
  extra:='[]';
  -- Somente descrições de despesas e critérios públicos já congelados no fechamento.
  FOR item IN SELECT x FROM jsonb_array_elements(coalesce(p.financial_snapshot->'transparency'->'expenses','[]')) x LOOP
   extra:=extra||jsonb_build_array(jsonb_build_object('label',item->>'label','amount',(item->>'amount')::numeric,'scope',item->>'scope','mode',item->>'mode','start_period',item->>'start_period','end_period',item->>'end_period','count',(item->>'count')::integer,'quotas',(item->>'quotas')::numeric));
  END LOOP;
  IF jsonb_array_length(extra)=0 THEN
   SELECT coalesce(jsonb_agg(jsonb_build_object('label',label,'amount',amount,'scope','Não registrado','mode','monthly','start_period',p.id,'end_period',p.id)),'[]') INTO extra FROM
    (SELECT min(x->>'label') label,sum((x->>'amount')::numeric) amount FROM public.invoices i CROSS JOIN LATERAL jsonb_array_elements(i.items) x WHERE i.period_id=p.id AND x->>'code' LIKE 'expense:%' GROUP BY x->>'code') s;
  END IF;
  r:=jsonb_build_object('version',1,'period_id',p.id,'status','closed','due_date',p.due_date,'closed_at',p.closed_at,
   'dates',jsonb_build_object('general',p.general_reading_date,'pump',p.pump_reading_date,'caretaker',p.caretaker_reading_date,'next',p.next_reading_date),
   'energy',jsonb_build_object('previous',p.general_prev,'current',p.general_curr,'kwh',general_kwh,'invoice',p.general_invoice,'rate',rate,'individual_kwh',individual_kwh,'individual_cost',coalesce(totals->'energy','0'),'pump_inside',p.pump_inside_general,'pump_previous',p.pump_prev,'pump_current',p.pump_curr,'pump_kwh',pump_kwh,'pump_cost',pump_cost,'lighting_kwh',lighting_kwh,'lighting_cost',coalesce(totals->'lighting','0'),'expected',expected,'difference',p.general_invoice-expected),
   'water',jsonb_build_object('divisor',p.water_divisor,'confirmed',p.water_unit_confirmed,'total',water_total,'ranches',water_total-caretaker_water,'caretaker',caretaker_water,'rate',coalesce(pump_cost/nullif(water_total,0),0)),
   'caretaker',jsonb_build_object('salary',p.caretaker,'salary_in_fee',p.caretaker_salary_in_fee,'energy_previous',p.caretaker_energy_prev,'energy_current',p.caretaker_energy_curr,'energy_kwh',caretaker_kwh,'energy_cost',ce,'water_previous',p.caretaker_water_prev,'water_current',p.caretaker_water_curr,'water_m3',caretaker_water,'water_cost',cw,'utilities',ce+cw,'provisions',jsonb_build_object('thirteenth',prov13,'vacation',vac,'total',prov13+vac)),
   'groups',groups,'expenses',extra,'totals',totals);
  output:=output||jsonb_build_array(r);
 END LOOP;
 RETURN output;
END$$;
REVOKE ALL ON FUNCTION public.pontal_month_reports() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pontal_month_reports() TO authenticated;

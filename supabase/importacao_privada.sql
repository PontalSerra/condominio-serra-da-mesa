-- Função administrativa de importação. O arquivo público contém somente código,
-- nunca nomes, saldos, contatos ou dados reais do condomínio.
BEGIN;
CREATE OR REPLACE FUNCTION public.pontal_import_real_data(p_payload jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d jsonb;x jsonb;o public.owners;l public.lots;s public.solar_participants;key text;existing jsonb;
 owner_map jsonb:='{}';lot_map jsonb:='{}';solar_map jsonb:='{}';v_owner uuid;lot_id uuid;sid uuid;count_new integer:=0;count_preserved integer:=0;extra_owners integer:=0;extra_names text;extra_flags jsonb;report jsonb;
BEGIN
 IF NOT public.is_admin() AND NOT(session_user='postgres' AND current_setting('role',true)='none' AND auth.uid() IS NULL) THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;
 PERFORM pg_advisory_xact_lock(175471,31);PERFORM pg_advisory_xact_lock(175471,32);
 IF p_payload->>'format'<>'pontal-serra-import-v1' OR coalesce(p_payload->>'batch_id','')!~'^[a-f0-9]{64}$' OR pg_column_size(p_payload)>10485760 THEN RAISE EXCEPTION 'Arquivo de importação inválido';END IF;
 SELECT payload INTO existing FROM public.import_batches WHERE id=p_payload->>'batch_id';
 IF FOUND THEN
  IF existing IS DISTINCT FROM p_payload THEN RAISE EXCEPTION 'A identificação da importação já existe com outros dados';END IF;
  RETURN jsonb_build_object('ok',true,'already_imported',true);
 END IF;
 d:=p_payload->'data';
 IF jsonb_typeof(d->'owners')<>'array' OR jsonb_array_length(d->'owners')=0 OR jsonb_array_length(d->'owners')>1000 THEN RAISE EXCEPTION 'Lista de responsáveis inválida';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(d->'periods') AS entry(value) JOIN public.periods p ON p.id=entry.value->>'id' WHERE p.status='closed') THEN RAISE EXCEPTION 'A importação inclui competência fechada; os lançamentos foram preservados';END IF;
 FOR x IN SELECT * FROM jsonb_array_elements(d->'owners') LOOP
  SELECT * INTO o FROM public.owners WHERE id=(x->>'id')::uuid;
  IF NOT FOUND THEN
   IF (SELECT count(*) FROM public.owners WHERE upper(trim(name))=upper(trim(x->>'name')))>1 THEN RAISE EXCEPTION 'Há responsáveis com mesmo nome. Confira o cadastro antes de importar';END IF;
   SELECT * INTO o FROM public.owners WHERE upper(trim(name))=upper(trim(x->>'name'));
  END IF;
  IF o.id IS NULL THEN
   INSERT INTO public.owners(id,name,whatsapp,opening_balance,monthly_fee,active,opening_balance_reviewed,opening_balance_source)
   VALUES((x->>'id')::uuid,trim(x->>'name'),coalesce(x->>'whatsapp',''),(x->>'opening_balance')::numeric,(x->>'monthly_fee')::numeric,true,false,x->>'opening_balance_source') RETURNING * INTO o;
   count_new:=count_new+1;
  ELSE
   -- Não alterar titularidade de login, saldo ou taxa já cadastrados.
   count_preserved:=count_preserved+1;
  END IF;
  owner_map:=jsonb_set(owner_map,ARRAY[x->>'id'],to_jsonb(o.id::text));
 END LOOP;
 FOR x IN SELECT * FROM jsonb_array_elements(d->'lots') LOOP
  v_owner:=(owner_map->>(x->>'owner_id'))::uuid;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'Lote sem responsável válido';END IF;
  SELECT * INTO l FROM public.lots WHERE number=x->>'number';
  IF FOUND AND l.owner_id<>v_owner THEN RAISE EXCEPTION 'O lote % já pertence a outro cadastro. Confira a titularidade antes de importar',l.number;END IF;
  IF NOT FOUND THEN
   INSERT INTO public.lots(id,number,owner_id,built,solar_opt_in)VALUES((x->>'id')::uuid,x->>'number',v_owner,coalesce((x->>'built')::boolean,false),coalesce((x->>'solar_opt_in')::boolean,false)) RETURNING * INTO l;
  END IF;
  lot_map:=jsonb_set(lot_map,ARRAY[x->>'id'],to_jsonb(l.id::text));
 END LOOP;
 SELECT count(*),string_agg(extra_owner.name,', ' ORDER BY extra_owner.name) INTO extra_owners,extra_names FROM public.owners extra_owner WHERE extra_owner.active AND NOT EXISTS(SELECT 1 FROM jsonb_each_text(owner_map) mapped WHERE mapped.value=extra_owner.id::text);
 extra_flags:=CASE WHEN extra_owners>0 THEN jsonb_build_array(jsonb_build_object('id','cadastros-adicionais','detail','Cadastros ativos fora desta planilha: '||extra_names||'. Confira se devem continuar ativos; inative os registros fictícios antes de emitir.','resolved',false)) ELSE '[]'::jsonb END;
 FOR x IN SELECT * FROM jsonb_array_elements(d->'periods') LOOP
  INSERT INTO public.periods(id,due_date,status,energy_rate,general_prev,general_curr,general_invoice,pump_prev,pump_curr,pump_invoice,pump_inside_general,water_divisor,water_unit_confirmed,caretaker,caretaker_salary_in_fee,caretaker_energy_prev,caretaker_energy_curr,caretaker_water_prev,caretaker_water_curr,lighting,provision,extra_amount,extra_scope,solar_per_lot,review_flags,notes)
  VALUES(x->>'id',(x->>'due_date')::date,'draft',(x->>'energy_rate')::numeric,(x->>'general_prev')::numeric,(x->>'general_curr')::numeric,(x->>'general_invoice')::numeric,(x->>'pump_prev')::numeric,(x->>'pump_curr')::numeric,(x->>'pump_invoice')::numeric,(x->>'pump_inside_general')::boolean,(x->>'water_divisor')::numeric,false,(x->>'caretaker')::numeric,coalesce((x->>'caretaker_salary_in_fee')::boolean,false),coalesce((x->>'caretaker_energy_prev')::numeric,0),coalesce((x->>'caretaker_energy_curr')::numeric,0),coalesce((x->>'caretaker_water_prev')::numeric,0),coalesce((x->>'caretaker_water_curr')::numeric,0),0,0,coalesce((x->>'extra_amount')::numeric,0),coalesce(x->>'extra_scope','built'),coalesce((x->>'solar_per_lot')::numeric,0),coalesce(x->'review_flags','[]')||extra_flags,x->>'notes')
  ON CONFLICT(id) DO UPDATE SET due_date=excluded.due_date,energy_rate=excluded.energy_rate,general_prev=excluded.general_prev,general_curr=excluded.general_curr,general_invoice=excluded.general_invoice,pump_prev=excluded.pump_prev,pump_curr=excluded.pump_curr,pump_invoice=excluded.pump_invoice,pump_inside_general=excluded.pump_inside_general,water_divisor=excluded.water_divisor,water_unit_confirmed=false,caretaker=excluded.caretaker,caretaker_salary_in_fee=excluded.caretaker_salary_in_fee,caretaker_energy_prev=excluded.caretaker_energy_prev,caretaker_energy_curr=excluded.caretaker_energy_curr,caretaker_water_prev=excluded.caretaker_water_prev,caretaker_water_curr=excluded.caretaker_water_curr,lighting=0,provision=0,review_flags=excluded.review_flags,notes=excluded.notes;
 END LOOP;
 FOR x IN SELECT * FROM jsonb_array_elements(d->'meter_readings') LOOP
  INSERT INTO public.meter_readings(id,period_id,owner_id,energy_prev,energy_curr,water_prev,water_curr)
  VALUES((x->>'id')::uuid,x->>'period_id',(owner_map->>(x->>'owner_id'))::uuid,(x->>'energy_prev')::numeric,(x->>'energy_curr')::numeric,(x->>'water_prev')::numeric,(x->>'water_curr')::numeric)
  ON CONFLICT(period_id,owner_id) DO UPDATE SET energy_prev=excluded.energy_prev,energy_curr=excluded.energy_curr,water_prev=excluded.water_prev,water_curr=excluded.water_curr;
 END LOOP;
 FOR x IN SELECT * FROM jsonb_array_elements(d->'allocation_rules') LOOP
  INSERT INTO public.allocation_rules(id,owner_id,start_period,end_period,settings,fee_override,reason)
  VALUES((x->>'id')::uuid,(owner_map->>(x->>'owner_id'))::uuid,x->>'start_period',x->>'end_period',x->'settings',(x->>'fee_override')::numeric,x->>'reason') ON CONFLICT(owner_id,start_period) DO NOTHING;
 END LOOP;
 FOR x IN SELECT * FROM jsonb_array_elements(d->'solar_participants') LOOP
  v_owner:=(owner_map->>(x->>'owner_id'))::uuid;
  SELECT * INTO s FROM public.solar_participants WHERE solar_participants.owner_id=v_owner;
  IF FOUND AND s.quota<>(x->>'quota')::numeric THEN RAISE EXCEPTION 'Cota solar já cadastrada com outro valor. Use ajuste explícito';END IF;
  IF NOT FOUND THEN
   INSERT INTO public.solar_participants(id,owner_id,quota,lot_ids)VALUES((x->>'id')::uuid,v_owner,(x->>'quota')::numeric,ARRAY(SELECT (lot_map->>value)::uuid FROM jsonb_array_elements_text(x->'lot_ids'))) RETURNING * INTO s;
  END IF;
  solar_map:=jsonb_set(solar_map,ARRAY[x->>'id'],to_jsonb(s.id::text));
 END LOOP;
 FOR x IN SELECT * FROM jsonb_array_elements(d->'solar_transactions') LOOP
  sid:=(solar_map->>(x->>'participant_id'))::uuid;
  IF EXISTS(SELECT 1 FROM public.solar_transactions WHERE source_key=x->>'source_key' AND (participant_id<>sid OR amount<>(x->>'amount')::numeric OR kind<>x->>'kind' OR paid_at<>(x->>'paid_at')::date)) THEN RAISE EXCEPTION 'Lançamento solar já importado com outros dados';END IF;
  INSERT INTO public.solar_transactions(id,participant_id,kind,amount,paid_at,reference,source_key,source_reported)
  VALUES((x->>'id')::uuid,sid,x->>'kind',(x->>'amount')::numeric,(x->>'paid_at')::date,x->>'reference',x->>'source_key',true) ON CONFLICT(source_key) DO NOTHING;
 END LOOP;
 report:=jsonb_build_object('owners_new',count_new,'owners_preserved',count_preserved,'extra_active_owners',extra_owners,'notes',p_payload->'notes','source_totals',p_payload->'source_totals');
 INSERT INTO public.import_batches(id,source_name,payload,report,imported_by)VALUES(p_payload->>'batch_id',p_payload->>'source_name',p_payload,report,auth.uid());
 RETURN jsonb_build_object('ok',true,'report',report);
END$$;
REVOKE ALL ON FUNCTION public.pontal_import_real_data(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pontal_import_real_data(jsonb) TO authenticated;
COMMIT;

-- Pontal da Serra 0.3.1. Aplicar depois do esquema inicial. Transação idempotente.
BEGIN;
ALTER TABLE public.owners ADD COLUMN IF NOT EXISTS monthly_fee numeric(13,2) CHECK(monthly_fee>=0);
ALTER TABLE public.owners ADD COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT true;
ALTER TABLE public.owners ADD COLUMN IF NOT EXISTS opening_balance_reviewed boolean NOT NULL DEFAULT true;
ALTER TABLE public.owners ADD COLUMN IF NOT EXISTS opening_balance_source text;
ALTER TABLE public.owners DROP CONSTRAINT IF EXISTS owners_opening_balance_check;
ALTER TABLE public.lots ADD COLUMN IF NOT EXISTS monthly_fee numeric(13,2) CHECK(monthly_fee>=0);
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS pump_inside_general boolean;
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS water_unit_confirmed boolean NOT NULL DEFAULT false;
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS financial_snapshot jsonb;
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS caretaker_salary_in_fee boolean NOT NULL DEFAULT false;
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS caretaker_energy_prev numeric(15,3) NOT NULL DEFAULT 0;
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS caretaker_energy_curr numeric(15,3) NOT NULL DEFAULT 0;
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS caretaker_water_prev numeric(15,3) NOT NULL DEFAULT 0;
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS caretaker_water_curr numeric(15,3) NOT NULL DEFAULT 0;
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS review_flags jsonb NOT NULL DEFAULT '[]';
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS snapshot jsonb NOT NULL DEFAULT '{}';
CREATE TABLE IF NOT EXISTS public.financial_links(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),lot_id uuid NOT NULL REFERENCES public.lots(id) ON DELETE RESTRICT,
 owner_id uuid NOT NULL REFERENCES public.owners(id) ON DELETE RESTRICT,built boolean NOT NULL DEFAULT true,
 monthly_fee numeric(13,2) NOT NULL CHECK(monthly_fee>=0),created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(lot_id,owner_id));
CREATE TABLE IF NOT EXISTS public.fee_rules(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_id uuid NOT NULL REFERENCES public.owners(id) ON DELETE RESTRICT,
 amount numeric(13,2) NOT NULL CHECK(amount>=0),start_period text NOT NULL CHECK(start_period~'^\d{4}-(0[1-9]|1[0-2])$'),
 end_period text CHECK(end_period IS NULL OR (end_period~'^\d{4}-(0[1-9]|1[0-2])$' AND end_period>=start_period)),
 reason text NOT NULL DEFAULT '',created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(owner_id,start_period));
CREATE TABLE IF NOT EXISTS public.allocation_rules(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_id uuid NOT NULL REFERENCES public.owners(id) ON DELETE RESTRICT,
 start_period text NOT NULL CHECK(start_period~'^\d{4}-(0[1-9]|1[0-2])$'),
 end_period text CHECK(end_period IS NULL OR (end_period~'^\d{4}-(0[1-9]|1[0-2])$' AND end_period>=start_period)),
 settings jsonb NOT NULL,fee_override numeric(13,2) CHECK(fee_override>=0),reason text NOT NULL CHECK(length(trim(reason))>0),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),UNIQUE(owner_id,start_period));
CREATE INDEX IF NOT EXISTS allocation_rules_owner_period ON public.allocation_rules(owner_id,start_period);
CREATE TABLE IF NOT EXISTS public.expenses(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),title text NOT NULL,kind text NOT NULL CHECK(kind IN('expense','fee')),
 amount numeric(13,2) NOT NULL CHECK(amount>0),scope text NOT NULL,
 start_period text NOT NULL CHECK(start_period~'^\d{4}-(0[1-9]|1[0-2])$'),
 end_period text NOT NULL CHECK(end_period>=start_period AND end_period~'^\d{4}-(0[1-9]|1[0-2])$'),
 notes text,receipt_path text,receipt_name text,created_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS mode text NOT NULL DEFAULT 'monthly';
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS target_owner_ids uuid[] NOT NULL DEFAULT '{}';
ALTER TABLE public.expenses DROP CONSTRAINT IF EXISTS expenses_scope_check;
ALTER TABLE public.expenses ADD CONSTRAINT expenses_scope_check CHECK(scope IN('built','all','lot','selected'));
ALTER TABLE public.expenses DROP CONSTRAINT IF EXISTS expenses_mode_check;
ALTER TABLE public.expenses ADD CONSTRAINT expenses_mode_check CHECK(mode IN('monthly','installments'));
CREATE TABLE IF NOT EXISTS public.employee_payouts(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),type text NOT NULL CHECK(type IN('13','vacation')),
 amount numeric(13,2) NOT NULL CHECK(amount>0),paid_at date NOT NULL,
 period_id text NOT NULL CHECK(period_id~'^\d{4}-(0[1-9]|1[0-2])$'),notes text,receipt_path text,receipt_name text,
 created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.solar_participants(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_id uuid NOT NULL UNIQUE REFERENCES public.owners(id) ON DELETE RESTRICT,
 quota numeric(13,2) NOT NULL CHECK(quota>0),lot_ids uuid[] NOT NULL DEFAULT '{}',created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.solar_transactions(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),participant_id uuid NOT NULL REFERENCES public.solar_participants(id) ON DELETE RESTRICT,
 kind text NOT NULL CHECK(kind IN('payment','refund','reversal','adjustment')),
 amount numeric(13,2) NOT NULL CHECK(amount<>0 AND(kind='adjustment' OR amount>0)),paid_at date NOT NULL,
 reference text NOT NULL CHECK(length(trim(reference))>0),source_key text NOT NULL UNIQUE,
 receipt_path text,receipt_name text,source_reported boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.import_batches(
 id text PRIMARY KEY,source_name text NOT NULL,payload jsonb NOT NULL,report jsonb NOT NULL DEFAULT '{}',
 imported_by uuid REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.access_invites(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_id uuid NOT NULL REFERENCES public.owners(id) ON DELETE RESTRICT,
 token_hash text NOT NULL UNIQUE CHECK(token_hash~'^[a-f0-9]{64}$'),expires_at timestamptz NOT NULL,
 created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 redeemed_by uuid REFERENCES auth.users(id),redeemed_at timestamptz,revoked boolean NOT NULL DEFAULT false);
CREATE TABLE IF NOT EXISTS public.audit_log(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,table_name text NOT NULL,record_id text,operation text NOT NULL,
 actor uuid,old_data jsonb,new_data jsonb,created_at timestamptz NOT NULL DEFAULT now());

REVOKE ALL ON public.app_admins FROM anon;
GRANT SELECT ON public.app_admins TO authenticated;
REVOKE INSERT,UPDATE,DELETE ON public.app_admins FROM authenticated;

-- Regras administrativas são privadas; condôminos recebem apenas suas faturas.
DO $$DECLARE t text;BEGIN
 FOREACH t IN ARRAY ARRAY['owners','lots','periods','meter_readings','invoices','payments','announcements','lot_access','owner_members','payment_config','whatsapp_log','financial_links','fee_rules','allocation_rules','expenses','employee_payouts','solar_participants','solar_transactions','import_batches','access_invites','audit_log'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM anon',t);
  EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON public.%I TO authenticated',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['financial_links','fee_rules','allocation_rules','expenses','employee_payouts','solar_participants','solar_transactions','import_batches'] LOOP
  EXECUTE format('DROP POLICY IF EXISTS pontal_admin_manage ON public.%I',t);
  EXECUTE format('CREATE POLICY pontal_admin_manage ON public.%I FOR ALL TO authenticated USING(public.is_admin()) WITH CHECK(public.is_admin())',t);
 END LOOP;
END$$;
REVOKE INSERT,UPDATE,DELETE ON public.audit_log,public.access_invites FROM authenticated;
DROP POLICY IF EXISTS pontal_audit_admin_read ON public.audit_log;
CREATE POLICY pontal_audit_admin_read ON public.audit_log FOR SELECT TO authenticated USING(public.is_admin());
DROP POLICY IF EXISTS pontal_invites_admin_read ON public.access_invites;
CREATE POLICY pontal_invites_admin_read ON public.access_invites FOR SELECT TO authenticated USING(public.is_admin());
DROP POLICY IF EXISTS pontal_financial_link_owner_read ON public.financial_links;
CREATE POLICY pontal_financial_link_owner_read ON public.financial_links FOR SELECT TO authenticated USING(public.can_view_owner(owner_id));
DROP POLICY IF EXISTS pontal_solar_owner_read ON public.solar_participants;
CREATE POLICY pontal_solar_owner_read ON public.solar_participants FOR SELECT TO authenticated USING(public.can_view_owner(owner_id));
DROP POLICY IF EXISTS pontal_solar_transaction_owner_read ON public.solar_transactions;
CREATE POLICY pontal_solar_transaction_owner_read ON public.solar_transactions FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.solar_participants p WHERE p.id=participant_id AND public.can_view_owner(p.owner_id)));
DROP POLICY IF EXISTS lots_select ON public.lots;
CREATE POLICY lots_select ON public.lots FOR SELECT TO authenticated USING(public.is_admin() OR public.can_view_owner(owner_id) OR EXISTS(SELECT 1 FROM public.lot_access a WHERE a.lot_id=lots.id AND public.can_view_owner(a.owner_id)) OR EXISTS(SELECT 1 FROM public.financial_links a WHERE a.lot_id=lots.id AND public.can_view_owner(a.owner_id)));

-- Uma conta recém-criada sem convite ainda não é integrante do condomínio.
DROP POLICY IF EXISTS payment_config_select ON public.payment_config;
CREATE POLICY payment_config_select ON public.payment_config FOR SELECT TO authenticated USING(public.is_admin() OR EXISTS(SELECT 1 FROM public.owners o WHERE public.can_view_owner(o.id)));
DROP POLICY IF EXISTS announcements_select ON public.announcements;
CREATE POLICY announcements_select ON public.announcements FOR SELECT TO authenticated USING(public.is_admin() OR EXISTS(SELECT 1 FROM public.owners o WHERE public.can_view_owner(o.id) AND(announcements.audience='all' OR o.id::text=ANY(announcements.target_owner_ids))));

CREATE OR REPLACE FUNCTION public.pontal_audit() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.audit_log(table_name,record_id,operation,actor,old_data,new_data)
 VALUES(TG_TABLE_NAME,coalesce(to_jsonb(NEW)->>'id',to_jsonb(OLD)->>'id'),TG_OP,auth.uid(),CASE WHEN TG_OP<>'INSERT' THEN to_jsonb(OLD) END,CASE WHEN TG_OP<>'DELETE' THEN to_jsonb(NEW) END);
 RETURN coalesce(NEW,OLD);
END$$;
CREATE OR REPLACE FUNCTION public.pontal_guard_rule() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
DECLARE r record;k text;v jsonb;candidate jsonb;
BEGIN
 -- O mesmo bloqueio é usado no fechamento para serializar regra e emissão.
 PERFORM pg_advisory_xact_lock(175471,31);
 FOR candidate IN SELECT x FROM jsonb_array_elements(jsonb_build_array(CASE WHEN TG_OP<>'INSERT' THEN to_jsonb(OLD) END,CASE WHEN TG_OP<>'DELETE' THEN to_jsonb(NEW) END)) x WHERE x<>'null'::jsonb LOOP
  IF EXISTS(SELECT 1 FROM public.periods p WHERE p.status='closed' AND p.id>=candidate->>'start_period' AND(candidate->>'end_period' IS NULL OR p.id<=candidate->>'end_period')) THEN RAISE EXCEPTION 'A regra alcança competência fechada. Crie nova vigência.';END IF;
 END LOOP;
 IF TG_OP<>'DELETE' AND TG_TABLE_NAME='allocation_rules' THEN
  IF jsonb_typeof(NEW.settings)<>'object' OR (SELECT count(*) FROM jsonb_object_keys(NEW.settings))<>4 THEN RAISE EXCEPTION 'Configuração de rateio inválida';END IF;
  FOREACH k IN ARRAY ARRAY['caretaker','lighting','provision','extra'] LOOP
   v:=NEW.settings->k;
   IF v IS NULL OR jsonb_typeof(v)<>'object' OR coalesce(v->>'mode','') NOT IN('auto','include','exclude') OR jsonb_typeof(v->'shares')<>'number' THEN RAISE EXCEPTION 'Participação ou cotas inválidas: %',k;END IF;
   IF (v->>'shares')::numeric<0.01 OR (v->>'shares')::numeric>1000 OR round((v->>'shares')::numeric,2)<>(v->>'shares')::numeric THEN RAISE EXCEPTION 'Número de cotas inválido: %',k;END IF;
  END LOOP;
  NEW.updated_at:=now();
 END IF;
 RETURN coalesce(NEW,OLD);
END$$;
CREATE OR REPLACE FUNCTION public.pontal_guard_financial_history() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF TG_TABLE_NAME='periods' THEN
  IF TG_OP<>'INSERT' AND OLD.status='closed' THEN RAISE EXCEPTION 'Competência fechada: lançamentos preservados';END IF;
 ELSIF TG_TABLE_NAME='meter_readings' THEN
  IF EXISTS(SELECT 1 FROM public.periods WHERE status='closed' AND id IN(coalesce(to_jsonb(OLD)->>'period_id',''),coalesce(to_jsonb(NEW)->>'period_id',''))) THEN RAISE EXCEPTION 'Leitura de competência fechada';END IF;
 ELSIF TG_TABLE_NAME='invoices' THEN
  IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Fatura emitida: use retificação auditável';END IF;
 ELSIF TG_TABLE_NAME='owners' AND TG_OP='UPDATE' THEN
  IF NEW.opening_balance IS DISTINCT FROM OLD.opening_balance AND EXISTS(SELECT 1 FROM public.invoices WHERE owner_id=OLD.id) THEN RAISE EXCEPTION 'Saldo inicial já utilizado em fatura. Registre um ajuste identificado.';END IF;
 END IF;
 RETURN coalesce(NEW,OLD);
END$$;
DO $$DECLARE t text;BEGIN
 FOREACH t IN ARRAY ARRAY['allocation_rules','fee_rules'] LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS pontal_guard_rule ON public.%I',t);
  EXECUTE format('CREATE TRIGGER pontal_guard_rule BEFORE INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.pontal_guard_rule()',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['periods','meter_readings','invoices','owners'] LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS pontal_guard_history ON public.%I',t);
  EXECUTE format('CREATE TRIGGER pontal_guard_history BEFORE INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.pontal_guard_financial_history()',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['allocation_rules','fee_rules','financial_links','periods','invoices','owners','payments','solar_transactions','owner_members'] LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS pontal_audit_change ON public.%I',t);
  EXECUTE format('CREATE TRIGGER pontal_audit_change AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.pontal_audit()',t);
 END LOOP;
END$$;

CREATE OR REPLACE FUNCTION public.pontal_capabilities() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;RETURN jsonb_build_object('version','0.3.1');END$$;
CREATE OR REPLACE FUNCTION public.pontal_source_snapshot() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE t text;value jsonb;result jsonb:='{}';BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;
 FOREACH t IN ARRAY ARRAY['owners','lots','periods','meter_readings','invoices','payments','expenses','financial_links','fee_rules','solar_participants','allocation_rules'] LOOP
  EXECUTE format('SELECT coalesce(jsonb_agg(to_jsonb(r)-''created_at''-''closed_at''-''issued_at''-''updated_at'' ORDER BY r.id),''[]''::jsonb) FROM public.%I r',t) INTO value;
  result:=jsonb_set(result,ARRAY[t],value);
 END LOOP;RETURN result;
END$$;
CREATE OR REPLACE FUNCTION public.pontal_close_month(p_period text,p_invoices jsonb,p_summary jsonb,p_source jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.periods;item jsonb;v numeric;target integer;issued timestamptz:=now();BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;
 PERFORM pg_advisory_xact_lock(175471,31);
 -- A fotografia da origem deve ser exatamente a que o administrador conferiu.
 LOCK TABLE public.owners,public.lots,public.meter_readings,public.payments,public.financial_links,public.fee_rules,public.allocation_rules,public.expenses IN SHARE MODE;
 SELECT * INTO p FROM public.periods WHERE id=p_period FOR UPDATE;
 IF NOT FOUND OR p.status<>'draft' THEN RAISE EXCEPTION 'Competência inexistente ou já fechada';END IF;
 IF p_source IS DISTINCT FROM public.pontal_source_snapshot() THEN RAISE EXCEPTION 'Dados alterados desde a conferência. Recarregue e confira novamente.';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p.review_flags) x WHERE NOT coalesce((x->>'resolved')::boolean,false)) THEN RAISE EXCEPTION 'Há pendências de importação a conferir';END IF;
 IF NOT p.water_unit_confirmed OR p.pump_inside_general IS NULL THEN RAISE EXCEPTION 'Confira medidores e unidade da água';END IF;
 IF EXISTS(SELECT 1 FROM public.owners WHERE active AND NOT opening_balance_reviewed) THEN RAISE EXCEPTION 'Confira os saldos de abertura';END IF;
 IF abs(coalesce((p_summary->>'energyDifference')::numeric,999999))>0.01 THEN RAISE EXCEPTION 'Energia não conciliada';END IF;
 IF EXISTS(SELECT 1 FROM public.invoices WHERE period_id>=p_period) THEN RAISE EXCEPTION 'Já há faturas neste mês ou em mês posterior';END IF;
 IF jsonb_typeof(p_invoices)<>'array' OR jsonb_array_length(p_invoices)=0 THEN RAISE EXCEPTION 'Faturas não informadas';END IF;
 SELECT count(*) INTO target FROM public.owners o WHERE o.active AND(EXISTS(SELECT 1 FROM public.lots l WHERE l.owner_id=o.id) OR EXISTS(SELECT 1 FROM public.financial_links l WHERE l.owner_id=o.id));
 IF jsonb_array_length(p_invoices)<>target OR (SELECT count(DISTINCT x->>'owner_id') FROM jsonb_array_elements(p_invoices) x)<>target THEN RAISE EXCEPTION 'Confira a lista de responsáveis a faturar';END IF;
 FOR item IN SELECT * FROM jsonb_array_elements(p_invoices) LOOP
  IF item->>'period_id'<>p_period OR NOT EXISTS(SELECT 1 FROM public.owners o WHERE o.id=(item->>'owner_id')::uuid AND o.active) THEN RAISE EXCEPTION 'Responsável ou competência inválidos';END IF;
  SELECT coalesce(sum((x->>'amount')::numeric),0) INTO v FROM jsonb_array_elements(item->'items') x;
  IF round(v,2)<>(item->>'current_amount')::numeric OR v<0 THEN RAISE EXCEPTION 'Total da fatura não corresponde aos itens';END IF;
  INSERT INTO public.invoices(id,period_id,owner_id,due_date,items,current_amount,previous_balance_at_issue,issued_at,snapshot)
  VALUES((item->>'id')::uuid,p_period,(item->>'owner_id')::uuid,p.due_date,item->'items',round(v,2),(item->>'previous_balance_at_issue')::numeric,issued,item->'snapshot');
 END LOOP;
 UPDATE public.periods SET status='closed',closed_at=issued,financial_snapshot=p_summary WHERE id=p_period;
 RETURN jsonb_build_object('ok',true,'invoices',target);
END$$;

CREATE OR REPLACE FUNCTION public.pontal_issue_invite(p_owner uuid,p_token_hash text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;
 IF p_token_hash!~'^[a-f0-9]{64}$' OR NOT EXISTS(SELECT 1 FROM public.owners WHERE id=p_owner AND active) THEN RAISE EXCEPTION 'Convite inválido';END IF;
 UPDATE public.access_invites SET revoked=true WHERE owner_id=p_owner AND redeemed_at IS NULL AND NOT revoked;
 INSERT INTO public.access_invites(owner_id,token_hash,expires_at,created_by)VALUES(p_owner,p_token_hash,now()+interval '30 days',auth.uid());
 RETURN jsonb_build_object('ok',true);
END$$;
CREATE OR REPLACE FUNCTION public.pontal_redeem_invite(p_code text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE invitation public.access_invites;uid uuid:=auth.uid();BEGIN
 IF uid IS NULL THEN RETURN jsonb_build_object('ok',false,'message','Entre na sua conta antes de informar o convite.');END IF;
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=uid AND email_confirmed_at IS NOT NULL) THEN RETURN jsonb_build_object('ok',false,'message','Confirme seu e-mail antes de vincular o acesso.');END IF;
 IF p_code!~'^[a-f0-9]{64}$' THEN RETURN jsonb_build_object('ok',false,'message','Convite inválido, utilizado ou expirado.');END IF;
 SELECT * INTO invitation FROM public.access_invites WHERE token_hash=encode(sha256(convert_to(p_code,'UTF8')),'hex') FOR UPDATE;
 IF NOT FOUND OR invitation.revoked OR invitation.redeemed_at IS NOT NULL OR invitation.expires_at<=now() OR NOT EXISTS(SELECT 1 FROM public.owners WHERE id=invitation.owner_id AND active) THEN RETURN jsonb_build_object('ok',false,'message','Convite inválido, utilizado ou expirado. Solicite outro ao síndico.');END IF;
 INSERT INTO public.owner_members(owner_id,user_id)VALUES(invitation.owner_id,uid) ON CONFLICT DO NOTHING;
 UPDATE public.access_invites SET redeemed_by=uid,redeemed_at=now() WHERE id=invitation.id;
 RETURN jsonb_build_object('ok',true);
END$$;

CREATE OR REPLACE FUNCTION public.pontal_import_solar(p_participants jsonb,p_transactions jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE x jsonb;old public.solar_transactions;BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;
 PERFORM pg_advisory_xact_lock(175471,32);
 FOR x IN SELECT * FROM jsonb_array_elements(p_participants) LOOP
  IF EXISTS(SELECT 1 FROM public.solar_participants WHERE owner_id=(x->>'owner_id')::uuid AND quota<>(x->>'quota')::numeric) THEN RAISE EXCEPTION 'Cota já cadastrada com outro valor';END IF;
  INSERT INTO public.solar_participants(id,owner_id,quota,lot_ids)VALUES((x->>'id')::uuid,(x->>'owner_id')::uuid,(x->>'quota')::numeric,ARRAY(SELECT value::uuid FROM jsonb_array_elements_text(x->'lot_ids'))) ON CONFLICT(owner_id) DO NOTHING;
 END LOOP;
 FOR x IN SELECT * FROM jsonb_array_elements(p_transactions) LOOP
  SELECT * INTO old FROM public.solar_transactions WHERE source_key=x->>'source_key';
  IF FOUND THEN
   IF old.participant_id<>(x->>'participant_id')::uuid OR old.kind<>x->>'kind' OR old.amount<>(x->>'amount')::numeric OR old.paid_at<>(x->>'paid_at')::date OR old.reference<>x->>'reference' THEN RAISE EXCEPTION 'Chave de importação repetida com dados diferentes';END IF;
  ELSE
   INSERT INTO public.solar_transactions(id,participant_id,kind,amount,paid_at,reference,source_key,receipt_path,receipt_name,source_reported)
   VALUES((x->>'id')::uuid,(x->>'participant_id')::uuid,x->>'kind',(x->>'amount')::numeric,(x->>'paid_at')::date,x->>'reference',x->>'source_key',x->>'receipt_path',x->>'receipt_name',coalesce((x->>'source_reported')::boolean,false));
  END IF;
 END LOOP;RETURN jsonb_build_object('ok',true);
END$$;

-- Funções de gatilho não são pontos de entrada da API.
REVOKE ALL ON FUNCTION public.pontal_audit(),public.pontal_guard_rule(),public.pontal_guard_financial_history() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.pontal_capabilities(),public.pontal_source_snapshot(),public.pontal_close_month(text,jsonb,jsonb,jsonb),public.pontal_issue_invite(uuid,text),public.pontal_redeem_invite(text),public.pontal_import_solar(jsonb,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pontal_capabilities(),public.pontal_source_snapshot(),public.pontal_close_month(text,jsonb,jsonb,jsonb),public.pontal_issue_invite(uuid,text),public.pontal_redeem_invite(text),public.pontal_import_solar(jsonb,jsonb) TO authenticated;
COMMIT;

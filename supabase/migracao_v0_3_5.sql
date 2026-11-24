-- 0.3.5: reabertura auditada e documentos privados do condomínio.
BEGIN;
CREATE TABLE IF NOT EXISTS public.month_reopen_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),period_id text NOT NULL,
 reason text NOT NULL CHECK(length(trim(reason)) BETWEEN 10 AND 1000),
 reopened_by uuid REFERENCES auth.users(id),reopened_at timestamptz NOT NULL DEFAULT now(),
 old_period jsonb NOT NULL,old_invoices jsonb NOT NULL
);
ALTER TABLE public.month_reopen_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.month_reopen_events FROM anon,authenticated;
GRANT SELECT ON public.month_reopen_events TO authenticated;
DROP POLICY IF EXISTS reopen_admin_read ON public.month_reopen_events;
CREATE POLICY reopen_admin_read ON public.month_reopen_events FOR SELECT TO authenticated USING(public.is_admin());

CREATE OR REPLACE FUNCTION public.pontal_guard_financial_history() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
DECLARE permitted boolean:=false;month_id text;
BEGIN
 month_id:=CASE WHEN TG_TABLE_NAME='periods' THEN coalesce(to_jsonb(OLD)->>'id',to_jsonb(NEW)->>'id') ELSE coalesce(to_jsonb(OLD)->>'period_id',to_jsonb(NEW)->>'period_id') END;
 -- Só a função privilegiada pode atravessar esta proteção. Um usuário que definir
 -- a variável por conta própria continua sem o papel proprietário da função.
 permitted:=TG_TABLE_NAME IN('periods','invoices') AND current_setting('pontal.reopening',true)=month_id
 AND current_user=(SELECT pg_catalog.pg_get_userbyid(p.proowner) FROM pg_catalog.pg_proc p WHERE p.oid='public.pontal_reopen_month(text,text)'::pg_catalog.regprocedure);
 IF permitted THEN
  IF TG_TABLE_NAME='invoices' AND TG_OP='DELETE' THEN RETURN OLD;END IF;
  IF TG_TABLE_NAME='periods' AND TG_OP='UPDATE' THEN IF OLD.status='closed' AND NEW.status='draft' THEN RETURN NEW;END IF;END IF;
 END IF;
 IF TG_TABLE_NAME='periods' THEN
  IF TG_OP<>'INSERT' AND OLD.status='closed' THEN RAISE EXCEPTION 'Competência fechada: lançamentos preservados';END IF;
 ELSIF TG_TABLE_NAME='meter_readings' THEN
  IF EXISTS(SELECT 1 FROM public.periods WHERE status='closed' AND id IN(coalesce(to_jsonb(OLD)->>'period_id',''),coalesce(to_jsonb(NEW)->>'period_id',''))) THEN RAISE EXCEPTION 'Leitura de competência fechada';END IF;
 ELSIF TG_TABLE_NAME='invoices' THEN
  IF TG_OP='INSERT' AND EXISTS(SELECT 1 FROM public.month_reopen_events e CROSS JOIN LATERAL jsonb_array_elements(e.old_invoices) i WHERE i->>'id'=NEW.id::text) THEN RAISE EXCEPTION 'Identificador de fatura arquivada não pode ser reutilizado';END IF;
  IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Fatura emitida: use a reabertura auditada';END IF;
 ELSIF TG_TABLE_NAME='owners' AND TG_OP='UPDATE' THEN
  IF NEW.opening_balance IS DISTINCT FROM OLD.opening_balance AND EXISTS(SELECT 1 FROM public.invoices WHERE owner_id=OLD.id) THEN RAISE EXCEPTION 'Saldo inicial já utilizado em fatura. Registre um ajuste identificado.';END IF;
 END IF;
 RETURN coalesce(NEW,OLD);
END$$;

CREATE OR REPLACE FUNCTION public.pontal_reopen_month(p_period text,p_reason text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.periods;old_bills jsonb;event_id uuid;BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;
 IF length(trim(coalesce(p_reason,''))) NOT BETWEEN 10 AND 1000 THEN RAISE EXCEPTION 'Informe um motivo de 10 a 1.000 caracteres';END IF;
 PERFORM pg_advisory_xact_lock(175471,31);
 LOCK TABLE public.periods,public.invoices,public.payments,public.employee_payouts,public.whatsapp_log IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO p FROM public.periods WHERE id=p_period FOR UPDATE;
 IF NOT FOUND OR p.status<>'closed' THEN RAISE EXCEPTION 'O mês não está fechado';END IF;
 IF p.closed_at IS NULL THEN RAISE EXCEPTION 'Fechamento sem data: precisa de conferência administrativa';END IF;
 IF EXISTS(SELECT 1 FROM public.periods WHERE id>p_period AND status='closed') OR EXISTS(SELECT 1 FROM public.invoices WHERE period_id>p_period) THEN RAISE EXCEPTION 'Existe mês posterior fechado ou com faturas. Reabra do mais recente para o mais antigo.';END IF;
 -- Pagamentos não têm alocação por fatura. Conservadoramente bloqueamos qualquer
 -- recebimento dos envolvidos no dia/após o fechamento ou lançado depois dele.
 IF EXISTS(SELECT 1 FROM public.payments x WHERE (x.created_at>=p.closed_at OR x.paid_at>=(p.closed_at AT TIME ZONE 'America/Sao_Paulo')::date) AND EXISTS(SELECT 1 FROM public.invoices i WHERE i.period_id=p_period AND i.owner_id=x.owner_id)) THEN RAISE EXCEPTION 'Há pagamentos que podem estar ligados às faturas. A reabertura automática está bloqueada.';END IF;
 IF EXISTS(SELECT 1 FROM public.employee_payouts WHERE period_id>=p_period) THEN RAISE EXCEPTION 'Há baixas de reservas neste mês ou depois dele. Confira antes de retificar.';END IF;
 IF EXISTS(SELECT 1 FROM public.whatsapp_log WHERE period_id=p_period AND kind='invoice') THEN RAISE EXCEPTION 'Há envio registrado de faturas. É necessária retificação acompanhada pela administração.';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(i) ORDER BY i.id),'[]') INTO old_bills FROM public.invoices i WHERE i.period_id=p_period;
 INSERT INTO public.month_reopen_events(period_id,reason,reopened_by,old_period,old_invoices) VALUES(p_period,trim(p_reason),auth.uid(),to_jsonb(p),old_bills) RETURNING id INTO event_id;
 PERFORM set_config('pontal.reopening',p_period,true);
 DELETE FROM public.invoices WHERE period_id=p_period;
 UPDATE public.periods SET status='draft',closed_at=NULL,financial_snapshot=NULL WHERE id=p_period;
 PERFORM set_config('pontal.reopening','',true);
 RETURN jsonb_build_object('ok',true,'event_id',event_id,'archived_invoices',jsonb_array_length(old_bills));
END$$;
REVOKE ALL ON FUNCTION public.pontal_reopen_month(text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pontal_reopen_month(text,text) TO authenticated;

CREATE TABLE IF NOT EXISTS public.community_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),title text NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 160),
 category text NOT NULL CHECK(category IN('documento','norma','aviso','contato','servico','agenda')),
 body text NOT NULL DEFAULT '' CHECK(length(body)<=12000),url text NOT NULL DEFAULT '' CHECK(url='' OR url~'^https://'),
 document_path text,document_name text,event_date date,published boolean NOT NULL DEFAULT true,
 updated_at timestamptz NOT NULL DEFAULT now(),created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.community_items ADD COLUMN IF NOT EXISTS period_id text REFERENCES public.periods(id) ON DELETE RESTRICT;
ALTER TABLE public.community_items ADD COLUMN IF NOT EXISTS context text NOT NULL DEFAULT 'condominio' CHECK(context IN('condominio','solar'));
ALTER TABLE public.community_items ADD COLUMN IF NOT EXISTS document_kind text NOT NULL DEFAULT 'geral' CHECK(document_kind IN('geral','conta_energia','leitura_geral','leitura_bomba','leitura_caseiro','leitura_individual','outro'));
ALTER TABLE public.community_items DROP CONSTRAINT IF EXISTS community_solar_no_period;
ALTER TABLE public.community_items ADD CONSTRAINT community_solar_no_period CHECK(context<>'solar' OR period_id IS NULL);
ALTER TABLE public.community_items DROP CONSTRAINT IF EXISTS community_document_period;
ALTER TABLE public.community_items ADD CONSTRAINT community_document_period CHECK(document_kind='geral' OR period_id IS NOT NULL);
ALTER TABLE public.community_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.community_items FROM anon;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.community_items TO authenticated;
DROP POLICY IF EXISTS community_admin ON public.community_items;
CREATE POLICY community_admin ON public.community_items FOR ALL TO authenticated USING(public.is_admin()) WITH CHECK(public.is_admin());
DROP POLICY IF EXISTS community_member_read ON public.community_items;
CREATE POLICY community_member_read ON public.community_items FOR SELECT TO authenticated USING(published AND EXISTS(SELECT 1 FROM public.owners o WHERE o.active AND public.can_view_owner(o.id)));
DROP TRIGGER IF EXISTS pontal_audit_change ON public.community_items;
CREATE TRIGGER pontal_audit_change AFTER INSERT OR UPDATE OR DELETE ON public.community_items FOR EACH ROW EXECUTE FUNCTION public.pontal_audit();
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('condominium-documents','condominium-documents',false,5242880,ARRAY['application/pdf','image/jpeg','image/png','image/webp']) ON CONFLICT(id) DO NOTHING;
DROP POLICY IF EXISTS community_document_admin ON storage.objects;
CREATE POLICY community_document_admin ON storage.objects FOR ALL TO authenticated USING(bucket_id='condominium-documents' AND public.is_admin()) WITH CHECK(bucket_id='condominium-documents' AND public.is_admin());
DROP POLICY IF EXISTS community_document_read ON storage.objects;
CREATE POLICY community_document_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='condominium-documents' AND EXISTS(SELECT 1 FROM public.community_items c WHERE c.document_path=storage.objects.name AND c.published));
CREATE OR REPLACE FUNCTION public.pontal_capabilities() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;RETURN jsonb_build_object('version','0.3.5','monthly_reports',true,'access_overview',true,'reopen_month',true,'community',true);END$$;
COMMIT;

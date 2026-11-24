BEGIN;
CREATE TABLE IF NOT EXISTS public.improvement_notes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
 title text NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 160),
 problem text NOT NULL CHECK(length(trim(problem)) BETWEEN 1 AND 6000),
 suggestion text NOT NULL DEFAULT '' CHECK(length(suggestion)<=6000),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN('pending','in_progress','done','not_possible')),
 app_version text NOT NULL DEFAULT '',context text NOT NULL DEFAULT '',
 resolution text NOT NULL DEFAULT '' CHECK(length(resolution)<=6000),
 resolved_version text NOT NULL DEFAULT '',created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(status NOT IN('done','not_possible') OR length(trim(resolution))>0),
 CHECK(status<>'done' OR length(trim(resolved_version))>0)
);
ALTER TABLE public.improvement_notes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.improvement_notes FROM anon;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.improvement_notes TO authenticated;
DROP POLICY IF EXISTS improvement_own_admin ON public.improvement_notes;
CREATE POLICY improvement_own_admin ON public.improvement_notes FOR ALL TO authenticated
 USING(user_id=(SELECT auth.uid()) AND public.is_admin()) WITH CHECK(user_id=(SELECT auth.uid()) AND public.is_admin());
CREATE OR REPLACE FUNCTION public.pontal_note_updated() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN NEW.updated_at:=now();NEW.created_at:=OLD.created_at;RETURN NEW;END$$;
DROP TRIGGER IF EXISTS improvement_timestamp ON public.improvement_notes;
CREATE TRIGGER improvement_timestamp BEFORE UPDATE ON public.improvement_notes FOR EACH ROW EXECUTE FUNCTION public.pontal_note_updated();
CREATE OR REPLACE FUNCTION public.pontal_capabilities() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;RETURN jsonb_build_object('version','0.3.6','monthly_reports',true,'access_overview',true,'reopen_month',true,'community',true,'improvement_notes',true,'draft_explanations',true);END$$;

-- Prévia individual publicada explicitamente pela administração; não constitui fatura.
CREATE TABLE IF NOT EXISTS public.month_explanations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 period_id text NOT NULL REFERENCES public.periods(id) ON DELETE CASCADE,
 owner_id uuid NOT NULL REFERENCES public.owners(id) ON DELETE CASCADE,
 report jsonb NOT NULL, own_calculation jsonb NOT NULL,
 published_at timestamptz NOT NULL DEFAULT now(), UNIQUE(period_id,owner_id)
);
ALTER TABLE public.month_explanations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.month_explanations FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.month_explanations TO authenticated;
DROP POLICY IF EXISTS explanation_read ON public.month_explanations;
CREATE POLICY explanation_read ON public.month_explanations FOR SELECT TO authenticated USING(
 public.is_admin() OR EXISTS(SELECT 1 FROM public.owners o WHERE o.id=owner_id AND o.active AND public.can_view_owner(o.id)));
CREATE OR REPLACE FUNCTION public.pontal_clear_explanations() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN DELETE FROM public.month_explanations;RETURN NULL;END$$;
REVOKE ALL ON FUNCTION public.pontal_clear_explanations() FROM PUBLIC,anon,authenticated;
DO $$DECLARE t text;BEGIN
 FOREACH t IN ARRAY ARRAY['owners','lots','periods','meter_readings','invoices','payments','expenses','financial_links','fee_rules','allocation_rules','solar_participants'] LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS explanation_invalidate ON public.%I',t);
  EXECUTE format('CREATE TRIGGER explanation_invalidate AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH STATEMENT EXECUTE FUNCTION public.pontal_clear_explanations()',t);
 END LOOP;
END$$;
CREATE OR REPLACE FUNCTION public.pontal_publish_explanations(p_period text,p_report jsonb,p_items jsonb,p_source jsonb) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item jsonb;oid uuid;n integer:=0;BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;
 PERFORM pg_advisory_xact_lock(175471,31);
 LOCK TABLE public.owners,public.lots,public.periods,public.meter_readings,public.invoices,public.payments,public.expenses,public.financial_links,public.fee_rules,public.allocation_rules,public.solar_participants IN SHARE MODE;
 IF NOT EXISTS(SELECT 1 FROM public.periods WHERE id=p_period AND status='draft') THEN RAISE EXCEPTION 'A prévia exige mês em rascunho';END IF;
 IF p_source IS DISTINCT FROM public.pontal_source_snapshot() THEN RAISE EXCEPTION 'Dados alterados. Recarregue e publique novamente';END IF;
 IF p_report->>'period_id' IS DISTINCT FROM p_period OR p_report->>'status' IS DISTINCT FROM 'draft' OR jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Prévia inválida';END IF;
 DELETE FROM public.month_explanations WHERE period_id=p_period;
 FOR item IN SELECT x FROM jsonb_array_elements(p_items) x LOOP
  oid:=(item->>'owner_id')::uuid;
  IF NOT EXISTS(SELECT 1 FROM public.owners WHERE id=oid AND active) OR jsonb_typeof(item->'calculation'->'items') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Parcela inválida';END IF;
  INSERT INTO public.month_explanations(period_id,owner_id,report,own_calculation) VALUES(p_period,oid,p_report,item->'calculation');n:=n+1;
 END LOOP;
 INSERT INTO public.audit_log(table_name,record_id,operation,actor,new_data) VALUES('month_explanations',p_period,'INSERT',auth.uid(),jsonb_build_object('published_count',n,'provisional',true));
 RETURN jsonb_build_object('ok',true,'count',n);
END$$;
REVOKE ALL ON FUNCTION public.pontal_publish_explanations(text,jsonb,jsonb,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pontal_publish_explanations(text,jsonb,jsonb,jsonb) TO authenticated;

-- Exclusão limitada ao registro fictício conhecido. Nenhuma busca por nome parcial.
CREATE OR REPLACE FUNCTION public.pontal_remove_homologation_internal() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE oid uuid:='46785172-f607-463c-92ef-bf2ffa60e3ae';o public.owners;lid uuid;BEGIN
 PERFORM pg_advisory_xact_lock(175471,31);
 SELECT * INTO o FROM public.owners WHERE id=oid FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',true,'already_removed',true);END IF;
 IF o.name<>'Teste de Homologação' OR o.active OR o.opening_balance<>0 OR o.login_user_id IS NOT NULL THEN RAISE EXCEPTION 'Cadastro de teste alterado ou vinculado: exclusão bloqueada';END IF;
 IF (SELECT count(*) FROM public.lots WHERE owner_id=oid)<>1 THEN RAISE EXCEPTION 'Lotes do teste alterados';END IF;
 SELECT id INTO lid FROM public.lots WHERE owner_id=oid AND number='TESTE-01' FOR UPDATE;
 IF lid IS NULL THEN RAISE EXCEPTION 'Lote de teste não confere';END IF;
 IF EXISTS(SELECT 1 FROM public.owner_members WHERE owner_id=oid)
 OR EXISTS(SELECT 1 FROM public.access_invites WHERE owner_id=oid)
 OR EXISTS(SELECT 1 FROM public.invoices WHERE owner_id=oid)
 OR EXISTS(SELECT 1 FROM public.payments WHERE owner_id=oid)
 OR EXISTS(SELECT 1 FROM public.meter_readings WHERE owner_id=oid)
 OR EXISTS(SELECT 1 FROM public.solar_participants WHERE owner_id=oid)
 OR EXISTS(SELECT 1 FROM public.financial_links WHERE owner_id=oid OR lot_id=lid)
 OR EXISTS(SELECT 1 FROM public.lot_access WHERE owner_id=oid OR lot_id=lid)
 OR EXISTS(SELECT 1 FROM public.allocation_rules WHERE owner_id=oid)
 OR EXISTS(SELECT 1 FROM public.fee_rules WHERE owner_id=oid)
 OR EXISTS(SELECT 1 FROM public.whatsapp_log WHERE owner_id=oid)
 OR EXISTS(SELECT 1 FROM public.expenses WHERE oid=ANY(target_owner_ids))
 OR EXISTS(SELECT 1 FROM public.announcements WHERE oid::text=ANY(target_owner_ids))
 THEN RAISE EXCEPTION 'Teste possui vínculos: preservado para conferência, sem apagar histórico';END IF;
 DELETE FROM public.lots WHERE id=lid;
 DELETE FROM public.owners WHERE id=oid;
 RETURN jsonb_build_object('ok',true,'removed',true);
END$$;
REVOKE ALL ON FUNCTION public.pontal_remove_homologation_internal() FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.pontal_remove_homologation() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;RETURN public.pontal_remove_homologation_internal();END$$;
REVOKE ALL ON FUNCTION public.pontal_remove_homologation() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pontal_remove_homologation() TO authenticated;
DO $$BEGIN PERFORM public.pontal_remove_homologation_internal();EXCEPTION WHEN raise_exception OR foreign_key_violation THEN RAISE WARNING 'Cadastro fictício preservado: %',SQLERRM;END$$;
COMMIT;

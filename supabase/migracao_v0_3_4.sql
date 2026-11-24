-- Identificação de síndico é cadastral; não concede privilégios aos membros do lote.
ALTER TABLE public.owners ADD COLUMN IF NOT EXISTS is_syndic boolean NOT NULL DEFAULT false;
ALTER TABLE public.access_invites ADD COLUMN IF NOT EXISTS recipient_label text NOT NULL DEFAULT '';

CREATE OR REPLACE FUNCTION public.pontal_capabilities() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;RETURN jsonb_build_object('version','0.3.4','monthly_reports',true,'access_overview',true);END$$;

CREATE OR REPLACE FUNCTION public.pontal_access_overview() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('owner_id',o.id,
  'users',coalesce((SELECT jsonb_agg(jsonb_build_object('user_id',u.id,'email',u.email,'name',coalesce(nullif(u.raw_user_meta_data->>'full_name',''),nullif(u.raw_user_meta_data->>'name',''),u.email),'confirmed',u.email_confirmed_at IS NOT NULL,'is_admin',EXISTS(SELECT 1 FROM public.app_admins a WHERE a.user_id=u.id)) ORDER BY u.email) FROM auth.users u WHERE u.id=o.login_user_id OR EXISTS(SELECT 1 FROM public.owner_members m WHERE m.owner_id=o.id AND m.user_id=u.id)),'[]'),
  'invites',coalesce((SELECT jsonb_agg(jsonb_build_object('id',i.id,'recipient_label',i.recipient_label,'created_at',i.created_at,'expires_at',i.expires_at,'redeemed_at',i.redeemed_at,'revoked',i.revoked) ORDER BY i.created_at DESC) FROM public.access_invites i WHERE i.owner_id=o.id),'[]'))),'[]') INTO result FROM public.owners o;
 RETURN result;
END$$;

CREATE OR REPLACE FUNCTION public.pontal_issue_personal_invite(p_owner uuid,p_token_hash text,p_recipient_label text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;
 IF p_token_hash!~'^[a-f0-9]{64}$' OR NOT EXISTS(SELECT 1 FROM public.owners WHERE id=p_owner AND active) OR length(coalesce(p_recipient_label,''))>100 THEN RAISE EXCEPTION 'Convite inválido';END IF;
 -- Cada pessoa recebe convite próprio; criar o do pai não invalida o do filho.
 INSERT INTO public.access_invites(owner_id,token_hash,expires_at,created_by,recipient_label)VALUES(p_owner,p_token_hash,now()+interval '30 days',auth.uid(),trim(coalesce(p_recipient_label,'')));
 RETURN jsonb_build_object('ok',true);
END$$;
-- Compatível com janelas anteriores, sem revogar os demais convites do mesmo lote.
CREATE OR REPLACE FUNCTION public.pontal_issue_invite(p_owner uuid,p_token_hash text) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$SELECT public.pontal_issue_personal_invite(p_owner,p_token_hash,'')$$;

CREATE OR REPLACE FUNCTION public.pontal_revoke_invite(p_invite uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso administrativo necessário';END IF;
 UPDATE public.access_invites SET revoked=true WHERE id=p_invite AND redeemed_at IS NULL AND NOT revoked;
END$$;
REVOKE ALL ON FUNCTION public.pontal_access_overview(),public.pontal_issue_personal_invite(uuid,text,text),public.pontal_revoke_invite(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pontal_access_overview(),public.pontal_issue_personal_invite(uuid,text,text),public.pontal_revoke_invite(uuid) TO authenticated;

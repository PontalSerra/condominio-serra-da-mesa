-- Pontal da Serra 0.3.2: atualização completa sem dados reais.
-- Uma transação, reaplicável no projeto existente.
BEGIN;
-- Pontal da Serra Web | Esquema inicial para Supabase Postgres
-- Rodar no SQL Editor do projeto. Criar o primeiro síndico com SQL conforme README.
create extension if not exists pgcrypto;

create table if not exists public.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.app_admins where user_id = (select auth.uid()));
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

create table if not exists public.owners (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 whatsapp text,
 whatsapp_opt_in boolean not null default false,
 login_user_id uuid unique references auth.users(id) on delete set null,
 opening_balance numeric(13,2) not null default 0 check (opening_balance >= 0),
 created_at timestamptz not null default now()
);
create table if not exists public.lots (
 id uuid primary key default gen_random_uuid(),
 number text not null unique,
 owner_id uuid not null references public.owners(id) on delete restrict,
 built boolean not null default false,
 solar_opt_in boolean not null default false,
 created_at timestamptz not null default now()
);
-- Informações de outro coproprietário: acesso ao lote, não à cobrança do titular principal.
create table if not exists public.lot_access (
 lot_id uuid not null references public.lots(id) on delete cascade,
 owner_id uuid not null references public.owners(id) on delete cascade,
 primary key (lot_id, owner_id)
);
-- Várias contas de login podem acessar o mesmo titular de cobrança (ex.: coproprietários).
create table if not exists public.owner_members (
  owner_id uuid not null references public.owners(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key(owner_id,user_id)
);
create or replace function public.can_view_owner(p_owner uuid) returns boolean
language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.owners o where o.id=p_owner and
   (o.login_user_id=(select auth.uid()) or exists(select 1 from public.owner_members m where m.owner_id=o.id and m.user_id=(select auth.uid()))));
$$;
revoke all on function public.can_view_owner(uuid) from public;
grant execute on function public.can_view_owner(uuid) to authenticated;
create table if not exists public.periods (
 id text primary key check (id ~ '^[0-9]{4}-[0-9]{2}$'),
 due_date date not null,
 status text not null default 'draft' check (status in ('draft','closed')),
 energy_rate numeric(13,6) not null default 0,
 general_prev numeric(15,3) not null default 0,
 general_curr numeric(15,3) not null default 0,
 general_invoice numeric(13,2) not null default 0,
 pump_prev numeric(15,3) not null default 0,
 pump_curr numeric(15,3) not null default 0,
 pump_invoice numeric(13,2) not null default 0,
 water_divisor numeric(13,3) not null default 1000 check (water_divisor > 0),
 caretaker numeric(13,2) not null default 0,
 lighting numeric(13,2) not null default 0,
 provision numeric(13,2) not null default 0,
 extra_amount numeric(13,2) not null default 0,
 extra_scope text not null default 'built' check (extra_scope in ('built','all','lot')),
 solar_per_lot numeric(13,2) not null default 0,
 notes text,
 closed_at timestamptz,
 created_at timestamptz not null default now(),
 check (general_curr >= general_prev and pump_curr >= pump_prev)
);
create table if not exists public.meter_readings (
 id uuid primary key default gen_random_uuid(),
 period_id text not null references public.periods(id) on delete cascade,
 owner_id uuid not null references public.owners(id) on delete cascade,
 energy_prev numeric(15,3), energy_curr numeric(15,3),
 water_prev numeric(15,3), water_curr numeric(15,3),
 unique (period_id, owner_id),
 check ((energy_prev is null or energy_curr is null) or energy_curr >= energy_prev),
 check ((water_prev is null or water_curr is null) or water_curr >= water_prev)
);
create table if not exists public.invoices (
 id uuid primary key default gen_random_uuid(),
 period_id text not null references public.periods(id) on delete restrict,
 owner_id uuid not null references public.owners(id) on delete restrict,
 due_date date not null,
 items jsonb not null default '[]'::jsonb,
 current_amount numeric(13,2) not null default 0 check (current_amount >= 0),
 previous_balance_at_issue numeric(13,2) not null default 0,
 issued_at timestamptz not null default now(),
 unique(period_id, owner_id)
);
create table if not exists public.payments (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.owners(id) on delete restrict,
 paid_at date not null,
 amount numeric(13,2) not null check (amount > 0),
 method text not null default 'pix',
 reference text,
 created_at timestamptz not null default now()
);
create table if not exists public.announcements (
 id uuid primary key default gen_random_uuid(),
 title text not null,
 body text not null,
 category text not null default 'geral',
 audience text not null default 'all' check (audience in ('all','selected')),
 target_owner_ids text[] not null default '{}',
 created_at timestamptz not null default now()
);
create table if not exists public.payment_config (
 id integer primary key default 1 check (id=1),
 pix_key text not null default '',
 pix_name text not null default 'CONDOMINIO PONTAL DA SERRA',
 pix_city text not null default 'NIQUELANDIA',
 pix_enabled boolean not null default false
);
insert into public.payment_config(id) values(1) on conflict do nothing;
create table if not exists public.whatsapp_log (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.owners(id) on delete restrict,
 period_id text not null,
 kind text not null check(kind in ('invoice','reminder')),
 sent_at timestamptz not null default now(),
 provider_message_id text,
 unique(owner_id,period_id,kind)
);

alter table public.app_admins enable row level security;
alter table public.owners enable row level security;
alter table public.lots enable row level security;
alter table public.lot_access enable row level security;
alter table public.owner_members enable row level security;
alter table public.periods enable row level security;
alter table public.meter_readings enable row level security;
alter table public.invoices enable row level security;
alter table public.payments enable row level security;
alter table public.announcements enable row level security;
alter table public.payment_config enable row level security;
alter table public.whatsapp_log enable row level security;

DROP POLICY IF EXISTS admins_self_select ON public.app_admins;
create policy admins_self_select on public.app_admins for select to authenticated using (user_id = (select auth.uid()));

DROP POLICY IF EXISTS owners_select ON public.owners;
create policy owners_select on public.owners for select to authenticated
using (public.is_admin() or public.can_view_owner(owners.id));
DROP POLICY IF EXISTS owners_admin_insert ON public.owners;
create policy owners_admin_insert on public.owners for insert to authenticated with check(public.is_admin());
DROP POLICY IF EXISTS owners_admin_update ON public.owners;
create policy owners_admin_update on public.owners for update to authenticated using(public.is_admin()) with check(public.is_admin());
DROP POLICY IF EXISTS owners_admin_delete ON public.owners;
create policy owners_admin_delete on public.owners for delete to authenticated using(public.is_admin());

DROP POLICY IF EXISTS lots_select ON public.lots;
create policy lots_select on public.lots for select to authenticated using (
 public.is_admin() or public.can_view_owner(lots.owner_id)
 or exists(select 1 from public.lot_access a where a.lot_id=lots.id and public.can_view_owner(a.owner_id))
);
DROP POLICY IF EXISTS lots_admin_manage ON public.lots;
create policy lots_admin_manage on public.lots for all to authenticated using (public.is_admin()) with check(public.is_admin());
DROP POLICY IF EXISTS lot_access_select ON public.lot_access;
create policy lot_access_select on public.lot_access for select to authenticated using (
 public.is_admin() or public.can_view_owner(lot_access.owner_id)
);
DROP POLICY IF EXISTS lot_access_admin_manage ON public.lot_access;
create policy lot_access_admin_manage on public.lot_access for all to authenticated using(public.is_admin()) with check(public.is_admin());

DROP POLICY IF EXISTS owner_members_read ON public.owner_members;
create policy owner_members_read on public.owner_members for select to authenticated using (public.is_admin() or user_id=(select auth.uid()));
DROP POLICY IF EXISTS owner_members_admin_manage ON public.owner_members;
create policy owner_members_admin_manage on public.owner_members for all to authenticated using(public.is_admin()) with check(public.is_admin());
DROP POLICY IF EXISTS periods_admin_only ON public.periods;
create policy periods_admin_only on public.periods for all to authenticated using(public.is_admin()) with check(public.is_admin());
DROP POLICY IF EXISTS readings_select ON public.meter_readings;
create policy readings_select on public.meter_readings for select to authenticated using (
 public.is_admin() or public.can_view_owner(meter_readings.owner_id)
);
DROP POLICY IF EXISTS readings_admin_manage ON public.meter_readings;
create policy readings_admin_manage on public.meter_readings for all to authenticated using(public.is_admin()) with check(public.is_admin());
DROP POLICY IF EXISTS invoices_select ON public.invoices;
create policy invoices_select on public.invoices for select to authenticated using (
 public.is_admin() or public.can_view_owner(invoices.owner_id)
);
DROP POLICY IF EXISTS invoices_admin_manage ON public.invoices;
create policy invoices_admin_manage on public.invoices for all to authenticated using(public.is_admin()) with check(public.is_admin());
DROP POLICY IF EXISTS payments_select ON public.payments;
create policy payments_select on public.payments for select to authenticated using (
 public.is_admin() or public.can_view_owner(payments.owner_id)
);
DROP POLICY IF EXISTS payments_admin_manage ON public.payments;
create policy payments_admin_manage on public.payments for all to authenticated using(public.is_admin()) with check(public.is_admin());
DROP POLICY IF EXISTS announcements_select ON public.announcements;
create policy announcements_select on public.announcements for select to authenticated using (
 public.is_admin() or exists(select 1 from public.owners o where public.can_view_owner(o.id) and
 (announcements.audience='all' or o.id::text=any(announcements.target_owner_ids)))
);
DROP POLICY IF EXISTS announcements_admin_manage ON public.announcements;
create policy announcements_admin_manage on public.announcements for all to authenticated using(public.is_admin()) with check(public.is_admin());
DROP POLICY IF EXISTS payment_config_select ON public.payment_config;
create policy payment_config_select on public.payment_config for select to authenticated using(true);
DROP POLICY IF EXISTS payment_config_admin_manage ON public.payment_config;
create policy payment_config_admin_manage on public.payment_config for all to authenticated using(public.is_admin()) with check(public.is_admin());
DROP POLICY IF EXISTS whatsapp_log_admin_only ON public.whatsapp_log;
create policy whatsapp_log_admin_only on public.whatsapp_log for all to authenticated using(public.is_admin()) with check(public.is_admin());

-- SEGURANÇA: nunca usar a chave service_role no navegador ou no GitHub.
-- O lote compartilhado não concede acesso automático a outras cobranças do titular.


-- Pontal da Serra Web v0.2: executar no SQL Editor do Supabase após schema.sql v0.1.
-- Idempotente nas estruturas; apenas o usuário síndico pode lançar gastos e acessar anexos.
ALTER TABLE public.owners ADD COLUMN IF NOT EXISTS monthly_fee numeric(13,2) CHECK (monthly_fee >= 0);
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS pump_inside_general boolean NOT NULL DEFAULT true;

CREATE TABLE IF NOT EXISTS public.expenses (
 id uuid primary key default gen_random_uuid(),
 title text not null,
 kind text not null check (kind in ('expense','fee')),
 amount numeric(13,2) not null check (amount > 0),
 scope text not null check (scope in ('built','all','lot')),
 start_period text not null check (start_period ~ '^[0-9]{4}-[0-9]{2}$'),
 end_period text not null check (end_period ~ '^[0-9]{4}-[0-9]{2}$' and end_period >= start_period),
 notes text,
 receipt_path text,
 receipt_name text,
 created_at timestamptz not null default now()
);
CREATE TABLE IF NOT EXISTS public.employee_payouts (
 id uuid primary key default gen_random_uuid(),
 type text not null check (type in ('13','vacation')),
 amount numeric(13,2) not null check (amount > 0),
 paid_at date not null,
 period_id text not null check (period_id ~ '^[0-9]{4}-[0-9]{2}$'),
 notes text,
 receipt_path text,
 receipt_name text,
 created_at timestamptz not null default now()
);
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_payouts ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='expenses' AND policyname='expenses_admin_manage') THEN
    CREATE POLICY expenses_admin_manage ON public.expenses FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
  END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='employee_payouts' AND policyname='employee_payouts_admin_manage') THEN
    CREATE POLICY employee_payouts_admin_manage ON public.employee_payouts FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
  END IF;
END $$;

-- Armazenamento PRIVADO de fotos, recibos e notas fiscais.
INSERT INTO storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
VALUES('expense-receipts','expense-receipts',false,5242880,ARRAY['image/jpeg','image/png','image/webp','application/pdf'])
ON CONFLICT(id) DO UPDATE SET public=false, file_size_limit=5242880, allowed_mime_types=EXCLUDED.allowed_mime_types;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='pontal_receipts_admin_select') THEN
    CREATE POLICY pontal_receipts_admin_select ON storage.objects FOR SELECT TO authenticated USING(bucket_id='expense-receipts' AND public.is_admin());
  END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='pontal_receipts_admin_insert') THEN
    CREATE POLICY pontal_receipts_admin_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='expense-receipts' AND public.is_admin());
  END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='pontal_receipts_admin_update') THEN
    CREATE POLICY pontal_receipts_admin_update ON storage.objects FOR UPDATE TO authenticated USING(bucket_id='expense-receipts' AND public.is_admin()) WITH CHECK(bucket_id='expense-receipts' AND public.is_admin());
  END IF;
END $$;


-- Pontal da Serra 0.3.1. Aplicar depois do esquema inicial. Transação idempotente.

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



-- Função administrativa de importação. O arquivo público contém somente código,
-- nunca nomes, saldos, contatos ou dados reais do condomínio.

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

COMMIT;

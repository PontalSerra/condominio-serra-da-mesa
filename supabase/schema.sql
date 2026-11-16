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

create policy admins_self_select on public.app_admins for select to authenticated using (user_id = (select auth.uid()));

create policy owners_select on public.owners for select to authenticated
using (public.is_admin() or public.can_view_owner(owners.id));
create policy owners_admin_insert on public.owners for insert to authenticated with check(public.is_admin());
create policy owners_admin_update on public.owners for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy owners_admin_delete on public.owners for delete to authenticated using(public.is_admin());

create policy lots_select on public.lots for select to authenticated using (
 public.is_admin() or public.can_view_owner(lots.owner_id)
 or exists(select 1 from public.lot_access a where a.lot_id=lots.id and public.can_view_owner(a.owner_id))
);
create policy lots_admin_manage on public.lots for all to authenticated using (public.is_admin()) with check(public.is_admin());
create policy lot_access_select on public.lot_access for select to authenticated using (
 public.is_admin() or public.can_view_owner(lot_access.owner_id)
);
create policy lot_access_admin_manage on public.lot_access for all to authenticated using(public.is_admin()) with check(public.is_admin());

create policy owner_members_read on public.owner_members for select to authenticated using (public.is_admin() or user_id=(select auth.uid()));
create policy owner_members_admin_manage on public.owner_members for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy periods_admin_only on public.periods for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy readings_select on public.meter_readings for select to authenticated using (
 public.is_admin() or public.can_view_owner(meter_readings.owner_id)
);
create policy readings_admin_manage on public.meter_readings for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy invoices_select on public.invoices for select to authenticated using (
 public.is_admin() or public.can_view_owner(invoices.owner_id)
);
create policy invoices_admin_manage on public.invoices for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy payments_select on public.payments for select to authenticated using (
 public.is_admin() or public.can_view_owner(payments.owner_id)
);
create policy payments_admin_manage on public.payments for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy announcements_select on public.announcements for select to authenticated using (
 public.is_admin() or exists(select 1 from public.owners o where public.can_view_owner(o.id) and
 (announcements.audience='all' or o.id::text=any(announcements.target_owner_ids)))
);
create policy announcements_admin_manage on public.announcements for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy payment_config_select on public.payment_config for select to authenticated using(true);
create policy payment_config_admin_manage on public.payment_config for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy whatsapp_log_admin_only on public.whatsapp_log for all to authenticated using(public.is_admin()) with check(public.is_admin());

-- SEGURANÇA: nunca usar a chave service_role no navegador ou no GitHub.
-- O lote compartilhado não concede acesso automático a outras cobranças do titular.

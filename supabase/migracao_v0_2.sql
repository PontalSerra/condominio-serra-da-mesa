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

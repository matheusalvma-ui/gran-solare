-- Applied to Supabase project dbfxmjxigrjybxappxlj on 2026-10-15.
-- This migration assumes the existing Solara base schema from the earlier project migrations.
ALTER VIEW public.dashboard_company_metrics SET (security_invoker = true);
REVOKE ALL ON TABLE public.dashboard_company_metrics FROM anon;
GRANT SELECT ON TABLE public.dashboard_company_metrics TO authenticated;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
CHECK (role = ANY (ARRAY['platform_admin','company_admin','manager','operator','commercial','financial','support','customer']));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL;

ALTER TABLE public.customers
 ADD COLUMN IF NOT EXISTS street_address text,
 ADD COLUMN IF NOT EXISTS city text,
 ADD COLUMN IF NOT EXISTS state text,
 ADD COLUMN IF NOT EXISTS assigned_to uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 ADD COLUMN IF NOT EXISTS last_activity_at timestamptz;

ALTER TABLE public.solar_plants
 ADD COLUMN IF NOT EXISTS latitude numeric,
 ADD COLUMN IF NOT EXISTS longitude numeric,
 ADD COLUMN IF NOT EXISTS expected_daily_kwh numeric,
 ADD COLUMN IF NOT EXISTS monthly_generation_goal_kwh numeric,
 ADD COLUMN IF NOT EXISTS monitoring_provider text,
 ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;

ALTER TABLE public.energy_bills
 ADD COLUMN IF NOT EXISTS issued_at date,
 ADD COLUMN IF NOT EXISTS grid_consumption_kwh numeric,
 ADD COLUMN IF NOT EXISTS injected_energy_kwh numeric,
 ADD COLUMN IF NOT EXISTS credits_received_kwh numeric,
 ADD COLUMN IF NOT EXISTS credits_used_kwh numeric,
 ADD COLUMN IF NOT EXISTS credits_balance_kwh numeric,
 ADD COLUMN IF NOT EXISTS tariff_per_kwh numeric,
 ADD COLUMN IF NOT EXISTS payment_status text NOT NULL DEFAULT 'pending';

ALTER TABLE public.inverter_telemetry
 ADD COLUMN IF NOT EXISTS pv_voltage_v numeric,
 ADD COLUMN IF NOT EXISTS pv_current_a numeric,
 ADD COLUMN IF NOT EXISTS temperature_c numeric,
 ADD COLUMN IF NOT EXISTS grid_frequency_hz numeric,
 ADD COLUMN IF NOT EXISTS fault_code text,
 ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_sync_logs_integration_id ON public.integration_sync_logs(integration_id);
CREATE INDEX IF NOT EXISTS idx_inverter_integrations_created_by ON public.inverter_integrations(created_by);
CREATE INDEX IF NOT EXISTS idx_plant_alerts_device_id ON public.plant_alerts(device_id);
CREATE INDEX IF NOT EXISTS idx_plant_alerts_solar_plant_id ON public.plant_alerts(solar_plant_id);
CREATE INDEX IF NOT EXISTS idx_profiles_customer_id ON public.profiles(customer_id);
CREATE INDEX IF NOT EXISTS idx_customers_company_city ON public.customers(company_id, city);
CREATE INDEX IF NOT EXISTS idx_solar_plants_company_status ON public.solar_plants(company_id, status);
CREATE INDEX IF NOT EXISTS idx_bills_company_due_date ON public.energy_bills(company_id, due_date);
CREATE INDEX IF NOT EXISTS idx_generation_company_period ON public.generation_records(company_id, period_start, period_end);

CREATE TABLE IF NOT EXISTS public.saas_plans (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 code text NOT NULL UNIQUE,
 name text NOT NULL,
 description text,
 price_monthly numeric NOT NULL CHECK (price_monthly >= 0),
 price_yearly numeric NOT NULL CHECK (price_yearly >= 0),
 max_users integer CHECK (max_users IS NULL OR max_users > 0),
 max_customers integer CHECK (max_customers IS NULL OR max_customers > 0),
 max_plants integer CHECK (max_plants IS NULL OR max_plants > 0),
 max_integrations integer CHECK (max_integrations IS NULL OR max_integrations > 0),
 history_days integer CHECK (history_days IS NULL OR history_days > 0),
 api_requests_per_day integer CHECK (api_requests_per_day IS NULL OR api_requests_per_day > 0),
 features jsonb NOT NULL DEFAULT '{}'::jsonb,
 is_active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.saas_subscriptions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
 plan_id uuid REFERENCES public.saas_plans(id) ON DELETE RESTRICT,
 status text NOT NULL DEFAULT 'trial' CHECK (status IN ('trial','active','past_due','suspended','canceled')),
 billing_period text NOT NULL DEFAULT 'monthly' CHECK (billing_period IN ('monthly','yearly')),
 trial_ends_at timestamptz,
 current_period_start timestamptz,
 current_period_end timestamptz,
 cancel_at_period_end boolean NOT NULL DEFAULT false,
 payment_provider text,
 provider_customer_id text,
 provider_subscription_id text,
 last_payment_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_saas_subscriptions_company_created ON public.saas_subscriptions(company_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.organization_settings (
 company_id uuid PRIMARY KEY REFERENCES public.companies(id) ON DELETE CASCADE,
 display_name text,
 logo_url text,
 brand_color text,
 timezone text NOT NULL DEFAULT 'America/Sao_Paulo',
 locale text NOT NULL DEFAULT 'pt-BR',
 generation_targets jsonb NOT NULL DEFAULT '{}'::jsonb,
 alert_preferences jsonb NOT NULL DEFAULT '{}'::jsonb,
 custom_fields jsonb NOT NULL DEFAULT '{}'::jsonb,
 updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.crm_tasks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
 lead_id uuid REFERENCES public.leads(id) ON DELETE SET NULL,
 customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
 title text NOT NULL,
 description text,
 task_type text NOT NULL DEFAULT 'follow_up' CHECK (task_type IN ('call','email','meeting','follow_up','other')),
 status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','canceled')),
 priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low','normal','high','urgent')),
 assigned_to uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 due_at timestamptz,
 completed_at timestamptz,
 created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.proposals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
 customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
 lead_id uuid REFERENCES public.leads(id) ON DELETE SET NULL,
 proposal_number text,
 title text NOT NULL,
 scope text,
 amount numeric NOT NULL DEFAULT 0 CHECK (amount >= 0),
 payment_terms text,
 valid_until date,
 status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','review','sent','accepted','rejected','expired','canceled')),
 version integer NOT NULL DEFAULT 1 CHECK (version > 0),
 document_path text,
 created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.contracts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
 customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
 solar_plant_id uuid REFERENCES public.solar_plants(id) ON DELETE SET NULL,
 proposal_id uuid REFERENCES public.proposals(id) ON DELETE SET NULL,
 contract_number text,
 title text NOT NULL,
 contract_type text,
 amount numeric NOT NULL DEFAULT 0 CHECK (amount >= 0),
 start_date date,
 end_date date,
 renewal_enabled boolean NOT NULL DEFAULT false,
 renewal_index text,
 status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','expiring','expired','terminated')),
 document_path text,
 created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.maintenance_work_orders (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
 solar_plant_id uuid REFERENCES public.solar_plants(id) ON DELETE SET NULL,
 device_id uuid REFERENCES public.inverter_devices(id) ON DELETE SET NULL,
 work_order_number text,
 title text NOT NULL,
 description text,
 maintenance_type text NOT NULL DEFAULT 'corrective' CHECK (maintenance_type IN ('preventive','corrective','inspection')),
 priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low','normal','high','critical')),
 status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','scheduled','in_progress','waiting_parts','resolved','closed','canceled')),
 scheduled_at timestamptz,
 assigned_to uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 opened_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 diagnosis text,
 root_cause text,
 resolution text,
 materials jsonb NOT NULL DEFAULT '[]'::jsonb,
 labor_minutes integer CHECK (labor_minutes IS NULL OR labor_minutes >= 0),
 closed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
 recipient_user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
 notification_type text NOT NULL DEFAULT 'system',
 severity text NOT NULL DEFAULT 'info' CHECK (severity IN ('info','warning','critical')),
 title text NOT NULL,
 message text,
 related_table text,
 related_id uuid,
 action_url text,
 read_at timestamptz,
 acknowledged_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread ON public.notifications(recipient_user_id, created_at DESC) WHERE read_at IS NULL;
CREATE TABLE IF NOT EXISTS public.audit_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 company_id uuid REFERENCES public.companies(id) ON DELETE SET NULL,
 actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 action text NOT NULL,
 resource_type text NOT NULL,
 resource_id text,
 outcome text NOT NULL DEFAULT 'success' CHECK (outcome IN ('success','failure','blocked')),
 details jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_company_created ON public.audit_events(company_id, created_at DESC);

ALTER TABLE public.saas_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saas_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_work_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.saas_plans TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.saas_subscriptions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.organization_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.crm_tasks TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.proposals TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.contracts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.maintenance_work_orders TO authenticated;
GRANT SELECT, UPDATE ON public.notifications TO authenticated;
GRANT SELECT, INSERT ON public.audit_events TO authenticated;
GRANT ALL ON public.saas_plans, public.saas_subscriptions, public.organization_settings, public.crm_tasks, public.proposals, public.contracts, public.maintenance_work_orders, public.notifications, public.audit_events TO service_role;
REVOKE ALL ON public.saas_plans, public.saas_subscriptions, public.organization_settings, public.crm_tasks, public.proposals, public.contracts, public.maintenance_work_orders, public.notifications, public.audit_events FROM anon;
REVOKE UPDATE, DELETE, TRUNCATE ON public.audit_events FROM anon, authenticated;

CREATE POLICY saas_plans_read_active ON public.saas_plans FOR SELECT TO authenticated USING (is_active OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'));
CREATE POLICY saas_plans_platform_manage ON public.saas_plans FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin')) WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'));
CREATE POLICY saas_subscriptions_read_own_or_platform ON public.saas_subscriptions FOR SELECT TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'));
CREATE POLICY saas_subscriptions_platform_manage ON public.saas_subscriptions FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin')) WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'));
CREATE POLICY org_settings_read_company ON public.organization_settings FOR SELECT TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())));
CREATE POLICY org_settings_manage_admins ON public.organization_settings FOR ALL TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager')) WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager'));
CREATE POLICY crm_tasks_company_read ON public.crm_tasks FOR SELECT TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial'));
CREATE POLICY crm_tasks_company_write ON public.crm_tasks FOR ALL TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial')) WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial'));
CREATE POLICY proposals_company_read ON public.proposals FOR SELECT TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial','financial'));
CREATE POLICY proposals_company_write ON public.proposals FOR ALL TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial')) WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial'));
CREATE POLICY contracts_company_read ON public.contracts FOR SELECT TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial','financial'));
CREATE POLICY contracts_company_write ON public.contracts FOR ALL TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial','financial')) WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial','financial'));
CREATE POLICY work_orders_company_read ON public.maintenance_work_orders FOR SELECT TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator','support'));
CREATE POLICY work_orders_company_write ON public.maintenance_work_orders FOR ALL TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator')) WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator'));
CREATE POLICY notifications_read_recipient_or_admin ON public.notifications FOR SELECT TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (recipient_user_id=(SELECT auth.uid()) OR (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager')));
CREATE POLICY notifications_update_recipient ON public.notifications FOR UPDATE TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND recipient_user_id=(SELECT auth.uid())) WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND recipient_user_id=(SELECT auth.uid()));
CREATE POLICY audit_events_read_admins ON public.audit_events FOR SELECT TO authenticated USING ((company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager')) OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'));
CREATE POLICY audit_events_insert_self ON public.audit_events FOR INSERT TO authenticated WITH CHECK (actor_user_id=(SELECT auth.uid()) AND (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) OR (company_id IS NULL AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'))));

CREATE POLICY platform_admin_read_companies ON public.companies FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'));
CREATE POLICY platform_admin_insert_companies ON public.companies FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'));
CREATE POLICY platform_admin_update_companies ON public.companies FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin')) WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'));
GRANT SELECT, INSERT, UPDATE ON public.companies TO authenticated;
CREATE POLICY company_admin_read_profiles ON public.profiles FOR SELECT TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager'));

DROP POLICY IF EXISTS "company members read inverter integrations" ON public.inverter_integrations;
CREATE POLICY integration_admins_read ON public.inverter_integrations FOR SELECT TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager'));
DROP POLICY IF EXISTS "company admins manage inverter integrations" ON public.inverter_integrations;
CREATE POLICY integration_admins_manage ON public.inverter_integrations FOR ALL TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager')) WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager'));
DROP POLICY IF EXISTS "company members read inverter devices" ON public.inverter_devices;
DROP POLICY IF EXISTS "company admins manage inverter devices" ON public.inverter_devices;
CREATE POLICY devices_company_read ON public.inverter_devices FOR SELECT TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator','support'));
CREATE POLICY devices_company_manage ON public.inverter_devices FOR ALL TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator')) WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator'));

DROP POLICY IF EXISTS "company members read plant alerts" ON public.plant_alerts;
DROP POLICY IF EXISTS "company managers update plant alerts" ON public.plant_alerts;
CREATE POLICY plant_alerts_company_read ON public.plant_alerts FOR SELECT TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator','support'));
CREATE POLICY plant_alerts_company_update ON public.plant_alerts FOR UPDATE TO authenticated USING (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator')) WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator'));

DO $$
DECLARE t text; p record;
BEGIN
 FOREACH t IN ARRAY ARRAY['customers','solar_plants','generation_records','energy_bills','support_tickets','leads'] LOOP
  FOR p IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename=t LOOP
   EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I',p.policyname,t);
  END LOOP;
 END LOOP;
END $$;

CREATE POLICY customers_read_scoped ON public.customers FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND ((p.company_id=customers.company_id AND p.role IN ('platform_admin','company_admin','manager','operator','commercial','financial','support')) OR (p.role='customer' AND p.customer_id=customers.id))));
CREATE POLICY customers_insert_scoped ON public.customers FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=customers.company_id AND p.role IN ('platform_admin','company_admin','manager','commercial')));
CREATE POLICY customers_update_scoped ON public.customers FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=customers.company_id AND p.role IN ('platform_admin','company_admin','manager','commercial'))) WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=customers.company_id AND p.role IN ('platform_admin','company_admin','manager','commercial')));
CREATE POLICY customers_delete_scoped ON public.customers FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=customers.company_id AND p.role IN ('platform_admin','company_admin','manager')));

CREATE POLICY plants_read_scoped ON public.solar_plants FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND ((p.company_id=solar_plants.company_id AND p.role IN ('platform_admin','company_admin','manager','operator','commercial','financial','support')) OR (p.role='customer' AND EXISTS (SELECT 1 FROM public.customers c WHERE c.id=solar_plants.customer_id AND c.id=p.customer_id AND c.company_id=solar_plants.company_id)))));
CREATE POLICY plants_insert_scoped ON public.solar_plants FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=solar_plants.company_id AND p.role IN ('platform_admin','company_admin','manager','operator')));
CREATE POLICY plants_update_scoped ON public.solar_plants FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=solar_plants.company_id AND p.role IN ('platform_admin','company_admin','manager','operator'))) WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=solar_plants.company_id AND p.role IN ('platform_admin','company_admin','manager','operator')));
CREATE POLICY plants_delete_scoped ON public.solar_plants FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=solar_plants.company_id AND p.role IN ('platform_admin','company_admin','manager')));

CREATE POLICY generation_read_scoped ON public.generation_records FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND ((p.company_id=generation_records.company_id AND p.role IN ('platform_admin','company_admin','manager','operator','financial')) OR (p.role='customer' AND EXISTS (SELECT 1 FROM public.customers c JOIN public.solar_plants sp ON sp.customer_id=c.id WHERE c.id=p.customer_id AND sp.id=generation_records.solar_plant_id AND sp.company_id=generation_records.company_id)))));
CREATE POLICY generation_insert_scoped ON public.generation_records FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=generation_records.company_id AND p.role IN ('platform_admin','company_admin','manager','operator')));
CREATE POLICY generation_update_scoped ON public.generation_records FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=generation_records.company_id AND p.role IN ('platform_admin','company_admin','manager','operator'))) WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=generation_records.company_id AND p.role IN ('platform_admin','company_admin','manager','operator')));
CREATE POLICY generation_delete_scoped ON public.generation_records FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=generation_records.company_id AND p.role IN ('platform_admin','company_admin','manager')));

CREATE POLICY bills_read_scoped ON public.energy_bills FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND ((p.company_id=energy_bills.company_id AND p.role IN ('platform_admin','company_admin','manager','financial')) OR (p.role='customer' AND p.customer_id=energy_bills.customer_id))));
CREATE POLICY bills_insert_scoped ON public.energy_bills FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=energy_bills.company_id AND p.role IN ('platform_admin','company_admin','manager','financial')));
CREATE POLICY bills_update_scoped ON public.energy_bills FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=energy_bills.company_id AND p.role IN ('platform_admin','company_admin','manager','financial'))) WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=energy_bills.company_id AND p.role IN ('platform_admin','company_admin','manager','financial')));
CREATE POLICY bills_delete_scoped ON public.energy_bills FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=energy_bills.company_id AND p.role IN ('platform_admin','company_admin','manager')));

CREATE POLICY tickets_read_scoped ON public.support_tickets FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND ((p.company_id=support_tickets.company_id AND p.role IN ('platform_admin','company_admin','manager','operator','support')) OR (p.role='customer' AND (p.customer_id=support_tickets.customer_id OR support_tickets.created_by=p.id)))));
CREATE POLICY tickets_insert_scoped ON public.support_tickets FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND ((p.company_id=support_tickets.company_id AND p.role IN ('platform_admin','company_admin','manager','operator','support')) OR (p.role='customer' AND support_tickets.created_by=p.id AND (support_tickets.customer_id IS NULL OR support_tickets.customer_id=p.customer_id)))));
CREATE POLICY tickets_update_scoped ON public.support_tickets FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND ((p.company_id=support_tickets.company_id AND p.role IN ('platform_admin','company_admin','manager','support')) OR (p.role='customer' AND support_tickets.created_by=p.id)))) WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND ((p.company_id=support_tickets.company_id AND p.role IN ('platform_admin','company_admin','manager','support')) OR (p.role='customer' AND support_tickets.created_by=p.id))));
CREATE POLICY tickets_delete_scoped ON public.support_tickets FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=support_tickets.company_id AND p.role IN ('platform_admin','company_admin','manager')));

CREATE POLICY leads_read_scoped ON public.leads FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=leads.company_id AND p.role IN ('platform_admin','company_admin','manager','commercial')));
CREATE POLICY leads_insert_scoped ON public.leads FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=leads.company_id AND p.role IN ('platform_admin','company_admin','manager','commercial')));
CREATE POLICY leads_update_scoped ON public.leads FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=leads.company_id AND p.role IN ('platform_admin','company_admin','manager','commercial'))) WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=leads.company_id AND p.role IN ('platform_admin','company_admin','manager','commercial')));
CREATE POLICY leads_delete_scoped ON public.leads FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.company_id=leads.company_id AND p.role IN ('platform_admin','company_admin','manager')));

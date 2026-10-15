-- Split broad policies into operation-specific rules and add FK/query indexes.
DROP INDEX IF EXISTS public.idx_alerts_company_status_date;

CREATE INDEX IF NOT EXISTS idx_audit_events_actor_user ON public.audit_events(actor_user_id);
CREATE INDEX IF NOT EXISTS idx_contracts_company_created ON public.contracts(company_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_contracts_customer_id ON public.contracts(customer_id);
CREATE INDEX IF NOT EXISTS idx_contracts_solar_plant_id ON public.contracts(solar_plant_id);
CREATE INDEX IF NOT EXISTS idx_contracts_proposal_id ON public.contracts(proposal_id);
CREATE INDEX IF NOT EXISTS idx_contracts_created_by ON public.contracts(created_by);
CREATE INDEX IF NOT EXISTS idx_crm_tasks_company_due ON public.crm_tasks(company_id, due_at);
CREATE INDEX IF NOT EXISTS idx_crm_tasks_lead_id ON public.crm_tasks(lead_id);
CREATE INDEX IF NOT EXISTS idx_crm_tasks_customer_id ON public.crm_tasks(customer_id);
CREATE INDEX IF NOT EXISTS idx_crm_tasks_assigned_to ON public.crm_tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_crm_tasks_created_by ON public.crm_tasks(created_by);
CREATE INDEX IF NOT EXISTS idx_maintenance_company_scheduled ON public.maintenance_work_orders(company_id, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_maintenance_solar_plant_id ON public.maintenance_work_orders(solar_plant_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_device_id ON public.maintenance_work_orders(device_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_assigned_to ON public.maintenance_work_orders(assigned_to);
CREATE INDEX IF NOT EXISTS idx_maintenance_opened_by ON public.maintenance_work_orders(opened_by);
CREATE INDEX IF NOT EXISTS idx_notifications_company_recipient ON public.notifications(company_id, recipient_user_id);
CREATE INDEX IF NOT EXISTS idx_organization_settings_updated_by ON public.organization_settings(updated_by);
CREATE INDEX IF NOT EXISTS idx_proposals_company_created ON public.proposals(company_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_proposals_customer_id ON public.proposals(customer_id);
CREATE INDEX IF NOT EXISTS idx_proposals_lead_id ON public.proposals(lead_id);
CREATE INDEX IF NOT EXISTS idx_proposals_created_by ON public.proposals(created_by);
CREATE INDEX IF NOT EXISTS idx_saas_subscriptions_plan_id ON public.saas_subscriptions(plan_id);

DROP POLICY IF EXISTS platform_admin_read_companies ON public.companies;
DROP POLICY IF EXISTS "company members can read their company" ON public.companies;
CREATE POLICY companies_read_scoped ON public.companies FOR SELECT TO authenticated USING (
 id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin')
);

DROP POLICY IF EXISTS company_admin_read_profiles ON public.profiles;
DROP POLICY IF EXISTS "users can read their own profile" ON public.profiles;
CREATE POLICY profiles_read_self_and_team ON public.profiles FOR SELECT TO authenticated USING (
 id=(SELECT auth.uid())
 OR (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
     AND EXISTS (SELECT 1 FROM public.profiles actor WHERE actor.id=(SELECT auth.uid()) AND actor.role IN ('platform_admin','company_admin','manager')))
);

DROP POLICY IF EXISTS saas_plans_platform_manage ON public.saas_plans;
CREATE POLICY saas_plans_platform_insert ON public.saas_plans FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'));
CREATE POLICY saas_plans_platform_update ON public.saas_plans FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'))
WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'));
CREATE POLICY saas_plans_platform_delete ON public.saas_plans FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'));

DROP POLICY IF EXISTS saas_subscriptions_platform_manage ON public.saas_subscriptions;
CREATE POLICY saas_subscriptions_platform_insert ON public.saas_subscriptions FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'));
CREATE POLICY saas_subscriptions_platform_update ON public.saas_subscriptions FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'))
WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'));
CREATE POLICY saas_subscriptions_platform_delete ON public.saas_subscriptions FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='platform_admin'));

DROP POLICY IF EXISTS org_settings_manage_admins ON public.organization_settings;
CREATE POLICY org_settings_insert_admins ON public.organization_settings FOR INSERT TO authenticated WITH CHECK (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager'));
CREATE POLICY org_settings_update_admins ON public.organization_settings FOR UPDATE TO authenticated USING (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager'))
WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager'));
CREATE POLICY org_settings_delete_admins ON public.organization_settings FOR DELETE TO authenticated USING (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager'));

DROP POLICY IF EXISTS crm_tasks_company_write ON public.crm_tasks;
CREATE POLICY crm_tasks_company_insert ON public.crm_tasks FOR INSERT TO authenticated WITH CHECK (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial'));
CREATE POLICY crm_tasks_company_update ON public.crm_tasks FOR UPDATE TO authenticated USING (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial'))
WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial'));
CREATE POLICY crm_tasks_company_delete ON public.crm_tasks FOR DELETE TO authenticated USING (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial'));

DROP POLICY IF EXISTS proposals_company_write ON public.proposals;
CREATE POLICY proposals_company_insert ON public.proposals FOR INSERT TO authenticated WITH CHECK (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial'));
CREATE POLICY proposals_company_update ON public.proposals FOR UPDATE TO authenticated USING (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial'))
WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial'));
CREATE POLICY proposals_company_delete ON public.proposals FOR DELETE TO authenticated USING (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial'));

DROP POLICY IF EXISTS contracts_company_write ON public.contracts;
CREATE POLICY contracts_company_insert ON public.contracts FOR INSERT TO authenticated WITH CHECK (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial','financial'));
CREATE POLICY contracts_company_update ON public.contracts FOR UPDATE TO authenticated USING (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial','financial'))
WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial','financial'));
CREATE POLICY contracts_company_delete ON public.contracts FOR DELETE TO authenticated USING (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','commercial','financial'));

DROP POLICY IF EXISTS work_orders_company_write ON public.maintenance_work_orders;
CREATE POLICY work_orders_company_insert ON public.maintenance_work_orders FOR INSERT TO authenticated WITH CHECK (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator'));
CREATE POLICY work_orders_company_update ON public.maintenance_work_orders FOR UPDATE TO authenticated USING (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator'))
WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator'));
CREATE POLICY work_orders_company_delete ON public.maintenance_work_orders FOR DELETE TO authenticated USING (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator'));

DROP POLICY IF EXISTS integration_admins_manage ON public.inverter_integrations;
CREATE POLICY integration_admins_insert ON public.inverter_integrations FOR INSERT TO authenticated WITH CHECK (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager'));
CREATE POLICY integration_admins_update ON public.inverter_integrations FOR UPDATE TO authenticated USING (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager'))
WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager'));
CREATE POLICY integration_admins_delete ON public.inverter_integrations FOR DELETE TO authenticated USING (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager'));

DROP POLICY IF EXISTS devices_company_manage ON public.inverter_devices;
CREATE POLICY devices_company_insert ON public.inverter_devices FOR INSERT TO authenticated WITH CHECK (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator'));
CREATE POLICY devices_company_update ON public.inverter_devices FOR UPDATE TO authenticated USING (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator'))
WITH CHECK (company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator'));
CREATE POLICY devices_company_delete ON public.inverter_devices FOR DELETE TO authenticated USING (
 company_id=(SELECT p.company_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
 AND (SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid())) IN ('platform_admin','company_admin','manager','operator'));

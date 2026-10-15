CREATE OR REPLACE FUNCTION public.company_access_active(target_company_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
  SELECT
    EXISTS (
      SELECT 1
      FROM public.profiles actor
      WHERE actor.id = auth.uid()
        AND (actor.company_id = target_company_id OR actor.role = 'platform_admin')
    )
    AND EXISTS (
      SELECT 1 FROM public.companies c
      WHERE c.id = target_company_id AND c.status IN ('active','trial')
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.saas_subscriptions s
      WHERE s.company_id = target_company_id
        AND s.id = (
          SELECT s2.id FROM public.saas_subscriptions s2
          WHERE s2.company_id = target_company_id
          ORDER BY s2.created_at DESC LIMIT 1
        )
        AND s.status IN ('suspended','canceled')
    );
$$;
REVOKE ALL ON FUNCTION public.company_access_active(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.company_access_active(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.enforce_plan_limits()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_company_id uuid;
  v_plan_id uuid;
  v_subscription_status text;
  v_limit integer;
  v_used bigint;
BEGIN
  v_company_id := NEW.company_id;
  IF v_company_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT s.plan_id, s.status
    INTO v_plan_id, v_subscription_status
  FROM public.saas_subscriptions s
  WHERE s.company_id = v_company_id
  ORDER BY s.created_at DESC
  LIMIT 1;

  IF v_subscription_status IN ('suspended','canceled') THEN
    RAISE EXCEPTION 'A assinatura desta empresa está suspensa ou encerrada.'
      USING ERRCODE = 'P0001';
  END IF;
  IF v_plan_id IS NULL OR v_subscription_status NOT IN ('active','trial','past_due') THEN
    RETURN NEW;
  END IF;

  IF TG_TABLE_NAME = 'profiles' THEN
    SELECT max_users INTO v_limit FROM public.saas_plans WHERE id = v_plan_id;
    IF v_limit IS NOT NULL THEN
      SELECT count(*) INTO v_used FROM public.profiles
      WHERE company_id = v_company_id AND id <> NEW.id;
      IF v_used >= v_limit THEN
        RAISE EXCEPTION 'Limite do plano atingido: máximo de % usuários.', v_limit USING ERRCODE = 'P0001';
      END IF;
    END IF;
  ELSIF TG_TABLE_NAME = 'customers' THEN
    SELECT max_customers INTO v_limit FROM public.saas_plans WHERE id = v_plan_id;
    IF v_limit IS NOT NULL THEN
      SELECT count(*) INTO v_used FROM public.customers
      WHERE company_id = v_company_id AND id <> NEW.id;
      IF v_used >= v_limit THEN
        RAISE EXCEPTION 'Limite do plano atingido: máximo de % clientes.', v_limit USING ERRCODE = 'P0001';
      END IF;
    END IF;
  ELSIF TG_TABLE_NAME = 'solar_plants' THEN
    SELECT max_plants INTO v_limit FROM public.saas_plans WHERE id = v_plan_id;
    IF v_limit IS NOT NULL THEN
      SELECT count(*) INTO v_used FROM public.solar_plants
      WHERE company_id = v_company_id AND id <> NEW.id;
      IF v_used >= v_limit THEN
        RAISE EXCEPTION 'Limite do plano atingido: máximo de % usinas.', v_limit USING ERRCODE = 'P0001';
      END IF;
    END IF;
  ELSIF TG_TABLE_NAME = 'inverter_integrations' THEN
    SELECT max_integrations INTO v_limit FROM public.saas_plans WHERE id = v_plan_id;
    IF v_limit IS NOT NULL THEN
      SELECT max_integrations INTO v_limit FROM public.saas_plans WHERE id = v_plan_id;
      SELECT count(*) INTO v_used FROM public.inverter_integrations
      WHERE company_id = v_company_id AND id <> NEW.id;
      IF v_used >= v_limit THEN
        RAISE EXCEPTION 'Limite do plano atingido: máximo de % integrações.', v_limit USING ERRCODE = 'P0001';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_plan_limits() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS enforce_profile_plan_limit ON public.profiles;
CREATE TRIGGER enforce_profile_plan_limit BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_limits();
DROP TRIGGER IF EXISTS enforce_customer_plan_limit ON public.customers;
CREATE TRIGGER enforce_customer_plan_limit BEFORE INSERT OR UPDATE ON public.customers
FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_limits();
DROP TRIGGER IF EXISTS enforce_plant_plan_limit ON public.solar_plants;
CREATE TRIGGER enforce_plant_plan_limit BEFORE INSERT OR UPDATE ON public.solar_plants
FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_limits();
DROP TRIGGER IF EXISTS enforce_integration_plan_limit ON public.inverter_integrations;
CREATE TRIGGER enforce_integration_plan_limit BEFORE INSERT OR UPDATE ON public.inverter_integrations
FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_limits();

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'customers','solar_plants','generation_records','energy_bills','support_tickets','leads',
    'inverter_integrations','inverter_devices','inverter_telemetry','integration_sync_logs',
    'plant_alerts','crm_tasks','proposals','contracts','maintenance_work_orders',
    'notifications','organization_settings'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS company_subscription_guard ON public.%I', t);
    EXECUTE format(
      'CREATE POLICY company_subscription_guard ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (public.company_access_active(company_id)) WITH CHECK (public.company_access_active(company_id))',
      t
    );
  END LOOP;
END $$;

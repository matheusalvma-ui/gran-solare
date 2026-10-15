-- Keep the helper callable by authenticated RLS policies, but execute reads using caller RLS.
CREATE OR REPLACE FUNCTION public.company_access_active(target_company_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = pg_catalog, public, pg_temp
AS $$
  SELECT
    EXISTS (
      SELECT 1 FROM public.profiles actor
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

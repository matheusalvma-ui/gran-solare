-- Avoid recursive RLS evaluation when an authenticated user reads profiles.
CREATE OR REPLACE FUNCTION public.can_read_profile(target_profile_id uuid, target_company_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT
    target_profile_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.profiles actor
      WHERE actor.id = auth.uid()
        AND (
          actor.role = 'platform_admin'
          OR (
            actor.company_id = target_company_id
            AND actor.role IN ('company_admin', 'manager')
          )
        )
    );
$$;

REVOKE ALL ON FUNCTION public.can_read_profile(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_read_profile(uuid, uuid) TO authenticated;

DROP POLICY IF EXISTS profiles_read_self_and_team ON public.profiles;
DROP POLICY IF EXISTS company_admin_read_profiles ON public.profiles;

CREATE POLICY profiles_read_self_and_team
ON public.profiles
FOR SELECT
TO authenticated
USING (public.can_read_profile(id, company_id));

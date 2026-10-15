-- Customer-portal access must be scoped by both linked customer and company.
DROP POLICY IF EXISTS customers_read_scoped ON public.customers;
CREATE POLICY customers_read_scoped ON public.customers FOR SELECT TO authenticated USING (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND (
  (p.company_id=customers.company_id AND p.role IN ('platform_admin','company_admin','manager','operator','commercial','financial','support'))
  OR (p.role='customer' AND p.company_id=customers.company_id AND p.customer_id=customers.id)
 ))
);

DROP POLICY IF EXISTS plants_read_scoped ON public.solar_plants;
CREATE POLICY plants_read_scoped ON public.solar_plants FOR SELECT TO authenticated USING (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND (
  (p.company_id=solar_plants.company_id AND p.role IN ('platform_admin','company_admin','manager','operator','commercial','financial','support'))
  OR (p.role='customer' AND p.company_id=solar_plants.company_id
      AND EXISTS (SELECT 1 FROM public.customers c WHERE c.id=p.customer_id AND c.id=solar_plants.customer_id AND c.company_id=solar_plants.company_id))
 ))
);

DROP POLICY IF EXISTS generation_read_scoped ON public.generation_records;
CREATE POLICY generation_read_scoped ON public.generation_records FOR SELECT TO authenticated USING (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND (
  (p.company_id=generation_records.company_id AND p.role IN ('platform_admin','company_admin','manager','operator','financial'))
  OR (p.role='customer' AND p.company_id=generation_records.company_id
      AND EXISTS (SELECT 1 FROM public.customers c JOIN public.solar_plants sp ON sp.customer_id=c.id
                  WHERE c.id=p.customer_id AND sp.id=generation_records.solar_plant_id AND sp.company_id=generation_records.company_id AND c.company_id=generation_records.company_id))
 ))
);

DROP POLICY IF EXISTS bills_read_scoped ON public.energy_bills;
CREATE POLICY bills_read_scoped ON public.energy_bills FOR SELECT TO authenticated USING (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND (
  (p.company_id=energy_bills.company_id AND p.role IN ('platform_admin','company_admin','manager','financial'))
  OR (p.role='customer' AND p.company_id=energy_bills.company_id AND p.customer_id=energy_bills.customer_id)
 ))
);

DROP POLICY IF EXISTS tickets_read_scoped ON public.support_tickets;
CREATE POLICY tickets_read_scoped ON public.support_tickets FOR SELECT TO authenticated USING (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND (
  (p.company_id=support_tickets.company_id AND p.role IN ('platform_admin','company_admin','manager','operator','support'))
  OR (p.role='customer' AND p.company_id=support_tickets.company_id
      AND (p.customer_id=support_tickets.customer_id OR support_tickets.created_by=p.id))
 ))
);

DROP POLICY IF EXISTS tickets_insert_scoped ON public.support_tickets;
CREATE POLICY tickets_insert_scoped ON public.support_tickets FOR INSERT TO authenticated WITH CHECK (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND (
  (p.company_id=support_tickets.company_id AND p.role IN ('platform_admin','company_admin','manager','operator','support'))
  OR (p.role='customer' AND p.company_id=support_tickets.company_id AND support_tickets.created_by=p.id
      AND (support_tickets.customer_id IS NULL OR support_tickets.customer_id=p.customer_id))
 ))
);

DROP POLICY IF EXISTS tickets_update_scoped ON public.support_tickets;
CREATE POLICY tickets_update_scoped ON public.support_tickets FOR UPDATE TO authenticated USING (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND (
  (p.company_id=support_tickets.company_id AND p.role IN ('platform_admin','company_admin','manager','support'))
  OR (p.role='customer' AND p.company_id=support_tickets.company_id AND support_tickets.created_by=p.id)
 ))
)
WITH CHECK (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND (
  (p.company_id=support_tickets.company_id AND p.role IN ('platform_admin','company_admin','manager','support'))
  OR (p.role='customer' AND p.company_id=support_tickets.company_id AND support_tickets.created_by=p.id)
 ))
);

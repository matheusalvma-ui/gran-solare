ALTER TABLE public.leads DROP CONSTRAINT IF EXISTS leads_stage_check;
ALTER TABLE public.leads ADD CONSTRAINT leads_stage_check
CHECK (stage = ANY (ARRAY['new','first_contact','contacted','qualified','meeting','diagnosis','proposal','negotiation','won','lost']));
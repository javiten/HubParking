-- Run once in the Supabase SQL editor before using Delete Card.
ALTER TABLE public.parking_history
ADD COLUMN IF NOT EXISTS event_type text NOT NULL DEFAULT 'pickup'
CHECK (event_type IN ('pickup', 'deleted'));

-- SECURITY INVOKER preserves the caller's existing table permissions / RLS.
-- Insertion and deletion succeed or fail together, avoiding lost cards.
CREATE OR REPLACE FUNCTION public.delete_parking_card(p_id uuid, p_actor text)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    affected integer;
BEGIN
    IF p_actor IS NULL OR length(trim(p_actor)) = 0 THEN
        RAISE EXCEPTION 'A team member is required';
    END IF;
    PERFORM id FROM public.parked_vehicles WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'This parking card no longer exists. Refresh the list.';
    END IF;
    INSERT INTO public.parking_history
        (id, vehicle_id, airport_name, garage_name, parking_spot, date_parked,
         photo, added_by_id, added_by, air_tag, notes, created_at, event_type)
    SELECT id, vehicle_id, airport_name, garage_name, parking_spot, date_parked,
           photo, NULL, trim(p_actor), air_tag, notes, now(), 'deleted'
    FROM public.parked_vehicles WHERE id = p_id;
    DELETE FROM public.parked_vehicles WHERE id = p_id;
    GET DIAGNOSTICS affected = ROW_COUNT;
    IF affected <> 1 THEN
        RAISE EXCEPTION 'Could not remove the parking card';
    END IF;
END;
$$;

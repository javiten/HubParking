-- Run once in the Supabase SQL editor before using Remove Vehicle.
-- Existing rows remain active; history and parking foreign keys stay unchanged.
ALTER TABLE public.vehicles
ADD COLUMN IF NOT EXISTS is_archived boolean NOT NULL DEFAULT false;

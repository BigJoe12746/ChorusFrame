-- ChorusFrame — artist brand kit
-- Run in the Supabase SQL Editor AFTER 006_billing.sql. Safe to re-run.
--
-- "Artist identity memory: saved fonts, colours, cover treatments and approved
-- visual language" is listed in the business plan as defensible
-- differentiation. This is the first piece of it: a kit belongs to the artist,
-- not to a song, so their fifth release looks like their first.

alter table public.profiles
  -- Hex colours, validated in the API before they reach a style attribute
  add column if not exists brand_primary text,
  add column if not exists brand_secondary text,
  -- sans | serif | mono — families that exist in the worker image, so a kit
  -- never silently falls back to a different face on the render host
  add column if not exists brand_font text,
  add column if not exists default_vibe text;

comment on column public.profiles.brand_primary is
  'Accent colour (#rrggbb). Overrides both the vibe palette and cover-art extraction.';

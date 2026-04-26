-- Ajusta registros antigos de WaterLog em -3 horas.
-- Execute no SQL Editor do Supabase uma única vez.

update "WaterLog"
set "date" = "date" - interval '3 hours'
where "date" is not null;

-- No va pero sigue en el amigo secreto: entrega y recibe su regalo después (Victor, 2026-11-22).
alter table social_participacion add column if not exists entrega_despues boolean not null default false;

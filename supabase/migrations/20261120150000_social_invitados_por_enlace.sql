-- +1 por enlace (Victor, 2026-11-20): se invita con un enlace y el +1 escribe su nombre al entrar.
alter table public.social_invitados add column if not exists entro_en timestamptz;
comment on column public.social_invitados.entro_en is 'Cuándo el +1 abrió su enlace y escribió su nombre (null = enlace enviado, todavía no entra)';
comment on column public.social_invitados.nombre is 'Nombre del +1; vacío hasta que abre su enlace y lo escribe';
update public.social_invitados set entro_en = created_at where entro_en is null and nombre <> '';

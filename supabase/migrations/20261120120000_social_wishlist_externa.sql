-- Link opcional a una wishlist externa (Wishdeck, Amazon u otra) en las pistas del amigo secreto (Victor, 2026-11-20).
alter table public.social_perfiles add column if not exists wishlist_link text;
comment on column public.social_perfiles.wishlist_link is 'Link opcional a una wishlist externa (Wishdeck, Amazon u otra), la ve quien le regala';

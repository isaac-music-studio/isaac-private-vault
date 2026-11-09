-- ISAAC PRIVATE VAULT V3
-- Run once in Supabase SQL Editor. The browser must use only the publishable/anon key.
-- RLS ensures each signed-in user can access only their own vault rows.

create table if not exists public.vaults (
  user_id uuid primary key references auth.users(id) on delete cascade,
  vault_id uuid not null unique,
  salt text not null,
  kdf_iterations integer not null check (kdf_iterations between 310000 and 1000000),
  schema_version integer not null default 3,
  created_at timestamptz not null default now()
);

create table if not exists public.vault_records (
  vault_id uuid not null references public.vaults(vault_id) on delete cascade,
  record_id text not null check (length(record_id) <= 100),
  kind text not null check (kind in ('note', 'filemeta', 'file')),
  payload jsonb not null check (jsonb_typeof(payload) = 'object' and payload ? 'iv' and payload ? 'data'),
  updated_at timestamptz not null default now(),
  primary key (vault_id, record_id),
  check (
    (kind = 'note' and record_id like 'note:%') or
    (kind = 'filemeta' and record_id like 'filemeta:%') or
    (kind = 'file' and record_id like 'file:%')
  )
);

alter table public.vaults enable row level security;
alter table public.vault_records enable row level security;

revoke all on public.vaults from anon, authenticated;
revoke all on public.vault_records from anon, authenticated;
grant select, insert on public.vaults to authenticated;
grant select, insert, update on public.vault_records to authenticated;

drop policy if exists "vault owner can read own vault" on public.vaults;
create policy "vault owner can read own vault"
  on public.vaults for select to authenticated
  using ((select auth.uid()) is not null and user_id = (select auth.uid()));

drop policy if exists "vault owner can create own vault" on public.vaults;
create policy "vault owner can create own vault"
  on public.vaults for insert to authenticated
  with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

drop policy if exists "vault owner can read own records" on public.vault_records;
create policy "vault owner can read own records"
  on public.vault_records for select to authenticated
  using (exists (
    select 1 from public.vaults v
    where v.vault_id = vault_records.vault_id
      and v.user_id = (select auth.uid())
  ));

drop policy if exists "vault owner can create own records" on public.vault_records;
create policy "vault owner can create own records"
  on public.vault_records for insert to authenticated
  with check (exists (
    select 1 from public.vaults v
    where v.vault_id = vault_records.vault_id
      and v.user_id = (select auth.uid())
  ));

drop policy if exists "vault owner can update own records" on public.vault_records;
create policy "vault owner can update own records"
  on public.vault_records for update to authenticated
  using (exists (
    select 1 from public.vaults v
    where v.vault_id = vault_records.vault_id
      and v.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.vaults v
    where v.vault_id = vault_records.vault_id
      and v.user_id = (select auth.uid())
  ));

-- Conditional timestamp upsert prevents a slower/offline device from replacing a newer edit.
-- SECURITY INVOKER is the default; RLS is enforced for the calling authenticated user.
create or replace function public.upsert_vault_record(
  p_vault_id uuid,
  p_record_id text,
  p_kind text,
  p_payload jsonb,
  p_updated_at timestamptz
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  insert into public.vault_records (vault_id, record_id, kind, payload, updated_at)
  values (p_vault_id, p_record_id, p_kind, p_payload, p_updated_at)
  on conflict (vault_id, record_id) do update
    set kind = excluded.kind,
        payload = excluded.payload,
        updated_at = excluded.updated_at
    where excluded.updated_at >= public.vault_records.updated_at;
end;
$$;

revoke all on function public.upsert_vault_record(uuid, text, text, jsonb, timestamptz) from public;
revoke all on function public.upsert_vault_record(uuid, text, text, jsonb, timestamptz) from anon;
grant execute on function public.upsert_vault_record(uuid, text, text, jsonb, timestamptz) to authenticated;

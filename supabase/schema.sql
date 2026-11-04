-- LINKUP database schema. This file mirrors the migrations applied to the LINKUP Supabase project.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Guest',
  avatar_url text,
  created_at timestamptz not null default now()
);
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  name text,
  invite_code text not null unique default encode(gen_random_bytes(6), 'hex'),
  is_group boolean not null default false,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  nickname text,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  content text,
  kind text not null default 'text' check (kind in ('text','image','audio','system')),
  media_path text,
  created_at timestamptz not null default now()
);
create table if not exists public.game_sessions (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  game text not null default 'tic_tac_toe',
  state jsonb not null default '{"board":[null,null,null,null,null,null,null,null,null],"turn":0,"status":"playing"}'::jsonb,
  updated_at timestamptz not null default now(),
  unique (conversation_id, game)
);

alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.game_sessions enable row level security;

create or replace function public.is_conversation_member(_conversation_id uuid, _user_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.conversation_members where conversation_id = _conversation_id and user_id = _user_id); $$;
create or replace function public.is_conversation_creator(_conversation_id uuid, _user_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.conversations where id = _conversation_id and created_by = _user_id); $$;
create or replace function public.join_conversation_by_code(_code text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare target_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select id into target_id from public.conversations where invite_code = _code;
  if target_id is null then raise exception 'Invite not found'; end if;
  insert into public.conversation_members (conversation_id, user_id) values (target_id, auth.uid()) on conflict do nothing;
  return target_id;
end;
$$;
grant execute on function public.join_conversation_by_code(text) to authenticated;

drop policy if exists "profiles readable by signed in guests" on public.profiles;
create policy "profiles readable by signed in guests" on public.profiles for select to authenticated using (true);
drop policy if exists "guests create own profile" on public.profiles;
create policy "guests create own profile" on public.profiles for insert to authenticated with check (id = auth.uid());
drop policy if exists "guests update own profile" on public.profiles;
create policy "guests update own profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "members read conversations" on public.conversations;
create policy "members read conversations" on public.conversations for select to authenticated using (public.is_conversation_member(id, auth.uid()));
drop policy if exists "guests create conversations" on public.conversations;
create policy "guests create conversations" on public.conversations for insert to authenticated with check (created_by = auth.uid());

drop policy if exists "members read membership" on public.conversation_members;
create policy "members read membership" on public.conversation_members for select to authenticated using (public.is_conversation_member(conversation_id, auth.uid()));
drop policy if exists "guests join conversations" on public.conversation_members;
create policy "guests join conversations" on public.conversation_members for insert to authenticated with check (user_id = auth.uid() and public.is_conversation_creator(conversation_id, auth.uid()));

drop policy if exists "members read messages" on public.messages;
create policy "members read messages" on public.messages for select to authenticated using (public.is_conversation_member(conversation_id, auth.uid()));
drop policy if exists "members send messages" on public.messages;
create policy "members send messages" on public.messages for insert to authenticated with check (sender_id = auth.uid() and public.is_conversation_member(conversation_id, auth.uid()));
drop policy if exists "senders delete own messages" on public.messages;
create policy "senders delete own messages" on public.messages for delete to authenticated using (sender_id = auth.uid() and public.is_conversation_member(conversation_id, auth.uid()));

drop policy if exists "members read game sessions" on public.game_sessions;
create policy "members read game sessions" on public.game_sessions for select to authenticated using (public.is_conversation_member(conversation_id, auth.uid()));
drop policy if exists "members create game sessions" on public.game_sessions;
create policy "members create game sessions" on public.game_sessions for insert to authenticated with check (public.is_conversation_member(conversation_id, auth.uid()));
drop policy if exists "members update game sessions" on public.game_sessions;
create policy "members update game sessions" on public.game_sessions for update to authenticated using (public.is_conversation_member(conversation_id, auth.uid())) with check (public.is_conversation_member(conversation_id, auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-media','chat-media',false,12582912,array['image/jpeg','image/png','image/webp','image/gif','audio/webm','audio/mp4','audio/mpeg','audio/ogg'])
on conflict (id) do nothing;
drop policy if exists "conversation members read media" on storage.objects;
create policy "conversation members read media" on storage.objects for select to authenticated using (
 bucket_id='chat-media' and exists (select 1 from public.conversation_members m where m.conversation_id::text=(storage.foldername(name))[1] and m.user_id=auth.uid())
);
drop policy if exists "conversation members upload media" on storage.objects;
create policy "conversation members upload media" on storage.objects for insert to authenticated with check (
 bucket_id='chat-media' and exists (select 1 from public.conversation_members m where m.conversation_id::text=(storage.foldername(name))[1] and m.user_id=auth.uid())
);
drop policy if exists "owners delete media" on storage.objects;
create policy "owners delete media" on storage.objects for delete to authenticated using (bucket_id='chat-media' and owner=auth.uid());

do $$
begin
 if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='messages') then alter publication supabase_realtime add table public.messages; end if;
 if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='game_sessions') then alter publication supabase_realtime add table public.game_sessions; end if;
end $$;


-- Realtime broadcast access for private, conversation-scoped call signaling.
drop policy if exists "LINKUP members can receive call broadcasts" on realtime.messages;
create policy "LINKUP members can receive call broadcasts" on realtime.messages for select to authenticated
using (public.is_conversation_member(substring(realtime.topic() from 6)::uuid, auth.uid()));
drop policy if exists "LINKUP members can send call broadcasts" on realtime.messages;
create policy "LINKUP members can send call broadcasts" on realtime.messages for insert to authenticated
with check (public.is_conversation_member(substring(realtime.topic() from 6)::uuid, auth.uid()));

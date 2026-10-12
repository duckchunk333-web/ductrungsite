-- StudyRoom schema for Supabase. Run the whole file in SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Học viên',
  created_at timestamptz not null default now()
);
create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 60),
  description text not null default '' check (char_length(description) <= 240),
  code text not null unique check (char_length(code) between 6 and 12),
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.room_members (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key(room_id,user_id)
);
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 4000),
  reply_to uuid references public.messages(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null check (emoji in ('👍','❤️','😂','🎯','👏','😮','😢')),
  created_at timestamptz not null default now(),
  unique(message_id,user_id,emoji)
);
create table if not exists public.room_files (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  file_name text not null,
  storage_path text not null unique,
  file_size bigint not null check(file_size >= 0 and file_size <= 26214400),
  mime_type text not null default 'application/octet-stream',
  uploader_name text not null default 'Học viên',
  created_at timestamptz not null default now()
);
create index if not exists room_members_user_idx on public.room_members(user_id);
create index if not exists messages_room_created_idx on public.messages(room_id,created_at);
create index if not exists room_files_room_created_idx on public.room_files(room_id,created_at desc);
create index if not exists rooms_code_idx on public.rooms(code);

create or replace function public.is_room_member(rid uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.room_members where room_id=rid and user_id=auth.uid()); $$;
create or replace function public.is_room_owner(rid uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.room_members where room_id=rid and user_id=auth.uid() and role='owner'); $$;
create or replace function public.can_access_file_path(obj_name text)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.room_files f where f.storage_path=obj_name and public.is_room_member(f.room_id)); $$;

alter table public.profiles enable row level security;
alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.messages enable row level security;
alter table public.message_reactions enable row level security;
alter table public.room_files enable row level security;

drop policy if exists "profile visible to self or shared room members" on public.profiles;
create policy "profile visible to self or shared room members" on public.profiles for select to authenticated using (
 id=auth.uid() or exists(select 1 from public.room_members mine join public.room_members theirs on mine.room_id=theirs.room_id where mine.user_id=auth.uid() and theirs.user_id=profiles.id)
);
drop policy if exists "profile insert self" on public.profiles;
create policy "profile insert self" on public.profiles for insert to authenticated with check(id=auth.uid());
drop policy if exists "profile update self" on public.profiles;
create policy "profile update self" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());

drop policy if exists "rooms visible to members or lookup code" on public.rooms;
create policy "rooms visible to members or lookup code" on public.rooms for select to authenticated using(public.is_room_member(id) or true);
drop policy if exists "signed in create room" on public.rooms;
create policy "signed in create room" on public.rooms for insert to authenticated with check(owner_id=auth.uid());
drop policy if exists "owner update room" on public.rooms;
create policy "owner update room" on public.rooms for update to authenticated using(public.is_room_owner(id)) with check(public.is_room_owner(id));
drop policy if exists "owner delete room" on public.rooms;
create policy "owner delete room" on public.rooms for delete to authenticated using(public.is_room_owner(id));

drop policy if exists "members visible in same room" on public.room_members;
create policy "members visible in same room" on public.room_members for select to authenticated using(public.is_room_member(room_id) or user_id=auth.uid());
drop policy if exists "join self as member" on public.room_members;
create policy "join self as member" on public.room_members for insert to authenticated with check(user_id=auth.uid() and role='member');
drop policy if exists "owner can add room members" on public.room_members;
create policy "owner can add room members" on public.room_members for insert to authenticated with check((public.is_room_owner(room_id) and role in ('member','owner')) or (user_id=auth.uid() and role='owner' and exists(select 1 from public.rooms r where r.id=room_id and r.owner_id=auth.uid())));
drop policy if exists "self leave or owner remove member" on public.room_members;
create policy "self leave or owner remove member" on public.room_members for delete to authenticated using(user_id=auth.uid() or public.is_room_owner(room_id));
drop policy if exists "owner change membership role" on public.room_members;
create policy "owner change membership role" on public.room_members for update to authenticated using(public.is_room_owner(room_id)) with check(public.is_room_owner(room_id));

drop policy if exists "messages visible to room members" on public.messages;
create policy "messages visible to room members" on public.messages for select to authenticated using(public.is_room_member(room_id));
drop policy if exists "members send messages" on public.messages;
create policy "members send messages" on public.messages for insert to authenticated with check(user_id=auth.uid() and public.is_room_member(room_id));
drop policy if exists "author or owner delete messages" on public.messages;
create policy "author or owner delete messages" on public.messages for delete to authenticated using(user_id=auth.uid() or public.is_room_owner(room_id));

drop policy if exists "reactions visible to room members" on public.message_reactions;
create policy "reactions visible to room members" on public.message_reactions for select to authenticated using(exists(select 1 from public.messages m where m.id=message_id and public.is_room_member(m.room_id)));
drop policy if exists "member add own reaction" on public.message_reactions;
create policy "member add own reaction" on public.message_reactions for insert to authenticated with check(user_id=auth.uid() and exists(select 1 from public.messages m where m.id=message_id and public.is_room_member(m.room_id)));
drop policy if exists "member remove own reaction or owner" on public.message_reactions;
create policy "member remove own reaction or owner" on public.message_reactions for delete to authenticated using(user_id=auth.uid() or exists(select 1 from public.messages m where m.id=message_id and public.is_room_owner(m.room_id)));

drop policy if exists "files visible to room members" on public.room_files;
create policy "files visible to room members" on public.room_files for select to authenticated using(public.is_room_member(room_id));
drop policy if exists "members upload files" on public.room_files;
create policy "members upload files" on public.room_files for insert to authenticated with check(user_id=auth.uid() and public.is_room_member(room_id));
drop policy if exists "uploader or owner delete files" on public.room_files;
create policy "uploader or owner delete files" on public.room_files for delete to authenticated using(user_id=auth.uid() or public.is_room_owner(room_id));

-- Private Storage bucket. Max size 25 MB. Only room members can access objects
-- after a room_files row exists; the browser creates signed URLs for downloads.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('study-files','study-files',false,26214400,null)
on conflict(id) do update set public=false,file_size_limit=26214400;

drop policy if exists "room members upload study files" on storage.objects;
create policy "room members upload study files" on storage.objects for insert to authenticated
with check(bucket_id='study-files' and split_part(name,'/',1) ~* '^[0-9a-f-]{36}$' and public.is_room_member(split_part(name,'/',1)::uuid));
drop policy if exists "room members read study files" on storage.objects;
create policy "room members read study files" on storage.objects for select to authenticated
using(bucket_id='study-files' and public.can_access_file_path(name));
drop policy if exists "uploader or room owner remove storage files" on storage.objects;
create policy "uploader or room owner remove storage files" on storage.objects for delete to authenticated
using(bucket_id='study-files' and (exists(select 1 from public.room_files f where f.storage_path=name and f.user_id=auth.uid()) or exists(select 1 from public.room_files f where f.storage_path=name and public.is_room_owner(f.room_id))));

-- Realtime events for chat and files.
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.message_reactions;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.room_members;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.room_files;
exception when duplicate_object then null; when undefined_object then null; end $$;

-- Allow new users to get their profile row automatically from Auth metadata.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$ begin
 insert into public.profiles(id,display_name)
 values(new.id,coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1),'Học viên'))
 on conflict(id) do nothing;
 return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

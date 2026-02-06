-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Create Enum for User Roles
create type user_role as enum ('admin', 'teacher');

-- Create Public Users Table
create table public.users (
  id uuid references auth.users(id) on delete cascade not null primary key,
  email text,
  role user_role,
  created_at timestamptz default now()
);

-- Enable RLS on Users
alter table public.users enable row level security;

-- Policies for Users
create policy "Users can view their own profile"
  on public.users for select
  using (auth.uid() = id);

create policy "Users can update their own profile"
  on public.users for update
  using (auth.uid() = id);

-- Trigger to create public user on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Create Academies Table
create table public.academies (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  join_code text unique default substr(md5(random()::text), 0, 7),
  owner_id uuid references public.users(id) not null,
  created_at timestamptz default now()
);

-- Enable RLS on Academies
alter table public.academies enable row level security;

-- Policies for Academies
create policy "Admins can create academies"
  on public.academies for insert
  with check (auth.uid() = owner_id);

create policy "Users can view academies they belong to"
  on public.academies for select
  using (
    exists (
      select 1 from public.academy_members
      where academy_members.academy_id = academies.id
      and academy_members.user_id = auth.uid()
    )
    or owner_id = auth.uid()
  );

-- Create Academy Members Table
create table public.academy_members (
  id uuid default uuid_generate_v4() primary key,
  academy_id uuid references public.academies(id) on delete cascade not null,
  user_id uuid references public.users(id) on delete cascade not null,
  role user_role not null,
  joined_at timestamptz default now(),
  unique(academy_id, user_id)
);

-- Enable RLS on Academy Members
alter table public.academy_members enable row level security;

-- Policies for Academy Members
create policy "Users can view members of their academies"
  on public.academy_members for select
  using (
    exists (
      select 1 from public.academy_members as am
      where am.academy_id = academy_members.academy_id
      and am.user_id = auth.uid()
    )
    or exists (
        select 1 from public.academies as a
        where a.id = academy_members.academy_id
        and a.owner_id = auth.uid()
    )
  );

create policy "Admins can add members"
  on public.academy_members for insert
  with check (
    exists (
      select 1 from public.academies
      where id = academy_id
      and owner_id = auth.uid()
    )
  );

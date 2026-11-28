begin;
create extension if not exists pgcrypto;
create extension if not exists btree_gist;

create or replace function public.set_updated_at() returns trigger language plpgsql set search_path=public as $$
begin new.updated_at=now(); new.version=coalesce(old.version,0)+1; return new; end $$;

create table public.organizations(
  id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name)) between 1 and 120), slug text not null unique check(slug~'^[a-z0-9][a-z0-9-]{1,62}$'),
  timezone text not null default 'Asia/Taipei' check(timezone='Asia/Taipei'), currency text not null default 'TWD' check(currency='TWD'), active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), version integer not null default 1
);
create table public.profiles(
  id uuid primary key references auth.users(id) on delete cascade, display_name text not null check(length(trim(display_name)) between 1 and 80), phone text, avatar_path text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), version integer not null default 1
);
create table public.organization_members(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, user_id uuid not null references auth.users(id) on delete restrict,
  role text not null check(role in('owner','manager','staff','customer')), status text not null default 'active' check(status in('invited','active','inactive')),
  invited_by uuid references auth.users(id), joined_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), version integer not null default 1,
  unique(organization_id,user_id), unique(organization_id,id)
);
create index organization_members_user_idx on public.organization_members(user_id,status);
create table public.hotel_settings(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null unique references public.organizations(id) on delete restrict,
  reminder_time time not null default '17:00', shift_reminder_minutes integer[] not null default '{60,30,10}', checkout_time time default '11:00', checkin_time time default '15:00', settings jsonb not null default '{}',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users(id), updated_by uuid references auth.users(id), version integer not null default 1
);

create table public.room_types(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, code text not null, name text not null, max_cats integer not null check(max_cats between 1 and 20), sort_order integer not null default 0, active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users(id), updated_by uuid references auth.users(id), version integer not null default 1,
  unique(organization_id,code), unique(organization_id,id)
);
create table public.rooms(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, room_type_id uuid not null, name text not null,
  status text not null default 'available' check(status in('available','reserved','waiting_checkin','occupied','waiting_checkout','cleaning_required','cleaning_completed','out_of_service')), sort_order integer not null default 0, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users(id), updated_by uuid references auth.users(id), version integer not null default 1,
  unique(organization_id,name), unique(organization_id,id), foreign key(organization_id,room_type_id) references public.room_types(organization_id,id) on delete restrict
);
create table public.pricing_rules(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, room_type_id uuid not null, code text not null,
  min_nights integer not null check(min_nights>=1), cat_group text not null check(cat_group in('single','multi')), nightly_amount integer not null check(nightly_amount>=0), valid_from date not null default current_date, valid_until date, active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users(id), updated_by uuid references auth.users(id), version integer not null default 1,
  check(valid_until is null or valid_until>=valid_from), unique(organization_id,room_type_id,code,cat_group,valid_from), unique(organization_id,id), foreign key(organization_id,room_type_id) references public.room_types(organization_id,id) on delete restrict
);

create table public.owners(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, name text not null, phone text not null, line_contact text, email text, emergency_contact text, emergency_phone text, preferred_vet text, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users(id), updated_by uuid references auth.users(id), version integer not null default 1, archived_at timestamptz,
  unique(organization_id,id)
);
create index owners_search_idx on public.owners(organization_id,name,phone);
create table public.cats(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, owner_id uuid not null, name text not null, profile_photo_path text, breed text,
  sex text check(sex in('female','male','unknown')), birth_date date, weight_kg numeric(5,2) check(weight_kg is null or weight_kg>0), neutered boolean, personality text, stress_level text, social_behavior text,
  allergies text, chronic_conditions text, food_restrictions text, medication_info text, special_care text, emergency_instructions text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users(id), updated_by uuid references auth.users(id), version integer not null default 1, archived_at timestamptz,
  unique(organization_id,id), foreign key(organization_id,owner_id) references public.owners(organization_id,id) on delete restrict
);
create index cats_search_idx on public.cats(organization_id,name,owner_id);
create table public.owner_user_links(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, owner_id uuid not null, user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(), created_by uuid references auth.users(id), unique(organization_id,owner_id,user_id), foreign key(organization_id,owner_id) references public.owners(organization_id,id) on delete cascade
);

create sequence public.reservation_number_seq;
create table public.reservations(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, owner_id uuid not null,
  reservation_number text not null, status text not null default 'draft' check(status in('draft','pending','confirmed','checked_in','waiting_checkout','checked_out','cancelled','no_show')),
  booked_at timestamptz not null default now(), expected_check_in_at timestamptz not null, actual_check_in_at timestamptz, expected_check_out_at timestamptz not null, actual_check_out_at timestamptz,
  currency text not null default 'TWD' check(currency='TWD'), total_amount integer not null default 0 check(total_amount>=0), deposit_amount integer not null default 0 check(deposit_amount>=0), additional_charges integer not null default 0 check(additional_charges>=0), discount_amount integer not null default 0 check(discount_amount>=0), balance_amount integer not null default 0 check(balance_amount>=0),
  payment_status text not null default 'unpaid' check(payment_status in('unpaid','deposit_paid','partially_paid','paid','refunded')), notes text, idempotency_key uuid not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1,
  check(expected_check_out_at>expected_check_in_at), check(actual_check_out_at is null or actual_check_in_at is null or actual_check_out_at>=actual_check_in_at),
  unique(organization_id,reservation_number), unique(organization_id,id), unique(organization_id,idempotency_key), foreign key(organization_id,owner_id) references public.owners(organization_id,id) on delete restrict
);
create index reservations_schedule_idx on public.reservations(organization_id,expected_check_in_at,expected_check_out_at,status);
create table public.reservation_cats(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, reservation_id uuid not null, cat_id uuid not null, care_snapshot jsonb not null default '{}',
  created_at timestamptz not null default now(), created_by uuid not null references auth.users(id), unique(organization_id,reservation_id,cat_id), unique(organization_id,id),
  foreign key(organization_id,reservation_id) references public.reservations(organization_id,id) on delete restrict, foreign key(organization_id,cat_id) references public.cats(organization_id,id) on delete restrict
);
create table public.room_allocations(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, reservation_id uuid not null, room_id uuid not null, check_in_at timestamptz not null, check_out_at timestamptz not null,
  allocation_status text not null default 'active' check(allocation_status in('active','cancelled','completed')), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1,
  check(check_out_at>check_in_at), unique(organization_id,id), foreign key(organization_id,reservation_id) references public.reservations(organization_id,id) on delete restrict, foreign key(organization_id,room_id) references public.rooms(organization_id,id) on delete restrict,
  exclude using gist(organization_id with =,room_id with =,tstzrange(check_in_at,check_out_at,'[)') with &&) where(allocation_status='active')
);
create index room_allocations_reservation_idx on public.room_allocations(organization_id,reservation_id);
create table public.price_snapshots(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, reservation_id uuid not null, version_label text not null, calculation jsonb not null,
  nights integer not null check(nights>=1), cat_count integer not null check(cat_count>=1), nightly_amount integer not null check(nightly_amount>=0), total_amount integer not null check(total_amount>=0), deposit_amount integer not null check(deposit_amount>=0), balance_amount integer not null check(balance_amount>=0),
  created_at timestamptz not null default now(), created_by uuid not null references auth.users(id), unique(organization_id,reservation_id), foreign key(organization_id,reservation_id) references public.reservations(organization_id,id) on delete restrict
);
create table public.payments(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, reservation_id uuid not null, amount integer not null check(amount>0), currency text not null default 'TWD' check(currency='TWD'), payment_type text not null check(payment_type in('deposit','balance','additional','refund')), method text, paid_at timestamptz not null, reference text, notes text,
  created_at timestamptz not null default now(), created_by uuid not null references auth.users(id), unique(organization_id,id), foreign key(organization_id,reservation_id) references public.reservations(organization_id,id) on delete restrict
);

do $$ declare t text; begin foreach t in array array['organizations','profiles','organization_members','hotel_settings','room_types','rooms','pricing_rules','owners','cats','reservations','room_allocations'] loop execute format('create trigger %I_updated before update on public.%I for each row execute function public.set_updated_at()',t,t); end loop; end $$;
commit;

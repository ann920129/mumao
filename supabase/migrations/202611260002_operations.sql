begin;
create table public.stay_item_categories(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, code text not null, name text not null, sort_order integer not null default 0, active boolean not null default true,
  created_at timestamptz not null default now(), unique(organization_id,code), unique(organization_id,id)
);
create table public.stay_items(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, reservation_id uuid not null, reservation_cat_id uuid, category_id uuid not null, shared_group_id uuid,
  name text not null, received_quantity numeric(12,3) check(received_quantity is null or received_quantity>=0), remaining_quantity numeric(12,3) check(remaining_quantity is null or remaining_quantity>=0), unit text, storage_location text, storage_instructions text, opened_on date, expires_on date, usage_instructions text, special_instructions text, return_required boolean not null default true, low_stock_threshold numeric(12,3),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1, archived_at timestamptz,
  check(expires_on is null or opened_on is null or expires_on>=opened_on), unique(organization_id,id),
  foreign key(organization_id,reservation_id) references public.reservations(organization_id,id) on delete restrict, foreign key(organization_id,reservation_cat_id) references public.reservation_cats(organization_id,id) on delete restrict, foreign key(organization_id,category_id) references public.stay_item_categories(organization_id,id) on delete restrict
);
create index stay_items_stay_idx on public.stay_items(organization_id,reservation_id,reservation_cat_id);
create table public.item_inventory_movements(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, stay_item_id uuid not null, movement_type text not null check(movement_type in('received','offered','consumed','waste','replenishment','correction','returned')),
  quantity numeric(12,3) not null check(quantity<>0), unit text, reason text, idempotency_key uuid not null, occurred_at timestamptz not null default now(), created_at timestamptz not null default now(), created_by uuid not null references auth.users(id),
  unique(organization_id,stay_item_id,idempotency_key), foreign key(organization_id,stay_item_id) references public.stay_items(organization_id,id) on delete restrict
);
create table public.checkout_item_checks(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, stay_item_id uuid not null,
  used_quantity numeric(12,3), remaining_quantity numeric(12,3), expected_return_quantity numeric(12,3), actual_return_quantity numeric(12,3), status text not null default 'pending' check(status in('pending','returned','fully_consumed','left_with_permission','missing','damaged','not_applicable')), notes text, exception_reason text,
  verified_by uuid references auth.users(id), verified_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1,
  unique(organization_id,stay_item_id), foreign key(organization_id,stay_item_id) references public.stay_items(organization_id,id) on delete restrict
);
create table public.item_alerts(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, stay_item_id uuid not null, alert_type text not null check(alert_type in('low_stock','expired','expiring','missing','other')), status text not null default 'open' check(status in('open','acknowledged','closed')), message text not null,
  created_at timestamptz not null default now(), closed_at timestamptz, closed_by uuid references auth.users(id), foreign key(organization_id,stay_item_id) references public.stay_items(organization_id,id) on delete restrict
);

create table public.care_plans(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, reservation_cat_id uuid not null, status text not null default 'draft' check(status in('draft','confirmed','superseded')),
  confirmed_at timestamptz, confirmed_by uuid references auth.users(id), instructions_snapshot jsonb not null default '{}', effective_from timestamptz not null, effective_until timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1,
  check(effective_until is null or effective_until>effective_from), unique(organization_id,id), foreign key(organization_id,reservation_cat_id) references public.reservation_cats(organization_id,id) on delete restrict
);
create table public.care_plan_meals(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, care_plan_id uuid not null, label text not null, scheduled_time time, recurrence jsonb not null default '{"type":"daily"}', feeding_method text, special_instructions text, active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1,
  unique(organization_id,id), foreign key(organization_id,care_plan_id) references public.care_plans(organization_id,id) on delete restrict
);
create table public.care_plan_items(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, care_plan_meal_id uuid not null, stay_item_id uuid not null, planned_quantity numeric(12,3), unit text, sort_order integer not null default 0,
  created_at timestamptz not null default now(), created_by uuid not null references auth.users(id), unique(organization_id,care_plan_meal_id,stay_item_id), foreign key(organization_id,care_plan_meal_id) references public.care_plan_meals(organization_id,id) on delete restrict, foreign key(organization_id,stay_item_id) references public.stay_items(organization_id,id) on delete restrict
);
create table public.care_days(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, reservation_cat_id uuid not null, care_date date not null, day_number integer not null check(day_number>=1),
  created_at timestamptz not null default now(), created_by uuid not null references auth.users(id), unique(organization_id,reservation_cat_id,care_date), unique(organization_id,id), foreign key(organization_id,reservation_cat_id) references public.reservation_cats(organization_id,id) on delete restrict
);
create table public.meal_records(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, care_day_id uuid not null, care_plan_meal_id uuid, label text not null, scheduled_at timestamptz, actual_feeding_at timestamptz, planned_quantity numeric(12,3), offered_quantity numeric(12,3), remaining_quantity numeric(12,3), consumed_quantity numeric(12,3), unit text, feeding_method text,
  appetite_status text, status text not null default 'pending' check(status in('pending','offered','finished','small_remaining','half_eaten','small_eaten','not_eaten','observing','not_applicable')), not_applicable_reason text, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1,
  check(status<>'not_applicable' or length(trim(not_applicable_reason))>0), unique(organization_id,id), foreign key(organization_id,care_day_id) references public.care_days(organization_id,id) on delete restrict, foreign key(organization_id,care_plan_meal_id) references public.care_plan_meals(organization_id,id) on delete restrict
);
create table public.meal_record_items(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, meal_record_id uuid not null, stay_item_id uuid not null, offered_quantity numeric(12,3), consumed_quantity numeric(12,3), unit text,
  created_at timestamptz not null default now(), created_by uuid not null references auth.users(id), unique(organization_id,meal_record_id,stay_item_id), foreign key(organization_id,meal_record_id) references public.meal_records(organization_id,id) on delete restrict, foreign key(organization_id,stay_item_id) references public.stay_items(organization_id,id) on delete restrict
);
create table public.water_records(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, care_day_id uuid not null, observed_at timestamptz not null, amount numeric(12,3), unit text, observation text not null check(observation in('normal','less','more','not_observed','unknown')), water_replaced boolean, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1, foreign key(organization_id,care_day_id) references public.care_days(organization_id,id) on delete restrict
);
create table public.urination_records(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, care_day_id uuid not null, observed_at timestamptz not null, observation_state text not null check(observation_state in('not_yet_observed','none_observed','normal','abnormal')), clump_count integer check(clump_count is null or clump_count>=0), clump_size text, color text, suspected_blood boolean, repeated_visits boolean, unusual_behavior boolean, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1, foreign key(organization_id,care_day_id) references public.care_days(organization_id,id) on delete restrict
);
create table public.defecation_records(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, care_day_id uuid not null, observed_at timestamptz not null, observation_state text not null check(observation_state in('not_yet_observed','none_observed','normal','abnormal')), quantity text, consistency text check(consistency is null or consistency in('formed','hard','soft','diarrhea','unknown')), unusual_color boolean, suspected_blood boolean, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1, foreign key(organization_id,care_day_id) references public.care_days(organization_id,id) on delete restrict
);
create table public.activity_records(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, care_day_id uuid not null, observed_at timestamptz not null, activity text, mood text, social_interaction text, hiding_behavior boolean, vomiting boolean, scratching boolean, visible_injury boolean, cleaning_completed boolean, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1, foreign key(organization_id,care_day_id) references public.care_days(organization_id,id) on delete restrict
);
create table public.medication_orders(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, reservation_cat_id uuid not null, name text not null, prescribed_dose text not null, dose_unit text, administration_method text not null, scheduled_times time[] not null, start_date date not null, end_date date not null, received_quantity numeric(12,3), remaining_quantity numeric(12,3), storage_instructions text, prescription_source text, confirmation_status text not null default 'requires_confirmation' check(confirmation_status in('requires_confirmation','confirmed','rejected')), confirmed_by uuid references auth.users(id), confirmed_at timestamptz, special_instructions text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1,
  check(end_date>=start_date), unique(organization_id,id), foreign key(organization_id,reservation_cat_id) references public.reservation_cats(organization_id,id) on delete restrict
);
create table public.medication_records(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, medication_order_id uuid not null, scheduled_at timestamptz not null, status text not null default 'pending' check(status in('pending','in_progress','administered','unsuccessful','requires_confirmation','paused','not_applicable')), actual_administered_at timestamptz, claimed_by uuid references auth.users(id), claimed_at timestamptz, responsible_staff uuid references auth.users(id), notes text, idempotency_key uuid not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1,
  unique(organization_id,medication_order_id,scheduled_at), unique(organization_id,idempotency_key), unique(organization_id,id), foreign key(organization_id,medication_order_id) references public.medication_orders(organization_id,id) on delete restrict
);
create table public.medication_item_links(
  organization_id uuid not null references public.organizations(id) on delete restrict, medication_order_id uuid not null, stay_item_id uuid not null, primary key(organization_id,medication_order_id,stay_item_id), foreign key(organization_id,medication_order_id) references public.medication_orders(organization_id,id) on delete restrict, foreign key(organization_id,stay_item_id) references public.stay_items(organization_id,id) on delete restrict
);

create table public.abnormal_events(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, reservation_cat_id uuid not null, category text not null check(category in('appetite','water','urination','defecation','vomiting','low_activity','injury','behavior','medication','other')), severity text not null check(severity in('observation','follow_up','high','emergency')), event_at timestamptz not null, description text not null, follow_up_required boolean not null default false, responsible_person uuid references auth.users(id), manager_notified_at timestamptz, owner_notified_at timestamptz, veterinarian_contacted_at timestamptz, next_follow_up_at timestamptz, resolution text, status text not null default 'open' check(status in('open','monitoring','resolved','closed')), closed_by uuid references auth.users(id), closed_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1, unique(organization_id,id), foreign key(organization_id,reservation_cat_id) references public.reservation_cats(organization_id,id) on delete restrict
);
create table public.abnormal_event_updates(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, abnormal_event_id uuid not null, update_type text not null, notes text not null, created_at timestamptz not null default now(), created_by uuid not null references auth.users(id), foreign key(organization_id,abnormal_event_id) references public.abnormal_events(organization_id,id) on delete restrict
);
create table public.shifts(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, staff_user_id uuid not null references auth.users(id), starts_at timestamptz not null, ends_at timestamptz not null, actual_start_at timestamptz, actual_end_at timestamptz, status text not null default 'scheduled' check(status in('scheduled','active','handover_required','completed','cancelled')), completion_exception text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1, check(ends_at>starts_at), unique(organization_id,id)
);
create table public.handover_records(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, from_shift_id uuid, to_user_id uuid references auth.users(id), reservation_id uuid, important boolean not null default false, notes text not null, acknowledged_by uuid references auth.users(id), acknowledged_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1, unique(organization_id,id), foreign key(organization_id,from_shift_id) references public.shifts(organization_id,id) on delete restrict, foreign key(organization_id,reservation_id) references public.reservations(organization_id,id) on delete restrict
);
create table public.tasks(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, reservation_id uuid, reservation_cat_id uuid, room_id uuid, task_type text not null, title text not null, description text, due_at timestamptz, priority integer not null default 1 check(priority between 0 and 3), status text not null default 'pending' check(status in('pending','in_progress','completed','not_applicable','cancelled','requires_confirmation')), not_applicable_reason text, assigned_to uuid references auth.users(id), claimed_by uuid references auth.users(id), claimed_at timestamptz, completed_by uuid references auth.users(id), completed_at timestamptz, source_type text, source_id uuid, idempotency_key text not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1,
  check(status<>'not_applicable' or length(trim(not_applicable_reason))>0), unique(organization_id,idempotency_key), unique(organization_id,id), foreign key(organization_id,reservation_id) references public.reservations(organization_id,id) on delete restrict, foreign key(organization_id,reservation_cat_id) references public.reservation_cats(organization_id,id) on delete restrict, foreign key(organization_id,room_id) references public.rooms(organization_id,id) on delete restrict
);
create index tasks_queue_idx on public.tasks(organization_id,status,due_at,priority desc);
create table public.notification_tasks(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, reservation_id uuid not null, notification_type text not null check(notification_type in('next_day_checkin','next_day_checkout','care_report','other')), target_date date not null, status text not null default 'pending' check(status in('pending','message_copied','sent','waiting_response','confirmed','rescheduled','not_required','cancelled')), message text not null, source_revision integer not null, actual_notified_at timestamptz, responsible_staff uuid references auth.users(id), channel text, response text, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1,
  unique(organization_id,reservation_id,notification_type,target_date), unique(organization_id,id), foreign key(organization_id,reservation_id) references public.reservations(organization_id,id) on delete restrict
);
create table public.notification_logs(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, notification_task_id uuid not null, action text not null, from_status text, to_status text, details jsonb not null default '{}', created_at timestamptz not null default now(), created_by uuid not null references auth.users(id), foreign key(organization_id,notification_task_id) references public.notification_tasks(organization_id,id) on delete restrict
);
create table public.daily_reports(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, reservation_cat_id uuid not null, report_date date not null, status text not null default 'draft' check(status in('draft','approved','published','superseded')), owner_content jsonb not null default '{}', internal_source_revision jsonb not null default '{}', approved_by uuid references auth.users(id), approved_at timestamptz, published_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1, unique(organization_id,reservation_cat_id,report_date), unique(organization_id,id), foreign key(organization_id,reservation_cat_id) references public.reservation_cats(organization_id,id) on delete restrict
);
create table public.cleaning_records(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, room_id uuid not null, reservation_id uuid, scheduled_at timestamptz, completed_at timestamptz, status text not null default 'pending' check(status in('pending','in_progress','completed','requires_review')), checklist jsonb not null default '{}', responsible_staff uuid references auth.users(id), notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id), version integer not null default 1, unique(organization_id,id), foreign key(organization_id,room_id) references public.rooms(organization_id,id) on delete restrict, foreign key(organization_id,reservation_id) references public.reservations(organization_id,id) on delete restrict
);
create table public.media_files(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, reservation_id uuid, reservation_cat_id uuid, stay_item_id uuid, abnormal_event_id uuid, category text not null, storage_bucket text not null default 'private-media' check(storage_bucket='private-media'), storage_path text not null, original_name text, mime_type text not null check(mime_type in('image/jpeg','image/png','image/webp','image/heic','image/heif','application/pdf')), file_size bigint not null check(file_size>0 and file_size<=12582912), width integer, height integer, metadata jsonb not null default '{}', status text not null default 'active' check(status in('uploading','active','replaced','pending_delete','deleted')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id), updated_by uuid references auth.users(id), version integer not null default 1, unique(storage_bucket,storage_path), unique(organization_id,id),
  foreign key(organization_id,reservation_id) references public.reservations(organization_id,id) on delete restrict, foreign key(organization_id,reservation_cat_id) references public.reservation_cats(organization_id,id) on delete restrict, foreign key(organization_id,stay_item_id) references public.stay_items(organization_id,id) on delete restrict, foreign key(organization_id,abnormal_event_id) references public.abnormal_events(organization_id,id) on delete restrict
);
create table public.audit_logs(
  id bigint generated always as identity primary key, organization_id uuid not null references public.organizations(id) on delete restrict, actor_id uuid references auth.users(id), table_name text not null, record_id uuid, action text not null check(action in('insert','update','delete','rpc')), old_data jsonb, new_data jsonb, occurred_at timestamptz not null default now(), request_id text
);
create index audit_logs_lookup_idx on public.audit_logs(organization_id,occurred_at desc,table_name);
create table public.legacy_imports(
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict, fingerprint text not null, source_format text not null, status text not null check(status in('previewed','importing','completed','failed')), counts jsonb not null default '{}', errors jsonb not null default '[]', created_at timestamptz not null default now(), completed_at timestamptz, created_by uuid not null references auth.users(id), unique(organization_id,fingerprint)
);

do $$ declare t text; begin foreach t in array array['stay_items','checkout_item_checks','care_plans','care_plan_meals','meal_records','water_records','urination_records','defecation_records','activity_records','medication_orders','medication_records','abnormal_events','shifts','handover_records','tasks','notification_tasks','daily_reports','cleaning_records','media_files'] loop execute format('create trigger %I_updated before update on public.%I for each row execute function public.set_updated_at()',t,t); end loop; end $$;
commit;

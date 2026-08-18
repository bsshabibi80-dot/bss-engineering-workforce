begin;

alter table public.review_seed_data enable row level security;

create or replace function public.validate_attendance(
  p_employee_id uuid,
  p_building_code text,
  p_qr_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare b public.buildings%rowtype; q public.qr_locations%rowtype; d double precision;
begin
  select * into b from public.buildings where code=p_building_code and active=true;
  if not found then return jsonb_build_object('ok',false,'reason','BUILDING_INVALID'); end if;
  select * into q from public.qr_locations where id=p_qr_id and active=true;
  if not found or q.building_code<>p_building_code then return jsonb_build_object('ok',false,'reason','QR_INVALID'); end if;
  if p_accuracy_m is null or p_accuracy_m > 100 then return jsonb_build_object('ok',false,'reason','GPS_ACCURACY_TOO_LOW'); end if;
  if b.latitude is null or b.longitude is null then
    return jsonb_build_object('ok',true,'reason','VALID_QR_ONLY','validation_mode','QR_ONLY','distance_m',null,'radius_m',b.geofence_radius_m,'server_at',now());
  end if;
  if p_lat is null or p_lng is null then return jsonb_build_object('ok',false,'reason','GPS_REQUIRED'); end if;
  d := public.haversine_m(b.latitude,b.longitude,p_lat,p_lng);
  if d > b.geofence_radius_m then return jsonb_build_object('ok',false,'reason','OUTSIDE_GEOFENCE','distance_m',round(d::numeric,1),'radius_m',b.geofence_radius_m); end if;
  return jsonb_build_object('ok',true,'reason','VALID','validation_mode','GPS_QR','distance_m',round(d::numeric,1),'radius_m',b.geofence_radius_m,'server_at',now());
end;
$$;

create or replace function public.record_attendance(
  p_building_code text,p_qr_id uuid,p_lat double precision,p_lng double precision,p_accuracy_m double precision,p_action text
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_employee uuid; v_validation jsonb; v_att public.attendance%rowtype; v_shift uuid; v_now timestamptz:=now(); v_date date:=current_date; v_minutes integer;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if upper(p_action) not in ('CHECK_IN','CHECK_OUT') then raise exception 'INVALID_ACTION'; end if;
  select id into v_employee from public.employees where user_id=auth.uid() and active=true limit 1;
  if v_employee is null then raise exception 'EMPLOYEE_NOT_FOUND'; end if;
  v_validation:=public.validate_attendance(v_employee,p_building_code,p_qr_id,p_lat,p_lng,p_accuracy_m);
  if coalesce((v_validation->>'ok')::boolean,false) is not true then
    insert into public.attendance_logs(employee_id,action,server_at,device_lat,device_lng,device_accuracy_m,qr_location_id,distance_m,result,note)
    values(v_employee,upper(p_action),v_now,p_lat,p_lng,p_accuracy_m,p_qr_id,null,'REJECTED',coalesce(v_validation->>'reason','VALIDATION_FAILED'));
    return v_validation||jsonb_build_object('ok',false);
  end if;
  select id into v_shift from public.shifts where active=true and ((start_time<=end_time and localtime>=start_time and localtime<end_time) or (start_time>end_time and (localtime>=start_time or localtime<end_time))) order by start_time limit 1;
  if v_shift is null then select id into v_shift from public.shifts where active=true order by start_time limit 1; end if;
  select * into v_att from public.attendance where employee_id=v_employee and work_date=v_date for update;
  if upper(p_action)='CHECK_IN' then
    if v_att.id is not null and v_att.check_in_at is not null then raise exception 'ALREADY_CHECKED_IN'; end if;
    if v_att.id is null then
      insert into public.attendance(employee_id,building_code,shift_id,work_date,check_in_at,check_in_lat,check_in_lng,check_in_accuracy_m,check_in_qr_id,validation_status,validation_note)
      values(v_employee,p_building_code,v_shift,v_date,v_now,p_lat,p_lng,p_accuracy_m,p_qr_id,'VALID',coalesce(v_validation->>'validation_mode','GPS_QR')) returning * into v_att;
    else
      update public.attendance set building_code=p_building_code,shift_id=v_shift,check_in_at=v_now,check_in_lat=p_lat,check_in_lng=p_lng,check_in_accuracy_m=p_accuracy_m,check_in_qr_id=p_qr_id,validation_status='VALID',validation_note=coalesce(v_validation->>'validation_mode','GPS_QR') where id=v_att.id returning * into v_att;
    end if;
    insert into public.attendance_logs(attendance_id,employee_id,action,server_at,device_lat,device_lng,device_accuracy_m,qr_location_id,distance_m,result,note)
    values(v_att.id,v_employee,'CHECK_IN',v_now,p_lat,p_lng,p_accuracy_m,p_qr_id,(v_validation->>'distance_m')::double precision,'ACCEPTED',coalesce(v_validation->>'validation_mode','GPS_QR'));
    return v_validation||jsonb_build_object('ok',true,'action','CHECK_IN','attendance_id',v_att.id,'server_at',v_now);
  end if;
  if v_att.id is null or v_att.check_in_at is null then raise exception 'NO_ACTIVE_CHECK_IN'; end if;
  if v_att.check_out_at is not null then raise exception 'ALREADY_CHECKED_OUT'; end if;
  v_minutes:=greatest(0,round(extract(epoch from (v_now-v_att.check_in_at))/60.0)::integer);
  update public.attendance set check_out_at=v_now,check_out_lat=p_lat,check_out_lng=p_lng,check_out_accuracy_m=p_accuracy_m,check_out_qr_id=p_qr_id,total_minutes=v_minutes,validation_status='VALID',validation_note=coalesce(v_validation->>'validation_mode','GPS_QR') where id=v_att.id returning * into v_att;
  insert into public.attendance_logs(attendance_id,employee_id,action,server_at,device_lat,device_lng,device_accuracy_m,qr_location_id,distance_m,result,note)
  values(v_att.id,v_employee,'CHECK_OUT',v_now,p_lat,p_lng,p_accuracy_m,p_qr_id,(v_validation->>'distance_m')::double precision,'ACCEPTED',coalesce(v_validation->>'validation_mode','GPS_QR'));
  return v_validation||jsonb_build_object('ok',true,'action','CHECK_OUT','attendance_id',v_att.id,'server_at',v_now,'total_minutes',v_minutes);
end;
$$;

commit;

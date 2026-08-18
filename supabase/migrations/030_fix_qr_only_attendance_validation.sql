-- BSS ENGINEERING
-- Fix QR-only attendance fallback when a building has no GPS coordinates.
-- GPS accuracy is required only when geofencing is configured.
create or replace function public.validate_attendance(
  p_employee_id uuid,
  p_building_code text,
  p_qr_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  b public.buildings%rowtype;
  q public.qr_locations%rowtype;
  d double precision;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok',false,'reason','NOT_AUTHENTICATED');
  end if;

  if not exists (
    select 1 from public.employees
    where id=p_employee_id and user_id=auth.uid() and active=true
  ) then
    return jsonb_build_object('ok',false,'reason','EMPLOYEE_INVALID');
  end if;

  select * into b
  from public.buildings
  where code=p_building_code and active=true;
  if not found then
    return jsonb_build_object('ok',false,'reason','BUILDING_INVALID');
  end if;

  select * into q
  from public.qr_locations
  where id=p_qr_id and active=true;
  if not found or q.building_code<>p_building_code then
    return jsonb_build_object('ok',false,'reason','QR_INVALID');
  end if;

  -- Until a real site coordinate is configured, QR is the authoritative
  -- location proof. Do not require browser GPS in this mode.
  if b.latitude is null or b.longitude is null then
    return jsonb_build_object(
      'ok',true,
      'reason','VALID_QR_ONLY',
      'validation_mode','QR_ONLY',
      'distance_m',null,
      'radius_m',b.geofence_radius_m,
      'server_at',now()
    );
  end if;

  if p_lat is null or p_lng is null then
    return jsonb_build_object('ok',false,'reason','GPS_REQUIRED');
  end if;

  if p_accuracy_m is null or p_accuracy_m > 100 then
    return jsonb_build_object('ok',false,'reason','GPS_ACCURACY_TOO_LOW');
  end if;

  d := public.haversine_m(b.latitude,b.longitude,p_lat,p_lng);
  if d > coalesce(b.geofence_radius_m,75) then
    return jsonb_build_object(
      'ok',false,
      'reason','OUTSIDE_GEOFENCE',
      'distance_m',round(d::numeric,1),
      'radius_m',coalesce(b.geofence_radius_m,75)
    );
  end if;

  return jsonb_build_object(
    'ok',true,
    'reason','VALID',
    'validation_mode','GPS_QR',
    'distance_m',round(d::numeric,1),
    'radius_m',coalesce(b.geofence_radius_m,75),
    'server_at',now()
  );
end;
$$;

revoke all on function public.validate_attendance(uuid,text,uuid,double precision,double precision,double precision) from public;
grant execute on function public.validate_attendance(uuid,text,uuid,double precision,double precision,double precision) to authenticated, service_role;

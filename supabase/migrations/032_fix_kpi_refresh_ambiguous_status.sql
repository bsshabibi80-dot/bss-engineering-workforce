-- Fix ambiguous status reference in KPI PPM calculation after joining schedule/equipment.
create or replace function public.refresh_kpi_month(p_month date)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start date:=date_trunc('month',p_month)::date;
  v_end date:=(date_trunc('month',p_month)+interval '1 month')::date;
  v_count integer:=0;
  b record;
  e record;
  ppm numeric;
  complaint numeric;
  repeat_score numeric;
  sla numeric;
  avail numeric;
  ep numeric;
  impact numeric;
  quality numeric;
  response numeric;
  attendance_score numeric;
  safety numeric;
  bk numeric;
  ek numeric;
begin
  if not public.can_manage_engineering() then raise exception 'NOT_AUTHORIZED'; end if;
  for b in select code from public.buildings where active=true loop
    select coalesce(round(100.0*count(*) filter(where p.status='DONE')/nullif(count(*),0),2),100)
      into ppm
      from public.ppm_schedule p
      join public.equipment q on q.id=p.equipment_id
      where q.building_code=b.code and p.scheduled_date>=v_start and p.scheduled_date<v_end;
    select greatest(0,least(100,100-sum(public.complaint_severity_points(severity))*2)) into complaint from public.complaints where building_code=b.code and reported_at>=v_start and reported_at<v_end;
    complaint:=coalesce(complaint,100);
    select greatest(0,least(100,100-count(*)*5)) into repeat_score from public.complaints where building_code=b.code and is_repeat and reported_at>=v_start and reported_at<v_end;
    repeat_score:=coalesce(repeat_score,100);
    select coalesce(round(100.0*count(*) filter(where response_at is not null and response_at-reported_at<=interval '30 minutes')/nullif(count(*),0),2),100) into sla from public.complaints where building_code=b.code and reported_at>=v_start and reported_at<v_end;
    avail:=100;
    bk:=public.calculate_building_kpi(ppm,complaint,repeat_score,sla,avail);
    delete from public.kpi_monthly where period_month=v_start and building_code=b.code and employee_id is null;
    insert into public.kpi_monthly(period_month,building_code,employee_id,ppm_achievement,complaint_score,repeat_complaint_score,sla_score,availability_score,building_kpi,grade,calculated_at)
    values(v_start,b.code,null,ppm,complaint,repeat_score,sla,avail,bk,case when bk>=90 then 'SANGAT BAIK' when bk>=80 then 'BAIK' when bk>=70 then 'CUKUP' else 'PERLU PERHATIAN' end,now());
    v_count:=v_count+1;
  end loop;
  for e in select id from public.employees where active=true loop
    select coalesce(round(100.0*count(*) filter(where x.completed_at is not null)/nullif(count(*),0),2),100) into ep from public.ppm_execution_steps x where x.employee_id=e.id and x.started_at>=v_start and x.started_at<v_end;
    select greatest(0,least(100,100-sum(public.complaint_severity_points(c.severity))*2)) into impact from public.complaints c where c.assigned_to=e.id and c.reported_at>=v_start and c.reported_at<v_end;
    impact:=coalesce(impact,100);
    select coalesce(round(100.0*count(*) filter(where qc_status='APPROVED')/nullif(count(*),0),2),100) into quality from public.ppm_execution_steps where employee_id=e.id and completed_at>=v_start and completed_at<v_end;
    select coalesce(round(100.0*count(*) filter(where response_at is not null and response_at-reported_at<=interval '30 minutes')/nullif(count(*),0),2),100) into response from public.complaints where assigned_to=e.id and reported_at>=v_start and reported_at<v_end;
    select coalesce(greatest(0,least(100,100-5*count(*) filter(where check_in_at is null))),100) into attendance_score from public.attendance where employee_id=e.id and work_date>=v_start and work_date<v_end;
    safety:=100;
    ek:=public.calculate_employee_kpi(ep,impact,quality,response,attendance_score,safety);
    delete from public.kpi_monthly where period_month=v_start and employee_id=e.id;
    insert into public.kpi_monthly(period_month,building_code,employee_id,ppm_execution_score,complaint_impact_score,quality_repeat_job_score,response_resolution_score,attendance_discipline_score,safety_sop_score,employee_kpi,grade,calculated_at)
    select v_start,building_code,e.id,ep,impact,quality,response,attendance_score,safety,ek,case when ek>=90 then 'SANGAT BAIK' when ek>=80 then 'BAIK' when ek>=70 then 'CUKUP' else 'PERLU PERHATIAN' end,now() from public.employees where id=e.id;
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.refresh_kpi_month(date) from public;
grant execute on function public.refresh_kpi_month(date) to authenticated, service_role;

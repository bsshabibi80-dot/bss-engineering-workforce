begin;
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_name text; v_role public.app_role; v_emp_id uuid; v_existing_role public.app_role;
begin
  v_name:=coalesce(nullif(new.raw_user_meta_data->>'full_name',''),split_part(new.email,'@',1));
  select id,role into v_emp_id,v_existing_role from public.employees where lower(email)=lower(new.email) limit 1;
  v_role:=case when lower(new.email)='bsshabibi80@gmail.com' then 'SUPER_ADMIN'::public.app_role else coalesce(v_existing_role,'ENGINEER'::public.app_role) end;
  insert into public.profiles(id,full_name,email,role,active) values(new.id,v_name,new.email,v_role,true)
  on conflict(id) do update set email=excluded.email,full_name=excluded.full_name,role=excluded.role,active=true;
  if v_emp_id is not null then
    update public.employees set user_id=new.id,full_name=v_name,email=new.email,role=v_role,active=true where id=v_emp_id;
  else
    insert into public.employees(employee_no,full_name,email,user_id,role,active) values('EMP-'||upper(substr(replace(new.id::text,'-',''),1,8)),v_name,new.email,new.id,v_role,true)
    on conflict(user_id) do update set full_name=excluded.full_name,email=excluded.email,role=excluded.role,active=true;
  end if;
  return new;
end;
$$;
commit;

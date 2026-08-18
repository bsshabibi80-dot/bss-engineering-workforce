-- Allow the KPI UI to invoke the secured refresh function.
-- Authorization remains enforced inside refresh_kpi_month via can_manage_engineering().
revoke all on function public.refresh_kpi_month(date) from public;
grant execute on function public.refresh_kpi_month(date) to authenticated, service_role;

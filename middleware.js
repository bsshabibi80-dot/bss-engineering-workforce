import { createServerClient } from '@supabase/ssr';
import { NextResponse } from 'next/server';

const SUPABASE_URL=process.env.NEXT_PUBLIC_SUPABASE_URL||'https://fzjgktgvmavuirfipfha.supabase.co';
const SUPABASE_KEY=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY||'sb_publishable_kZnIPkZm9W_MOKFSErv-7w_u937Fz4w';
const PUBLIC_PATHS = new Set(['/login']);

export async function middleware(request){
 const response=NextResponse.next({request});
 const supabase=createServerClient(SUPABASE_URL,SUPABASE_KEY,{cookies:{getAll(){return request.cookies.getAll()},setAll(cookiesToSet){cookiesToSet.forEach(({name,value,options})=>{request.cookies.set(name,value);response.cookies.set(name,value,options)})}}});
 const{data:{user}}=await supabase.auth.getUser();
 const pathname=request.nextUrl.pathname;
 if(!user&&!PUBLIC_PATHS.has(pathname)){const url=request.nextUrl.clone();url.pathname='/login';url.searchParams.set('next',pathname);return NextResponse.redirect(url)}
 if(user&&pathname==='/login'){const url=request.nextUrl.clone();url.pathname='/';url.search='';return NextResponse.redirect(url)}
 return response;
}

export const config={matcher:['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)']};

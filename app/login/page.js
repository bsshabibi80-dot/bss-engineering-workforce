'use client';
import {useEffect,useState} from 'react';
import Link from 'next/link';
import {supabase} from '../../lib/supabase-browser';

export default function Login(){
 const[nextPath,setNextPath]=useState('/');
 const[email,setEmail]=useState('');
 const[user,setUser]=useState(null);
 const[msg,setMsg]=useState('');
 useEffect(()=>{const next=new URLSearchParams(window.location.search).get('next');if(next?.startsWith('/'))setNextPath(next);supabase.auth.getUser().then(({data})=>setUser(data.user));},[]);
 async function go(e){e.preventDefault();setMsg('Mengirim link login…');const{error}=await supabase.auth.signInWithOtp({email:email.trim(),options:{emailRedirectTo:`${window.location.origin}${nextPath}`}});setMsg(error?error.message:'Link login terkirim. Buka email lalu kembali ke aplikasi.');}
 async function out(){await supabase.auth.signOut();setUser(null);setMsg('Logout berhasil.');}
 return <main className="loginPage"><form onSubmit={go}><img src="/bss-engineering-logo.png" alt="BSS Engineering"/><h1>BSS ENGINEERING</h1>{user?<><p>Login aktif sebagai<br/><b>{user.email}</b></p><button type="button" onClick={out}>Logout</button></>:<><p>Login untuk Absensi, Complaint, WO, PPM, QC, KPI dan laporan.</p><input type="email" value={email} onChange={e=>setEmail(e.target.value)} placeholder="nama@bssengineering.com" autoComplete="email" required/><button type="submit">Kirim Link Login</button></>}<p className="muted">{msg}</p><Link href="/">← Kembali Dashboard</Link></form></main>
}

'use client';
import {useState} from 'react';
import Link from 'next/link';
import {supabase} from '../../lib/supabase-browser';
export default function Login(){const[email,setEmail]=useState('bsshabibi80@gmail.com');const[msg,setMsg]=useState('');async function go(e){e.preventDefault();setMsg('Mengirim link login…');const {error}=await supabase.auth.signInWithOtp({email,options:{emailRedirectTo:window.location.origin}});setMsg(error?error.message:'Link login sudah dikirim. Cek email.')}return <main className="loginPage"><form onSubmit={go}><img src="/bss-engineering-logo.png"/><h1>BSS Engineering</h1><p>Login untuk mengaktifkan Absensi dan modul database.</p><input type="email" value={email} onChange={e=>setEmail(e.target.value)} required/><button>Kirim Link Login</button><p>{msg}</p><Link href="/">← Kembali Dashboard</Link></form></main>}

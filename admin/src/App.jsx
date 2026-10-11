import React,{useEffect,useState} from 'react';
import {Link,NavLink,Navigate,Route,Routes,useLocation,useNavigate} from 'react-router-dom';
import {LayoutDashboard,Scale,Briefcase,BadgeIndianRupee,Users,Radio,Clock3,CreditCard,WalletCards,HandCoins,Percent,History as HistoryIcon,PhoneCall,MessageSquareWarning,RotateCcw,Star,ChartNoAxesCombined,Menu,X,Bell,LogOut,ChevronRight,ArrowLeftRight,BadgeCheck} from 'lucide-react';
import {adminEmail,adminSignOut,api,requestAdminCode,token,verifyAdminCode} from './api.js';
import Dashboard from './pages/Dashboard.jsx';
import Lawyers from './pages/Lawyers.jsx';
import Verification from './pages/Verification.jsx';
import Pricing from './pages/Pricing.jsx';
import Customers from './pages/Customers.jsx';
import Live from './pages/Live.jsx';
import Billing from './pages/Billing.jsx';
import {Payments,Payouts,Wallets} from './pages/Money.jsx';
import Commission from './pages/Commission.jsx';
import History,{CallLogs} from './pages/History.jsx';
import {Complaints,Refunds,Reviews} from './pages/Support.jsx';
import Reports from './pages/Reports.jsx';
import Transactions from './pages/Transactions.jsx';

// Sidebar in the LegalDash design order. Old mock pages: admin/legacy-mock/.
const menu=[
 ['dashboard','Main Dashboard',LayoutDashboard,Dashboard],['verification','Lawyer Verification',BadgeCheck,Verification],['lawyers','Lawyer Management',Briefcase,Lawyers],['pricing','Lawyer Pricing Management',BadgeIndianRupee,Pricing],['customers','Customer Management',Users,Customers],
 ['live','Live Consultation Management',Radio,Live],['billing','Per-Minute Billing System',Clock3,Billing],['payments','Payment Management',CreditCard,Payments],['wallet','Wallet Management',WalletCards,Wallets],['transactions','Wallet Transactions',ArrowLeftRight,Transactions],
 ['payouts','Lawyer Payout Management',HandCoins,Payouts],['commissions','Commission Management',Percent,Commission],['history','Consultation History',HistoryIcon,History],['calls','Call Logs',PhoneCall,CallLogs],
 ['complaints','Complaints and Dispute Management',MessageSquareWarning,Complaints],['refunds','Refund and Cancellation Rules',RotateCcw,Refunds],['reviews','Ratings and Reviews',Star,Reviews],['analytics','Report And Analytics',ChartNoAxesCombined,Reports]
];

// Admin sign-in: an email code, only for the emails in the server's ADMIN_EMAILS.
function Login(){const nav=useNavigate();const [email,setEmail]=useState('');const [sent,setSent]=useState(false);const [code,setCode]=useState('');const [devCode,setDevCode]=useState('');const [error,setError]=useState('');const [busy,setBusy]=useState(false);
 if(token())return <Navigate to="/dashboard"/>;
 async function submit(e){e.preventDefault();setError('');setBusy(true);
  try{if(!sent){const d=await requestAdminCode(email.trim());setSent(true);setDevCode(d.devCode||'')}else{await verifyAdminCode(email.trim(),code.trim());nav('/dashboard')}}
  catch(err){setError(err.message)}finally{setBusy(false)}}
 return <div className="auth-page"><section className="auth-art"><div className="art-logo"><Scale/> LEGALLY TALK</div><div><span>ADMIN CONSOLE</span><h1>Secure Admin<br/>Platform</h1><p>Only approved admin emails can sign in. A one-time code is emailed to you each time.</p></div></section><section className="auth-box"><form onSubmit={submit}><h2>Admin Access</h2><p>{sent?`Enter the 6-digit code sent to ${email}.`:'Enter your admin email and we will email you a sign-in code.'}</p>
 <label>Admin email<input type="email" value={email} onChange={e=>setEmail(e.target.value)} disabled={sent} autoComplete="email" required/></label>
 {sent&&<label>Sign-in code<input value={code} onChange={e=>setCode(e.target.value.replace(/\D/g,''))} inputMode="numeric" maxLength="6" minLength="6" autoComplete="one-time-code" autoFocus required/></label>}
 {devCode&&<small>Test mode code: <b>{devCode}</b></small>}
 <small className="form-error">{error}</small><button className="primary wide" disabled={busy}>{busy?'Please wait…':sent?'Verify & Sign In':'Email me a code'} <ChevronRight size={15}/></button>
 {sent&&<button type="button" className="secondary wide" style={{marginTop:8}} onClick={()=>{setSent(false);setCode('');setDevCode('');setError('')}}>Use a different email</button>}</form></section></div>}

// Bell: real items waiting for an admin (verifications, complaints, refunds, failed payments).
function Alerts(){const [a,setA]=useState(null);const [open,setOpen]=useState(false);
 useEffect(()=>{const load=()=>api('/api/admin/overview').then(d=>setA({...d.alerts,verifications:d.registration.pendingVerification})).catch(()=>{});load();const t=setInterval(load,30000);return()=>clearInterval(t)},[]);
 const items=a?[['verifications','lawyers waiting for verification','/verification'],['openComplaints','open complaints','/complaints'],['refundRequests','refund requests to decide','/refunds'],['failedPayments','failed payments','/payments'],['flaggedReviews','flagged reviews','/reviews']].filter(([k])=>a[k]>0):[];
 return <div className="profile"><button className="icon-btn" onClick={()=>setOpen(!open)} aria-label="Alerts"><Bell size={17}/>{items.length>0&&<i/>}</button>{open&&<div className="profile-menu ld-alerts"><b>Alerts</b>{items.length?items.map(([k,text,to])=><Link key={k} to={to} onClick={()=>setOpen(false)}><strong>{a[k]}</strong> {text}</Link>):<p>Nothing needs attention.</p>}</div>}</div>}

function Shell(){if(!token())return <Navigate to="/login"/>;return <SignedInShell/>}
function SignedInShell(){const [open,setOpen]=useState(false);const [profile,setProfile]=useState(false);const loc=useLocation();const nav=useNavigate();const current=menu.find(([path])=>loc.pathname.startsWith('/'+path))?.[1]||'Dashboard';
 useEffect(()=>{document.title=`${current} · Vakil Admin`},[current]);
 function logout(){adminSignOut();nav('/login')}
 return <div className="shell"><aside className={open?'open':''}><div className="side-logo"><span><Scale size={16}/></span><div><b>Vakil Admin</b><small>Admin Console · India</small></div><button onClick={()=>setOpen(false)}><X/></button></div><nav><small className="ld-nav-label">NAVIGATION</small>{menu.map(([path,label,Icon])=><NavLink key={path} to={'/'+path} onClick={()=>setOpen(false)}><Icon size={15}/><span>{label}</span></NavLink>)}</nav></aside>
 <div className="workspace"><header><button className="hamburger" onClick={()=>setOpen(true)}><Menu/></button><b className="product ld-brand"><span><Scale size={13}/></span> LegalDash</b><div className="head-right"><Alerts/><div className="profile"><button onClick={()=>setProfile(!profile)}><span className="avatar">{(adminEmail()[0]||'A').toUpperCase()}</span><span><b>{adminEmail()||'Admin'}</b><small>Admin</small></span></button>{profile&&<div className="profile-menu"><b>{current}</b><button onClick={logout}><LogOut size={14}/> Sign out</button></div>}</div></div></header>
 <main><Routes>{menu.map(([path,,,Page])=><Route key={path} path={path} element={<Page/>}/>)}<Route path="requests" element={<Navigate to="/history"/>}/><Route path="users" element={<Navigate to="/customers"/>}/><Route path="*" element={<Navigate to="/dashboard"/>}/></Routes></main></div></div>}

export default function App(){return <Routes><Route path="/login" element={<Login/>}/><Route path="/*" element={<Shell/>}/></Routes>}

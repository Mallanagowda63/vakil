import React,{useEffect,useState} from 'react';
import {Link,NavLink,Navigate,Route,Routes,useLocation,useNavigate} from 'react-router-dom';
import {LayoutDashboard,Scale,Briefcase,BadgeIndianRupee,Users,Radio,Clock3,CreditCard,WalletCards,HandCoins,Percent,History as HistoryIcon,PhoneCall,MessageSquareWarning,RotateCcw,Star,ChartNoAxesCombined,Menu,X,Bell,LogOut,ChevronRight,ArrowLeftRight} from 'lucide-react';
import {api} from './api.js';
import Dashboard from './pages/Dashboard.jsx';
import Lawyers from './pages/Lawyers.jsx';
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
 ['dashboard','Main Dashboard',LayoutDashboard,Dashboard],['lawyers','Lawyer Management',Briefcase,Lawyers],['pricing','Lawyer Pricing Management',BadgeIndianRupee,Pricing],['customers','Customer Management',Users,Customers],
 ['live','Live Consultation Management',Radio,Live],['billing','Per-Minute Billing System',Clock3,Billing],['payments','Payment Management',CreditCard,Payments],['wallet','Wallet Management',WalletCards,Wallets],['transactions','Wallet Transactions',ArrowLeftRight,Transactions],
 ['payouts','Lawyer Payout Management',HandCoins,Payouts],['commissions','Commission Management',Percent,Commission],['history','Consultation History',HistoryIcon,History],['calls','Call Logs',PhoneCall,CallLogs],
 ['complaints','Complaints and Dispute Management',MessageSquareWarning,Complaints],['refunds','Refund and Cancellation Rules',RotateCcw,Refunds],['reviews','Ratings and Reviews',Star,Reviews],['analytics','Report And Analytics',ChartNoAxesCombined,Reports]
];

function Login(){const nav=useNavigate();const [register,setRegister]=useState(false);const [error,setError]=useState('');function submit(e){e.preventDefault();const form=new FormData(e.currentTarget);if(!form.get('email')||!form.get('password'))return setError('Please complete all required fields.');localStorage.setItem('vakilReactSession',JSON.stringify({email:form.get('email'),name:form.get('name')||'Admin User'}));nav('/dashboard')}return <div className="auth-page"><section className="auth-art"><div className="art-logo"><Scale/> VAKIL</div><div><span>ENTERPRISE CONTROL</span><h1>Secure Admin<br/>Platform</h1><p>Enterprise-grade access management for legal platform administrators.</p></div></section><section className="auth-box"><form onSubmit={submit}><h2>{register?'Admin Registration':'Admin Access'}</h2><p>{register?'Create your administrator identity credential.':'Sign in to manage your platform resources.'}</p><div className="auth-tabs"><button type="button" className={!register?'active':''} onClick={()=>setRegister(false)}>Sign in</button><button type="button" className={register?'active':''} onClick={()=>setRegister(true)}>New registration</button></div>{register&&<label>Full name<input name="name" placeholder="Audrey Chen" required/></label>}<label>Work email<input name="email" type="email" defaultValue={!register?'admin@enterprise.com':''} required/></label><label>Password<input name="password" type="password" defaultValue={!register?'SecureAdmin12!':''} minLength="8" required/></label>{register&&<label>Role<select name="role"><option>Security Admin</option><option>Finance Manager</option><option>Customer Support</option></select></label>}{!register&&<label>Authentication code<input name="otp" defaultValue="824910" inputMode="numeric" maxLength="6" required/></label>}<small className="form-error">{error}</small><button className="primary wide">{register?'Create Admin Account':'Verify & Sign In'} <ChevronRight size={15}/></button></form></section></div>}

// Bell: real items waiting for an admin (verifications, complaints, refunds, failed payments).
function Alerts(){const [a,setA]=useState(null);const [open,setOpen]=useState(false);
 useEffect(()=>{const load=()=>api('/api/admin/overview').then(d=>setA({...d.alerts,verifications:d.registration.pendingVerification})).catch(()=>{});load();const t=setInterval(load,30000);return()=>clearInterval(t)},[]);
 const items=a?[['verifications','lawyers waiting for verification','/lawyers?status=under_review'],['openComplaints','open complaints','/complaints'],['refundRequests','refund requests to decide','/refunds'],['failedPayments','failed payments','/payments'],['flaggedReviews','flagged reviews','/reviews']].filter(([k])=>a[k]>0):[];
 return <div className="profile"><button className="icon-btn" onClick={()=>setOpen(!open)} aria-label="Alerts"><Bell size={17}/>{items.length>0&&<i/>}</button>{open&&<div className="profile-menu ld-alerts"><b>Alerts</b>{items.length?items.map(([k,text,to])=><Link key={k} to={to} onClick={()=>setOpen(false)}><strong>{a[k]}</strong> {text}</Link>):<p>Nothing needs attention.</p>}</div>}</div>}

function Shell(){const [open,setOpen]=useState(false);const [profile,setProfile]=useState(false);const loc=useLocation();const nav=useNavigate();const current=menu.find(([path])=>loc.pathname.startsWith('/'+path))?.[1]||'Dashboard';
 useEffect(()=>{document.title=`${current} · Vakil Admin`},[current]);
 function logout(){localStorage.removeItem('vakilReactSession');localStorage.removeItem('vakilAdminToken');nav('/login')}
 return <div className="shell"><aside className={open?'open':''}><div className="side-logo"><span><Scale size={16}/></span><div><b>Vakil Admin</b><small>Admin Console · India</small></div><button onClick={()=>setOpen(false)}><X/></button></div><nav><small className="ld-nav-label">NAVIGATION</small>{menu.map(([path,label,Icon])=><NavLink key={path} to={'/'+path} onClick={()=>setOpen(false)}><Icon size={15}/><span>{label}</span></NavLink>)}</nav></aside>
 <div className="workspace"><header><button className="hamburger" onClick={()=>setOpen(true)}><Menu/></button><b className="product ld-brand"><span><Scale size={13}/></span> LegalDash</b><div className="head-right"><Alerts/><div className="profile"><button onClick={()=>setProfile(!profile)}><span className="avatar">AU</span><span><b>Admin User</b><small>Super Admin</small></span></button>{profile&&<div className="profile-menu"><b>{current}</b><button onClick={logout}><LogOut size={14}/> Sign out</button></div>}</div></div></header>
 <main><Routes>{menu.map(([path,,,Page])=><Route key={path} path={path} element={<Page/>}/>)}<Route path="requests" element={<Navigate to="/history"/>}/><Route path="users" element={<Navigate to="/customers"/>}/><Route path="*" element={<Navigate to="/dashboard"/>}/></Routes></main></div></div>}

export default function App(){return <Routes><Route path="/login" element={<Login/>}/><Route path="/*" element={<Shell/>}/></Routes>}

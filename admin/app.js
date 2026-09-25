const content = document.querySelector('#content');
const modal = document.querySelector('#modal');
const modalTitle = document.querySelector('#modalTitle');
const modalBody = document.querySelector('#modalBody');
const toast = document.querySelector('#appToast');

const lawyers = [
 {name:'Sarah Johnson',email:'sarah.johnson@lawfirm.com',specialty:'Corporate',status:'Approved',clients:24,rating:'4.9',price:'₹2,000/min'},
 {name:'Michael Chang',email:'m.chang@legal.com',specialty:'Criminal',status:'Pending',clients:11,rating:'4.7',price:'₹1,500/min'},
 {name:'Aaliyah Jackson',email:'aaliyah@justice.in',specialty:'Civil Law',status:'Approved',clients:37,rating:'4.8',price:'₹1,800/min'},
 {name:'Robert Miller',email:'robert@counsel.com',specialty:'Family Law',status:'Suspended',clients:8,rating:'4.3',price:'₹1,250/min'},
 {name:'David Klinger',email:'david@klinger.co',specialty:'Tax Law',status:'Approved',clients:19,rating:'4.6',price:'₹2,200/min'}
];
const customers = [
 {name:'Priya Sharma',email:'priya.sharma@gmail.com',phone:'+91 99250 64821',spent:'₹12,500',cases:4,risk:'Low'},
 {name:'Rahul Mehta',email:'rahul.mehta@mail.com',phone:'+91 98640 20855',spent:'₹8,400',cases:2,risk:'Low'},
 {name:'Aarav Jain',email:'aarav.jain@mail.com',phone:'+91 90012 37648',spent:'₹0',cases:1,risk:'Medium'},
 {name:'Vikram Singh',email:'vikram.singh@mail.com',phone:'+91 88200 19482',spent:'₹15,000',cases:5,risk:'High'},
 {name:'Neha Deshmukh',email:'neha.d@mail.com',phone:'+91 97120 65310',spent:'₹9,500',cases:3,risk:'Low'}
];
const prices = [
 {type:'Maximum per minute rate',current:'₹100.00/min',requested:'₹100.00/min',status:'Approved'},
 {type:'Minimum per minute rate',current:'₹25.00/min',requested:'₹30.00/min',status:'Approved'},
 {type:'Chat rate per minute',current:'₹100.00/min',requested:'₹75.00/min',status:'Approved'},
 {type:'Video call rate per minute',current:'₹200.00/min',requested:'₹250.00/min',status:'Approved'},
 {type:'Legal document review',current:'₹2,000/session',requested:'₹2,400/session',status:'Pending Approval'},
 {type:'Promotional discount',current:'10%',requested:'15%',status:'Change Requested'}
];

const stats = items => `<div class="stat-grid">${items.map(x=>`<article class="stat"><div class="stat-head"><span>${x.label}</span><span class="stat-icon">${x.icon||'◫'}</span></div><h2>${x.value}</h2><span class="trend ${x.down?'down':''}">${x.trend}</span></article>`).join('')}</div>`;
const head = (title,desc,action='',secondary='') => `<div class="page-head"><div><h1>${title}</h1><p>${desc}</p></div><div class="page-actions">${secondary?`<button class="btn light" data-action="${secondary}">Export report</button>`:''}${action?`<button class="btn primary" data-action="${action}">+ ${action}</button>`:''}</div></div>`;
const person = (name,email) => `<div class="person"><span class="avatar">${name.split(' ').map(x=>x[0]).join('').slice(0,2)}</span><span><strong>${name}</strong><small>${email}</small></span></div>`;
const badge = status => `<span class="badge ${/Pending|Medium|Change/.test(status)?'warn':/Suspended|High|Flagged/.test(status)?'red':''}">${status}</span>`;

function dashboard(){
 content.innerHTML=head('Main Dashboard','Registration Overview','','export')+stats([
  {label:'Total Registered Customers',value:'24,59,200',trend:'↗ 15% this month',icon:'♧'}, {label:'Total Registered Lawyers',value:'1,84,200',trend:'↗ 8.2% this month',icon:'♙'}, {label:'Lawyer Pending Verification',value:'1,280',trend:'↓ 3.1% this month',icon:'!',down:true}, {label:'Lawyer Currently Online',value:'4,520',trend:'↗ 12.4% this month',icon:'●'}
 ])+stats([{label:'Total Customer Payment',value:'₹12,45,000',trend:'↗ 12.5% from May'},{label:'Today Platform Commission',value:'₹2,14,500',trend:'↗ 8.4% from yesterday'},{label:'Lawyer Earning (Today)',value:'₹10,30,500',trend:'↗ 9.2% from May'},{label:'Pending Payouts',value:'₹45,20,000',trend:'35 payouts need review',down:true}])+`<div class="chart-grid"><section class="section"><div class="section-title"><div><h3>Monthly Revenue</h3><p>Platform performance for the last seven months</p></div><button class="row-actions">•••</button></div><div class="bars">${[51,66,46,74,88,78,58].map((h,i)=>`<div class="bar ${i===5?'active':''}" style="height:${h}%"><span>${['Jan','Feb','Mar','Apr','May','Jun','Jul'][i]}</span></div>`).join('')}</div></section><section class="section"><div class="section-title"><h3>Top Performing Lawyers</h3></div>${lawyers.slice(0,4).map((l,i)=>`<div class="ranking">${person(l.name,l.specialty)}<b>₹${[24,18,15,12][i]}k</b></div>`).join('')}</section></div>`;
 bindActions();
}

function lawyerPage(){content.innerHTML=head('Lawyer Management','Search, verify, and manage lawyer registrations, pricing, communication settings, fraud alerts, complaints, and consultation history from one place.','Add New Lawyer')+stats([{label:'Total Lawyers',value:'1,842',trend:'↗ 4.2% this month'},{label:'Pending Verifications',value:'128',trend:'42 due for review',down:true},{label:'Active & Online',value:'452',trend:'↗ 8.2% this month'},{label:'Avg Rating Quality',value:'96.2%',trend:'↑ 2.1% this month'}])+tableSection('Lawyer Directory','Search, filter, review, suspend, block, and inspect lawyer records.',lawyers,['Lawyer','Specialization','Verification','Price','Rating','Clients'],l=>[person(l.name,l.email),l.specialty,badge(l.status),l.price,l.rating,l.clients]);bindActions()}
function customersPage(){content.innerHTML=head('Customer Management','Monitor and review customer accounts, activity, verification, and risk controls.','Add Customer')+stats([{label:'Total Customers',value:'24,592',trend:'↗ 8.4% this month'},{label:'Lifetime Revenue',value:'₹14,25,000',trend:'↗ 11.2% this month'},{label:'Avg. Spend per Customer',value:'₹2,458',trend:'↗ 4.4% this month'},{label:'System Risk Flags',value:'5 Flagged',trend:'3 need urgent review',down:true}])+tableSection('Customer Directory & Ledger','Complete customer profiles, ledger and risk overview.',customers,['Customer','Mobile Number','Total Spent','Consultations','Risk Level'],c=>[person(c.name,c.email),c.phone,c.spent,c.cases,badge(c.risk)]);bindActions()}
function pricingPage(){content.innerHTML=head('Lawyer Pricing Management','Manage lawyer pricing plans, rates, platform commission, discounts, and lawyer-specific overrides.','Create New Rate')+stats([{label:'Average Customer Rate',value:'₹20.00/min',trend:'↓ 2.4% this month',down:true},{label:'Pending Approvals',value:'18 Rates',trend:'6 past due',down:true},{label:'Max Rate Available',value:'₹45.00/min',trend:'Stable this month'},{label:'Platform Commission',value:'20%',trend:'Available for all rates'}])+tableSection('India Rate Configuration Matrix','Review and approve current and requested pricing rules.',prices,['Rate Type','Current Rate','Requested Rate','Approval Status'],p=>[p.type,p.current,p.requested,badge(p.status)])+`<section class="section"><div class="section-title"><div><h3>Commission Deduction Examples</h3><p>Approximate fee breakdown at current platform rates</p></div></div><div class="stat-grid"><div class="stat"><span>Chat consultation</span><h2>₹800</h2><span class="trend">Lawyer gets ₹640</span></div><div class="stat"><span>Video call</span><h2>₹1,600</h2><span class="trend">Lawyer gets ₹1,280</span></div></div></section>`;bindActions()}

function tableSection(title,desc,data,headers,row){return `<section class="section"><div class="section-title"><div><h3>${title}</h3><p>${desc}</p></div><div class="filters"><label class="search">⌕<input data-search placeholder="Search records..."></label><select class="filter" data-filter><option>All statuses</option><option>Approved</option><option>Pending</option><option>Suspended</option><option>High</option></select></div></div><div class="table-wrap"><table><thead><tr>${headers.map(h=>`<th>${h}</th>`).join('')}<th>Actions</th></tr></thead><tbody>${data.map((item,i)=>`<tr data-row="${Object.values(item).join(' ').toLowerCase()}">${row(item).map(v=>`<td>${v}</td>`).join('')}<td><button class="row-actions" data-edit="${item.name||item.type}" data-index="${i}">•••</button></td></tr>`).join('')}</tbody></table></div></section>`}

const generic = {
 documents:['User Documents Management','Review submitted IDs, legal documents, and verification records.','▤'],video:['Online Video System','Monitor video consultations and platform connectivity.','▶'],appointments:['Admin Appointments','Schedule and manage administrative appointments.','□'],verification:['Lawyer Verify Management','Review verification requests and compliance checks.','✓'],content:['Content Management','Publish and manage platform pages, articles, and notices.','▣'],complaints:['Complaint & Dispute Management','Investigate complaints and resolve platform disputes.','!'],communication:['Communication Management','Manage system messages, email templates, and announcements.','✉'],billing:['Billing and Revenue','Review invoices, transactions, payouts, and revenue.','₹'],reports:['Report and Analytics','Explore operational reports and platform analytics.','◫']
};
function genericPage(key){const [title,desc,icon]=generic[key];content.innerHTML=head(title,desc,`Create ${title.split(' ')[0]}`)+`<section class="section empty-page"><div><div class="empty-icon">${icon}</div><h2>${title}</h2><p>This workspace is ready. Use the action above to create a record, or connect this view to your backend API to load live data.</p><button class="btn primary" data-action="Create record">Create first record</button></div></section>`;bindActions()}

function openModal(action,item=''){modalTitle.textContent=item?`Manage ${item}`:action;modalBody.innerHTML=`<label>Name<input id="recordName" value="${item}" placeholder="Enter a name"></label><label>Status<select><option>Active</option><option>Pending</option><option>Suspended</option></select></label><label>Internal note<textarea rows="3" placeholder="Add an optional note"></textarea></label>`;modal.classList.add('show');document.querySelector('#recordName').focus()}
function closeModal(){modal.classList.remove('show')}
function showToast(msg){toast.textContent=msg;toast.classList.add('show');clearTimeout(showToast.t);showToast.t=setTimeout(()=>toast.classList.remove('show'),2600)}
function bindActions(){
 document.querySelectorAll('[data-action]').forEach(b=>b.addEventListener('click',()=>openModal(b.dataset.action)));
 document.querySelectorAll('[data-edit]').forEach(b=>b.addEventListener('click',()=>openModal('Manage record',b.dataset.edit)));
 const search=document.querySelector('[data-search]');if(search)search.addEventListener('input',()=>document.querySelectorAll('tbody tr').forEach(r=>r.hidden=!r.dataset.row.includes(search.value.toLowerCase())));
 const filter=document.querySelector('[data-filter]');if(filter)filter.addEventListener('change',()=>document.querySelectorAll('tbody tr').forEach(r=>r.hidden=filter.value!=='All statuses'&&!r.dataset.row.includes(filter.value.toLowerCase())));
}

function route(){const page=location.hash.slice(1)||'dashboard';document.querySelectorAll('#mainNav a').forEach(a=>a.classList.toggle('active',a.dataset.page===page));({dashboard,lawyers:lawyerPage,pricing:pricingPage,customers:customersPage}[page]||(()=>genericPage(generic[page]?page:'reports')))();document.querySelector('#sidebar').classList.remove('open');content.focus()}
document.querySelector('#mainNav').addEventListener('click',e=>{const a=e.target.closest('a');if(a&&location.hash===a.hash){e.preventDefault();route()}});
window.addEventListener('hashchange',route);document.querySelector('#menuBtn').onclick=()=>document.querySelector('#sidebar').classList.add('open');document.querySelector('#closeMenu').onclick=()=>document.querySelector('#sidebar').classList.remove('open');
document.querySelector('#profileBtn').onclick=()=>document.querySelector('#profilePop').classList.toggle('show');document.querySelector('[data-profile]').onclick=()=>{document.querySelector('#profilePop').classList.remove('show');openModal('Profile settings','Admin User')};document.querySelector('[data-logout]').onclick=()=>{localStorage.removeItem('vakilAdminSession');location.href='index.html'};document.querySelector('#notifyBtn').onclick=()=>showToast('You have 3 pending verification requests.');
document.querySelectorAll('[data-close]').forEach(b=>b.onclick=closeModal);modal.addEventListener('click',e=>{if(e.target===modal)closeModal()});document.querySelector('#modalSave').onclick=()=>{closeModal();showToast('Changes saved successfully.')};
document.addEventListener('keydown',e=>{if(e.key==='Escape')closeModal()});
try{const session=JSON.parse(localStorage.getItem('vakilAdminSession'));if(session?.name)document.querySelector('#adminName').textContent=session.name}catch{}
route();

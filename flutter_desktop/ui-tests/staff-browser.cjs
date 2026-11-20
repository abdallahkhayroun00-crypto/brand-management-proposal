const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
(async()=>{
 const fixture={employees:[{id:1,name:'Ömer',active:true}],localMenu:[{id:0,name:'Falafel Dürüm',price:140,category:'wrap',image:'assets/real.webp'},{id:1,name:'Ayran',price:45,category:'drink'},{id:32,name:'Şambali',price:100,category:'dessert',active:false}],orders:[{id:1200,dailyNumber:1,numberDay:'2026-11-15',source:'Masa',table:3,serviceStatus:'Hazırlanıyor',totalCents:28000,paidCents:0,dueCents:28000,batches:[{id:1,lines:[{productId:0,name:'Falafel Dürüm',price:140,qty:2,note:'Sos ayrı',removed:['Domates']}]}]}]};
 let state,revision,mode,posts,receipts,prints;
 const html=fs.readFileSync(path.join(__dirname,'../assets/staff.html'));
 function recalc(o){o.totalCents=o.batches.flatMap(b=>b.lines).filter(l=>!l.voided&&!l.correction).reduce((n,l)=>n+Math.round(l.price*100)*l.qty,0);o.dueCents=o.totalCents-o.paidCents;for(const g of o.guestChecks||[])g.balanceCents=g.allocations.reduce((n,a)=>n+a.cents,0)-(o.testPayments||[]).filter(p=>p.guestId===g.id).reduce((n,p)=>n+p.amount,0);}
 async function route(r){const u=new URL(r.request().url());
  if(u.pathname==='/api/bootstrap')return r.fulfill({json:{state,revision}});
  if(['/api/staff/orders','/api/staff/actions'].includes(u.pathname)){
   const p=r.request().postDataJSON();posts.push(p);
   if(mode==='conflict')return r.fulfill({status:409,json:{error:'conflict'}});
   if(receipts.has(p.requestId))return r.fulfill({json:receipts.get(p.requestId)});
   let o=state.orders.find(o=>p.orderId?o.id===p.orderId:p.source==='Masa'&&o.table===p.table);
   if(u.pathname==='/api/staff/orders'){
    if(!o){o={id:1201,dailyNumber:2,source:p.source,table:p.table,serviceStatus:'Hazırlanıyor',paidCents:0,batches:[]};state.orders.push(o);}
    o.batches.push({id:o.batches.length+1,lines:p.lines.map(l=>({...l,name:state.localMenu.find(x=>x.id===l.productId).name,price:state.localMenu.find(x=>x.id===l.productId).price}))});o.serviceStatus='Hazırlanıyor';
   }else{
    if(p.action==='editLine'){const [batch,index]=p.key.split(':').map(Number),l=o.batches.find(b=>b.id===batch).lines[index];Object.assign(l,{basePrice:l.basePrice??l.price,qty:p.qty,note:p.note,removed:p.removed,voided:p.qty===0,adjustmentCents:p.adjustmentCents||0});l.price=l.basePrice+l.adjustmentCents/100;}
    if(p.action==='move')o.table=p.table;
    if(p.action==='status')o.serviceStatus=p.status;
    if(p.action==='pay'||p.action==='payMixed'){o.paidCents+=p.amountCents;(o.testPayments??=[]).push({guestId:p.guestId,amount:p.amountCents});if(p.printReceipt)prints++;}
    if(p.action==='splitEqual')o.guestChecks=Array.from({length:p.count},(_,i)=>({id:i+1,name:'Kişi '+(i+1),allocations:[{key:'1:0',cents:o.totalCents/p.count}]}));
    if(p.action==='addGuest')(o.guestChecks??=[]).push({id:(o.guestChecks||[]).length+1,name:p.name,allocations:[]});
    if(p.action==='allocate'){const g=o.guestChecks.find(g=>g.id===p.guestId);g.allocations=g.allocations.filter(a=>a.key!==p.key);if(p.cents)g.allocations.push({key:p.key,cents:p.cents});}
    if(p.action==='resetGuests')o.guestChecks=[];
    if(p.action==='delete')state.orders=state.orders.filter(x=>x.id!==o.id);
    if(p.action==='close')o.closed=true;
   }
   recalc(o);const result={ok:true,orderId:o.id,orderNumber:String(o.dailyNumber).padStart(4,'0'),revision:++revision};receipts.set(p.requestId,result);
   if(mode==='lost')return r.abort('failed');return r.fulfill({json:result});
  }
  if(u.pathname.startsWith('/assets/fonts/'))return r.fulfill({contentType:'font/ttf',body:fs.readFileSync(path.join(__dirname,'../assets/brand/fonts',path.basename(u.pathname)))});
  if(u.pathname==='/assets/nohut-logo.webp')return r.fulfill({contentType:'image/webp',body:fs.readFileSync(path.join(__dirname,'../assets/brand/nohut-logo.webp'))});
  return r.fulfill({contentType:'text/html; charset=utf-8',body:html});
 }
 const browser=await chromium.launch({headless:true,executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH});
 try{for(const width of [320,390,768,1280]){
  state=structuredClone(fixture);revision=1;mode='ok';posts=[];receipts=new Map();prints=0;
  const ctx=await browser.newContext({viewport:{width,height:width===320?568:844}}),page=await ctx.newPage(),errors=[];
  await page.route('http://pos.test/**',route);page.on('pageerror',e=>errors.push(e.message));page.on('dialog',d=>d.accept());
  await page.goto('http://pos.test/');await page.locator('#staff option[value="1"]').waitFor({state:'attached'});await page.locator('#staff').selectOption('1');
  fs.mkdirSync(path.join(__dirname,'../build'),{recursive:true});
  await page.screenshot({path:path.join(__dirname,`../build/staff-brand-${width}.png`),fullPage:true});
  const fit=await page.locator('[data-screen="tables"]').evaluate(screen=>{
    const bottom=screen.getBoundingClientRect().bottom;
    return [...screen.querySelectorAll('[data-floor-table]')].every(tile=>{
      const bounds=tile.getBoundingClientRect();
      return bounds.bottom<=bottom&&bounds.width>=44&&bounds.height>=44;
    });
  });
  assert.equal(fit,true,'all tables fit on the opening page with touch targets');
  if(width<=550)assert.equal(await page.locator('.top-nav').evaluate(el=>el.scrollWidth<=el.clientWidth),true);
  await page.locator('[data-floor-table="1"]').click();
  if(width<=550){
    assert.equal(await page.locator('[data-screen="menu"]').evaluate(el=>getComputedStyle(el).overflowY),'auto');
    assert.equal(await page.locator('#menu').evaluate(el=>getComputedStyle(el).overflowY),'visible');
  }
  assert.equal(await page.locator('#menu img').count(),0,'product images removed');
  assert.equal(await page.locator('#menu').getByText('Şambali',{exact:true}).count(),0);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollHeight<=innerHeight+1),true,'app itself needs no long page scrolling');
  await page.locator('[data-add="0"]').click();await page.locator('[data-add="0"]').click();assert.equal(await page.locator('#cart-count').innerText(),'2');
  await page.locator('[data-custom="0"]').click();await page.locator('#custom-note').fill('Acılı');await page.locator('#custom-form button[type=submit]').click();
  await page.locator('.top-nav [data-view=cart]').click();assert.equal(await page.locator('.cart-line').count(),2,'different variants stay separate');
  await page.locator('[data-note]').first().fill('Sos ayrı');await page.locator('[data-note]').first().focus();
  await page.evaluate(()=>{window.noteNode=document.querySelector('[data-note]');});
  await page.locator('#reload').click();await page.waitForFunction(()=>document.activeElement!==null);await page.locator('[data-note]').first().focus();
  assert.equal(await page.evaluate(()=>window.noteNode===document.querySelector('[data-note]')),true,'refresh preserves input node');
  mode='conflict';await page.locator('#submit').click();await page.waitForFunction(()=>document.querySelector('#notice').textContent.includes('Sepet korundu'));assert.equal(await page.locator('.cart-line').count(),2);
  mode='lost';await page.locator('#submit').click();await page.locator('#retry').waitFor({state:'visible'});const id=posts.at(-1).requestId;mode='ok';await page.locator('#retry').click();await page.waitForFunction(()=>document.querySelector('#notice').textContent.includes('kaydedildi'));assert.equal(posts.at(-1).requestId,id);assert.equal(state.orders.length,2);
  await page.locator('#orders [data-open="1200"]').click();await page.locator('[data-edit-line]').first().click();await page.locator('#custom-qty').fill('1');await page.locator('#custom-note').fill('Az sos');await page.locator('#custom-form button[type=submit]').click();await page.waitForFunction(()=>!document.querySelector('#customize').open);assert.equal(state.orders[0].batches[0].lines[0].qty,1);
  await page.locator('#move-order').click();await page.locator('#move-table').selectOption('2');await page.locator('#move-form button[type=submit]').click();await page.waitForFunction(()=>!document.querySelector('#move-dialog').open);assert.equal(state.orders[0].table,2);assert.equal(state.orders[0].id,1200);
  await page.locator('[data-existing-add]').click();await page.locator('[data-category=drink]').click();await page.locator('[data-add="1"]').click();await page.locator('.top-nav [data-view=cart]').click();await page.locator('#submit').click();await page.waitForFunction(()=>document.querySelector('[data-screen=orders]').hidden===false);assert.equal(state.orders.length,2,'additional batch keeps same order');
  await page.locator('#orders [data-open="1200"]').click();
  assert.equal(await page.locator('#advance-status').count(),0,'table orders have no delivery status');
  await page.locator('#pay-order').click();await page.locator('#pay-print').selectOption('yes');mode='lost';await page.locator('#payment-form button[type=submit]').click();await page.locator('#retry').waitFor({state:'visible'});await page.waitForFunction(()=>!document.querySelector('#payment-dialog').open);mode='ok';await page.locator('#retry').click();await page.waitForFunction(()=>document.querySelector('#notice').textContent.includes('kaydedildi'));assert.equal(prints,1);assert.equal(state.orders[0].dueCents,0);
  await page.locator('#close-order').click();await page.waitForFunction(()=>document.querySelector('#order-detail').textContent.includes('Hesap kapalı'));assert.equal(state.orders[0].closed,true);
  state=structuredClone(fixture);revision++;receipts.clear();prints=0;mode='ok';await page.reload();await page.locator('#staff option[value="1"]').waitFor({state:'attached'});await page.locator('#staff').selectOption('1');
  await page.locator('.top-nav [data-view=orders]').click();await page.locator('[data-open="1200"]').click();await page.locator('[data-edit-line]').click();
  await page.locator('#custom-note').fill('Ek sembusek');await page.locator('#custom-adjustment').fill('+10');await page.locator('[data-ingredient="Domates"]').click();await page.locator('#custom-form button[type=submit]').click();await page.waitForFunction(()=>!document.querySelector('#customize').open);assert.equal(state.orders[0].totalCents,30000);assert.equal(state.orders[0].batches[0].lines[0].removed.includes('Domates'),false);
  await page.locator('#split-order').click();await page.locator('#equal-split').click();await page.waitForFunction(()=>!document.querySelector('#split-dialog').open);assert.equal(state.orders[0].guestChecks.length,2);
  await page.locator('[data-pay-guest="1"]').click();await page.locator('#pay-method').selectOption('Karışık');await page.locator('#mixed-cash').fill('50');await page.locator('#card-confirmed').check();await page.locator('#pay-print').selectOption('no');await page.locator('#payment-form button[type=submit]').click();await page.waitForFunction(()=>!document.querySelector('#payment-dialog').open);assert.equal(state.orders[0].guestChecks[0].balanceCents,0);assert.equal(posts.at(-1).cashCents,5000);
  await page.locator('[data-pay-guest="2"]').click();await page.locator('#pay-print').selectOption('no');await page.locator('#payment-form button[type=submit]').click();await page.waitForFunction(()=>!document.querySelector('#payment-dialog').open);assert.equal(state.orders[0].dueCents,0);assert.equal(prints,0);
  mode='lost';await page.locator('#delete-order').click();await page.locator('#retry').waitFor({state:'visible'});mode='ok';await page.locator('#retry').click();await page.waitForFunction(()=>document.querySelector('#order-detail').textContent.includes('Hesap kapalı'));assert.equal(state.orders.length,0);
  console.log(`PASS modifiers, ingredient buttons, person split, mixed payment and deletion retry at ${width}px`);
  state.trendyolGoOrders=[
    {orderNumber:'OPEN-OLD',dailyNumber:2,numberDay:'2026-10-02',status:'Picking',lines:[]},
    {orderNumber:'DELIVERED',dailyNumber:3,numberDay:'2026-11-18',status:'Delivered',lines:[]},
    {orderNumber:'CANCELLED',dailyNumber:4,numberDay:'2026-11-18',status:'Cancelled',lines:[]},
    {orderNumber:'UNSUPPLIED',dailyNumber:5,numberDay:'2026-11-18',status:'UnSupplied',lines:[]},
  ];
  revision++;
  await page.locator('.top-nav [data-view=orders]').click();
  await page.locator('#order-filter').selectOption('Trendyol Go');
  await page.locator('#reload').click();
  await page.locator('#orders .platform-order').filter({hasText:'OPEN-OLD'}).waitFor();
  assert.equal(await page.locator('#orders .platform-order').count(),1,'only active platform orders appear');
  assert.equal(await page.locator('#order-count').innerText(),'1');
  state.trendyolGoOrders[0].status='Delivered';
  revision++;
  await page.locator('#reload').click();
  await page.locator('#orders').getByText('Açık sipariş yok.').waitFor();
  assert.equal(await page.locator('#order-count').innerText(),'0');
  assert.deepEqual(errors,[]);assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  console.log(`PASS staff lifecycle at ${width}px: no photos, compact menu, variants, conflict, retry, edit, move, add, payment, optional receipt, close`);
  await ctx.close();
 }}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1});


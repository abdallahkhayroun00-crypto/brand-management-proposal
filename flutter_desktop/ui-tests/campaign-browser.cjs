const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
(async()=>{
 const html=fs.readFileSync(path.join(__dirname,'../assets/staff.html'));
 const components=[0,0,1,1].map((id,slot)=>({slot,productId:id,name:id?'Küçük Ayran':'Falafel Dürüm',qty:1,price:id?25:140,basePrice:id?25:140,note:'',removed:[],adjustmentCents:0}));
 const browser=await chromium.launch({headless:true,executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH});
 try{for(const width of [320,390,768,1280]){
  const fixture={employees:[{id:1,name:'Ömer',active:true}],orders:[],localMenu:[{id:-100,name:'2’li Menü',campaignId:'two',category:'campaign',price:300,components},{id:0,name:'Falafel Dürüm',category:'wrap',price:140},{id:1,name:'Küçük Ayran',category:'drink',price:25}]};
  let posts=[],revision=1,mode='ok';
  const ctx=await browser.newContext({viewport:{width,height:844}}),page=await ctx.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.route('http://pos.test/**',r=>{
   const url=new URL(r.request().url());
   if(url.pathname==='/api/bootstrap')return r.fulfill({json:{state:fixture,revision}});
   if(url.pathname==='/api/staff/orders'){posts.push(r.request().postDataJSON());return r.fulfill({status:409,json:{error:'conflict'}})}
   if(url.pathname.startsWith('/assets/'))return r.fulfill({status:404,body:''});
   return r.fulfill({contentType:'text/html; charset=utf-8',body:html});
  });
  await page.goto('http://pos.test/');await page.locator('#staff option[value="1"]').waitFor({state:'attached'});await page.locator('#staff').selectOption('1');
  assert.equal(await page.locator('#categories button').first().innerText(),'Kampanyalar');
  await page.locator('.top-nav [data-view=menu]').click();
  await page.locator('[data-category=campaign]').click();assert.equal(await page.locator('.product').count(),1);
  await page.locator('[data-custom="-100"]').click();assert.equal(await page.locator('[data-component]').count(),4);
  await page.locator('[data-component="0"]').click();await page.locator('#component-chips [data-ingredient="Domates"]').click();await page.locator('#component-note').fill('Ek falafel');await page.locator('#component-adjustment').fill('+10');await page.locator('#component-form button[type=submit]').click();
  await page.locator('[data-component="1"]').click();assert.equal(await page.locator('#component-note').inputValue(),'');assert.equal(await page.locator('#component-removed').inputValue(),'');await page.locator('#component-note').fill('Sos ayrı');await page.locator('#component-form button[type=submit]').click();
  await page.locator('#custom-qty').fill('2');await page.locator('#custom-form button[type=submit]').click();await page.locator('.top-nav [data-view=cart]').click();
  assert.match(await page.locator('#total').innerText(),/620,00/);assert.equal(await page.locator('.cart-line').count(),1);
  await page.locator('[data-cart-custom]').click();await page.locator('[data-component="0"]').click();assert.equal(await page.locator('#component-note').inputValue(),'Ek falafel');await page.locator('#component-adjustment').fill('+20');await page.locator('#component-form button[type=submit]').click();await page.locator('#custom-form button[type=submit]').click();
  assert.match(await page.locator('#total').innerText(),/640,00/);
  await page.locator('#submit').click();await page.waitForFunction(()=>document.querySelector('#notice').textContent.includes('Sepet korundu'));
  assert.equal(posts[0].lines[0].components.length,4);assert.equal(posts[0].lines[0].components[0].adjustmentCents,2000);assert.equal(posts[0].lines[0].components[1].note,'Sos ayrı');assert.equal(posts[0].lines[0].qty,2);
  assert.equal(await page.locator('.cart-line').count(),1);assert.deepEqual(errors,[]);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  if(width===390)await page.screenshot({path:path.join(__dirname,'campaign-phone.png'),fullPage:true});
  await page.locator('[data-cart-custom]').click();await page.locator('#custom-qty').fill('0');await page.locator('#custom-form button[type=submit]').click();assert.equal(await page.locator('.cart-line').count(),0);
  await page.locator('.top-nav [data-view=menu]').click();await page.locator('[data-add="-100"]').click();await page.locator('.top-nav [data-view=cart]').click();await page.locator('[data-cart-custom]').click();fixture.localMenu.shift();revision++;await page.evaluate(()=>refresh());await page.locator('#custom-form button[type=submit]').click();assert.match(await page.locator('#custom-error').innerText(),/sepet korundu/);assert.equal(await page.locator('.cart-line').count(),1);await page.locator('#custom-cancel').click();
  console.log(`PASS campaign category, component customization, independent wraps, no double charge and conflict at ${width}px`);await ctx.close();
 }}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});

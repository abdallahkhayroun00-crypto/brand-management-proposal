'use strict';
let lang='tr', category='drink';
const byId=id=>document.getElementById(id);
const escapeHtml=value=>String(value).replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
const categoryOrder=['all','wrap','plate','fatte','meze','salad','side','dessert','drink'];
const categoryCrops={wrap:[170,495,35,40],plate:[304,497,38,38],fatte:[451,497,41,38],meze:[560,497,41,38],salad:[689,497,43,38],side:[832,495,41,41],dessert:[951,496,41,40]};
const categoryIcons={all:'#all',wrap:'🌯',plate:'🧆',fatte:'🥣',meze:'🥣',salad:'🥗',side:'🥟',dessert:'🍰',drink:'#drink'};
const descriptions={all:['Lübnan mutfağından taze ve doğal lezzetler','Fresh, natural flavours from Lebanese cuisine'],wrap:['Taptaze malzemeler, bol lezzet','Fresh ingredients, wrapped with flavour'],plate:['Doyurucu tabaklar, doğal lezzetler','Generous plates, naturally delicious'],fatte:['Lübnan mutfağının sıcacık klasiği','A comforting Lebanese classic'],meze:['Sofranıza renk katan mezeler','A colourful selection of mezze'],salad:['Taze, hafif ve renkli','Fresh, light and colourful'],side:['Lezzeti tamamlayan seçenekler','A little something on the side'],dessert:['Yemeğinize tatlı bir son','A sweet finish to your meal'],drink:['Serinletici ve doğal içecekler','Refreshing drinks, naturally delicious']};
// Approved mockup photographs are displayed through SVG viewBoxes. All menu
// names, descriptions and prices are live HTML, independent of the artwork.
const referencePhotos={
 'Büyük Ayran':[35,689,180,180], 'Küçük Ayran':[231,689,180,180],
 'Doğanay Acılı Şalgam':[428,689,180,180], 'Doğanay Acısız Şalgam':[624,689,180,180],
 'Niğde Gazozu':[821,689,180,180], 'Çamlıca Gazoz':[1017,689,180,180],
 'Didi Limon Aromalı Soğuk Çay':[35,988,153,170],
 'Didi Çilek Aromalı Soğuk Çay':[203,988,153,170],
 'Didi Şeftali Aromalı Soğuk Çay':[371,988,153,170],
 'Sarıyer Portakal Aromalı Gazoz':[539,988,153,170],
 'Sarıyer Mandalina Aromalı Gazoz':[707,988,153,170],
 'Beypazarı Mandalina Aromalı Maden Suyu':[875,988,153,170],
 'Su':[1043,988,153,170]
};
const drinkOrder=Object.keys(referencePhotos);
const drinkDisplayNames={'Büyük Ayran':['Eker Ayran (Büyük)','Eker Ayran (Large)'],'Küçük Ayran':['Eker Ayran (Küçük)','Eker Ayran (Small)'],'Doğanay Acılı Şalgam':['Doğanay Şalgam (Acı)','Doğanay Şalgam (Spicy)'],'Doğanay Acısız Şalgam':['Doğanay Şalgam (Acısız)','Doğanay Şalgam (Mild)']};
function productVisual(item,index){
 const crop=referencePhotos[item[1]];
 if(crop)return `<svg class="product-photo" viewBox="${crop.join(' ')}" preserveAspectRatio="xMidYMid slice" role="img" aria-label="${escapeHtml(lang==='tr'?item[1]:item[2])}"><image href="assets/menu-reference.jpeg" width="1230" height="1278"/></svg>`;
 const source=photoMap[item[1]],illustration=pic(item[0],index);
 if(source)return `<img class="real-dish-image" src="${escapeHtml(source)}" alt="${escapeHtml(lang==='tr'?item[1]:item[2])}" loading="lazy"><span class="fallback-art" hidden aria-hidden="true">${illustration}</span>`;
 return `<span class="fallback-art" aria-hidden="true">${illustration}</span>`;
}
function renderCategories(){
 byId('categories').setAttribute('aria-label',lang==='tr'?'Menü kategorileri':'Menu categories');
 byId('categories').innerHTML=categoryOrder.map(key=>{
  const row=categories.find(c=>c[0]===key),label=row[lang==='tr'?1:2],icon=categoryIcons[key];
  const crop=categoryCrops[key];
  const visual=crop?`<svg viewBox="${crop.join(' ')}" aria-hidden="true"><image href="assets/menu-reference.jpeg" width="1230" height="1278"/></svg>`:icon.startsWith('#')?`<svg aria-hidden="true"><use href="${icon}"/></svg>`:icon;
  return `<button class="category" type="button" data-category="${key}" aria-pressed="${key===category}"><span class="category-icon" aria-hidden="true">${visual}</span><span>${label}</span></button>`;
 }).join('');
 const nav=byId('categories'),selected=nav.querySelector('[aria-pressed="true"]');
 if(selected && nav.scrollWidth>nav.clientWidth)nav.scrollLeft=Math.max(0,selected.offsetLeft-nav.clientWidth+selected.offsetWidth+10);
}
function renderMenu(){
 const tr=lang==='tr',current=categories.find(c=>c[0]===category);
 byId('sectionTitle').textContent=current[tr?1:2];
 byId('sectionDescription').textContent=descriptions[category][tr?0:1];
 byId('search').placeholder=category==='drink'?(tr?'İçeceklerde ara...':'Search drinks...'):(tr?'Menüde ara...':'Search menu...');
 byId('search').setAttribute('aria-label',tr?'Menüde ara':'Search menu');
 const normalize=value=>String(value).toLocaleLowerCase('tr-TR').normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/ı/g,'i');
 const query=normalize(byId('search').value.trim());
 let items=data.filter(item=>(category==='all'||category===item[0])&&normalize([item[1],item[2],item[4],item[5],...(drinkDisplayNames[item[1]]||[])].join(' ')).includes(query));
 if(category==='drink')items=items.slice().sort((a,b)=>{
  const rank=item=>drinkOrder.includes(item[1])?drinkOrder.indexOf(item[1]):drinkOrder.length+data.indexOf(item);
  return rank(a)-rank(b);
 });
 byId('grid').innerHTML=items.map((item,index)=>{
  const displayName=drinkDisplayNames[item[1]]?.[tr?0:1]||item[tr?1:2];
  const price=item[3]==null?'':`${escapeHtml(item[3])} TL`;
  const desc=item[0]==='drink'?'':`<p class="desc">${escapeHtml(item[tr?4:5])}</p>`;
  return `<article class="dish"><div class="art">${productVisual(item,index)}</div><div class="dish-text"><h3 class="name">${escapeHtml(displayName)}</h3><span class="price">${price}</span>${desc}</div></article>`;
 }).join('');
 byId('grid').querySelectorAll('img').forEach(image=>image.addEventListener('error',()=>{image.hidden=true;image.nextElementSibling.hidden=false;},{once:true}));
 byId('empty').hidden=items.length>0;
 byId('empty').textContent=tr?'Ürün bulunamadı. Başka bir kelime deneyin.':'No items found. Try another search.';
 byId('counter').textContent=`${items.length} ${tr?'ürün':'items'}`;
}
function setLanguage(next){
 lang=next;document.documentElement.lang=lang;
 byId('tr').setAttribute('aria-pressed',String(lang==='tr'));byId('en').setAttribute('aria-pressed',String(lang==='en'));
 document.querySelectorAll('[data-tr][data-en]').forEach(node=>{
  const parts=node.dataset[lang].split('|');node.replaceChildren();
  parts.forEach((part,index)=>{if(index)node.append(document.createElement('br'));node.append(document.createTextNode(part));});
 });
 try{localStorage.setItem('nohut-lang',lang);}catch(_){}
 renderCategories();renderMenu();
}
byId('tr').addEventListener('click',()=>setLanguage('tr'));
byId('en').addEventListener('click',()=>setLanguage('en'));
byId('search').addEventListener('input',renderMenu);
byId('categories').addEventListener('click',event=>{
 const button=event.target.closest('[data-category]');if(!button)return;
 category=button.dataset.category;byId('search').value='';
 byId('categories').querySelectorAll('button').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));
 renderMenu();
 const reduced=window.matchMedia('(prefers-reduced-motion: reduce)').matches;
 if(window.scrollY>byId('categories').offsetTop)byId('fullMenu').scrollIntoView({behavior:reduced?'instant':'smooth',block:'start'});
});
let initialLanguage='tr';try{if(localStorage.getItem('nohut-lang')==='en')initialLanguage='en';}catch(_){}
setLanguage(initialLanguage);

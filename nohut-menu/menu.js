'use strict';
let lang='tr', category='wrap';
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
const restaurantPhotos = {
 "Kıymalı Sembusek (4 Adet)": "assets/products/tgo-9295371_1738157983821.jpg",
 "Nohut Özel Dürüm": "assets/products/ys-68085842.jpg",
 "Falafel Dürüm": "assets/products/ys-68085839.jpg",
 "Patatesli Patlıcanlı Falafel Dürüm": "assets/products/ys-76539202.jpg",
 "Kibbe (3 Adet)": "assets/products/kibbe-6003492c.jpg",
 "Nohut Özel Tabağı": "assets/products/nohut-ozel-d953124a.jpg",
 "Sarma (6 Adet)": "assets/products/tgo-9295403_1738157981309.jpg",
 "Tereyağlı Fatte": "assets/products/tgo-9295446_1738157998385.jpg",
 "Patates Dürüm": "assets/products/ys-68085841.jpg",
 "Vegan Özel Tabağı": "assets/products/vegan-ozel-69312e96.jpg",
 "Beyrut Tabağı": "assets/products/beyrut-9c6b1b3a.jpg",
 "Kuruyemişli Humus": "assets/meze-cutouts/kuruyemisli-humus.png",
 "Peynirli Sembusek (4 Adet)": "assets/products/ys-68085846.jpg",
 "Falafel Porsiyon": "assets/products/falafel-porsiyon-instagram-original.webp",
 "Bakla Tabağı": "assets/products/ys-68085833.jpg",
 "Patlıcanlı Fatte": "assets/products/ys-68085836.jpg",
 "Tereyağında Kuruyemişli Fatte": "assets/products/ys-68085837.jpg",
 "Patatesli Falafel Dürüm": "assets/products/ys-72772393.jpg",
 "Ispanaklı Sembusek (4 Adet)": "assets/products/ys-68085845.jpg",
 "Patates Kızartması": "assets/products/ys-72263052.jpg",
 "Sade Humus": "assets/meze-cutouts/sade-humus-top.png",
 "Babagannuş": "assets/meze-cutouts/babagannus-updated.png",
 "Mütebbel": "assets/meze-cutouts/mutebbel.png",
 "Pancarlı Humus": "assets/meze-cutouts/pancarli-humus.png",
 "Muhammara": "assets/meze-cutouts/muhammara.png",
 "Tabbule": "assets/products/ys-68085854.jpg",
 "Fettuş": "assets/products/ys-68085855.jpg",
 "Falafel Salatası": "assets/products/instagram-falafel-salatasi.webp",
 "Kutu Cola Turka": "assets/products/ys-68085857.jpg",
 "Şişe Cola Turka": "assets/products/ys-68085858.jpg",
 "Niğde Gazozu": "assets/products/ys-75005278.jpg",
 "Doğanay Acılı Şalgam": "assets/products/ys-69711494.jpg",
 "Doğanay Acısız Şalgam": "assets/products/ys-69712096.jpg",
 "Küçük Ayran": "assets/products/ys-68085859.jpg",
 "Beypazarı Maden Suyu": "assets/products/ys-68085860.jpg",
 "Su": "assets/products/ys-68085861.jpg"
};
const mezePlateGeometry={"Sade Humus":{"width":1254,"height":1254,"matrix":[0.7312,-0.000248,-0.000248,0.739627,42.369389,42.922908]},"Kuruyemişli Humus":{"width":1254,"height":1254,"matrix":[0.719352,-0.000638,-0.000638,0.722961,41.809196,51.435731]},"Babagannuş":{"width":1254,"height":1254,"matrix":[0.710531,0.000526,0.000526,0.713243,54.855174,52.317941]},"Pancarlı Humus":{"width":1254,"height":1254,"matrix":[0.74633,0.001627,0.001627,0.754575,32.269832,27.221773]},"Mütebbel":{"width":1254,"height":1254,"matrix":[0.703334,0.000529,0.000529,0.70583,58.431362,52.554385]},"Muhammara":{"width":1254,"height":1254,"matrix":[0.757604,-0.002332,-0.002332,0.753512,25.043649,26.179502]}};
function menuName(item){
 return lang==='ar'?arabicMenu.items[item[1]][0]:(drinkDisplayNames[item[1]]?.[lang==='tr'?0:1]||item[lang==='tr'?1:2]);
}
function menuDescription(item){return lang==='ar'?arabicMenu.items[item[1]][1]:item[lang==='tr'?4:5];}
function productVisual(item,index){
 const actualPhoto=restaurantPhotos[item[1]],isCutout=actualPhoto?.startsWith('assets/meze-cutouts/');
 const plate=mezePlateGeometry[item[1]];
 if(isCutout&&plate)return `<svg class="meze-cutout" viewBox="0 0 1000 1000" role="img" aria-label="${escapeHtml(menuName(item))}"><image href="${escapeHtml(actualPhoto)}" width="${plate.width}" height="${plate.height}" transform="matrix(${plate.matrix.join(' ')})"/></svg>`;
 if(actualPhoto&&item[1]==='Falafel Porsiyon')return `<svg class="product-photo plate-only-photo" viewBox="140 245 1160 1160" role="img" aria-label="${escapeHtml(menuName(item))}"><defs><clipPath id="falafel-porsiyon-plate-clip"><path d="M699 328 722 290Q736 288 740 320C961 321 1110 446 1178 622Q1222 604 1233 642Q1240 662 1217 699C1266 928 1172 1187 992 1297C835 1388 541 1377 374 1228C245 1128 187 957 204 796L188 774 209 768C223 554 410 349 655 329Z"/></clipPath></defs><image href="${escapeHtml(actualPhoto)}" width="1440" height="1440" clip-path="url(#falafel-porsiyon-plate-clip)"/></svg>`;
 if(actualPhoto&&item[1]==='Beyrut Tabağı'){
  const platesLabel=lang==='ar'?'طبقان':lang==='tr'?'2 tabak':'2 plates';
  return `<svg class="product-photo plate-only-photo" viewBox="0 0 1000 1000" role="img" aria-label="${escapeHtml(menuName(item))} — ${platesLabel}"><defs><clipPath id="beyrut-main-plate-clip"><ellipse cx="675" cy="635" rx="620" ry="620"/><path d="M18 480 80 420 200 590 70 660 15 610Z"/></clipPath><clipPath id="beyrut-salad-plate-clip"><ellipse cx="1005" cy="1055" rx="840" ry="855"/></clipPath></defs><svg x="0" y="0" width="620" height="620" viewBox="0 0 1350 1350"><image href="${escapeHtml(actualPhoto)}" width="2048" height="1365" clip-path="url(#beyrut-main-plate-clip)"/></svg><svg x="400" y="400" width="600" height="600" viewBox="115 160 1780 1780"><image href="assets/products/beyrut-14e055b2.jpg" width="2000" height="1969" clip-path="url(#beyrut-salad-plate-clip)"/></svg></svg><span class="meal-plates-label">${platesLabel}</span>`;
 }
 if(actualPhoto&&item[1]==='Falafel Salatası')return `<svg class="product-photo" viewBox="260 375 920 920" role="img" aria-label="${escapeHtml(menuName(item))}"><defs><clipPath id="falafel-salad-photo-clip"><ellipse cx="720" cy="835" rx="423" ry="431"/></clipPath></defs><image href="${escapeHtml(actualPhoto)}" width="1440" height="1440" clip-path="url(#falafel-salad-photo-clip)"/></svg>`;
 if(actualPhoto)return `<img class="real-dish-image${isCutout?' meze-cutout':''}" src="${escapeHtml(actualPhoto)}" alt="${escapeHtml(menuName(item))}" loading="lazy" style="object-fit:${isCutout?'contain':'cover'};padding:${isCutout?'10px':'0'};position:absolute;inset:0"><span class="fallback-art" hidden aria-hidden="true">${pic(item[0],index)}</span>`;
 const crop=referencePhotos[item[1]];
 if(crop)return `<svg class="product-photo" viewBox="${crop.join(' ')}" preserveAspectRatio="xMidYMid slice" role="img" aria-label="${escapeHtml(menuName(item))}"><image href="assets/menu-reference.jpeg" width="1230" height="1278"/></svg>`;
 const source=photoMap[item[1]],illustration=pic(item[0],index);
 if(source)return `<img class="real-dish-image" src="${escapeHtml(source)}" alt="${escapeHtml(menuName(item))}" loading="lazy"><span class="fallback-art" hidden aria-hidden="true">${illustration}</span>`;
 return `<span class="fallback-art" aria-hidden="true">${illustration}</span>`;
}
function renderCategories(){
 byId('categories').setAttribute('aria-label',lang==='ar'?'أقسام القائمة':lang==='tr'?'Menü kategorileri':'Menu categories');
 byId('categories').innerHTML=categoryOrder.map(key=>{
  const row=categories.find(c=>c[0]===key),label=lang==='ar'?arabicMenu.categories[key]:row[lang==='tr'?1:2],icon=categoryIcons[key];
  const crop=categoryCrops[key];
  const visual=crop?`<svg viewBox="${crop.join(' ')}" aria-hidden="true"><image href="assets/menu-reference.jpeg" width="1230" height="1278"/></svg>`:icon.startsWith('#')?`<svg aria-hidden="true"><use href="${icon}"/></svg>`:icon;
  return `<button class="category" type="button" data-category="${key}" aria-pressed="${key===category}"><span class="category-icon" aria-hidden="true">${visual}</span><span>${label}</span></button>`;
 }).join('');
 const nav=byId('categories'),selected=nav.querySelector('[aria-pressed="true"]');
 if(selected && nav.scrollWidth>nav.clientWidth){
  const selectedRect=selected.getBoundingClientRect(),navRect=nav.getBoundingClientRect();
  if(selectedRect.left<navRect.left)nav.scrollLeft+=selectedRect.left-navRect.left-5;
  else if(selectedRect.right>navRect.right)nav.scrollLeft+=selectedRect.right-navRect.right+5;
 }
}
function renderMenu(){
 const tr=lang==='tr',current=categories.find(c=>c[0]===category);
 const searching=byId('search').value.trim().length>0;
 byId('sectionTitle').textContent=searching?(lang==='ar'?'نتائج البحث':tr?'Arama sonuçları':'Search results'):(lang==='ar'?arabicMenu.categories[category]:current[tr?1:2]);
 byId('sectionDescription').textContent=searching?(lang==='ar'?'نتائج من جميع أقسام القائمة':tr?'Tüm menü kategorilerinden sonuçlar':'Results from all menu categories'):(lang==='ar'?arabicMenu.descriptions[category]:descriptions[category][tr?0:1]);
 byId('search').placeholder=lang==='ar'?'ابحث في القائمة...':tr?'Menüde ara...':'Search menu...';
 byId('search').setAttribute('aria-label',lang==='ar'?'ابحث في القائمة':tr?'Menüde ara':'Search menu');
 const normalize=value=>String(value).toLocaleLowerCase('tr-TR').normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/ı/g,'i').replace(/[\u064B-\u065F\u0670\u0640]/g,'').replace(/[أإآٱ]/g,'ا').replace(/ى/g,'ي');
 const query=normalize(byId('search').value.trim());
 let items=data.filter(item=>(searching||category==='all'||category===item[0])&&normalize([item[1],item[2],item[4],item[5],...arabicMenu.items[item[1]],...(drinkDisplayNames[item[1]]||[])].join(' ')).includes(query));
 if(!searching&&category==='drink')items=items.slice().sort((a,b)=>{
  const rank=item=>drinkOrder.includes(item[1])?drinkOrder.indexOf(item[1]):drinkOrder.length+data.indexOf(item);
  return rank(a)-rank(b);
 });
 byId('grid').innerHTML=items.map((item,index)=>{
  const displayName=menuName(item);
  const categoryRow=categories.find(row=>row[0]===item[0]);
  const categoryLabel=lang==='ar'?arabicMenu.categories[item[0]]:categoryRow[tr?1:2];
  const categoryTag=searching?`<p class="dish-category">${escapeHtml(categoryLabel)}</p>`:'';
  const price=item[3]==null?'':`${escapeHtml(item[3])} TL`;
  const desc=item[0]==='drink'?'':`<p class="desc">${escapeHtml(menuDescription(item))}</p>`;
  return `<article class="dish"><div class="art${restaurantPhotos[item[1]]?.startsWith('assets/meze-cutouts/')?' cutout-art':''}">${productVisual(item,index)}</div><div class="dish-text">${categoryTag}<h3 class="name">${escapeHtml(displayName)}</h3><span class="price" dir="ltr">${price}</span>${desc}</div></article>`;
 }).join('');
 byId('grid').querySelectorAll('img').forEach(image=>image.addEventListener('error',()=>{image.hidden=true;image.nextElementSibling.hidden=false;},{once:true}));
 byId('empty').hidden=items.length>0;
 byId('empty').textContent=lang==='ar'?'لم يتم العثور على منتجات. جرّب كلمة أخرى.':tr?'Ürün bulunamadı. Başka bir kelime deneyin.':'No items found. Try another search.';
 byId('counter').textContent=`${items.length} ${lang==='ar'?(items.length>=3&&items.length<=10?'منتجات':'منتج'):tr?'ürün':'items'}`;
}
function setLanguage(next){
 lang=['tr','ar','en'].includes(next)?next:'tr';
 document.documentElement.lang=lang;document.documentElement.dir=lang==='ar'?'rtl':'ltr';
 ['tr','ar','en'].forEach(code=>byId(code).setAttribute('aria-pressed',String(lang===code)));
 document.querySelector('.contact-strip').setAttribute('aria-label',lang==='ar'?'تواصل معنا واطلب عبر الإنترنت':lang==='tr'?'İletişim ve sipariş bağlantıları':'Contact and order links');
 document.querySelector('footer img').alt=lang==='ar'?'شعار نوحوت فلافل':lang==='tr'?'Nohut Falafel orijinal logo':'Nohut Falafel logo';
 reviewsTrack.scrollLeft=0;
 document.querySelectorAll('[data-tr][data-en]').forEach(node=>{
  const parts=node.dataset[lang].split('|');node.replaceChildren();
  parts.forEach((part,index)=>{if(index)node.append(document.createElement('br'));node.append(document.createTextNode(part));});
 });
 try{localStorage.setItem('nohut-lang',lang);}catch(_){}
 renderCategories();renderMenu();updateReviewsCarousel();
}
byId('tr').addEventListener('click',()=>setLanguage('tr'));
byId('en').addEventListener('click',()=>setLanguage('en'));
byId('ar').addEventListener('click',()=>setLanguage('ar'));
byId('search').addEventListener('input',renderMenu);
byId('categories').addEventListener('click',event=>{
 const button=event.target.closest('[data-category]');if(!button)return;
 category=button.dataset.category;byId('search').value='';
 byId('categories').querySelectorAll('button').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));
 renderMenu();
 const reduced=window.matchMedia('(prefers-reduced-motion: reduce)').matches;
 if(window.scrollY>byId('categories').offsetTop)byId('fullMenu').scrollIntoView({behavior:reduced?'instant':'smooth',block:'start'});
});
// Native touch swiping, mouse dragging, keyboard navigation and page arrows.
const reviewsTrack=byId('reviewsTrack');
const reviewsPrev=byId('reviewsPrev'),reviewsNext=byId('reviewsNext');
const reviewsCards=Array.from(reviewsTrack.querySelectorAll('.review-card'));
function reviewGeometry(){
 const gap=parseFloat(getComputedStyle(reviewsTrack).columnGap)||0;
 const step=reviewsCards[0].getBoundingClientRect().width+gap;
 return {step,visible:Math.max(1,Math.round(reviewsTrack.clientWidth/step)),max:Math.max(0,reviewsTrack.scrollWidth-reviewsTrack.clientWidth)};
}
function reviewSign(){return document.documentElement.dir==='rtl'?-1:1;}
function reviewOffset(max){return Math.max(0,Math.min(max,reviewSign()*reviewsTrack.scrollLeft));}
function updateReviewsCarousel(){
 const {step,visible,max}=reviewGeometry();
 const offset=reviewOffset(max);
 const first=Math.min(reviewsCards.length-visible+1,Math.round(offset/step)+1);
 const last=Math.min(reviewsCards.length,first+visible-1);
 const position=`${first===last?first:`${first}–${last}`} / ${reviewsCards.length}`;
 if(byId('reviewsPosition').textContent!==position)byId('reviewsPosition').textContent=position;
 byId('reviewsPosition').setAttribute('aria-label',lang==='ar'?`الآراء ${position}`:lang==='tr'?`Yorumlar ${position}`:`Reviews ${position}`);
 reviewsPrev.disabled=offset<=2;
 reviewsNext.disabled=offset>=max-2;
}
function moveReviews(direction){
 const {step,visible,max}=reviewGeometry();
 const target=Math.max(0,Math.min(max,reviewOffset(max)+direction*step*visible));
 reviewsTrack.scrollTo({left:reviewSign()*target,behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});
}
reviewsPrev.addEventListener('click',()=>moveReviews(-1));
reviewsNext.addEventListener('click',()=>moveReviews(1));
reviewsTrack.addEventListener('keydown',event=>{
 if(event.target!==reviewsTrack)return;
 if(event.key==='ArrowLeft'||event.key==='ArrowRight'){
  event.preventDefault();moveReviews((event.key==='ArrowLeft'?-1:1)*reviewSign());
 }else if(event.key==='Home'||event.key==='End'){
  event.preventDefault();reviewsTrack.scrollTo({left:event.key==='Home'?0:reviewSign()*reviewGeometry().max,behavior:'instant'});
 }
});
let reviewScrollTick=false;
reviewsTrack.addEventListener('scroll',()=>{
 if(reviewScrollTick)return;reviewScrollTick=true;
 requestAnimationFrame(()=>{reviewScrollTick=false;updateReviewsCarousel();});
},{passive:true});
window.addEventListener('resize',updateReviewsCarousel);
if(typeof ResizeObserver!=='undefined')new ResizeObserver(updateReviewsCarousel).observe(reviewsTrack);
let reviewDrag=null;
reviewsTrack.addEventListener('pointerdown',event=>{
 if(event.pointerType!=='mouse'||event.button!==0||event.target.closest('a,button'))return;
 reviewDrag={id:event.pointerId,startX:event.clientX,startLeft:reviewsTrack.scrollLeft,active:false};
});
reviewsTrack.addEventListener('pointermove',event=>{
 if(!reviewDrag||event.pointerId!==reviewDrag.id)return;
 const distance=event.clientX-reviewDrag.startX;
 if(!reviewDrag.active&&Math.abs(distance)>6){
  reviewDrag.active=true;reviewsTrack.setPointerCapture(event.pointerId);reviewsTrack.classList.add('is-dragging');
 }
 if(reviewDrag.active){event.preventDefault();reviewsTrack.scrollLeft=reviewDrag.startLeft-distance;}
});
function finishReviewDrag(){
 if(!reviewDrag)return;const active=reviewDrag.active;reviewDrag=null;reviewsTrack.classList.remove('is-dragging');
 if(active){
  const {step,max}=reviewGeometry();reviewsTrack.scrollTo({left:reviewSign()*Math.round(reviewOffset(max)/step)*step,behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});
 }
}
reviewsTrack.addEventListener('pointerup',finishReviewDrag);
reviewsTrack.addEventListener('pointercancel',finishReviewDrag);
reviewsTrack.addEventListener('pointerleave',()=>{if(reviewDrag&&!reviewDrag.active)reviewDrag=null;});
let initialLanguage='tr';try{const saved=localStorage.getItem('nohut-lang');if(['tr','ar','en'].includes(saved))initialLanguage=saved;}catch(_){}
setLanguage(initialLanguage);

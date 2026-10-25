'use strict';
let lang='tr', category='wrap';
const byId=id=>document.getElementById(id);
const escapeHtml=value=>String(value).replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
const categoryOrder=['all','wrap','plate','fatte','meze','salad','side','dessert','drink'];
const categoryCrops={wrap:[170,495,35,40],plate:[304,497,38,38],fatte:[451,497,41,38],meze:[560,497,41,38],salad:[689,497,43,38],side:[832,495,41,41],dessert:[951,496,41,40]};
const categoryIcons={all:'#all',wrap:'🌯',plate:'🧆',fatte:'🥣',meze:'🥣',salad:'🥗',side:'🥟',dessert:'🍰',drink:'#drink'};
const descriptions={all:['Lübnan mutfağından taze ve doğal lezzetler','Fresh Lebanese flavours, made with care'],wrap:['Taptaze malzemeler, bol lezzet','Freshly made wraps, packed with flavour'],plate:['Doyurucu tabaklar, doğal lezzetler','Hearty platters full of Lebanese flavours'],fatte:['Lübnan mutfağının sıcacık klasiği','Warm and comforting Lebanese-style fatteh'],meze:['Sofranıza renk katan mezeler','A delicious selection of appetizers'],salad:['Taze, hafif ve renkli','Fresh, light and colourful'],side:['Lezzeti tamamlayan seçenekler','Tasty additions to your meal'],dessert:['Yemeğinize tatlı bir son','A sweet finish to your meal'],drink:['Serinletici ve doğal içecekler','Cold drinks, mineral water and Turkish tea']};
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
 "Nohut Özel Tabağı": "assets/platter-cutouts/nohut-special-20261025.png",
 "Şambali Tatlısı": "assets/dessert-cutouts/sambali.png",
 "Tahinli Muhallebi": "assets/dessert-cutouts/tahinli-muhallebi.png",
 "Kıymalı Sembusek (4 Adet)": "assets/side-cutouts/sides.png",
 "Nohut Özel Dürüm": "assets/wrap-cutouts/wraps.png",
 "Falafel Dürüm": "assets/wrap-cutouts/wraps.png",
 "Patatesli Patlıcanlı Falafel Dürüm": "assets/wrap-cutouts/wraps.png",
 "Kibbe (3 Adet)": "assets/products/kibbe-6003492c.jpg",
 "Sarma (6 Adet)": "assets/products/tgo-9295403_1738157981309.jpg",
 "Tereyağlı Fatte": "assets/products/tgo-9295446_1738157998385.jpg",
 "Patates Dürüm": "assets/wrap-cutouts/wraps.png",
 "Vegan Özel Tabağı": "assets/platter-cutouts/vegan-ozel.png",
 "Beyrut Tabağı": "assets/platter-cutouts/nohut-ozel.png",
 "Kuruyemişli Humus": "assets/meze-cutouts/kuruyemisli-humus.png",
 "Peynirli Sembusek (4 Adet)": "assets/side-cutouts/cheese-sembusek.png",
 "Falafel Porsiyon": "assets/platter-cutouts/falafel-porsiyon.png",
 "Bakla Tabağı": "assets/platter-cutouts/bakla.png",
 "Patlıcanlı Fatte": "assets/products/ys-68085836.jpg",
 "Tereyağında Kuruyemişli Fatte": "assets/products/ys-68085837.jpg",
 "Patatesli Falafel Dürüm": "assets/wrap-cutouts/wraps.png",
 "Ispanaklı Sembusek (4 Adet)": "assets/side-cutouts/sides.png",
 "Patates Kızartması": "assets/side-cutouts/sides.png",
 "Sade Humus": "assets/meze-cutouts/sade-humus-top.png",
 "Babagannuş": "assets/meze-cutouts/babagannus-updated.png",
 "Mütebbel": "assets/meze-cutouts/mutebbel.png",
 "Pancarlı Humus": "assets/meze-cutouts/pancarli-humus.png",
 "Muhammara": "assets/meze-cutouts/muhammara.png",
 "Tabbule": "assets/salad-cutouts/salads.png",
 "Fettuş": "assets/salad-cutouts/salads.png",
 "Falafel Salatası": "assets/salad-cutouts/salads.png",
 "Kutu Cola Turka": "assets/drinks/cola-can.jpg",
 "Şişe Cola Turka": "assets/drinks/cola-bottle.jpg",
 "Niğde Gazozu": "assets/drinks/nigde.jpg",
 "Doğanay Acılı Şalgam": "assets/drinks/doganay-spicy.png",
 "Doğanay Acısız Şalgam": "assets/drinks/doganay-mild.png",
 "Küçük Ayran": "assets/drinks/eker-small.png",
 "Beypazarı Maden Suyu": "assets/drinks/beypazari-plain.png",
 "Su": "assets/drinks/water.jpg"
};
const mezePlateGeometry={"Sade Humus":{"width":1254,"height":1254,"matrix":[0.7312,-0.000248,-0.000248,0.739627,42.369389,42.922908]},"Kuruyemişli Humus":{"width":1254,"height":1254,"matrix":[0.719352,-0.000638,-0.000638,0.722961,41.809196,51.435731]},"Babagannuş":{"width":1254,"height":1254,"matrix":[0.710531,0.000526,0.000526,0.713243,54.855174,52.317941]},"Pancarlı Humus":{"width":1254,"height":1254,"matrix":[0.74633,0.001627,0.001627,0.754575,32.269832,27.221773]},"Mütebbel":{"width":1254,"height":1254,"matrix":[0.703334,0.000529,0.000529,0.70583,58.431362,52.554385]},"Muhammara":{"width":1254,"height":1254,"matrix":[0.757604,-0.002332,-0.002332,0.753512,25.043649,26.179502]}};
const platterPlateGeometry={"Nohut Özel Tabağı":{"width":1254,"height":1254,"matrix":[0.724138,0,0,0.724138,45.9655,45.9655]},"Beyrut Tabağı":{"width":1254,"height":1254,"matrix":[0.718182,-0.003145,-0.003145,0.712716,53.090195,57.978915]},"Vegan Özel Tabağı":{"width":1254,"height":1254,"matrix":[0.699812,-0.00037,-0.00037,0.702335,63.507687,61.131581]},"Falafel Porsiyon":{"width":1254,"height":1254,"matrix":[0.725014,0.002901,0.002901,0.718634,42.709828,40.724092]},"Bakla Tabağı":{"width":1254,"height":1254,"matrix":[0.712926,0.000184,0.000184,0.719855,53.095402,54.840502]},"beyrutMain":{"width":1254,"height":1254,"matrix":[0.700855,-0.002523,-0.002523,0.705824,62.399929,66.824682]},"beyrutSalad":{"width":1254,"height":1254,"matrix":[0.686487,-0.000358,-0.000358,0.679426,70.923657,70.085503]}};
function isCutoutPhoto(source){return /^assets\/(?:meze|platter|salad|side|wrap|dessert)-cutouts\//.test(source||"");}
function plateImage(source,plate){return `<image href="${escapeHtml(source)}" width="${plate.width}" height="${plate.height}" transform="matrix(${plate.matrix.join(" ")})"/>`;}
function menuName(item){
 return lang==='ar'?arabicMenu.items[item[1]][0]:(drinkDisplayNames[item[1]]?.[lang==='tr'?0:1]||item[lang==='tr'?1:2]);
}
function menuDescription(item){return lang==='ar'?arabicMenu.items[item[1]][1]:item[lang==='tr'?4:5];}
const saladPhotoCrops={"Falafel Salatası":[22,19,674,681],"Tabbule":[729,16,692,691],"Fettuş":[1436,16,710,693]};

// Original food and garnish are retained for kibbeh and sarma.
// Sarma deliberately uses the original eight-roll photograph, per owner request.
const originalSidePlates={
 "Kibbe (3 Adet)":{width:1920,height:1280,crop:[350,50,1160,1160],clip:'<ellipse cx="932" cy="642" rx="543" ry="544"/><path d="M755 70Q784 50 822 92L970 195 850 280 726 164Z"/><path d="M465 1015 505 897 650 956 609 1050Z"/><path d="M1390 714 1498 822 1440 877 1355 823Z"/>'},
 "Sarma (6 Adet)":{width:256,height:256,crop:[9,27,235,205],clip:'<ellipse cx="126.5" cy="129.5" rx="109" ry="94.5"/>'}
};
const sidePhotoCrops={
 "Kıymalı Sembusek (4 Adet)":{width:1536,height:1024,crop:[538,22,470,478]},
 "Ispanaklı Sembusek (4 Adet)":{width:1536,height:1024,crop:[1028,22,476,478]},
 "Peynirli Sembusek (4 Adet)":{width:1254,height:1254,crop:[15,8,1230,1230]},
 "Patates Kızartması":{width:1536,height:1024,crop:[1080,493,365,480]}
};
function isMenuCutout(item){return item[0]==='drink'||isCutoutPhoto(restaurantPhotos[item[1]])||Boolean(originalSidePlates[item[1]]);}
function sideProductVisual(item,source){
 const original=originalSidePlates[item[1]],plate=original||sidePhotoCrops[item[1]];
 if(!plate)return null;
 const clipId='side-plate-'+data.indexOf(item),isFries=item[1]==='Patates Kızartması';
 const crop=plate.crop.join(' ');
 const defs=original?`<defs><clipPath id="${clipId}">${original.clip}</clipPath></defs>`:'';
 const clip=original?` clip-path="url(#${clipId})"`:'';
 return `<svg class="meze-cutout" viewBox="0 0 1000 1000" role="img" aria-label="${escapeHtml(menuName(item))}"><svg x="65" y="65" width="870" height="870" viewBox="${crop}" preserveAspectRatio="${isFries?'xMidYMid meet':'none'}" overflow="hidden">${defs}<image href="${escapeHtml(source)}" width="${plate.width}" height="${plate.height}"${clip}/></svg></svg>`;
}


// Main wrap photographs share the same canvas; real open and folded forms are retained.
const wrapPhotoCrops={
 "Falafel Dürüm":[20,65,480,435],
 "Patates Dürüm":[516,127,506,356],
 "Nohut Özel Dürüm":[1015,34,512,479],
 "Patatesli Patlıcanlı Falafel Dürüm":[4,545,545,456],
 "Patatesli Falafel Dürüm":[546,538,500,460]
};


// Actual product packshots share the cream canvas and one baseline.
// Large and small Eker use distinct, verified SKUs rather than a reused image.
const drinkProducts={
 "Büyük Ayran": {
  "source": "assets/drinks/eker-large.png",
  "width": 250,
  "height": 250,
  "crop": [
   30,
   15,
   197,
   208
  ],
  "displayHeight": 660,
  "transparent": true
 },
 "Küçük Ayran": {
  "source": "assets/drinks/eker-small.png",
  "width": 1000,
  "height": 1000,
  "crop": [
   209,
   97,
   596,
   813
  ],
  "displayHeight": 520,
  "transparent": false
 },
 "Niğde Gazozu": {
  "source": "assets/drinks/nigde.jpg",
  "width": 640,
  "height": 640,
  "crop": [
   233,
   29,
   182,
   563
  ],
  "displayHeight": 820,
  "transparent": false
 },
 "Çamlıca Gazoz": {
  "source": "assets/drinks/camlica.jpg",
  "width": 1650,
  "height": 1650,
  "crop": [
   597,
   61,
   454,
   1527
  ],
  "displayHeight": 820,
  "transparent": false
 },
 "Beypazarı Maden Suyu": {
  "source": "assets/drinks/beypazari-plain.png",
  "width": 440,
  "height": 586,
  "crop": [
   125,
   -9,
   207,
   604
  ],
  "displayHeight": 800,
  "transparent": true
 },
 "Beypazarı Mandalina Aromalı Maden Suyu": {
  "source": "assets/drinks/beypazari-mandarin.png",
  "width": 440,
  "height": 586,
  "crop": [
   124,
   -9,
   207,
   603
  ],
  "displayHeight": 800,
  "transparent": true
 },
 "Şişe Cola Turka": {
  "source": "assets/drinks/cola-bottle.jpg",
  "width": 640,
  "height": 640,
  "crop": [
   239,
   56,
   162,
   530
  ],
  "displayHeight": 820,
  "transparent": false
 },
 "Kutu Cola Turka": {
  "source": "assets/drinks/cola-can.jpg",
  "width": 1000,
  "height": 1000,
  "crop": [
   313,
   210,
   372,
   656
  ],
  "displayHeight": 740,
  "transparent": false
 },
 "Doğanay Acılı Şalgam": {
  "source": "assets/drinks/doganay-spicy.png",
  "width": 960,
  "height": 1440,
  "crop": [
   355,
   502,
   262,
   829
  ],
  "displayHeight": 800,
  "transparent": true
 },
 "Doğanay Acısız Şalgam": {
  "source": "assets/drinks/doganay-mild.png",
  "width": 960,
  "height": 1440,
  "crop": [
   346,
   496,
   264,
   836
  ],
  "displayHeight": 800,
  "transparent": true
 },
 "Didi Limon Aromalı Soğuk Çay": {
  "source": "assets/drinks/didi-lemon.jpg",
  "width": 1000,
  "height": 1000,
  "crop": [
   332,
   75,
   327,
   842
  ],
  "displayHeight": 760,
  "transparent": false
 },
 "Didi Çilek Aromalı Soğuk Çay": {
  "source": "assets/drinks/didi-strawberry.jpg",
  "width": 1650,
  "height": 1650,
  "crop": [
   513,
   53,
   634,
   1539
  ],
  "displayHeight": 760,
  "transparent": false
 },
 "Didi Şeftali Aromalı Soğuk Çay": {
  "source": "assets/drinks/didi-peach.jpg",
  "width": 700,
  "height": 700,
  "crop": [
   232,
   49,
   232,
   595
  ],
  "displayHeight": 760,
  "transparent": false
 },
 "Sarıyer Portakal Aromalı Gazoz": {
  "source": "assets/drinks/sariyer-orange.jpg",
  "width": 510,
  "height": 510,
  "crop": [
   173,
   55,
   165,
   401
  ],
  "displayHeight": 760,
  "transparent": false
 },
 "Sarıyer Mandalina Aromalı Gazoz": {
  "source": "assets/drinks/sariyer-mandarin.jpg",
  "width": 650,
  "height": 650,
  "crop": [
   196,
   8,
   260,
   634
  ],
  "displayHeight": 760,
  "transparent": false
 },
 "Su": {
  "source": "assets/drinks/water.jpg",
  "width": 640,
  "height": 640,
  "crop": [
   249,
   115,
   135,
   450
  ],
  "displayHeight": 800,
  "transparent": false
 },
 "Çay": {
  "source": "assets/drinks/tea.png",
  "width": 1254,
  "height": 1254,
  "crop": [
   75,
   93,
   1104,
   1095
  ],
  "displayHeight": 700,
  "transparent": true
 }
};
function drinkProductVisual(item){
 const product=drinkProducts[item[1]];if(!product)return '';
 const height=product.displayHeight,width=height*product.crop[2]/product.crop[3],x=(1000-width)/2,y=900-height;
 const shadowId='drink-shadow-'+data.indexOf(item);
 return `<svg class="drink-product" viewBox="0 0 1000 1000" role="img" aria-label="${escapeHtml(menuName(item))}"><defs><filter id="${shadowId}" x="-50%" y="-100%" width="200%" height="300%"><feGaussianBlur stdDeviation="13"/></filter></defs><ellipse cx="500" cy="914" rx="${Math.max(58,width*.34)}" ry="15" fill="#43331d" opacity=".10" filter="url(#${shadowId})"/><svg x="${x}" y="${y}" width="${width}" height="${height}" viewBox="${product.crop.join(' ')}" preserveAspectRatio="xMidYMid meet" overflow="hidden"><image href="${escapeHtml(product.source)}" width="${product.width}" height="${product.height}"/></svg></svg>`;
}

function productVisual(item,index){
 if(item[1]==='Şambali Tatlısı')return `<svg class="meze-cutout" viewBox="0 0 1000 1000" role="img" aria-label="${escapeHtml(menuName(item))}"><image href="${escapeHtml(restaurantPhotos[item[1]])}" width="1254" height="1254" transform="matrix(0.69536 0 0 0.71795 61.22 44.10)"/></svg>`;
 if(item[1]==='Tahinli Muhallebi')return `<svg class="meze-cutout" viewBox="0 0 1254 1254" role="img" aria-label="${escapeHtml(menuName(item))}"><image href="${escapeHtml(restaurantPhotos[item[1]])}" width="1254" height="1254"/></svg>`;
 if(item[0]==='drink')return drinkProductVisual(item);
 const actualPhoto=restaurantPhotos[item[1]],isCutout=isMenuCutout(item);
 const wrapCrop=wrapPhotoCrops[item[1]];
 if(isCutout&&wrapCrop)return `<svg class="meze-cutout" viewBox="0 0 1000 1000" role="img" aria-label="${escapeHtml(menuName(item))}"><svg x="65" y="65" width="870" height="870" viewBox="${wrapCrop.join(' ')}" preserveAspectRatio="xMidYMid meet" overflow="hidden"><image href="${escapeHtml(actualPhoto)}" width="1536" height="1024"/></svg></svg>`;
 const sideVisual=sideProductVisual(item,actualPhoto);if(sideVisual)return sideVisual;
 const saladCrop=saladPhotoCrops[item[1]];
 if(isCutout&&saladCrop)return `<svg class="meze-cutout" viewBox="0 0 1000 1000" role="img" aria-label="${escapeHtml(menuName(item))}"><svg x="80" y="80" width="840" height="840" viewBox="${saladCrop.join(' ')}" preserveAspectRatio="none" overflow="hidden"><image href="${escapeHtml(actualPhoto)}" width="2156" height="729"/></svg></svg>`;
 const plate=mezePlateGeometry[item[1]]||platterPlateGeometry[item[1]];
 if(isCutout&&plate)return `<svg class="meze-cutout" viewBox="0 0 1000 1000" role="img" aria-label="${escapeHtml(menuName(item))}">${plateImage(actualPhoto,plate)}</svg>`;
 if(actualPhoto)return `<img class="real-dish-image${isCutout?' meze-cutout':''}" src="${escapeHtml(actualPhoto)}" alt="${escapeHtml(menuName(item))}" loading="lazy" decoding="async" fetchpriority="low" style="object-fit:${isCutout?'contain':'cover'};padding:${isCutout?'10px':'0'};position:absolute;inset:0"><span class="fallback-art" hidden aria-hidden="true">${pic(item[0],index)}</span>`;
 const crop=referencePhotos[item[1]];
 if(crop)return `<svg class="product-photo" viewBox="${crop.join(' ')}" preserveAspectRatio="xMidYMid slice" role="img" aria-label="${escapeHtml(menuName(item))}"><image href="assets/menu-reference.jpeg" width="1230" height="1278"/></svg>`;
 const source=photoMap[item[1]],illustration=pic(item[0],index);
 if(source)return `<img class="real-dish-image" src="${escapeHtml(source)}" alt="${escapeHtml(menuName(item))}" loading="lazy" decoding="async" fetchpriority="low"><span class="fallback-art" hidden aria-hidden="true">${illustration}</span>`;
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
// Defer heavy SVG food photography until the product card approaches the viewport.
const svgPhotoObserver=typeof IntersectionObserver==='function'?new IntersectionObserver(entries=>{
 for(const entry of entries){
  if(!entry.isIntersecting)continue;
  entry.target.querySelectorAll('image[data-deferred-href]').forEach(img=>{
   img.setAttribute('href',img.dataset.deferredHref);
   delete img.dataset.deferredHref;
  });
  svgPhotoObserver.unobserve(entry.target);
 }
},{rootMargin:(navigator.connection?.saveData||/^(slow-2g|2g)$/.test(navigator.connection?.effectiveType||''))?'100px 0px':'350px 0px'}):null;
function deferSvgFoodPhotos(){
 document.querySelectorAll('#grid .dish').forEach(card=>{
  const images=card.querySelectorAll('svg image[href]');
  if(!images.length)return;
  if(!svgPhotoObserver)return; // Browser fallback: retain normal images.
  images.forEach(img=>{
   img.dataset.deferredHref=img.getAttribute('href');
   img.removeAttribute('href');
  });
  svgPhotoObserver.observe(card);
 });
}
function renderMenu(){
 const tr=lang==='tr',current=categories.find(c=>c[0]===category);
 const searching=byId('search').value.trim().length>0;
 byId('sectionTitle').textContent=searching?(lang==='ar'?'نتائج البحث':tr?'Arama sonuçları':'Search results'):(lang==='ar'?arabicMenu.categories[category]:current[tr?1:2]);
 byId('sectionDescription').textContent=searching?(lang==='ar'?'نتائج البحث في قائمة الطعام':tr?'Tüm menü kategorilerinden sonuçlar':'Results from all menu categories'):(lang==='ar'?arabicMenu.descriptions[category]:descriptions[category][tr?0:1]);
 byId('search').placeholder=lang==='ar'?'ابحث عن طبق...':tr?'Menüde ara...':'Search menu...';
 byId('search').setAttribute('aria-label',lang==='ar'?'البحث في قائمة الطعام':tr?'Menüde ara':'Search menu');
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
  return `<article class="dish"><div class="art${isMenuCutout(item)?' cutout-art':''}">${productVisual(item,index)}</div><div class="dish-text">${categoryTag}<h3 class="name">${escapeHtml(displayName)}</h3><span class="price" dir="ltr">${price}</span>${desc}</div></article>`;
 }).join('');
 deferSvgFoodPhotos();
 byId('grid').querySelectorAll('img').forEach(image=>image.addEventListener('error',()=>{image.hidden=true;image.nextElementSibling.hidden=false;},{once:true}));
 byId('empty').hidden=items.length>0;
 byId('empty').textContent=lang==='ar'?'ما لقينا أي صنف بهذا الاسم. جرّب كلمة ثانية.':tr?'Ürün bulunamadı. Başka bir kelime deneyin.':'No items found. Try another search.';
 byId('counter').textContent=`${items.length} ${lang==='ar'?(items.length>=3&&items.length<=10?'منتجات':'منتج'):tr?'ürün':'items'}`;
}
function setLanguage(next){
 lang=['tr','ar','en'].includes(next)?next:'tr';
 document.documentElement.lang=lang;document.documentElement.dir=lang==='ar'?'rtl':'ltr';
 ['tr','ar','en'].forEach(code=>byId(code).setAttribute('aria-pressed',String(lang===code)));
 document.querySelector('.contact-strip').setAttribute('aria-label',lang==='ar'?'تواصل معنا واطلب عبر الإنترنت':lang==='tr'?'İletişim ve sipariş bağlantıları':'Contact and order links');
 document.querySelector('footer img').alt=lang==='ar'?'شعار نوهوت فلافل':lang==='tr'?'Nohut Falafel orijinal logo':'Nohut Falafel logo';
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

// Original Turkish menu names, prices and descriptions are preserved. English guest-facing copy has been refined.
const categories=[['all','Tümü','All'],['wrap','Dürümler','Wraps'],['plate','Porsiyonlar','Platters'],['fatte','Fatte','Fatteh'],['meze','Mezeler','Appetizers'],['side','Diğer','Sides'],['salad','Salatalar','Salads'],['dessert','Tatlı','Desserts'],['drink','İçecekler','Drinks']];
const data=[
['wrap','Falafel Dürüm','Falafel Wrap',140,'Humus, marul, domates, salatalık turşusu, nane, maydanoz, tahinli sos','Hummus, lettuce, tomato, pickles, mint, parsley and tahini sauce'],
['wrap','Patates Dürüm','Fries Wrap',135,'Kızartılmış patates, marul, domates, salatalık turşusu, nane, maydanoz','Crispy fries with lettuce, tomato, pickles, mint and parsley'],
['wrap','Nohut Özel Dürüm','Nohut Special Wrap',185,'Kızartılmış patlıcan, falafel, mütebbel, marul, domates, turşu, nane, maydanoz','Falafel, fried eggplant, mutabbal, lettuce, tomato, pickles, mint and parsley'],
['wrap','Patatesli Patlıcanlı Falafel Dürüm','Falafel Wrap with Fries & Eggplant',195,'Kızartılmış patates ve patlıcan, falafel, mütebbel, marul, domates, salatalık turşusu, nane, maydanoz','Falafel, fries, fried eggplant, mutabbal, lettuce, tomato, pickles, mint and parsley'],
['wrap','Patatesli Falafel Dürüm','Falafel & Fries Wrap',185,'Kızarmış patates, falafel, marul, domates, turşu, nane, maydanoz','Falafel, fries, lettuce, tomato, pickles, mint and parsley'],
['plate','Falafel Porsiyon','Falafel Platter',200,'6 adet falafel, humus, babagannuş, mütebbel','Six falafel pieces served with hummus, baba ghanoush and mutabbal'],
['plate','Vegan Özel Tabağı','Vegan Special Platter',320,'4 falafel, 2 ıspanaklı sembusek, 3 sarma, babagannuş, humus','Four falafel pieces, two spinach sambousek, three stuffed vine leaves, baba ghanoush and hummus'],
['plate','Nohut Özel Tabağı','Nohut Special Platter',350,'4 falafel, 1 kibbe, 2 ıspanaklı sembusek, humus','Four falafel pieces, one kibbeh, two spinach sambousek and hummus'],
['plate','Beyrut Tabağı','Beirut Platter',300,'4 falafel, 2 kıymalı sembusek, humus','Four falafel pieces, two meat sambousek and hummus'],
['plate','Bakla Tabağı','Fava Beans with Olive Oil',160,'Bakla, sarımsak, zeytinyağı, maydanoz, domates','Fava beans with garlic, olive oil, parsley and tomato'],
['plate','Yoğurtlu Bakla Tabağı','Fava Beans with Yogurt',180,'Bakla ve yoğurt','Fava beans served with yogurt'],
['fatte','Tereyağlı Fatte','Chickpea Fatteh with Butter',250,'Tahinli sarımsaklı yoğurt, haşlanmış nohut ve kızarmış Lübnan ekmeği','Chickpeas and crispy Lebanese bread with garlic-tahini yogurt and butter'],
['fatte','Patlıcanlı Fatte','Eggplant Fatteh',260,'Patlıcanlı fatte','Lebanese-style fatteh with eggplant'],
['fatte','Tereyağında Kuruyemişli Fatte','Fatteh with Butter & Nuts',280,'Tereyağı ve kuruyemişler','Lebanese-style fatteh with butter and mixed nuts'],
['fatte','Kavurmalı Fatte','Fatteh with Roasted Meat',330,'Kavurmalı fatte','Lebanese-style fatteh with roasted meat'],
['meze','Sade Humus','Classic Hummus',160,'Nohut ve tahin','Creamy chickpea and tahini dip'],
['meze','Kuruyemişli Humus','Hummus with Mixed Nuts',250,'Kaju, Antep fıstığı, badem','Hummus with cashews, pistachios and almonds'],
['meze','Pancarlı Humus','Beetroot Hummus',180,'Pancarlı humus','Hummus blended with beetroot'],
['meze','Mütebbel','Mutabbal (Eggplant Dip)',160,'Patlıcanlı meze','Lebanese-style eggplant dip'],
['meze','Babagannuş','Baba Ghanoush',170,'Patlıcanlı meze','Traditional eggplant appetizer'],
['meze','Muhammara','Muhammara (Pepper Dip)',160,'Biberli meze','A flavourful pepper-based dip'],
['meze','Karışık Meze Tabağı','Assorted Appetizer Platter',200,'Karışık meze','A selection of our appetizers'],
['side','Kibbe (3 Adet)','Kibbeh (3 Pieces)',330,'Lübnan usulü içli köfte','Three Lebanese-style stuffed bulgur croquettes'],
['side','Kıymalı Sembusek (4 Adet)','Meat Sambousek (4 Pieces)',250,'Kıymalı hamur işi','Four savoury pastries filled with minced meat'],
['side','Ispanaklı Sembusek (4 Adet)','Spinach Sambousek (4 Pieces)',180,'Ispanaklı hamur işi','Four pastries filled with spinach'],
['side','Peynirli Sembusek (4 Adet)','Cheese Sambousek (4 Pieces)',190,'Peynirli hamur işi','Four pastries filled with cheese'],
['side','Sarma (6 Adet)','Stuffed Vine Leaves (6 Pieces)',180,'Sarma','Six stuffed vine leaves'],
['side','Patates Kızartması','French Fries',150,'Kızarmış patates','Freshly fried potatoes'],
['side','Patlıcan Kızartması','Fried Eggplant',150,'Kızarmış patlıcan','Fried eggplant slices'],
['salad','Falafel Salatası','Falafel Salad',200,'Falafelli salata','Fresh salad with falafel'],
['salad','Tabbule','Tabbouleh',165,'Maydanozlu salata','Traditional parsley and bulgur salad'],
['salad','Fettuş','Fattoush',185,'Lübnan usulü salata','Fresh Lebanese-style salad with crispy bread'],
['dessert','Şambali Tatlısı','Şambali (Semolina Dessert)',70,'Geleneksel tatlı','Traditional Turkish semolina dessert'],
['dessert','Tahinli Muhallebi','Tahini Milk Pudding',90,'Tahinli muhallebi','Smooth milk pudding flavoured with tahini'],
['drink','Büyük Ayran','Eker Ayran (Large)','40','Eker ayran','Traditional Turkish yogurt drink'],
['drink','Küçük Ayran','Eker Ayran (Small)','25','Eker ayran','Traditional Turkish yogurt drink'],
['drink','Niğde Gazozu','Niğde Gazoz','40','Niğde gazoz','Turkish sparkling soft drink'],
['drink','Çamlıca Gazoz','Çamlıca Gazoz',45,'Çamlıca gazoz','Turkish sparkling soft drink'],
['drink','Beypazarı Maden Suyu','Beypazarı Sparkling Mineral Water','30','Sade','Plain sparkling mineral water'],
['drink','Beypazarı Mandalina Aromalı Maden Suyu','Beypazarı Mandarin Sparkling Water',45,'Mandalina aromalı','Sparkling mineral water with mandarin flavour'],
['drink','Şişe Cola Turka','Cola Turka (Glass Bottle)','35','Cam şişe','Cola Turka in a glass bottle'],
['drink','Kutu Cola Turka','Cola Turka (Can)','40','Kutu','Cola Turka in a can'],
['drink','Doğanay Acılı Şalgam','Doğanay Şalgam (Spicy)','35','Acılı şalgam suyu','Spicy Turkish fermented turnip drink'],
['drink','Doğanay Acısız Şalgam','Doğanay Şalgam (Mild)','35','Acısız şalgam suyu','Turkish fermented turnip drink, not spicy'],
['drink','Didi Limon Aromalı Soğuk Çay','Didi Lemon Iced Tea',45,'Limon aromalı','Lemon-flavoured iced tea'],
['drink','Didi Çilek Aromalı Soğuk Çay','Didi Strawberry Iced Tea',45,'Çilek aromalı','Strawberry-flavoured iced tea'],
['drink','Didi Şeftali Aromalı Soğuk Çay','Didi Peach Iced Tea',45,'Şeftali aromalı','Peach-flavoured iced tea'],
['drink','Sarıyer Portakal Aromalı Gazoz','Sarıyer Orange Soda',45,'Portakal aromalı','Orange-flavoured sparkling soft drink'],
['drink','Sarıyer Mandalina Aromalı Gazoz','Sarıyer Mandarin Soda',45,'Mandalina aromalı','Mandarin-flavoured sparkling soft drink'],
['drink','Su','Water','15','',''],
['drink','Çay','Turkish Tea','15','',''],
];

const photoMap = {
  "Büyük Ayran": "assets/drinks/eker-large.png",
  "Küçük Ayran": "assets/drinks/eker-small.png",
  "Niğde Gazozu": "assets/drinks/nigde.jpg",
  "Çamlıca Gazoz": "assets/drinks/camlica.jpg",
  "Beypazarı Maden Suyu": "assets/drinks/beypazari-plain.png",
  "Beypazarı Mandalina Aromalı Maden Suyu": "assets/drinks/beypazari-mandarin.png",
  "Şişe Cola Turka": "assets/drinks/cola-bottle.jpg",
  "Kutu Cola Turka": "assets/drinks/cola-can.jpg",
  "Doğanay Acılı Şalgam": "assets/drinks/doganay-spicy.png",
  "Doğanay Acısız Şalgam": "assets/drinks/doganay-mild.png",
  "Didi Limon Aromalı Soğuk Çay": "assets/drinks/didi-lemon.jpg",
  "Didi Çilek Aromalı Soğuk Çay": "assets/drinks/didi-strawberry.jpg",
  "Didi Şeftali Aromalı Soğuk Çay": "assets/drinks/didi-peach.jpg",
  "Sarıyer Portakal Aromalı Gazoz": "assets/drinks/sariyer-orange.jpg",
  "Sarıyer Mandalina Aromalı Gazoz": "assets/drinks/sariyer-mandarin.jpg",
  "Su": "assets/drinks/water.jpg",
  "Çay": "assets/drinks/tea.png"
};

function pic(type,index){let seeds=[['#946129','#aa7938'],['#6a8b4e','#839f63'],['#b4873d','#dbad57']];let s=seeds[index%3];let green='<path d="M110 58q-14-24-3-35 18 10 13 31M115 54q13-27 28-21-4 23-28 25" fill="#558455"/>';let bowl='<ellipse cx="118" cy="95" rx="75" ry="57" fill="#a18c6b" opacity=".16"/><ellipse cx="110" cy="91" rx="75" ry="57" fill="#faf5e7" stroke="#d2c9b5" stroke-width="4"/>';
if(type==='wrap')return `<svg viewBox="0 0 230 160">${green}<ellipse cx="125" cy="129" rx="97" ry="23" fill="#5c553933"/><g transform="translate(0 -7) rotate(-10 115 85)"><path d="M37 52Q119 20 198 55L169 137Q113 150 66 131Z" fill="#e5b77c" stroke="#c99962" stroke-width="3"/><path d="M47 51Q119 25 188 51L168 81Q114 105 70 83Z" fill="#508548"/><path d="M52 54q65-22 131 0" fill="none" stroke="#e9d39e" stroke-width="9"/><g fill="#91602d"><circle cx="92" cy="72" r="13"/><circle cx="122" cy="70" r="13"/><circle cx="150" cy="72" r="13"/></g><path d="M60 92Q118 106 174 88" stroke="#f4dfba" stroke-width="10" fill="none"/><path d="M89 104l65 18" stroke="#c89357" stroke-width="2"/></g></svg>`;
if(type==='drink')return `<svg viewBox="0 0 230 160"><ellipse cx="114" cy="134" rx="65" ry="13" fill="#58724729"/><path d="M92 37h47l-7 87q-19 11-34 0z" fill="#f5f8ecbb" stroke="#e9eadb" stroke-width="3"/><path d="M97 58h36l-5 60q-13 7-25 0z" fill="#b0d3b7"/><path d="M109 14l22 50" stroke="#dbaf56" stroke-width="7"/><circle cx="114" cy="87" r="10" fill="#e7f7e8a6"/><circle cx="123" cy="103" r="5" fill="#e7f7e8a6"/></svg>`;
if(type==='dessert')return `<svg viewBox="0 0 230 160">${bowl}<rect x="68" y="62" width="87" height="55" rx="9" fill="#d5ac58" stroke="#c29543" stroke-width="3"/><path d="M68 76h87M98 62v55M126 62v55" stroke="#f7d994" stroke-width="3"/><circle cx="114" cy="85" r="7" fill="#5c7943"/></svg>`;
if(type==='meze'||type==='fatte')return `<svg viewBox="0 0 230 160">${bowl}<ellipse cx="110" cy="90" rx="62" ry="43" fill="#cdb981"/><ellipse cx="110" cy="87" rx="52" ry="34" fill="#f5db9c"/><path d="M77 88q35-28 70-2t-67 12" stroke="#d5b476" stroke-width="9" fill="none" stroke-linecap="round"/><circle cx="112" cy="89" r="7" fill="#9c8a52"/><g fill="#61854e"><circle cx="105" cy="87" r="3"/><circle cx="121" cy="99" r="3"/><circle cx="95" cy="72" r="2"/></g></svg>`;
return `<svg viewBox="0 0 230 160">${bowl}<g fill="#668d4c"><path d="M61 101l36-44 33 45z"/><path d="M95 115l43-55 20 50z"/><path d="M65 90l45-29 13 42z"/></g><g fill="${s[0]}"><circle cx="88" cy="83" r="18"/><circle cx="129" cy="87" r="17"/><circle cx="106" cy="110" r="19"/><circle cx="151" cy="113" r="16"/></g><g fill="#e0bb66"><circle cx="91" cy="78" r="3"/><circle cx="128" cy="87" r="3"/><circle cx="108" cy="103" r="3"/><circle cx="146" cy="110" r="3"/></g></svg>`;
}

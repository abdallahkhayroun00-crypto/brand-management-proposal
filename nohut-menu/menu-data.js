// Existing approved menu: names, prices and descriptions are preserved.
const categories=[['all','Tümü','All'],['wrap','Dürümler','Wraps'],['plate','Porsiyonlar','Platters'],['fatte','Fatte','Fatteh'],['meze','Mezeler','Mezze'],['side','Diğer','Sides'],['salad','Salatalar','Salads'],['dessert','Tatlı','Desserts'],['drink','İçecekler','Drinks']];
const data=[
['wrap','Falafel Dürüm','Falafel Wrap',140,'Humus, marul, domates, salatalık turşusu, nane, maydanoz, tahinli sos','Hummus, lettuce, tomato, pickles, mint, parsley, tahini sauce'],
['wrap','Patates Dürüm','Fries Wrap',135,'Kızartılmış patates, marul, domates, salatalık turşusu, nane, maydanoz','Fries, lettuce, tomato, pickles, mint, parsley'],
['wrap','Nohut Özel Dürüm','Nohut Special Wrap',185,'Kızartılmış patlıcan, falafel, mütebbel, marul, domates, turşu, nane, maydanoz','Fried eggplant, falafel, mutabbal, lettuce, tomato, pickles, mint, parsley'],
['wrap','Patatesli Patlıcanlı Falafel Dürüm','Falafel Wrap with Potato & Eggplant',195,'Kızartılmış patates ve patlıcan, falafel, mütebbel, marul, domates, salatalık turşusu, nane, maydanoz','Fries, fried eggplant, falafel, mutabbal, lettuce, tomato, pickles, mint, parsley'],
['wrap','Patatesli Falafel Dürüm','Falafel & Fries Wrap',185,'Kızarmış patates, falafel, marul, domates, turşu, nane, maydanoz','Fries, falafel, lettuce, tomato, pickles, mint, parsley'],
['plate','Falafel Porsiyon','Falafel Platter',200,'6 adet falafel, humus, babagannuş, mütebbel','6 falafel, hummus, baba ghanoush, mutabbal'],
['plate','Vegan Özel Tabağı','Vegan Special Platter',320,'4 falafel, 2 ıspanaklı sembusek, 3 sarma, babagannuş, humus','4 falafel, 2 spinach sambousek, 3 stuffed vine leaves, baba ghanoush, hummus'],
['plate','Nohut Özel Tabağı','Nohut Special Platter',350,'4 falafel, 1 kibbe, 2 ıspanaklı sembusek, humus','4 falafel, 1 kibbeh, 2 spinach sambousek, hummus'],
['plate','Beyrut Tabağı','Beirut Platter',300,'4 falafel, 2 kıymalı sembusek, humus','4 falafel, 2 meat sambousek, hummus'],
['plate','Bakla Tabağı','Fava Bean Platter',160,'Bakla, sarımsak, zeytinyağı, maydanoz, domates','Fava beans, garlic, olive oil, parsley, tomato'],
['plate','Yoğurtlu Bakla Tabağı','Fava Beans with Yogurt',180,'Bakla ve yoğurt','Fava beans and yogurt'],
['fatte','Tereyağlı Fatte','Butter Fatteh',250,'Tahinli sarımsaklı yoğurt, haşlanmış nohut ve kızarmış Lübnan ekmeği','Garlic tahini yogurt, boiled chickpeas and crisp Lebanese bread'],
['fatte','Patlıcanlı Fatte','Eggplant Fatteh',260,'Patlıcanlı fatte','Fatteh with eggplant'],
['fatte','Tereyağında Kuruyemişli Fatte','Fatteh with Butter & Nuts',280,'Tereyağı ve kuruyemişler','Butter and nuts'],
['fatte','Kavurmalı Fatte','Fatteh with Roasted Meat',330,'Kavurmalı fatte','Fatteh with roasted meat'],
['meze','Sade Humus','Classic Hummus',160,'Nohut ve tahin','Chickpeas and tahini'],
['meze','Kuruyemişli Humus','Hummus with Nuts',250,'Kaju, Antep fıstığı, badem','Cashews, pistachios, almonds'],
['meze','Pancarlı Humus','Beetroot Hummus',180,'Pancarlı humus','Hummus with beetroot'],
['meze','Mütebbel','Mutabbal',160,'Patlıcanlı meze','Eggplant dip'],
['meze','Babagannuş','Baba Ghanoush',170,'Patlıcanlı meze','Eggplant appetizer'],
['meze','Muhammara','Muhammara',160,'Biberli meze','Pepper-based dip'],
['meze','Karışık Meze Tabağı','Mixed Mezze Platter',200,'Karışık meze','Mixed appetizers'],
['side','Kibbe (3 Adet)','Kibbeh (3 Pieces)',330,'Lübnan usulü içli köfte','Lebanese-style stuffed bulgur croquettes'],
['side','Kıymalı Sembusek (4 Adet)','Meat Sambousek (4)',250,'Kıymalı hamur işi','Pastry filled with minced meat'],
['side','Ispanaklı Sembusek (4 Adet)','Spinach Sambousek (4)',180,'Ispanaklı hamur işi','Spinach-filled pastry'],
['side','Peynirli Sembusek (4 Adet)','Cheese Sambousek (4)',190,'Peynirli hamur işi','Cheese-filled pastry'],
['side','Sarma (6 Adet)','Stuffed Vine Leaves (6)',180,'Sarma','Stuffed vine leaves'],
['side','Patates Kızartması','French Fries',150,'Kızarmış patates','Fried potatoes'],
['side','Patlıcan Kızartması','Fried Eggplant',150,'Kızarmış patlıcan','Fried eggplant'],
['salad','Falafel Salatası','Falafel Salad',200,'Falafelli salata','Fresh salad with falafel'],
['salad','Tabbule','Tabbouleh',165,'Maydanozlu salata','Parsley and bulgur salad'],
['salad','Fettuş','Fattoush',185,'Lübnan usulü salata','Levantine bread salad'],
['dessert','Şambali Tatlısı','Şambali Dessert',70,'Geleneksel tatlı','Traditional semolina dessert'],
['dessert','Tahinli Muhallebi','Tahini Milk Pudding',90,'Tahinli muhallebi','Tahini-flavored milk pudding'],
['drink','Büyük Ayran','Eker Ayran (Large)','40','Eker ayran','Eker ayran'],
['drink','Küçük Ayran','Eker Ayran (Small)','25','Eker ayran','Eker ayran'],
['drink','Niğde Gazozu','Niğde Soda','40','Niğde gazoz','Niğde soft drink'],
['drink','Çamlıca Gazoz','Çamlıca Soda',null,'Çamlıca gazoz','Çamlıca soft drink'],
['drink','Beypazarı Maden Suyu','Beypazarı Mineral Water','30','Sade','Plain'],
['drink','Beypazarı Mandalina Aromalı Maden Suyu','Beypazarı Mandarin Sparkling Mineral Water',null,'Mandalina aromalı','Mandarin flavoured'],
['drink','Şişe Cola Turka','Cola Turka (Bottle)','35','Cam şişe','Glass bottle'],
['drink','Kutu Cola Turka','Cola Turka (Can)','40','Kutu','Can'],
['drink','Doğanay Acılı Şalgam','Doğanay Spicy Şalgam','35','Acılı şalgam suyu','Spicy fermented turnip juice'],
['drink','Doğanay Acısız Şalgam','Doğanay Mild Şalgam','35','Acısız şalgam suyu','Non-spicy fermented turnip juice'],
['drink','Didi Limon Aromalı Soğuk Çay','Didi Lemon Iced Tea',null,'Limon aromalı','Lemon flavour'],
['drink','Didi Çilek Aromalı Soğuk Çay','Didi Strawberry Iced Tea',null,'Çilek aromalı','Strawberry flavour'],
['drink','Didi Şeftali Aromalı Soğuk Çay','Didi Peach Iced Tea',null,'Şeftali aromalı','Peach flavour'],
['drink','Sarıyer Portakal Aromalı Gazoz','Sarıyer Orange Soda',null,'Portakal aromalı','Orange flavour'],
['drink','Sarıyer Mandalina Aromalı Gazoz','Sarıyer Mandarin Soda',null,'Mandalina aromalı','Mandarin flavour'],
['drink','Su','Water','15','',''],
['drink','Çay','Turkish Tea','15','','']
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

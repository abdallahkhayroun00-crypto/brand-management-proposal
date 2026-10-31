'use strict';
// Kampanyayı kapatmak için active: false yapın. Yeni kampanyaları bu listeye ekleyin.
// startsAt / endsAt isteğe bağlıdır. Örnek: '2026-11-30T23:59:59+03:00'.
window.nohutCampaigns = [
  {
    id: 'falafel-menu-250',
    active: true,
    startsAt: null,
    endsAt: null,
    price: 250,
    poster: 'assets/campaigns/falafel-menu-250.webp',
    thumbnail: 'assets/campaigns/falafel-menu-250-thumb.webp',
    title: { tr: 'Falafel Menü', ar: 'وجبة الفلافل', en: 'Falafel Combo' },
    description: {
      tr: 'Dört lezzet bir arada.',
      ar: 'أربع نكهات في وجبة واحدة.',
      en: 'Four favourites, one combo.'
    },
    items: [
      { tr: 'Falafel Dürüm', ar: 'ساندويتش فلافل', en: 'Falafel wrap' },
      { tr: 'Tahinli Muhallebi', ar: 'مهلبية بالطحينة', en: 'Tahini pudding' },
      { tr: 'Şişe Cola Turka', ar: 'كولا توركا — زجاجة', en: 'Bottled Cola Turka' },
      { tr: 'Çay', ar: 'شاي', en: 'Tea' }
    ]
  },
  {
    "id": "lubnan-geceleri-150",
    "active": true,
    "startsAt": null,
    "endsAt": null,
    "price": 150,
    "poster": "assets/dessert-cutouts/lubnan-geceleri-top.webp",
    "thumbnail": "assets/dessert-cutouts/lubnan-geceleri-top.webp",
    "eyebrow": {
      "tr": "YENİ TATLI",
      "ar": "حلوى جديدة",
      "en": "NEW DESSERT"
    },
    "title": {
      "tr": "Lübnan Geceleri",
      "ar": "ليالي لبنان",
      "en": "Lebanese Nights"
    },
    "description": {
      "tr": "Yeni Lübnan tatlımızla tanışın.",
      "ar": "اكتشفوا حلوانا اللبنانية الجديدة.",
      "en": "Discover our new Lebanese dessert."
    },
    "items": [
      {
        "tr": "Geleneksel Lübnan tatlısı",
        "ar": "حلوى لبنانية تقليدية",
        "en": "Traditional Lebanese dessert"
      }
    ]
  }
];

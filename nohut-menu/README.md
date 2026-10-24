# Nohut Falafel QR menu

Live page: https://abdallahkhayroun00-crypto.github.io/brand-management-proposal/nohut-menu/

A static, view-only Turkish/English restaurant menu. The five contact/delivery links point to the existing Maps, Instagram, phone, Trendyol Go and Yemeksepeti destinations. No ordering form or backend is added.

## Content

- `menu-data.js` preserves all 51 existing menu records, including prices and ingredient descriptions.
- `menu.js` handles translated presentation, nine category filters, accent-insensitive search and empty results. Eker Ayran and spicy/mild Doğanay labels follow the owner's supplied information.
- `menu.css` implements the approved warm Mediterranean direction, a six-column desktop grid, four-column tablet grid and two-column phone grid.
- `assets/menu-reference.jpeg` is the user-supplied approved visual. SVG viewBoxes display its product illustrations and category icons. Product names and prices remain live HTML. These reference illustrations are not represented as photographs of the restaurant's actual dishes.
- `assets/original-logo.jpeg` preserves the supplied restaurant logo photo.
- The former product-image URLs remain in `photoMap` for drinks outside the visual reference, with illustration fallbacks if a source fails.

Seven drink prices were already unspecified: Çamlıca Gazoz; Beypazarı mandarin mineral water; the three Didi flavours; the two Sarıyer flavours. They stay unspecified. Do not substitute the unverified numbers drawn in the design mockup. There is no drink-photo warning banner.

## Hero asset

`assets/hero.png` was prepared with the built-in image generation tool from the supplied design and original logo photo. The production prompt requests a 3:1 warm sunlit stone-wall scene matching the supplied reference, a large round Nohut Falafel hanging sign on the left, blank warm ivory plaster in the centre for live HTML text, and falafel/hummus/herbs/olives/pita/tomatoes on the right; remove all central text, language toggle and website interface. The actual title, tagline, description, features and language buttons are HTML, not baked into the artwork.

Fonts are hosted locally; their OFL licenses are in `assets/fonts/`.

## Verification

- JavaScript syntax checks and whitespace check passed.
- Every original menu record was compared with the previous version: exact match for all 51 records.
- Browser checks: 51 items under All, 5 wraps, 17 drinks, Eker search returns 2, empty search state, TR/EN translation, 390px phone and 768px tablet layouts, no document horizontal overflow.
- GitHub Pages remains at the existing `/nohut-menu/` path. The repository's root proposal site is unaffected.

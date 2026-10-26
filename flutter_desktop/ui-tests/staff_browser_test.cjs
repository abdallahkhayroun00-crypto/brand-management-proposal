// Staff Chrome UI contract tests with synthetic local data; no platform connection.
const path = require("path");
const http = require("http"),
  fs = require("fs"),
  assert = require("assert");
const { chromium } = require(
  process.env.NOHUT_QA_PLAYWRIGHT_MODULE || "playwright",
);
const root = path.resolve(__dirname, "..");
const floorPlan = [
  [1, 0.456, 0.13, 0.143, 0.135],
  [2, 0.255, 0.165, 0.13, 0.113],
  [3, 0.265, 0.424, 0.343, 0.174],
  [4, 0.261, 0.71, 0.346, 0.178],
  [5, 0.032, 0.676, 0.076, 0.148],
].map(([number, x, y, w, h]) => ({ number, x, y, w, h }));
const state = {
  floorPlan,
  localMenu: [
    { id: 0, name: "Falafel Dürüm", category: "wrap", price: 140 },
    { id: 1, name: "Falafel Porsiyon", category: "plate", price: 200 },
    { id: 2, name: "Ayran", category: "drink", price: 30 },
    { id: 3, name: "Tatlı", category: "dessert", price: null },
  ],
  orders: [
    {
      id: 1200,
      source: "Masa",
      table: 3,
      serviceStatus: "Hazırlanıyor",
      batches: [{id: 1, lines: [{name: 'Falafel Dürüm', qty: 2, note: 'Sos ayrı', removed: ['Soğan']}]}],
      operations: [],
    },
    {
      id: 1201,
      source: "Trendyol Go",
      demoRemoteStatus: "Created",
      batches: [{id: 1, lines: [{name: 'Falafel Porsiyon', qty: 1, note: '', removed: []}]}],
      operations: [],
    },
  ],
};
let failNext = false,
  attempts = [];
const server = http.createServer((req, res) => {
  if (req.url === "/brand-logo") {
    res.setHeader("Content-Type", "image/jpeg");
    res.end(fs.readFileSync(root + "/assets/brand-logo.jpeg"));
    return;
  }
  if (req.url === "/api/bootstrap") {
    res.setHeader("Content-Type", "application/json");
    res.end(
      JSON.stringify({
        state,
        revision: 3,
        csrf: "TEST_CSRF",
        staff: { id: 2, name: "Mehmet" },
      }),
    );
    return;
  }
  if (req.url === "/api/staff/orders") {
    let s = "";
    req.on("data", (b) => (s += b));
    req.on("end", () => {
      attempts.push(JSON.parse(s));
      if (failNext) {
        failNext = false;
        req.socket.destroy();
        return;
      }
      res.setHeader("Content-Type", "application/json");
      res.end(JSON.stringify({ orderId: 1202 }));
    });
    return;
  }
  res.setHeader("Content-Type", "text/html");
  res.end(fs.readFileSync(root + "/assets/staff.html"));
});
(async () => {
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const browser = await chromium.launch({
    headless: true,
    ...(process.env.NOHUT_QA_CHROME ? { channel: "chrome" } : {}),
  });
  try {
    for (const width of [320, 390, 768]) {
      const page = await browser.newPage({ viewport: { width, height: 844 } });
      const errors = [];
      page.on("pageerror", (e) => errors.push(e.message));
      await page.goto(
        "http://127.0.0.1:" + server.address().port + "/personel",
      );
      await page.locator("#floor button").first().waitFor();
      assert.equal(await page.locator("#floor button").count(), 5);
      if (process.env.NOHUT_UI_SCREENSHOT_DIR) await page.screenshot({path:path.join(process.env.NOHUT_UI_SCREENSHOT_DIR, 'phone-floor-'+width+'.png'), fullPage:true});
      await page.locator('#floor [data-table="3"]').click();
      assert.equal(await page.locator('[data-add="0"]').count(), 1);
      assert.equal(await page.locator('[data-add="2"]').count(), 0);
      await page.locator('[data-add="0"]').click();
      await page.locator('[data-add="0"]').click();
      await page.locator('[data-category="plate"]').click();
      assert.equal(await page.locator('[data-add="1"]').count(), 1);
      assert.equal(await page.locator('[data-add="0"]').count(), 0);
      await page.locator('[data-category="drink"]').click();
      await page.locator('[data-add="2"]').click();
      if (process.env.NOHUT_UI_SCREENSHOT_DIR)
        await page.screenshot({
          path: path.join(
            process.env.NOHUT_UI_SCREENSHOT_DIR,
            "catalog-" + width + ".png",
          ),
          fullPage: true,
        });
      await page.locator("#open-cart").click();
      assert((await page.locator("#total").textContent()).includes("310"));
      assert.equal(await page.locator(".cart-line").count(), 2);
      assert(await page.locator("#submit").isVisible());
      const sendBox=await page.locator("#submit").boundingBox();
      assert(sendBox.y+sendBox.height<=844, "Send action must remain in the viewport");
      await page.locator(".cart-line").first().locator("summary").click();
      await page.locator('[data-note="0"]').fill("Sos ayrı");
      await page.locator('[data-removed="0"]').fill("Soğan");
      await page.locator('[data-product="0"][data-step="-1"]').click();
      assert((await page.locator("#total").textContent()).includes("170"));
      await page.locator('[data-remove="2"]').click();
      assert.equal(await page.locator(".cart-line").count(), 1);
      assert((await page.locator("#total").textContent()).includes("140"));
      await page.locator("#back-menu").click();
      await page.locator('[data-category="dessert"]').click();
      assert(await page.locator('[data-add="3"]').isDisabled());
      await page.locator("#search").fill("durum");
      assert.equal(await page.locator('[data-add="0"]').count(), 1);
      await page.locator("#search").fill("Ayran");
      assert.equal(await page.locator('[data-add="2"]').count(), 1);
      await page.locator('[data-add="2"]').click();
      await page.locator("#open-cart").click();
      assert.equal(
        await page.evaluate(
          () => document.documentElement.scrollWidth > innerWidth,
        ),
        false,
      );
      if (process.env.NOHUT_UI_SCREENSHOT_DIR)
        await page.screenshot({
          path: path.join(
            process.env.NOHUT_UI_SCREENSHOT_DIR,
            "basket-" + width + ".png",
          ),
          fullPage: true,
        });
      attempts = [];
      await page.route(
        "**/api/staff/orders",
        async (route) => {
          attempts.push(route.request().postDataJSON());
          await route.abort("failed");
        },
        { times: 1 },
      );
      await page.locator("#submit").click();
      await page
        .waitForFunction(() =>
          document
            .querySelector("#notice")
            .textContent.includes("Onay alınamadı"),
        )
        .catch(async (e) => {
          console.log(
            "Notice:",
            await page.locator("#notice").textContent(),
            "attempts",
            attempts.length,
          );
          throw e;
        });
      assert(
        await page.locator('[data-product="0"][data-step="1"]').isDisabled(),
      );
      await page.locator("#retry").click();
      await page.waitForFunction(() =>
        document.querySelector("#notice").textContent.includes("1202"),
      );
      assert.equal(attempts.length, 2);
      assert.deepEqual(attempts[0], attempts[1]);
      assert.equal(attempts[0].table, 3);
      assert.equal(attempts[0].lines.length, 2);
      assert.equal(attempts[0].lines[0].qty, 1);
      assert.equal(attempts[0].lines[0].note, "Sos ayrı");
      assert.deepEqual(attempts[0].lines[0].removed, ["Soğan"]);
      await page.locator('[data-tab="orders"]').click();
      if (process.env.NOHUT_UI_SCREENSHOT_DIR) await page.screenshot({path:path.join(process.env.NOHUT_UI_SCREENSHOT_DIR, 'phone-orders-'+width+'.png'), fullPage:true});
      await page.locator('#order-source').selectOption('Online');
      assert.equal(await page.locator('#orders .order').count(), 1);
      assert.equal(await page.locator('[data-ready]').count(), 0, 'Unaccepted platform order has no staff ready action');
      await page.locator('#order-source').selectOption('Tümü');
      await page.locator('#order-search').fill('durum');
      assert.equal(await page.locator('#orders .order').count(), 1);
      assert.equal(await page.locator('[data-ready="1200"]').count(), 1);
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
      assert.equal(
        await page.getByRole("button", { name: /Kabul|Reddet/ }).count(),
        0,
      );
      assert.deepEqual(errors, []);
      await page.close();
    }
    console.log(
      "Category/basket browser checks passed at 320, 390, 768px: sections, global search, cross-category cart, quantities/removal/notes, unavailable prices, locked uncertain request, exact retry payload and permissions.",
    );
  } finally {
    await browser.close();
    server.close();
  }
})().catch((e) => {
  console.error(e);
  process.exitCode = 1;
  server.close();
});

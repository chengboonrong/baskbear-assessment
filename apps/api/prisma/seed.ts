/**
 * Baskbear seed data.
 *
 * Idempotent — uses upserts on natural keys (codes, slugs, SKUs) so re-running
 * doesn't blow up. Designed for local dev + CI; production seed strategy is
 * documented in README.md.
 *
 * Country-variant data (countries, outlets, per-country prices, vouchers,
 * feature flags) lives in JSON under prisma/seed-data/. Adding a new country
 * is a JSON-only edit — see docs/architecture.md §4 Q8 "Adding a new country".
 *
 * Prisma 7 note: the standalone PrismaClient instance below uses the
 * @prisma/adapter-mariadb driver adapter (no more implicit Rust engine).
 * dotenv is imported explicitly because `npm run seed` calls ts-node directly,
 * bypassing the Prisma CLI which would otherwise load .env.
 */
import 'dotenv/config';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { PrismaMariaDb } from '@prisma/adapter-mariadb';
import { PrismaClient, VoucherType } from '../src/generated/prisma/client';

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error('DATABASE_URL is not set');
const prisma = new PrismaClient({ adapter: new PrismaMariaDb(databaseUrl) });

const DATA_DIR = path.join(__dirname, 'seed-data');
const loadJson = <T>(name: string): T =>
  JSON.parse(fs.readFileSync(path.join(DATA_DIR, name), 'utf8')) as T;

// ── Country-variant data (JSON) ─────────────────────────────────────────────
type CountryDef = {
  code: string;
  name: string;
  currencyCode: string;
  taxRateBps: number;
  timezone: string;
  defaultLocale: string;
  locales: string[];
  outlets: { name: string; address: string; lat: number; lng: number }[];
};
type VoucherDef = {
  code: string;
  type: 'PERCENT' | 'FIXED';
  value: number;
  minSpend: number;
  maxDiscount: number | null;
  perUser: number;
  total: number | null;
  startsAt: string;
  endsAt: string;
  stackable: boolean;
  countries: string[];
};
type FlagDef = { key: string; country: string | null; isEnabled: boolean };

const COUNTRIES = loadJson<CountryDef[]>('countries.json');
const PRICING = loadJson<Record<string, Record<string, number>>>('pricing.json');
const OPTION_PRICING = loadJson<Record<string, Record<string, number>>>('option-pricing.json');
const VOUCHERS = loadJson<VoucherDef[]>('vouchers.json');
const FLAGS = loadJson<FlagDef[]>('feature-flags.json');

// Locales are derived from the union of every country's `locales` — adding a
// country with a new locale (e.g. SG → "en") brings the locale row in for free.
const LOCALES = [...new Set(COUNTRIES.flatMap((c) => c.locales))].map((code) => ({ code }));

// ── Country-invariant data (in source) ──────────────────────────────────────
const CATEGORIES = [
  { slug: 'espresso',     sortOrder: 1, t: { en: 'Espresso',     ms: 'Espresso',          th: 'เอสเพรสโซ่' } },
  { slug: 'brew',         sortOrder: 2, t: { en: 'Brewed',       ms: 'Bancuhan',          th: 'กาแฟดริป' } },
  { slug: 'specialty',    sortOrder: 3, t: { en: 'Specialty',    ms: 'Istimewa',          th: 'เมนูพิเศษ' } },
  { slug: 'non-coffee',   sortOrder: 4, t: { en: 'Non-Coffee',   ms: 'Bukan Kopi',        th: 'เครื่องดื่มอื่น ๆ' } },
  { slug: 'food',         sortOrder: 5, t: { en: 'Food',         ms: 'Makanan',           th: 'อาหาร' } },
];

const CUSTOM_GROUPS = [
  {
    slug: 'size', min: 1, max: 1,
    t: { en: 'Size', ms: 'Saiz', th: 'ขนาด' },
    options: [
      { slug: 'S', delta: 0,   t: { en: 'Small',  ms: 'Kecil',         th: 'เล็ก' } },
      { slug: 'M', delta: 200, t: { en: 'Medium', ms: 'Sederhana',     th: 'กลาง' } },
      { slug: 'L', delta: 400, t: { en: 'Large',  ms: 'Besar',         th: 'ใหญ่' } },
    ],
  },
  {
    slug: 'milk', min: 1, max: 1,
    t: { en: 'Milk', ms: 'Susu', th: 'นม' },
    options: [
      { slug: 'whole', delta: 0,   t: { en: 'Whole', ms: 'Susu Penuh',         th: 'นมสด' } },
      { slug: 'skim',  delta: 0,   t: { en: 'Skim',  ms: 'Susu Rendah Lemak',  th: 'นมพร่อง' } },
      { slug: 'oat',   delta: 250, t: { en: 'Oat',   ms: 'Oat',                th: 'นมโอ๊ต' } },
      { slug: 'soy',   delta: 200, t: { en: 'Soy',   ms: 'Susu Soya',          th: 'นมถั่วเหลือง' } },
    ],
  },
  {
    slug: 'sugar', min: 1, max: 1,
    t: { en: 'Sugar', ms: 'Gula', th: 'ความหวาน' },
    options: [
      { slug: '0',   delta: 0, t: { en: 'No sugar',  ms: 'Tiada gula', th: 'ไม่หวาน' } },
      { slug: '25',  delta: 0, t: { en: '25%',       ms: '25%',        th: '25%' } },
      { slug: '50',  delta: 0, t: { en: '50%',       ms: '50%',        th: '50%' } },
      { slug: '100', delta: 0, t: { en: 'Normal',    ms: 'Biasa',      th: 'ปกติ' } },
    ],
  },
  {
    slug: 'ice', min: 1, max: 1,
    t: { en: 'Ice', ms: 'Ais', th: 'น้ำแข็ง' },
    options: [
      { slug: 'less',   delta: 0, t: { en: 'Less ice', ms: 'Kurang ais', th: 'น้ำแข็งน้อย' } },
      { slug: 'normal', delta: 0, t: { en: 'Normal',   ms: 'Biasa',      th: 'ปกติ' } },
      { slug: 'none',   delta: 0, t: { en: 'No ice',   ms: 'Tiada ais',  th: 'ไม่ใส่น้ำแข็ง' } },
    ],
  },
];

// Menu items — SKU, category, customisations, dietary tags, translations.
// Pricing is per-country and lives in seed-data/pricing.json.
type Item = {
  sku: string;
  category: string;
  customGroups: string[];
  dietary: string[];
  t: Record<'en' | 'ms' | 'th', { name: string; description: string }>;
};

const ITEMS: Item[] = [
  { sku: 'ESP-001', category: 'espresso', customGroups: ['size','milk','sugar'], dietary: [],
    t: {
      en: { name: 'Espresso',           description: 'Double shot of our signature blend.' },
      ms: { name: 'Espresso',           description: 'Dua tembakan campuran istimewa kami.' },
      th: { name: 'เอสเพรสโซ่',          description: 'เอสเพรสโซ่ดับเบิ้ลช็อตจากกาแฟคั่วของเรา' },
    } },
  { sku: 'ESP-002', category: 'espresso', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Latte',              description: 'Smooth espresso with steamed milk.' },
      ms: { name: 'Latte',              description: 'Espresso lembut dengan susu kukus.' },
      th: { name: 'ลาเต้',               description: 'เอสเพรสโซ่นุ่มนวลกับนมร้อน' },
    } },
  { sku: 'ESP-003', category: 'espresso', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Cappuccino',         description: 'Espresso with foamed milk and cocoa.' },
      ms: { name: 'Cappuccino',         description: 'Espresso dengan susu berbuih dan koko.' },
      th: { name: 'คาปูชิโน่',            description: 'เอสเพรสโซ่กับโฟมนมและผงโกโก้' },
    } },
  { sku: 'ESP-004', category: 'espresso', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Mocha',              description: 'Espresso, steamed milk, and chocolate.' },
      ms: { name: 'Mocha',              description: 'Espresso, susu kukus, dan coklat.' },
      th: { name: 'มอคค่า',              description: 'เอสเพรสโซ่ผสมนมและช็อกโกแลต' },
    } },
  { sku: 'ESP-005', category: 'espresso', customGroups: ['size','milk','sugar'], dietary: [],
    t: {
      en: { name: 'Macchiato',          description: 'Espresso marked with a dollop of foam.' },
      ms: { name: 'Macchiato',          description: 'Espresso dengan setitik buih susu.' },
      th: { name: 'มัคคิอาโต้',           description: 'เอสเพรสโซ่ตกแต่งด้วยโฟมนม' },
    } },
  { sku: 'BRW-001', category: 'brew', customGroups: ['size','sugar','ice'], dietary: ['dairy-free'],
    t: {
      en: { name: 'V60 Pour Over',      description: 'Single-origin, brewed by hand.' },
      ms: { name: 'V60 Tuang',          description: 'Asal tunggal, dibancuh dengan tangan.' },
      th: { name: 'V60 ดริป',           description: 'เมล็ดกาแฟแหล่งเดียว ดริปสดด้วยมือ' },
    } },
  { sku: 'BRW-002', category: 'brew', customGroups: ['size','sugar','ice'], dietary: ['dairy-free'],
    t: {
      en: { name: 'Cold Brew',          description: '16-hour slow extraction.' },
      ms: { name: 'Kopi Sejuk',         description: 'Penyarian perlahan 16 jam.' },
      th: { name: 'โคลด์บรูว',           description: 'สกัดเย็น 16 ชั่วโมง' },
    } },
  { sku: 'BRW-003', category: 'brew', customGroups: ['size','sugar','ice'], dietary: ['dairy-free'],
    t: {
      en: { name: 'Americano',          description: 'Espresso lengthened with hot water.' },
      ms: { name: 'Americano',          description: 'Espresso dengan air panas.' },
      th: { name: 'อเมริกาโน่',           description: 'เอสเพรสโซ่ผสมน้ำร้อน' },
    } },
  { sku: 'SPC-001', category: 'specialty', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Pandan Latte',       description: 'Local pandan syrup, espresso, steamed milk.' },
      ms: { name: 'Latte Pandan',       description: 'Sirap pandan tempatan, espresso, susu kukus.' },
      th: { name: 'ลาเต้ใบเตย',          description: 'ไซรัปใบเตยกับเอสเพรสโซ่และนม' },
    } },
  { sku: 'SPC-002', category: 'specialty', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Gula Melaka Latte',  description: 'Palm sugar caramel meets espresso.' },
      ms: { name: 'Latte Gula Melaka',  description: 'Karamel gula melaka bertemu espresso.' },
      th: { name: 'ลาเต้น้ำตาลโตนด',     description: 'น้ำตาลโตนดผสมเอสเพรสโซ่' },
    } },
  { sku: 'SPC-003', category: 'specialty', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Thai Iced Coffee',   description: 'Strong drip coffee with sweetened milk.' },
      ms: { name: 'Kopi Ais Thai',      description: 'Kopi titis pekat dengan susu manis.' },
      th: { name: 'กาแฟเย็นไทย',         description: 'กาแฟดริปเข้มข้นกับนมข้นหวาน' },
    } },
  { sku: 'SPC-004', category: 'specialty', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Matcha Latte',       description: 'Ceremonial-grade matcha with milk.' },
      ms: { name: 'Latte Matcha',       description: 'Matcha gred upacara dengan susu.' },
      th: { name: 'มัทฉะลาเต้',          description: 'มัทฉะเกรดพิธีผสมนม' },
    } },
  { sku: 'NCF-001', category: 'non-coffee', customGroups: ['size','sugar','ice'], dietary: ['caffeine-free'],
    t: {
      en: { name: 'Honey Lemonade',     description: 'Fresh lemon, local honey, sparkling water.' },
      ms: { name: 'Limau Madu',         description: 'Lemon segar, madu tempatan, air berkilauan.' },
      th: { name: 'เลม่อนน้ำผึ้ง',         description: 'เลม่อนสด น้ำผึ้งท้องถิ่น และโซดา' },
    } },
  { sku: 'NCF-002', category: 'non-coffee', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Hot Chocolate',      description: 'Rich dark chocolate with steamed milk.' },
      ms: { name: 'Coklat Panas',       description: 'Coklat hitam pekat dengan susu kukus.' },
      th: { name: 'ช็อกโกแลตร้อน',      description: 'ช็อกโกแลตเข้มข้นผสมนมร้อน' },
    } },
  { sku: 'NCF-003', category: 'non-coffee', customGroups: ['size','sugar','ice'], dietary: ['caffeine-free'],
    t: {
      en: { name: 'Yuzu Cooler',        description: 'Japanese yuzu with mint and ice.' },
      ms: { name: 'Yuzu Sejuk',         description: 'Yuzu Jepun dengan pudina dan ais.' },
      th: { name: 'ยูซุคูลเลอร์',         description: 'น้ำส้มยูซุญี่ปุ่นกับมิ้นต์' },
    } },
  { sku: 'FD-001', category: 'food', customGroups: [], dietary: ['vegetarian'],
    t: {
      en: { name: 'Almond Croissant',   description: 'Flaky pastry with almond cream.' },
      ms: { name: 'Croissant Badam',    description: 'Pastri lapis dengan krim badam.' },
      th: { name: 'ครัวซองต์อัลมอนด์',    description: 'ขนมอบกรอบนุ่มไส้ครีมอัลมอนด์' },
    } },
  { sku: 'FD-002', category: 'food', customGroups: [], dietary: ['vegetarian'],
    t: {
      en: { name: 'Avocado Toast',      description: 'Sourdough, avocado, chili flakes.' },
      ms: { name: 'Roti Avokado',       description: 'Roti masam, avokado, serpihan cili.' },
      th: { name: 'อะโวคาโดโทสต์',      description: 'ขนมปังซาวโดว์กับอะโวคาโด' },
    } },
  { sku: 'FD-003', category: 'food', customGroups: [], dietary: ['halal'],
    t: {
      en: { name: 'Chicken Slider',     description: 'Spiced grilled chicken in a brioche bun.' },
      ms: { name: 'Slider Ayam',        description: 'Ayam panggang berempah dalam roti brioche.' },
      th: { name: 'สไลเดอร์ไก่',         description: 'ไก่ย่างเครื่องเทศในขนมปังบริออช' },
    } },
];

// ── Validation: fail fast before touching the DB ────────────────────────────
function validateSeedData() {
  const countryCodes = new Set(COUNTRIES.map((c) => c.code));
  const errors: string[] = [];

  for (const item of ITEMS) {
    const priceMap = PRICING[item.sku];
    if (!priceMap) {
      errors.push(`pricing.json: missing entry for SKU "${item.sku}"`);
      continue;
    }
    for (const code of countryCodes) {
      if (priceMap[code] === undefined) {
        errors.push(`pricing.json: SKU "${item.sku}" has no price for country "${code}"`);
      }
    }
  }

  for (const v of VOUCHERS) {
    for (const code of v.countries) {
      if (!countryCodes.has(code)) {
        errors.push(`vouchers.json: voucher "${v.code}" references unknown country "${code}"`);
      }
    }
  }

  for (const f of FLAGS) {
    if (f.country !== null && !countryCodes.has(f.country)) {
      errors.push(`feature-flags.json: flag "${f.key}" references unknown country "${f.country}"`);
    }
  }

  // option-pricing keys must match an actual customisation option, and
  // each per-country override must reference a known country.
  const optionKeys = new Set<string>();
  for (const g of CUSTOM_GROUPS) {
    for (const opt of g.options) optionKeys.add(`${g.slug}/${opt.slug}`);
  }
  for (const [key, perCountry] of Object.entries(OPTION_PRICING)) {
    if (!optionKeys.has(key)) {
      errors.push(`option-pricing.json: unknown option key "${key}" (format: "<groupSlug>/<optionSlug>")`);
    }
    for (const code of Object.keys(perCountry)) {
      if (!countryCodes.has(code)) {
        errors.push(`option-pricing.json: option "${key}" overrides for unknown country "${code}"`);
      }
    }
  }

  if (errors.length) {
    console.error('❌ seed-data validation failed:\n  - ' + errors.join('\n  - '));
    process.exit(1);
  }
}

async function main() {
  validateSeedData();
  console.log('🌱 seeding Baskbear data…');

  // Locales (derived from countries.json)
  for (const l of LOCALES) {
    await prisma.locale.upsert({ where: { code: l.code }, update: {}, create: l });
  }
  const localeByCode = Object.fromEntries(
    (await prisma.locale.findMany()).map((l) => [l.code, l.id]),
  );

  // Countries
  for (const c of COUNTRIES) {
    await prisma.country.upsert({
      where: { code: c.code },
      update: {
        name: c.name, currencyCode: c.currencyCode,
        taxRateBps: c.taxRateBps, timezone: c.timezone, defaultLocale: c.defaultLocale,
      },
      create: {
        code: c.code, name: c.name, currencyCode: c.currencyCode,
        taxRateBps: c.taxRateBps, timezone: c.timezone, defaultLocale: c.defaultLocale,
      },
    });
  }
  const countryByCode = Object.fromEntries(
    (await prisma.country.findMany()).map((c) => [c.code, c.id]),
  );

  // Country-locales
  for (const c of COUNTRIES) {
    for (const lc of c.locales) {
      await prisma.countryLocale.upsert({
        where: { countryId_localeId: { countryId: countryByCode[c.code], localeId: localeByCode[lc] } },
        update: { isDefault: lc === c.defaultLocale },
        create: {
          countryId: countryByCode[c.code],
          localeId:  localeByCode[lc],
          isDefault: lc === c.defaultLocale,
        },
      });
    }
  }

  // Outlets (idempotent via findFirst on name; outlets live inside each country)
  for (const c of COUNTRIES) {
    for (const o of c.outlets) {
      const existing = await prisma.outlet.findFirst({ where: { name: o.name } });
      if (!existing) {
        await prisma.outlet.create({
          data: {
            countryId: countryByCode[c.code],
            name: o.name, address: o.address,
            latitude: o.lat, longitude: o.lng,
          },
        });
      }
    }
  }

  // Categories + translations
  for (const cat of CATEGORIES) {
    const dbCat = await prisma.category.upsert({
      where: { slug: cat.slug },
      update: { sortOrder: cat.sortOrder },
      create: { slug: cat.slug, sortOrder: cat.sortOrder },
    });
    for (const [lc, name] of Object.entries(cat.t)) {
      if (!localeByCode[lc]) continue;
      await prisma.categoryTranslation.upsert({
        where: { categoryId_localeId: { categoryId: dbCat.id, localeId: localeByCode[lc] } },
        update: { name },
        create: { categoryId: dbCat.id, localeId: localeByCode[lc], name },
      });
    }
  }
  const catBySlug = Object.fromEntries(
    (await prisma.category.findMany()).map((c) => [c.slug, c.id]),
  );

  // Customisation groups + options + per-country option overrides (from JSON)
  const groupIdBySlug: Record<string, number> = {};
  for (const g of CUSTOM_GROUPS) {
    const dbGroup = await prisma.customisationGroup.upsert({
      where: { slug: g.slug },
      update: { minSelect: g.min, maxSelect: g.max },
      create: { slug: g.slug, minSelect: g.min, maxSelect: g.max },
    });
    groupIdBySlug[g.slug] = dbGroup.id;
    for (const [lc, name] of Object.entries(g.t)) {
      if (!localeByCode[lc]) continue;
      await prisma.customisationGroupTranslation.upsert({
        where: { groupId_localeId: { groupId: dbGroup.id, localeId: localeByCode[lc] } },
        update: { name },
        create: { groupId: dbGroup.id, localeId: localeByCode[lc], name },
      });
    }
    for (const opt of g.options) {
      const dbOpt = await prisma.customisationOption.upsert({
        where: { groupId_slug: { groupId: dbGroup.id, slug: opt.slug } },
        update: { priceDeltaMinor: opt.delta },
        create: { groupId: dbGroup.id, slug: opt.slug, priceDeltaMinor: opt.delta },
      });
      for (const [lc, name] of Object.entries(opt.t)) {
        if (!localeByCode[lc]) continue;
        await prisma.customisationOptionTranslation.upsert({
          where: { optionId_localeId: { optionId: dbOpt.id, localeId: localeByCode[lc] } },
          update: { name },
          create: { optionId: dbOpt.id, localeId: localeByCode[lc], name },
        });
      }
      const overrides = OPTION_PRICING[`${g.slug}/${opt.slug}`];
      if (overrides) {
        for (const [cc, delta] of Object.entries(overrides)) {
          await prisma.customisationOptionCountryPrice.upsert({
            where: { optionId_countryId: { optionId: dbOpt.id, countryId: countryByCode[cc] } },
            update: { priceDeltaMinor: delta },
            create: { optionId: dbOpt.id, countryId: countryByCode[cc], priceDeltaMinor: delta },
          });
        }
      }
    }
  }

  // Menu items + translations + country pricing + customisation groups
  for (const it of ITEMS) {
    const dbItem = await prisma.menuItem.upsert({
      where: { sku: it.sku },
      update: {
        categoryId: catBySlug[it.category],
        dietaryTags: it.dietary,
      },
      create: {
        sku: it.sku,
        categoryId: catBySlug[it.category],
        dietaryTags: it.dietary,
      },
    });
    for (const [lc, t] of Object.entries(it.t)) {
      if (!localeByCode[lc]) continue;
      await prisma.menuItemTranslation.upsert({
        where: { menuItemId_localeId: { menuItemId: dbItem.id, localeId: localeByCode[lc] } },
        update: { name: t.name, description: t.description },
        create: {
          menuItemId: dbItem.id, localeId: localeByCode[lc],
          name: t.name, description: t.description,
        },
      });
    }
    for (const [cc, price] of Object.entries(PRICING[it.sku])) {
      await prisma.menuItemCountryPrice.upsert({
        where: { menuItemId_countryId: { menuItemId: dbItem.id, countryId: countryByCode[cc] } },
        update: { priceMinor: price },
        create: { menuItemId: dbItem.id, countryId: countryByCode[cc], priceMinor: price },
      });
    }
    await prisma.menuItemCustomisationGroup.deleteMany({ where: { menuItemId: dbItem.id } });
    for (let i = 0; i < it.customGroups.length; i++) {
      await prisma.menuItemCustomisationGroup.create({
        data: {
          menuItemId: dbItem.id,
          groupId: groupIdBySlug[it.customGroups[i]],
          sortOrder: i,
        },
      });
    }
  }

  // Vouchers
  for (const v of VOUCHERS) {
    const dbV = await prisma.voucher.upsert({
      where: { code: v.code },
      update: {
        type: v.type as VoucherType, value: v.value, minSpendMinor: v.minSpend,
        maxDiscountMinor: v.maxDiscount, perUserLimit: v.perUser, totalLimit: v.total,
        startsAt: new Date(v.startsAt), endsAt: new Date(v.endsAt),
        stackable: v.stackable, isActive: true,
      },
      create: {
        code: v.code, type: v.type as VoucherType, value: v.value, minSpendMinor: v.minSpend,
        maxDiscountMinor: v.maxDiscount, perUserLimit: v.perUser, totalLimit: v.total,
        startsAt: new Date(v.startsAt), endsAt: new Date(v.endsAt),
        stackable: v.stackable, isActive: true,
      },
    });
    await prisma.voucherCountry.deleteMany({ where: { voucherId: dbV.id } });
    for (const cc of v.countries) {
      await prisma.voucherCountry.create({
        data: { voucherId: dbV.id, countryId: countryByCode[cc] },
      });
    }
  }

  // Feature flags
  for (const f of FLAGS) {
    const countryId = f.country === null ? null : countryByCode[f.country];
    const existing = await prisma.featureFlag.findFirst({
      where: { key: f.key, countryId },
    });
    if (existing) {
      await prisma.featureFlag.update({
        where: { id: existing.id },
        data: { isEnabled: f.isEnabled },
      });
    } else {
      await prisma.featureFlag.create({
        data: { key: f.key, countryId, isEnabled: f.isEnabled },
      });
    }
  }

  // Demo user — defaults to the first country in countries.json so adding
  // a country and reordering won't leave the demo pointing at nothing.
  const demoCountryCode = COUNTRIES[0].code;
  await prisma.user.upsert({
    where: { cognitoSub: 'demo-user-sub' },
    update: {},
    create: {
      cognitoSub: 'demo-user-sub',
      email: 'demo@baskbear.test',
      defaultCountryId: countryByCode[demoCountryCode],
      defaultLocaleId:  localeByCode['en'],
    },
  });

  console.log('✅ seed complete');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

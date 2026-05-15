/**
 * Baskbear seed data.
 *
 * Idempotent — uses upserts on natural keys (codes, slugs, SKUs) so re-running
 * doesn't blow up. Designed for local dev + CI; production seed strategy is
 * documented in README.md.
 */
import { PrismaClient, VoucherType } from '@prisma/client';

const prisma = new PrismaClient();

// ── Reference data ──────────────────────────────────────────────────────────
const LOCALES = [
  { code: 'en' },
  { code: 'ms' }, // Bahasa Malaysia
  { code: 'th' }, // Thai
] as const;

const COUNTRIES = [
  {
    code: 'MY',
    name: 'Malaysia',
    currencyCode: 'MYR',
    taxRateBps: 600, // 6% SST
    timezone: 'Asia/Kuala_Lumpur',
    defaultLocale: 'en',
    locales: ['en', 'ms'],
  },
  {
    code: 'TH',
    name: 'Thailand',
    currencyCode: 'THB',
    taxRateBps: 700, // 7% VAT
    timezone: 'Asia/Bangkok',
    defaultLocale: 'en',
    locales: ['en', 'th'],
  },
] as const;

const OUTLETS = [
  { country: 'MY', name: 'Baskbear KLCC', address: 'Lot 421, Suria KLCC, Kuala Lumpur', lat: 3.158, lng: 101.713 },
  { country: 'MY', name: 'Baskbear Mid Valley', address: 'LG-021, Mid Valley Megamall, KL', lat: 3.118, lng: 101.677 },
  { country: 'TH', name: 'Baskbear Siam Paragon', address: '991 Rama I Rd, Pathum Wan, Bangkok', lat: 13.746, lng: 100.534 },
  { country: 'TH', name: 'Baskbear EmQuartier', address: '693-695 Sukhumvit Rd, Khlong Toei, Bangkok', lat: 13.731, lng: 100.569 },
];

const CATEGORIES = [
  { slug: 'espresso',     sortOrder: 1, t: { en: 'Espresso',     ms: 'Espresso',          th: 'เอสเพรสโซ่' } },
  { slug: 'brew',         sortOrder: 2, t: { en: 'Brewed',       ms: 'Bancuhan',          th: 'กาแฟดริป' } },
  { slug: 'specialty',    sortOrder: 3, t: { en: 'Specialty',    ms: 'Istimewa',          th: 'เมนูพิเศษ' } },
  { slug: 'non-coffee',   sortOrder: 4, t: { en: 'Non-Coffee',   ms: 'Bukan Kopi',        th: 'เครื่องดื่มอื่น ๆ' } },
  { slug: 'food',         sortOrder: 5, t: { en: 'Food',         ms: 'Makanan',           th: 'อาหาร' } },
];

// Customisation groups
const CUSTOM_GROUPS = [
  {
    slug: 'size',
    min: 1,
    max: 1,
    t: { en: 'Size', ms: 'Saiz', th: 'ขนาด' },
    options: [
      { slug: 'S', delta: 0,    t: { en: 'Small',  ms: 'Kecil',  th: 'เล็ก' } },
      { slug: 'M', delta: 200,  t: { en: 'Medium', ms: 'Sederhana', th: 'กลาง' } },
      { slug: 'L', delta: 400,  t: { en: 'Large',  ms: 'Besar',  th: 'ใหญ่' } },
    ],
  },
  {
    slug: 'milk',
    min: 1,
    max: 1,
    t: { en: 'Milk', ms: 'Susu', th: 'นม' },
    options: [
      { slug: 'whole', delta: 0,   t: { en: 'Whole',  ms: 'Susu Penuh', th: 'นมสด' } },
      { slug: 'skim',  delta: 0,   t: { en: 'Skim',   ms: 'Susu Rendah Lemak', th: 'นมพร่อง' } },
      { slug: 'oat',   delta: 250, t: { en: 'Oat',    ms: 'Oat',         th: 'นมโอ๊ต' } },
      { slug: 'soy',   delta: 200, t: { en: 'Soy',    ms: 'Susu Soya',   th: 'นมถั่วเหลือง' } },
    ],
  },
  {
    slug: 'sugar',
    min: 1,
    max: 1,
    t: { en: 'Sugar', ms: 'Gula', th: 'ความหวาน' },
    options: [
      { slug: '0',   delta: 0, t: { en: 'No sugar',  ms: 'Tiada gula', th: 'ไม่หวาน' } },
      { slug: '25',  delta: 0, t: { en: '25%',       ms: '25%',        th: '25%' } },
      { slug: '50',  delta: 0, t: { en: '50%',       ms: '50%',        th: '50%' } },
      { slug: '100', delta: 0, t: { en: 'Normal',    ms: 'Biasa',      th: 'ปกติ' } },
    ],
  },
  {
    slug: 'ice',
    min: 1,
    max: 1,
    t: { en: 'Ice', ms: 'Ais', th: 'น้ำแข็ง' },
    options: [
      { slug: 'less',   delta: 0, t: { en: 'Less ice', ms: 'Kurang ais', th: 'น้ำแข็งน้อย' } },
      { slug: 'normal', delta: 0, t: { en: 'Normal',   ms: 'Biasa',      th: 'ปกติ' } },
      { slug: 'none',   delta: 0, t: { en: 'No ice',   ms: 'Tiada ais',  th: 'ไม่ใส่น้ำแข็ง' } },
    ],
  },
];

// Menu items. Prices in MINOR units. MY uses MYR (100 = RM 1.00), TH uses THB (100 = ฿1.00).
type Item = {
  sku: string;
  category: string;
  customGroups: string[];
  dietary: string[];
  t: Record<'en' | 'ms' | 'th', { name: string; description: string }>;
  pricing: { MY: number; TH: number };
};

const ITEMS: Item[] = [
  // Espresso
  {
    sku: 'ESP-001', category: 'espresso', customGroups: ['size','milk','sugar'], dietary: [],
    t: {
      en: { name: 'Espresso',           description: 'Double shot of our signature blend.' },
      ms: { name: 'Espresso',           description: 'Dua tembakan campuran istimewa kami.' },
      th: { name: 'เอสเพรสโซ่',          description: 'เอสเพรสโซ่ดับเบิ้ลช็อตจากกาแฟคั่วของเรา' },
    },
    pricing: { MY: 850, TH: 8500 },
  },
  {
    sku: 'ESP-002', category: 'espresso', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Latte',              description: 'Smooth espresso with steamed milk.' },
      ms: { name: 'Latte',              description: 'Espresso lembut dengan susu kukus.' },
      th: { name: 'ลาเต้',               description: 'เอสเพรสโซ่นุ่มนวลกับนมร้อน' },
    },
    pricing: { MY: 1200, TH: 12000 },
  },
  {
    sku: 'ESP-003', category: 'espresso', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Cappuccino',         description: 'Espresso with foamed milk and cocoa.' },
      ms: { name: 'Cappuccino',         description: 'Espresso dengan susu berbuih dan koko.' },
      th: { name: 'คาปูชิโน่',            description: 'เอสเพรสโซ่กับโฟมนมและผงโกโก้' },
    },
    pricing: { MY: 1200, TH: 12000 },
  },
  {
    sku: 'ESP-004', category: 'espresso', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Mocha',              description: 'Espresso, steamed milk, and chocolate.' },
      ms: { name: 'Mocha',              description: 'Espresso, susu kukus, dan coklat.' },
      th: { name: 'มอคค่า',              description: 'เอสเพรสโซ่ผสมนมและช็อกโกแลต' },
    },
    pricing: { MY: 1400, TH: 14000 },
  },
  {
    sku: 'ESP-005', category: 'espresso', customGroups: ['size','milk','sugar'], dietary: [],
    t: {
      en: { name: 'Macchiato',          description: 'Espresso marked with a dollop of foam.' },
      ms: { name: 'Macchiato',          description: 'Espresso dengan setitik buih susu.' },
      th: { name: 'มัคคิอาโต้',           description: 'เอสเพรสโซ่ตกแต่งด้วยโฟมนม' },
    },
    pricing: { MY: 1000, TH: 10000 },
  },
  // Brew
  {
    sku: 'BRW-001', category: 'brew', customGroups: ['size','sugar','ice'], dietary: ['dairy-free'],
    t: {
      en: { name: 'V60 Pour Over',      description: 'Single-origin, brewed by hand.' },
      ms: { name: 'V60 Tuang',          description: 'Asal tunggal, dibancuh dengan tangan.' },
      th: { name: 'V60 ดริป',           description: 'เมล็ดกาแฟแหล่งเดียว ดริปสดด้วยมือ' },
    },
    pricing: { MY: 1500, TH: 15000 },
  },
  {
    sku: 'BRW-002', category: 'brew', customGroups: ['size','sugar','ice'], dietary: ['dairy-free'],
    t: {
      en: { name: 'Cold Brew',          description: '16-hour slow extraction.' },
      ms: { name: 'Kopi Sejuk',         description: 'Penyarian perlahan 16 jam.' },
      th: { name: 'โคลด์บรูว',           description: 'สกัดเย็น 16 ชั่วโมง' },
    },
    pricing: { MY: 1300, TH: 13000 },
  },
  {
    sku: 'BRW-003', category: 'brew', customGroups: ['size','sugar','ice'], dietary: ['dairy-free'],
    t: {
      en: { name: 'Americano',          description: 'Espresso lengthened with hot water.' },
      ms: { name: 'Americano',          description: 'Espresso dengan air panas.' },
      th: { name: 'อเมริกาโน่',           description: 'เอสเพรสโซ่ผสมน้ำร้อน' },
    },
    pricing: { MY: 950, TH: 9500 },
  },
  // Specialty
  {
    sku: 'SPC-001', category: 'specialty', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Pandan Latte',       description: 'Local pandan syrup, espresso, steamed milk.' },
      ms: { name: 'Latte Pandan',       description: 'Sirap pandan tempatan, espresso, susu kukus.' },
      th: { name: 'ลาเต้ใบเตย',          description: 'ไซรัปใบเตยกับเอสเพรสโซ่และนม' },
    },
    pricing: { MY: 1500, TH: 15000 },
  },
  {
    sku: 'SPC-002', category: 'specialty', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Gula Melaka Latte',  description: 'Palm sugar caramel meets espresso.' },
      ms: { name: 'Latte Gula Melaka',  description: 'Karamel gula melaka bertemu espresso.' },
      th: { name: 'ลาเต้น้ำตาลโตนด',     description: 'น้ำตาลโตนดผสมเอสเพรสโซ่' },
    },
    pricing: { MY: 1600, TH: 16000 },
  },
  {
    sku: 'SPC-003', category: 'specialty', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Thai Iced Coffee',   description: 'Strong drip coffee with sweetened milk.' },
      ms: { name: 'Kopi Ais Thai',      description: 'Kopi titis pekat dengan susu manis.' },
      th: { name: 'กาแฟเย็นไทย',         description: 'กาแฟดริปเข้มข้นกับนมข้นหวาน' },
    },
    pricing: { MY: 1400, TH: 11000 },
  },
  {
    sku: 'SPC-004', category: 'specialty', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Matcha Latte',       description: 'Ceremonial-grade matcha with milk.' },
      ms: { name: 'Latte Matcha',       description: 'Matcha gred upacara dengan susu.' },
      th: { name: 'มัทฉะลาเต้',          description: 'มัทฉะเกรดพิธีผสมนม' },
    },
    pricing: { MY: 1500, TH: 15000 },
  },
  // Non-coffee
  {
    sku: 'NCF-001', category: 'non-coffee', customGroups: ['size','sugar','ice'], dietary: ['caffeine-free'],
    t: {
      en: { name: 'Honey Lemonade',     description: 'Fresh lemon, local honey, sparkling water.' },
      ms: { name: 'Limau Madu',         description: 'Lemon segar, madu tempatan, air berkilauan.' },
      th: { name: 'เลม่อนน้ำผึ้ง',         description: 'เลม่อนสด น้ำผึ้งท้องถิ่น และโซดา' },
    },
    pricing: { MY: 1100, TH: 11000 },
  },
  {
    sku: 'NCF-002', category: 'non-coffee', customGroups: ['size','milk','sugar','ice'], dietary: [],
    t: {
      en: { name: 'Hot Chocolate',      description: 'Rich dark chocolate with steamed milk.' },
      ms: { name: 'Coklat Panas',       description: 'Coklat hitam pekat dengan susu kukus.' },
      th: { name: 'ช็อกโกแลตร้อน',      description: 'ช็อกโกแลตเข้มข้นผสมนมร้อน' },
    },
    pricing: { MY: 1300, TH: 13000 },
  },
  {
    sku: 'NCF-003', category: 'non-coffee', customGroups: ['size','sugar','ice'], dietary: ['caffeine-free'],
    t: {
      en: { name: 'Yuzu Cooler',        description: 'Japanese yuzu with mint and ice.' },
      ms: { name: 'Yuzu Sejuk',         description: 'Yuzu Jepun dengan pudina dan ais.' },
      th: { name: 'ยูซุคูลเลอร์',         description: 'น้ำส้มยูซุญี่ปุ่นกับมิ้นต์' },
    },
    pricing: { MY: 1300, TH: 13000 },
  },
  // Food
  {
    sku: 'FD-001', category: 'food', customGroups: [], dietary: ['vegetarian'],
    t: {
      en: { name: 'Almond Croissant',   description: 'Flaky pastry with almond cream.' },
      ms: { name: 'Croissant Badam',    description: 'Pastri lapis dengan krim badam.' },
      th: { name: 'ครัวซองต์อัลมอนด์',    description: 'ขนมอบกรอบนุ่มไส้ครีมอัลมอนด์' },
    },
    pricing: { MY: 950, TH: 9500 },
  },
  {
    sku: 'FD-002', category: 'food', customGroups: [], dietary: ['vegetarian'],
    t: {
      en: { name: 'Avocado Toast',      description: 'Sourdough, avocado, chili flakes.' },
      ms: { name: 'Roti Avokado',       description: 'Roti masam, avokado, serpihan cili.' },
      th: { name: 'อะโวคาโดโทสต์',      description: 'ขนมปังซาวโดว์กับอะโวคาโด' },
    },
    pricing: { MY: 1800, TH: 18000 },
  },
  {
    sku: 'FD-003', category: 'food', customGroups: [], dietary: ['halal'],
    t: {
      en: { name: 'Chicken Slider',     description: 'Spiced grilled chicken in a brioche bun.' },
      ms: { name: 'Slider Ayam',        description: 'Ayam panggang berempah dalam roti brioche.' },
      th: { name: 'สไลเดอร์ไก่',         description: 'ไก่ย่างเครื่องเทศในขนมปังบริออช' },
    },
    pricing: { MY: 1500, TH: 15000 },
  },
];

// Vouchers
const VOUCHERS = [
  {
    code: 'WELCOME10',
    type: VoucherType.PERCENT,
    value: 1000,            // 10.00%
    minSpend: 1500,         // RM 15 / THB 150 — we use MYR for the threshold but
    maxDiscount: 500,       // cap at RM 5 — see voucher service for cross-currency note
    perUser: 1,
    total: null as number | null,
    startsAt: new Date('2026-01-01T00:00:00Z'),
    endsAt:   new Date('2026-12-31T23:59:59Z'),
    stackable: false,
    countries: ['MY', 'TH'],
  },
  {
    code: 'MY5OFF',
    type: VoucherType.FIXED,
    value: 500,             // RM 5 off
    minSpend: 2500,         // RM 25
    maxDiscount: null,
    perUser: 3,
    total: 1000,
    startsAt: new Date('2026-04-01T00:00:00Z'),
    endsAt:   new Date('2026-12-31T23:59:59Z'),
    stackable: false,
    countries: ['MY'],
  },
  {
    code: 'EXPIRED20',
    type: VoucherType.PERCENT,
    value: 2000,
    minSpend: 0,
    maxDiscount: null,
    perUser: 1,
    total: null,
    startsAt: new Date('2024-01-01T00:00:00Z'),
    endsAt:   new Date('2024-12-31T23:59:59Z'),
    stackable: false,
    countries: ['MY', 'TH'],
  },
];

async function main() {
  console.log('🌱 seeding Baskbear data…');

  // Locales
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
      update: {},
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

  // Outlets (idempotent via findFirst on name)
  for (const o of OUTLETS) {
    const existing = await prisma.outlet.findFirst({ where: { name: o.name } });
    if (!existing) {
      await prisma.outlet.create({
        data: {
          countryId: countryByCode[o.country],
          name: o.name, address: o.address,
          latitude: o.lat, longitude: o.lng,
        },
      });
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

  // Customisation groups + options
  const groupIdBySlug: Record<string, number> = {};
  for (const g of CUSTOM_GROUPS) {
    const dbGroup = await prisma.customisationGroup.upsert({
      where: { slug: g.slug },
      update: { minSelect: g.min, maxSelect: g.max },
      create: { slug: g.slug, minSelect: g.min, maxSelect: g.max },
    });
    groupIdBySlug[g.slug] = dbGroup.id;
    for (const [lc, name] of Object.entries(g.t)) {
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
        await prisma.customisationOptionTranslation.upsert({
          where: { optionId_localeId: { optionId: dbOpt.id, localeId: localeByCode[lc] } },
          update: { name },
          create: { optionId: dbOpt.id, localeId: localeByCode[lc], name },
        });
      }
      // Thailand sees a 25% upcharge on oat/soy milk to reflect import cost
      if (g.slug === 'milk' && (opt.slug === 'oat' || opt.slug === 'soy')) {
        await prisma.customisationOptionCountryPrice.upsert({
          where: { optionId_countryId: { optionId: dbOpt.id, countryId: countryByCode['TH'] } },
          update: { priceDeltaMinor: Math.round(opt.delta * 12.5) }, // delta in MYR minor → THB minor approx
          create: { optionId: dbOpt.id, countryId: countryByCode['TH'], priceDeltaMinor: Math.round(opt.delta * 12.5) },
        });
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
      await prisma.menuItemTranslation.upsert({
        where: { menuItemId_localeId: { menuItemId: dbItem.id, localeId: localeByCode[lc] } },
        update: { name: t.name, description: t.description },
        create: {
          menuItemId: dbItem.id, localeId: localeByCode[lc],
          name: t.name, description: t.description,
        },
      });
    }
    for (const [cc, price] of Object.entries(it.pricing)) {
      await prisma.menuItemCountryPrice.upsert({
        where: { menuItemId_countryId: { menuItemId: dbItem.id, countryId: countryByCode[cc] } },
        update: { priceMinor: price },
        create: { menuItemId: dbItem.id, countryId: countryByCode[cc], priceMinor: price },
      });
    }
    // Link customisation groups (clear existing first to keep idempotent)
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
        type: v.type, value: v.value, minSpendMinor: v.minSpend,
        maxDiscountMinor: v.maxDiscount, perUserLimit: v.perUser, totalLimit: v.total,
        startsAt: v.startsAt, endsAt: v.endsAt, stackable: v.stackable, isActive: true,
      },
      create: {
        code: v.code, type: v.type, value: v.value, minSpendMinor: v.minSpend,
        maxDiscountMinor: v.maxDiscount, perUserLimit: v.perUser, totalLimit: v.total,
        startsAt: v.startsAt, endsAt: v.endsAt, stackable: v.stackable, isActive: true,
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
  const flags: Array<{ key: string; countryId: number | null; isEnabled: boolean }> = [
    { key: 'delivery_enabled',  countryId: countryByCode['MY'], isEnabled: true  },
    { key: 'delivery_enabled',  countryId: countryByCode['TH'], isEnabled: false },
    { key: 'loyalty_program',   countryId: null,                isEnabled: true  },
    { key: 'voucher_stacking',  countryId: null,                isEnabled: false },
  ];
  // Nullable composite uniques don't play well with prisma upsert; use findFirst.
  for (const f of flags) {
    const existing = await prisma.featureFlag.findFirst({
      where: { key: f.key, countryId: f.countryId },
    });
    if (existing) {
      await prisma.featureFlag.update({
        where: { id: existing.id },
        data: { isEnabled: f.isEnabled },
      });
    } else {
      await prisma.featureFlag.create({ data: f });
    }
  }

  // Demo user (created so reviewers can hit /v1/cart with DEV_AUTH_BYPASS)
  await prisma.user.upsert({
    where: { cognitoSub: 'demo-user-sub' },
    update: {},
    create: {
      cognitoSub: 'demo-user-sub',
      email: 'demo@baskbear.test',
      defaultCountryId: countryByCode['MY'],
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

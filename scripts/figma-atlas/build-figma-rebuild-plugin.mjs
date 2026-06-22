import fs from "node:fs";
import path from "node:path";

const repo = path.resolve(new URL("../..", import.meta.url).pathname);
const screenshotsDir = path.join(repo, "docs/billbandit-workflow/screenshots");
const layerMapPath = path.join(repo, "docs/billbandit-workflow/figma-atlas/layer-map.json");
const outDir = path.join(repo, "docs/billbandit-workflow/figma-plugin");
const manifestPath = path.join(outDir, "manifest.json");
const codePath = path.join(outDir, "code.js");
const reportPath = path.join(outDir, "README.md");

const screens = [
  { id: "01", title: "Welcome", file: "01-welcome.jpg", flow: "Auth", headline: "BillBandit", eyebrow: "SETTLE THE TAB", subtitle: "The trip ends. The tab settles itself.", cta: "Create account", secondary: "Login" },
  { id: "02", title: "New Member", file: "02-new-member.jpg", flow: "Auth", headline: "New member", eyebrow: "ACCOUNT RECEIPT", fields: ["Name", "Phone", "Email"], cta: "Create account" },
  { id: "03", title: "Trips Empty", file: "03-trips-empty.jpg", flow: "Trips", headline: "Trips", eyebrow: "LEDGER START", subtitle: "No trips yet", cta: "New trip" },
  { id: "04", title: "Your Trips", file: "04-your-trips.jpg", flow: "Trips", headline: "Trips", eyebrow: "ACTIVE LEDGERS", rows: ["Goa weekend", "Dinner crew"], cta: "Open ledger" },
  { id: "05", title: "New Ledger", file: "05-new-ledger.jpg", flow: "Trips", headline: "New ledger", eyebrow: "TRIP RECEIPT", fields: ["Trip name", "Currency", "Start date"], cta: "Create ledger" },
  { id: "05a", title: "Date Picker", file: "05a-new-ledger-dates.jpg", flow: "Trips", headline: "Dates", eyebrow: "CALENDAR", fields: ["Start", "End"], rows: ["June 2026"], cta: "Done" },
  { id: "06", title: "Live Ledger", file: "06-live-ledger.jpg", flow: "Ledger", headline: "Live ledger", eyebrow: "GOA WEEKEND", subtitle: "You are owed", rows: ["Hotel advance", "Dinner split", "Cab ride"], cta: "Add entry" },
  { id: "06a", title: "Ledger Empty", file: "06a-live-ledger-empty.jpg", flow: "Ledger", headline: "Live ledger", eyebrow: "GOA WEEKEND", subtitle: "No entries yet", cta: "Add entry" },
  { id: "07", title: "Settle", file: "07-settle.jpg", flow: "Settlement", headline: "Settle", eyebrow: "WHO PAYS WHOM", rows: ["Prateek pays Meera", "Rohit pays Prateek"], cta: "Settle up" },
  { id: "08", title: "Record Payment", file: "08-record-payment.jpg", flow: "Settlement", headline: "Record payment", eyebrow: "PAYMENT RECEIPT", fields: ["Amount", "Paid by", "Paid to"], cta: "Record payment" },
  { id: "09", title: "Final Bill", file: "09-final-bill.jpg", flow: "Settlement", headline: "Final bill", eyebrow: "ALL SETTLED", rows: ["Receipt", "Share summary"], cta: "Done" },
  { id: "10", title: "Add Entry", file: "10-add-entry.jpg", flow: "Ledger", headline: "Add entry", eyebrow: "EXPENSE RECEIPT", fields: ["Description", "Amount", "Paid by", "Split"], cta: "Save entry" },
  { id: "11", title: "Add Friend", file: "11-add-friend.jpg", flow: "Trips", headline: "Add friend", eyebrow: "INVITE", fields: ["Name or email"], cta: "Send invite" },
  { id: "12", title: "Auth Start", file: "12-auth-start.jpg", flow: "Auth", headline: "Start with your email or phone", eyebrow: "AUTH RECEIPT", fields: ["Email or phone"], cta: "Send code", secondary: "Sign in with Apple" },
  { id: "13", title: "Auth OTP", file: "13-auth-otp.jpg", flow: "Auth", headline: "Verify code", eyebrow: "ONE-TIME CODE", fields: ["Code"], cta: "Verify" },
  { id: "14", title: "Auth Profile", file: "14-auth-profile.jpg", flow: "Auth", headline: "Profile", eyebrow: "FINISH SETUP", fields: ["Display name"], cta: "Continue" },
  { id: "15", title: "Auth Loading", file: "15-auth-loading.jpg", flow: "Auth", headline: "Auth", eyebrow: "SETTING UP", subtitle: "Preparing your receipt", cta: "Please wait" },
];

const layerMap = JSON.parse(fs.readFileSync(layerMapPath, "utf8"));
const layerSummaries = Object.fromEntries(
  layerMap.screens.map((screen) => [
    screen.title,
    screen.layers.map((layer) => ({
      id: layer.id,
      label: layer.label,
      bounds: layer.bounds,
    })),
  ]),
);

const images = Object.fromEntries(
  screens.map((screen) => [
    screen.file,
    fs.readFileSync(path.join(screenshotsDir, screen.file)).toString("base64"),
  ]),
);

const manifest = {
  name: "BillBandit Native Rebuild",
  id: "billbandit-native-rebuild",
  api: "1.0.0",
  main: "code.js",
  editorType: ["figma"],
  documentAccess: "dynamic-page",
};

const pluginCode = `const RUN_ID = "bb-native-rebuild-" + new Date().toISOString().replace(/[:.]/g, "-");
const W = 368;
const H = 800;
const SCREENS = ${JSON.stringify(screens, null, 2)};
const LAYERS = ${JSON.stringify(layerSummaries, null, 2)};
const IMAGES = ${JSON.stringify(images)};

const FONT = { family: "Inter", style: "Regular" };
const FONT_MEDIUM = { family: "Inter", style: "Medium" };
const FONT_BOLD = { family: "Inter", style: "Bold" };
const C = {
  blue: { r: 36 / 255, g: 48 / 255, b: 224 / 255 },
  blue2: { r: 28 / 255, g: 41 / 255, b: 209 / 255 },
  ink: { r: 10 / 255, g: 31 / 255, b: 163 / 255 },
  navy: { r: 8 / 255, g: 13 / 255, b: 51 / 255 },
  paper: { r: 247 / 255, g: 242 / 255, b: 222 / 255 },
  cream: { r: 255 / 255, g: 245 / 255, b: 222 / 255 },
  muted: { r: 84 / 255, g: 99 / 255, b: 140 / 255 },
  line: { r: 191 / 255, g: 203 / 255, b: 230 / 255 },
  white: { r: 1, g: 1, b: 1 },
  black: { r: 0, g: 0, b: 0 },
};

function solid(color, opacity = 1) {
  return [{ type: "SOLID", color, opacity }];
}

function stroke(color, opacity = 1) {
  return [{ type: "SOLID", color, opacity }];
}

function b64ToBytes(b64) {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

async function loadFonts() {
  await figma.loadFontAsync(FONT);
  await figma.loadFontAsync(FONT_MEDIUM);
  await figma.loadFontAsync(FONT_BOLD);
}

function pageNamed(name) {
  let page = figma.root.children.find((p) => p.name === name);
  if (!page) page = figma.createPage();
  page.name = name;
  return page;
}

function tag(node, key, phase) {
  node.setSharedPluginData("billbandit", "run_id", RUN_ID);
  node.setSharedPluginData("billbandit", "key", key);
  node.setSharedPluginData("billbandit", "phase", phase);
}

function rect(name, x, y, w, h, fill, radius = 0, parent) {
  const node = figma.createRectangle();
  node.name = name;
  node.x = x;
  node.y = y;
  node.resize(w, h);
  node.fills = fill;
  node.cornerRadius = radius;
  if (parent) parent.appendChild(node);
  return node;
}

function text(name, value, x, y, size, fill, parent, fontName = FONT_BOLD) {
  const node = figma.createText();
  node.name = name;
  node.fontName = fontName;
  node.characters = value;
  node.fontSize = size;
  node.fills = fill;
  node.x = x;
  node.y = y;
  node.textAutoResize = "WIDTH_AND_HEIGHT";
  if (parent) parent.appendChild(node);
  return node;
}

function line(name, x, y, w, parent) {
  const node = figma.createLine();
  node.name = name;
  node.x = x;
  node.y = y;
  node.resize(w, 0);
  node.strokes = stroke(C.line, 0.7);
  if (parent) parent.appendChild(node);
  return node;
}

function makeComponent(name, w, h, build) {
  const c = figma.createComponent();
  c.name = name;
  c.resize(w, h);
  c.fills = [];
  build(c);
  tag(c, "component/" + name, "components");
  return c;
}

function mascot(parent, x, y, scale = 1) {
  const frame = figma.createFrame();
  frame.name = "BB Mascot / editable vector";
  frame.x = x;
  frame.y = y;
  frame.resize(120 * scale, 154 * scale);
  frame.fills = [];
  parent.appendChild(frame);
  const s = scale;
  const addEllipse = (name, cx, cy, rx, ry, fill, outline = false) => {
    const e = figma.createEllipse();
    e.name = name;
    e.x = (cx - rx) * s;
    e.y = (cy - ry) * s;
    e.resize(rx * 2 * s, ry * 2 * s);
    e.fills = fill;
    if (outline) {
      e.strokes = stroke(C.ink);
      e.strokeWeight = 4 * s;
    }
    frame.appendChild(e);
    return e;
  };
  addEllipse("Head", 60, 54, 48, 42, solid(C.cream), true);
  addEllipse("Left eye", 45, 54, 4, 4, solid(C.cream));
  addEllipse("Right eye", 76, 54, 4, 4, solid(C.cream));
  addEllipse("Nose", 61, 70, 9, 7, solid(C.ink));
  const mask = figma.createVector();
  mask.name = "Mask";
  mask.vectorPaths = [{ windingRule: "NONZERO", data: "M20 54 C34 34 50 34 60 55 C72 34 90 34 102 54 C86 74 72 74 60 61 C48 74 34 74 20 54Z" }];
  mask.resize(82 * s, 40 * s);
  mask.x = 20 * s;
  mask.y = 34 * s;
  mask.fills = solid(C.ink);
  frame.appendChild(mask);
  rect("Receipt", 42 * s, 96 * s, 40 * s, 54 * s, solid(C.cream), 2 * s, frame).strokes = stroke(C.ink);
  line("Receipt rule 1", 50 * s, 112 * s, 24 * s, frame);
  line("Receipt rule 2", 50 * s, 124 * s, 24 * s, frame);
  line("Receipt rule 3", 50 * s, 136 * s, 18 * s, frame);
  tag(frame, "mascot/vector", "screens");
  return frame;
}

function addReceiptPerforation(parent, x, y, h) {
  for (let dy = 18; dy < h - 8; dy += 22) {
    for (const sideX of [x, x + 320]) {
      const dot = figma.createEllipse();
      dot.name = "BB Receipt / perforation";
      dot.x = sideX - 6;
      dot.y = y + dy - 6;
      dot.resize(12, 12);
      dot.fills = solid({ r: 232 / 255, g: 237 / 255, b: 232 / 255 });
      parent.appendChild(dot);
    }
  }
}

function addScreenBackplate(frame, screen) {
  const image = figma.createImage(b64ToBytes(IMAGES[screen.file]));
  const plate = rect("LOCKED BACKPLATE / " + screen.id + " " + screen.title, 0, 0, W, H, [{ type: "IMAGE", scaleMode: "FILL", imageHash: image.hash }], 0, frame);
  plate.opacity = 0.2;
  try { plate.locked = true; } catch (error) {}
  tag(plate, "backplate/" + screen.id, "screens");
  return plate;
}

function createScreenFrame(pageFrame, screen, index, comps) {
  const col = index % 5;
  const row = Math.floor(index / 5);
  const x = col * 440;
  const y = row * 920;
  const frame = figma.createFrame();
  frame.name = "BB Screen " + screen.id + " / " + screen.title;
  frame.x = x;
  frame.y = y;
  frame.resize(W, H);
  frame.fills = solid(C.blue);
  pageFrame.appendChild(frame);
  tag(frame, "screen/" + screen.id, "screens");

  addScreenBackplate(frame, screen);
  const shell = comps.shell.createInstance();
  shell.name = "INSTANCE / BB Shell";
  shell.x = 0;
  shell.y = 0;
  frame.appendChild(shell);

  text("Status / time", "9:41", 22, 18, 12, solid(C.white), frame, FONT_MEDIUM);
  text("Status / signal", "LTE 100%", 280, 18, 12, solid(C.white), frame, FONT_MEDIUM);
  text("Flow eyebrow", screen.flow.toUpperCase(), 24, 64, 10, solid(C.white, 0.76), frame, FONT_BOLD);
  text("Headline", screen.headline, 24, 86, screen.id === "01" ? 34 : 28, solid(C.white), frame, FONT_BOLD);
  if (screen.subtitle) text("Subtitle", screen.subtitle, 24, 130, 15, solid(C.white, 0.84), frame, FONT_MEDIUM);
  mascot(frame, screen.id === "01" ? 122 : 134, screen.id === "01" ? 160 : 132, screen.id === "01" ? 1 : 0.78);

  const receiptY = screen.id === "01" || screen.id === "12" ? 394 : 284;
  const receiptH = screen.id === "01" || screen.id === "12" ? 306 : 436;
  const receipt = comps.receipt.createInstance();
  receipt.name = "INSTANCE / BB Receipt";
  receipt.x = 24;
  receipt.y = receiptY;
  receipt.resize(320, receiptH);
  frame.appendChild(receipt);
  addReceiptPerforation(frame, 24, receiptY, receiptH);
  text("Receipt eyebrow", screen.eyebrow, 48, receiptY + 30, 11, solid(C.ink), frame, FONT_BOLD);
  line("Receipt divider", 48, receiptY + 62, 272, frame);

  let cursor = receiptY + 84;
  const fields = screen.fields || [];
  fields.forEach((field) => {
    const inst = comps.field.createInstance();
    inst.name = "INSTANCE / BB Field / " + field;
    inst.x = 48;
    inst.y = cursor;
    frame.appendChild(inst);
    text("Field label / " + field, field.toUpperCase(), 60, cursor + 8, 10, solid(C.ink), frame, FONT_BOLD);
    cursor += 72;
  });

  const rows = screen.rows || [];
  rows.forEach((rowLabel) => {
    const inst = comps.row.createInstance();
    inst.name = "INSTANCE / BB Row / " + rowLabel;
    inst.x = 48;
    inst.y = cursor;
    frame.appendChild(inst);
    text("Row text / " + rowLabel, rowLabel, 68, cursor + 17, 13, solid(C.ink), frame, FONT_MEDIUM);
    cursor += 58;
  });

  if (!fields.length && !rows.length && screen.subtitle) {
    text("Empty body copy", screen.subtitle, 56, cursor, 18, solid(C.ink), frame, FONT_BOLD);
  }

  const primary = comps.buttonPrimary.createInstance();
  primary.name = "INSTANCE / BB Button Primary / " + screen.cta;
  primary.x = 48;
  primary.y = 696;
  frame.appendChild(primary);
  text("Button label / " + screen.cta, screen.cta, 78, 714, 14, solid(C.white), frame, FONT_BOLD);
  if (screen.secondary) {
    const secondary = comps.buttonSecondary.createInstance();
    secondary.name = "INSTANCE / BB Button Secondary / " + screen.secondary;
    secondary.x = 48;
    secondary.y = 632;
    frame.appendChild(secondary);
    text("Button label / " + screen.secondary, screen.secondary, 78, 650, 14, solid(C.ink), frame, FONT_BOLD);
  }

  const mapKey = screen.id + " " + screen.title;
  const layers = LAYERS[mapKey] || [];
  const hiddenMap = figma.createFrame();
  hiddenMap.name = "QA layer map / " + screen.id + " / named source regions";
  hiddenMap.x = 8;
  hiddenMap.y = 752;
  hiddenMap.resize(352, 32);
  hiddenMap.fills = solid(C.navy, 0.12);
  hiddenMap.visible = true;
  frame.appendChild(hiddenMap);
  text("QA layer count", layers.length + " mapped regions", 10, 8, 9, solid(C.white, 0.82), hiddenMap, FONT_MEDIUM);

  return frame;
}

function createFoundationPage(page) {
  const root = figma.createFrame();
  root.name = "BB Foundations / " + RUN_ID;
  root.x = 80;
  root.y = 80;
  root.resize(920, 640);
  root.fills = solid({ r: 238 / 255, g: 242 / 255, b: 251 / 255 });
  page.appendChild(root);
  tag(root, "foundations/root", "foundations");
  text("Title", "BB 01 Foundations", 32, 32, 34, solid(C.ink), root, FONT_BOLD);
  const swatches = [
    ["BB/Color/Primary Blue", C.blue],
    ["BB/Color/Ink", C.ink],
    ["BB/Color/Navy", C.navy],
    ["BB/Color/Paper", C.paper],
    ["BB/Color/Cream", C.cream],
    ["BB/Color/Muted", C.muted],
  ];
  swatches.forEach(([name, color], i) => {
    const sx = 32 + (i % 3) * 280;
    const sy = 112 + Math.floor(i / 3) * 150;
    rect(name, sx, sy, 96, 72, solid(color), 8, root);
    text(name + " label", name, sx, sy + 88, 13, solid(C.ink), root, FONT_MEDIUM);
  });
  text("Type specimen 1", "Receipt headline / Inter Bold 34", 32, 450, 34, solid(C.ink), root, FONT_BOLD);
  text("Type specimen 2", "Compact labels / Inter Medium 13", 32, 506, 13, solid(C.muted), root, FONT_MEDIUM);
  return root;
}

function createComponentSet(page) {
  const host = figma.createFrame();
  host.name = "BB Components / " + RUN_ID;
  host.x = 80;
  host.y = 80;
  host.resize(1320, 760);
  host.fills = solid({ r: 238 / 255, g: 242 / 255, b: 251 / 255 });
  page.appendChild(host);
  tag(host, "components/root", "components");
  text("Title", "BB Components", 32, 32, 34, solid(C.ink), host, FONT_BOLD);

  const comps = {};
  comps.shell = makeComponent("BB/Shell/Phone Blue", W, H, (c) => {
    rect("Blue base", 0, 0, W, H, solid(C.blue), 0, c);
    rect("Bottom ink wash", 0, 560, W, 240, solid(C.ink, 0.34), 0, c);
  });
  comps.receipt = makeComponent("BB/Receipt/Paper Card", 320, 320, (c) => {
    rect("Paper", 0, 0, 320, 320, solid(C.paper), 16, c);
    const paper = c.children[0];
    paper.strokes = stroke({ r: 214 / 255, g: 208 / 255, b: 182 / 255 });
    paper.strokeWeight = 1;
  });
  comps.field = makeComponent("BB/Form/Text Field", 272, 52, (c) => {
    rect("Field box", 0, 0, 272, 52, solid(C.cream, 0), 0, c).strokes = stroke(C.line);
  });
  comps.buttonPrimary = makeComponent("BB/Button/Primary", 272, 52, (c) => {
    rect("Pill", 0, 0, 272, 52, solid(C.navy), 26, c);
  });
  comps.buttonSecondary = makeComponent("BB/Button/Secondary", 272, 52, (c) => {
    const r = rect("Pill", 0, 0, 272, 52, solid(C.paper), 26, c);
    r.strokes = stroke(C.ink);
    r.strokeWeight = 1;
  });
  comps.row = makeComponent("BB/Content/Receipt Row", 272, 48, (c) => {
    const r = rect("Row box", 0, 0, 272, 48, solid(C.cream, 0.54), 8, c);
    r.strokes = stroke(C.line, 0.7);
    rect("Icon well", 10, 12, 24, 24, solid(C.blue, 0.12), 12, c);
  });
  comps.chip = makeComponent("BB/Chip/Active", 112, 34, (c) => {
    rect("Chip", 0, 0, 112, 34, solid({ r: 220 / 255, g: 228 / 255, b: 1 }), 17, c);
  });
  comps.stamp = makeComponent("BB/Stamp/Approved", 104, 44, (c) => {
    const r = rect("Stamp border", 0, 0, 104, 44, solid(C.cream, 0), 2, c);
    r.strokes = stroke(C.ink);
    r.strokeWeight = 2;
    text("Stamp text", "SETTLED", 14, 11, 14, solid(C.ink), c, FONT_BOLD);
  });
  comps.barcode = makeComponent("BB/Barcode", 168, 42, (c) => {
    for (let i = 0; i < 18; i++) {
      const bw = i % 3 === 0 ? 4 : 2;
      rect("Bar " + i, i * 9, 0, bw, 42, solid(C.ink), 0, c);
    }
  });

  Object.values(comps).forEach((component, i) => {
    component.x = 32 + (i % 3) * 410;
    component.y = 110 + Math.floor(i / 3) * 200;
    host.appendChild(component);
  });
  return { host, comps };
}

function createScreensPage(page, comps) {
  const host = figma.createFrame();
  host.name = "BB Screens / native editable rebuild / " + RUN_ID;
  host.x = 80;
  host.y = 80;
  host.resize(2160, 3680);
  host.fills = solid({ r: 238 / 255, g: 242 / 255, b: 251 / 255 });
  page.appendChild(host);
  tag(host, "screens/root", "screens");
  text("Title", "BB 06 Screens", 24, 24, 34, solid(C.ink), host, FONT_BOLD);
  text("Subtitle", "Each screen has a locked screenshot backplate plus editable text, shapes, vectors, and BB component instances.", 24, 70, 15, solid(C.muted), host, FONT_MEDIUM);
  const screenHost = figma.createFrame();
  screenHost.name = "Native screen frames";
  screenHost.x = 24;
  screenHost.y = 128;
  screenHost.resize(2120, 3400);
  screenHost.fills = [];
  host.appendChild(screenHost);
  const frames = SCREENS.map((screen, index) => createScreenFrame(screenHost, screen, index, comps));
  return { host, frames };
}

function createSourceAtlasPage(page) {
  const host = figma.createFrame();
  host.name = "BB Source Atlas / " + RUN_ID;
  host.x = 80;
  host.y = 80;
  host.resize(2160, 3680);
  host.fills = solid({ r: 238 / 255, g: 242 / 255, b: 251 / 255 });
  page.appendChild(host);
  tag(host, "source/root", "source");
  text("Title", "BB 00 Source Atlas", 24, 24, 34, solid(C.ink), host, FONT_BOLD);
  SCREENS.forEach((screen, index) => {
    const col = index % 5;
    const row = Math.floor(index / 5);
    const x = 24 + col * 420;
    const y = 100 + row * 880;
    const f = figma.createFrame();
    f.name = "Source screenshot / " + screen.id + " " + screen.title;
    f.x = x;
    f.y = y;
    f.resize(W, H);
    f.fills = [];
    host.appendChild(f);
    const image = figma.createImage(b64ToBytes(IMAGES[screen.file]));
    const plate = rect("LOCKED SOURCE / " + screen.id + " " + screen.title, 0, 0, W, H, [{ type: "IMAGE", scaleMode: "FILL", imageHash: image.hash }], 0, f);
    try { plate.locked = true; } catch (error) {}
    text("Source label", screen.id + " " + screen.title, 0, -24, 13, solid(C.ink), f, FONT_BOLD);
  });
  return host;
}

function createQaPage(page, counts) {
  const host = figma.createFrame();
  host.name = "BB QA Evidence / " + RUN_ID;
  host.x = 80;
  host.y = 80;
  host.resize(1040, 780);
  host.fills = solid({ r: 238 / 255, g: 242 / 255, b: 251 / 255 });
  page.appendChild(host);
  tag(host, "qa/root", "qa");
  text("Title", "BB QA Evidence", 32, 32, 34, solid(C.ink), host, FONT_BOLD);
  const lines = [
    "Run: " + RUN_ID,
    "Screens rebuilt: " + counts.screens + " / 17",
    "Components created: " + counts.components,
    "Backplates: locked source/reference images are present behind each rebuilt screen.",
    "Editability: foreground UI is native Figma text, rectangles, vectors, and component instances.",
    "Reuse: shell, receipt, form field, buttons, rows, chips, stamps, and barcode are BB-prefixed local components.",
    "Responsiveness: frames are fixed 368x800 iPhone screen references; production responsive resizing remains a handoff item.",
    "Manual handoff gap: inspect a few imported image layers in Figma and keep them locked after any manual edits.",
  ];
  lines.forEach((value, i) => text("QA line " + (i + 1), value, 32, 106 + i * 42, 17, solid(i < 6 ? C.ink : C.muted), host, FONT_MEDIUM));
  return host;
}

async function createVariablesAndStyles() {
  const result = { variables: 0, textStyles: 0, effectStyles: 0, warnings: [] };
  try {
    if (figma.variables && figma.variables.createVariableCollection) {
      const existing = figma.variables.getLocalVariableCollections().find((c) => c.name === "BB Variables");
      const collection = existing || figma.variables.createVariableCollection("BB Variables");
      const modeId = collection.modes[0].modeId;
      const vars = [
        ["color/primary-blue", "COLOR", C.blue, ["FRAME_FILL", "SHAPE_FILL", "TEXT_FILL", "STROKE_COLOR"]],
        ["color/ink", "COLOR", C.ink, ["FRAME_FILL", "SHAPE_FILL", "TEXT_FILL", "STROKE_COLOR"]],
        ["color/paper", "COLOR", C.paper, ["FRAME_FILL", "SHAPE_FILL"]],
        ["color/navy", "COLOR", C.navy, ["FRAME_FILL", "SHAPE_FILL", "TEXT_FILL"]],
      ];
      for (const [name, type, value, scopes] of vars) {
        let variable = figma.variables.getLocalVariables().find((v) => v.name === name && v.variableCollectionId === collection.id);
        if (!variable) variable = figma.variables.createVariable(name, collection, type);
        variable.setValueForMode(modeId, value);
        variable.scopes = scopes;
        result.variables++;
      }
    } else {
      result.warnings.push("Figma variables API was unavailable in this local plugin runtime.");
    }
  } catch (error) {
    result.warnings.push("Variables skipped: " + error.message);
  }

  try {
    const style = figma.createTextStyle();
    style.name = "BB/Text/Receipt Headline";
    style.fontName = FONT_BOLD;
    style.fontSize = 34;
    result.textStyles++;
    const small = figma.createTextStyle();
    small.name = "BB/Text/Receipt Label";
    small.fontName = FONT_BOLD;
    small.fontSize = 11;
    result.textStyles++;
  } catch (error) {
    result.warnings.push("Text styles skipped: " + error.message);
  }

  try {
    const effect = figma.createEffectStyle();
    effect.name = "BB/Effect/Receipt Lift";
    effect.effects = [{ type: "DROP_SHADOW", color: { r: 0, g: 0, b: 0, a: 0.16 }, offset: { x: 0, y: 12 }, radius: 24, spread: 0, visible: true, blendMode: "NORMAL" }];
    result.effectStyles++;
  } catch (error) {
    result.warnings.push("Effect styles skipped: " + error.message);
  }
  return result;
}

async function main() {
  await loadFonts();
  const pages = {
    source: pageNamed("BB 00 Source Atlas"),
    foundations: pageNamed("BB 01 Foundations"),
    shell: pageNamed("BB 02 Components - Shell"),
    receipt: pageNamed("BB 03 Components - Receipt"),
    forms: pageNamed("BB 04 Components - Forms"),
    content: pageNamed("BB 05 Components - Content"),
    screens: pageNamed("BB 06 Screens"),
    qa: pageNamed("BB 07 QA Evidence"),
  };

  const styles = await createVariablesAndStyles();
  await figma.setCurrentPageAsync(pages.source);
  const source = createSourceAtlasPage(pages.source);
  await figma.setCurrentPageAsync(pages.foundations);
  const foundations = createFoundationPage(pages.foundations);
  await figma.setCurrentPageAsync(pages.shell);
  const shellSet = createComponentSet(pages.shell);
  const comps = shellSet.comps;
  await figma.setCurrentPageAsync(pages.receipt);
  const receiptSet = createComponentSet(pages.receipt);
  await figma.setCurrentPageAsync(pages.forms);
  const formsSet = createComponentSet(pages.forms);
  await figma.setCurrentPageAsync(pages.content);
  const contentSet = createComponentSet(pages.content);
  await figma.setCurrentPageAsync(pages.screens);
  const screens = createScreensPage(pages.screens, comps);
  await figma.setCurrentPageAsync(pages.qa);
  const qa = createQaPage(pages.qa, { screens: screens.frames.length, components: Object.keys(comps).length * 4 });

  figma.currentPage.selection = [qa];
  figma.viewport.scrollAndZoomIntoView([qa]);
  figma.closePlugin("BillBandit native rebuild complete: " + screens.frames.length + " screens.");
}

main().catch((error) => {
  figma.closePlugin("BillBandit rebuild failed: " + error.message);
});
`;

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
fs.writeFileSync(codePath, pluginCode);
fs.writeFileSync(reportPath, `# BillBandit Native Rebuild Figma Plugin

Generated local development plugin for rebuilding the documented BillBandit screens inside the existing open Figma file.

## Files

- \`manifest.json\` - import this through Figma Desktop: Plugins > Development > Import plugin from manifest.
- \`code.js\` - plugin entrypoint with embedded screenshot backplates.

## Behavior

- Creates/reuses the requested BB pages.
- Appends timestamped rebuild frames; it does not delete existing Figma content.
- Creates BB-prefixed local components for shell, receipt, forms, content rows, chips, stamps, and barcode.
- Builds 17 fixed 368x800 editable screen frames on \`BB 06 Screens\`.
- Places locked screenshot backplates behind native foreground UI.
- Adds \`BB 07 QA Evidence\` with run details and handoff gaps.

## Limitation

This is a free local-plugin path, not Figma MCP. It still requires running the plugin once in Figma Desktop for the actual file write.
`);

console.log(manifestPath);

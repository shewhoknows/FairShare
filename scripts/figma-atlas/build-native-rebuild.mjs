import fs from "node:fs";
import path from "node:path";

const repo = path.resolve(new URL("../..", import.meta.url).pathname);
const screenshotsDir = path.join(repo, "docs/billbandit-workflow/screenshots");
const outDir = path.join(repo, "docs/billbandit-workflow/native-figma-rebuild");
const outSvg = path.join(outDir, "billbandit-native-rebuild.svg");
const outReport = path.join(outDir, "rebuild-report.md");

const W = 368;
const H = 800;
const GAP = 72;
const BLUE = "#2430e0";
const BLUE_DARK = "#081a78";
const INK = "#0a1fa3";
const PAPER = "#f7f2de";
const PAPER_2 = "#fff6dd";
const MUTED = "#6574a8";

const screens = [
  ["01", "Welcome", "01-welcome.jpg", "Auth", ["BillBandit", "he used to steal, now he settles", "The trip ends. The tab settles itself.", "Login", "Create an account"]],
  ["02", "New Member", "02-new-member.jpg", "Auth", ["NEW MEMBER", "Create your account", "Name", "Email", "Create account"]],
  ["03", "Trips Empty", "03-trips-empty.jpg", "Trips", ["TRIPS", "No trips yet", "Start a ledger with friends", "New trip"]],
  ["04", "Your Trips", "04-your-trips.jpg", "Trips", ["TRIPS", "Goa weekend", "Dinner crew", "Last updated today", "Open ledger"]],
  ["05", "New Ledger", "05-new-ledger.jpg", "Trips", ["NEW LEDGER", "Trip name", "Currency", "Start date", "Create ledger"]],
  ["05a", "Date Picker", "05a-new-ledger-dates.jpg", "Trips", ["DATES", "June 2026", "Start", "End", "Done"]],
  ["06", "Live Ledger", "06-live-ledger.jpg", "Ledger", ["LIVE LEDGER", "Goa weekend", "You are owed", "Recent entries", "Add entry"]],
  ["06a", "Ledger Empty", "06a-live-ledger-empty.jpg", "Ledger", ["LIVE LEDGER", "No entries yet", "Add the first expense", "Add entry"]],
  ["07", "Settle", "07-settle.jpg", "Settlement", ["SETTLE", "Who pays whom", "Prateek pays Meera", "Settle up"]],
  ["08", "Record Payment", "08-record-payment.jpg", "Settlement", ["RECORD PAYMENT", "Amount", "Paid by", "Paid to", "Record payment"]],
  ["09", "Final Bill", "09-final-bill.jpg", "Settlement", ["FINAL BILL", "All settled", "Receipt", "Share summary"]],
  ["10", "Add Entry", "10-add-entry.jpg", "Ledger", ["ADD ENTRY", "Description", "Amount", "Split equally", "Save entry"]],
  ["11", "Add Friend", "11-add-friend.jpg", "Trips", ["ADD FRIEND", "Name or email", "Invite to ledger", "Send invite"]],
  ["12", "Auth Start", "12-auth-start.jpg", "Auth", ["AUTH RECEIPT", "Start with your email or phone", "Email or phone", "Send code", "Sign in with Apple"]],
  ["13", "Auth OTP", "13-auth-otp.jpg", "Auth", ["VERIFY CODE", "Enter the code", "One-time code", "Verify"]],
  ["14", "Auth Profile", "14-auth-profile.jpg", "Auth", ["PROFILE", "Finish your profile", "Display name", "Continue"]],
  ["15", "Auth Loading", "15-auth-loading.jpg", "Auth", ["AUTH", "Setting up your receipt", "Please wait"]],
];

function esc(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&apos;",
  })[char]);
}

function imageData(filename) {
  const ext = path.extname(filename).slice(1);
  const bytes = fs.readFileSync(path.join(screenshotsDir, filename));
  return `data:image/${ext};base64,${bytes.toString("base64")}`;
}

function text(x, y, value, size = 16, fill = INK, weight = 700, extra = "") {
  return `<text data-name="${esc(value)}" x="${x}" y="${y}" fill="${fill}" font-family="Avenir Next, Inter, Arial, sans-serif" font-size="${size}" font-weight="${weight}" letter-spacing="0" ${extra}>${esc(value)}</text>`;
}

function rect(name, x, y, w, h, fill, radius = 0, stroke = "none", strokeWidth = 0, opacity = 1) {
  return `<rect data-name="${esc(name)}" x="${x}" y="${y}" width="${w}" height="${h}" rx="${radius}" fill="${fill}" stroke="${stroke}" stroke-width="${strokeWidth}" opacity="${opacity}"/>`;
}

function button(label, x, y, w, h, primary = true) {
  const fill = primary ? BLUE_DARK : PAPER;
  const stroke = primary ? BLUE_DARK : INK;
  const tfill = primary ? "#ffffff" : INK;
  return [
    rect(`BB/Button/${label}`, x, y, w, h, fill, 24, stroke, 2),
    text(x + 24, y + 31, label, 15, tfill, 800),
  ].join("\n");
}

function field(label, x, y, w, placeholder) {
  return [
    text(x, y, label.toUpperCase(), 10, INK, 800),
    rect(`BB/Field/${label}`, x, y + 12, w, 46, "transparent", 0, "#b6c3e0", 1),
    text(x + 14, y + 42, placeholder, 14, MUTED, 600),
  ].join("\n");
}

function receiptChrome(x, y, w, h, title) {
  const dots = [];
  for (let dy = 18; dy < h - 8; dy += 22) {
    dots.push(`<circle data-name="BB/Receipt perforation" cx="${x}" cy="${y + dy}" r="6" fill="#e2e7df"/>`);
    dots.push(`<circle data-name="BB/Receipt perforation" cx="${x + w}" cy="${y + dy}" r="6" fill="#e2e7df"/>`);
  }
  return [
    rect("BB/Receipt/Card", x, y, w, h, PAPER, 16, "#d6d0b6", 1),
    ...dots,
    text(x + 24, y + 36, title.toUpperCase(), 11, INK, 800),
  ].join("\n");
}

function mascot(x, y, scale = 1) {
  const s = scale;
  return `<g data-name="BB/Mascot placeholder" transform="translate(${x} ${y}) scale(${s})">
    <circle data-name="Mascot head" cx="60" cy="56" r="48" fill="${PAPER_2}" stroke="${INK}" stroke-width="5"/>
    <path data-name="Mascot mask" d="M20 54 C34 34 50 34 60 55 C72 34 90 34 102 54 C86 74 72 74 60 61 C48 74 34 74 20 54Z" fill="${INK}"/>
    <circle data-name="Mascot eye left" cx="45" cy="52" r="4" fill="${PAPER_2}"/>
    <circle data-name="Mascot eye right" cx="76" cy="52" r="4" fill="${PAPER_2}"/>
    <ellipse data-name="Mascot nose" cx="61" cy="70" rx="9" ry="7" fill="${INK}"/>
    <path data-name="Mascot receipt" d="M42 96 h40 v54 h-40 z" fill="${PAPER_2}" stroke="${INK}" stroke-width="4"/>
    <path data-name="Receipt rules" d="M50 112 h24 M50 124 h24 M50 136 h18" stroke="${INK}" stroke-width="4" stroke-linecap="round"/>
  </g>`;
}

function screenFrame(screen, index) {
  const [id, name, filename, group, labels] = screen;
  const col = index % 5;
  const row = Math.floor(index / 5);
  const x = col * (W + GAP);
  const y = 720 + row * (H + 150);
  const title = `${id} ${name}`;
  const isAuthHero = id === "01" || id === "12";
  const image = imageData(filename);
  const content = [
    `<g data-name="BB Screen ${esc(title)}" transform="translate(${x} ${y})">`,
    rect(`BB/Frame/${title}`, 0, 0, W, H, BLUE, 0),
    `<image data-name="LOCKED BACKPLATE ${esc(title)}" href="${image}" x="0" y="0" width="${W}" height="${H}" opacity="0.18" preserveAspectRatio="xMidYMid slice"/>`,
    `<linearGradient id="grad-${id.replace(/\W/g, "")}" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#2430e0"/><stop offset="1" stop-color="#0a1fa3"/></linearGradient>`,
    rect("BB/Shell/Blue gradient proxy", 0, 0, W, H, `url(#grad-${id.replace(/\W/g, "")})`, 0),
    text(24, 40, "9:41", 12, "#ffffff", 700),
    text(280, 40, "LTE 100%", 12, "#ffffff", 700),
    text(24, 74, group.toUpperCase(), 11, "#dce4ff", 800),
    text(24, 104, labels[0], isAuthHero ? 34 : 28, "#ffffff", 800),
    mascot(124, isAuthHero ? 132 : 112, isAuthHero ? 1.0 : 0.72),
    receiptChrome(24, isAuthHero ? 390 : 300, 320, isAuthHero ? 314 : 430, labels[1] ?? title),
  ];

  const fieldLabels = labels.slice(2, -1);
  fieldLabels.slice(0, 4).forEach((label, i) => {
    content.push(field(label, 48, (isAuthHero ? 462 : 372) + i * 76, 272, label));
  });

  const action = labels.at(-1) ?? "Continue";
  content.push(button(action, 48, 696, 272, 52, true));
  content.push(text(0, -18, title, 13, "#1d2a5c", 800));
  content.push("</g>");
  return content.join("\n");
}

function componentCatalog() {
  const x = 0;
  const y = 120;
  return `<g data-name="BB 02-05 Component Catalog" transform="translate(${x} ${y})">
    ${text(0, 0, "BB 01 Foundations", 28, INK, 800)}
    ${rect("BB/Color/Primary Blue", 0, 32, 96, 64, BLUE, 8)}
    ${rect("BB/Color/Ink", 112, 32, 96, 64, INK, 8)}
    ${rect("BB/Color/Paper", 224, 32, 96, 64, PAPER, 8, "#d6d0b6", 1)}
    ${text(0, 134, "BB Components", 28, INK, 800)}
    ${receiptChrome(0, 168, 320, 210, "Receipt Card")}
    ${field("Email or phone", 24, 230, 272, "meera@billbandit.app")}
    ${button("Send code", 24, 350, 272, 52, true)}
    ${button("Secondary", 24, 420, 272, 52, false)}
    ${mascot(380, 170, 1.25)}
    ${rect("BB/Chip/Active", 380, 380, 108, 34, "#dce4ff", 17, INK, 1)}
    ${text(405, 403, "ACTIVE", 11, INK, 800)}
    ${rect("BB/TabBar", 380, 436, 250, 54, "#071949", 27, "#8ba4ff", 1)}
    ${text(408, 470, "LEDGER", 12, "#ffffff", 800)}
    ${text(498, 470, "SETTLE", 12, "#d4dcff", 800)}
  </g>`;
}

fs.mkdirSync(outDir, { recursive: true });

const width = 5 * W + 4 * GAP;
const height = 720 + Math.ceil(screens.length / 5) * (H + 150);
const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  <rect data-name="BB Canvas Background" width="100%" height="100%" fill="#eef2fb"/>
  ${text(0, 52, "BillBandit Native Figma Rebuild", 36, INK, 800)}
  ${text(0, 86, "Screenshot backplates are dim reference images. Foreground UI is native SVG text/shapes intended for Figma import.", 15, "#39456f", 600)}
  ${componentCatalog()}
  <g data-name="BB 06 Screens">${screens.map(screenFrame).join("\n")}</g>
</svg>
`;

fs.writeFileSync(outSvg, svg);

const report = `# BillBandit Native Figma Rebuild

Generated: ${new Date().toISOString()}

## Output

- SVG: \`${path.relative(repo, outSvg)}\`
- Screens rebuilt: ${screens.length}
- Frame size: ${W}x${H}

## What This Provides

- A Figma-importable native SVG atlas with BB-prefixed groups.
- Locked-reference intent via \`LOCKED BACKPLATE ...\` image layers behind each native rebuild.
- Editable SVG text, rectangles, paths, circles, and grouped component proxies.
- Component catalog proxies for shell, receipt card, fields, buttons, chips, tab bar, and mascot.

## Limits

- This fallback cannot create true Figma variables, pages, variants, constraints, or component instances without a working Figma write API/plugin execution path.
- After import, lock the \`LOCKED BACKPLATE ...\` layers manually in Figma.
- Convert repeated BB groups into real Figma components if deeper Figma automation becomes available.
`;

fs.writeFileSync(outReport, report);
console.log(outSvg);

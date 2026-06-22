import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = new URL(".", import.meta.url).pathname;
const outputPath = `${outputDir}billbandit-feature-status.xlsx`;
const today = "2026-06-22";

const stories = [
  [
    "IOS-INK-001",
    "iOS Ink",
    "Launch and Auth Routing",
    "As a signed-out iOS user, I land on the ink welcome/auth flow; as a signed-in complete-profile user, I land in the ink trips shell.",
    "Root restores auth, resets/uses volatile sessions from launch args, routes signed-out users to welcome/auth, incomplete users to profile completion, and complete users to the ink app shell.",
    "apps/ios/BillBanditApp/Sources/BillBanditApp.swift; apps/ios/BillBanditApp/Sources/AuthStore.swift",
    "testAppLaunches; testMockAppleAuthCompletesProfileAndReachesTrips; testRailwayOTPAuthSignsIntoReceiptTrips",
    "P0",
    "Implemented",
    "Tested pass",
    "",
    "N/A",
    "Passed",
  ],
  [
    "IOS-INK-002",
    "iOS Ink",
    "Welcome",
    "As a new or returning user, I can start login from the blue/cream ink welcome screen.",
    "Welcome exposes the login CTA; tapping it enters the configured auth destination rather than mutating local data directly when auth callbacks are supplied.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift; apps/ios/BillBanditApp/Sources/BillBanditApp.swift",
    "testMockAppleAuthCompletesProfileAndReachesTrips; testRailwayOTPAuthSignsIntoReceiptTrips",
    "P0",
    "Implemented",
    "Tested pass",
    "",
    "N/A",
    "Passed",
  ],
  [
    "IOS-INK-003",
    "iOS Ink Auth",
    "OTP Start",
    "As an iOS user, I can enter a phone or email identifier and request an OTP from Railway.",
    "Auth start trims the identifier, calls /api/mobile/auth/otp/start, stores the challenge, and advances to OTP verification only on success.",
    "apps/ios/BillBanditApp/Sources/InkAuthFlowView.swift; apps/ios/BillBanditApp/Sources/AuthStore.swift",
    "testRailwayOTPAuthSignsIntoReceiptTrips against https://billbandit-api.contenthelper.in",
    "P0",
    "Implemented",
    "Tested pass",
    "",
    "N/A",
    "Passed",
  ],
  [
    "IOS-INK-004",
    "iOS Ink Auth",
    "OTP Verify",
    "As an iOS user, I can enter a 6-digit OTP and sign in to the Railway-backed account.",
    "OTP code input filters to six digits; submit calls /api/mobile/auth/otp/verify, applies token/user, clears the challenge, and routes by profile completion.",
    "apps/ios/BillBanditApp/Sources/InkAuthFlowView.swift; apps/ios/BillBanditApp/Sources/AuthStore.swift",
    "testRailwayOTPAuthSignsIntoReceiptTrips passed with API_BASE_URL=https://billbandit-api.contenthelper.in",
    "P0",
    "Implemented",
    "Tested pass",
    "The first live assertion only accepted empty-state copy; real Railway data can land on a non-empty trips list.",
    "Fixed",
    "Passed",
  ],
  [
    "IOS-INK-005",
    "iOS Ink Auth",
    "Apple Sign-In and Profile Completion",
    "As an iOS user, I can use Apple sign-in and complete required profile fields before entering the app.",
    "Mock/system Apple modes are supported; profile completion requires name and UPI ID, saves via AuthStore, then enters trips.",
    "apps/ios/BillBanditApp/Sources/BillBanditApp.swift; apps/ios/BillBanditApp/Sources/InkAuthFlowView.swift",
    "testMockAppleAuthCompletesProfileAndReachesTrips; testProfileCompletionRequiresUPI",
    "P0",
    "Implemented",
    "Tested pass",
    "XCTest saw duplicate keyboard toolbar Done buttons; helper now taps first resolved match.",
    "Fixed",
    "Passed",
  ],
  [
    "IOS-INK-006",
    "iOS Ink Trips",
    "Empty Trips",
    "As a new ink app user, I see an empty trips state and can start a new trip ledger.",
    "TripsEmpty shows No tabs running, mascot art, bottom tabs, top-right add, and Start a trip CTA.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift",
    "testMockAppleAuthCompletesProfileAndReachesTrips; testPrototypeLedgerCanAddEditAndDeleteExpense",
    "P0",
    "Implemented",
    "Tested pass",
    "",
    "N/A",
    "Passed",
  ],
  [
    "IOS-INK-007",
    "iOS Ink Trips",
    "Live Trips List",
    "As a signed-in Railway user with existing groups, I can land on a non-empty trips list.",
    "YourTrips renders TripCard rows for remote groups, including title, dates, member/entry counts, open/final stamp, total, and net balance.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift",
    "testRailwayOTPAuthSignsIntoReceiptTrips now accepts tripCard.* rows from real data",
    "P0",
    "Implemented",
    "Tested pass",
    "Original test assumed no real data and missed this valid state.",
    "Fixed",
    "Passed",
  ],
  [
    "IOS-INK-008",
    "iOS Ink Ledger",
    "Create Railway Ledger",
    "As a signed-in Railway-backed ink app user, I can create a new ledger from the trips shell.",
    "NewLedger captures title/date context; in remote mode opening posts /api/mobile/groups, maps the returned group, and routes to the live ledger.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift",
    "testRailwayCanCreateEditDeleteAndFinalizeInkLedger against https://billbandit-api.contenthelper.in",
    "P0",
    "Implemented",
    "Tested pass",
    "",
    "N/A",
    "Passed",
  ],
  [
    "IOS-INK-009",
    "iOS Ink Ledger",
    "Remote Ledger Sync",
    "As a signed-in ink user, my ledgers load from Railway mobile groups.",
    "InkTripStore configures with APIClient/current user, reloads /api/mobile/groups, fetches detail, maps groups to trips, and shows loading/error banners.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift; apps/ios/BillBanditApp/Sources/APIClient.swift",
    "testRailwayOTPAuthSignsIntoReceiptTrips; testRailwayCanCreateEditDeleteAndFinalizeInkLedger; BillBanditTests.testInkStoreRunsLedgerFlowThroughMobileAPIClient",
    "P0",
    "Implemented",
    "Tested pass",
    "",
    "N/A",
    "Passed",
  ],
  [
    "IOS-INK-010",
    "iOS Ink Members",
    "Add Friend by Email",
    "As a remote-backed ink ledger user, I can add a registered member by BillBandit email.",
    "AddFriend collects email, validates /api/mobile/users/lookup?email=..., submits email to /api/mobile/groups/{id}/members, and shows found/not-found states.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift; apps/ios/BillBanditApp/Sources/MockBillBanditAPI.swift; apps/web/app/api/mobile/users/lookup/route.ts",
    "testRailwayCanAddFriendSplitExpenseAndRecordSettlement seeds a registered friend, validates Account found, and adds the friend through iOS UI",
    "P0",
    "Fixed",
    "Tested pass",
    "Code previously used username lookup/submission against an email-only member route.",
    "Fixed",
    "Passed",
  ],
  [
    "IOS-INK-011",
    "iOS Ink Ledger",
    "Live Ledger Empty State",
    "As a ledger user with no entries, I can see the ledger empty state and add the first entry.",
    "LiveLedger shows ledger.empty copy when there are no expenses and exposes ledger.addEntry.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift",
    "testRailwayCanCreateEditDeleteAndFinalizeInkLedger asserts ledger.empty after live Railway expense deletion",
    "P0",
    "Implemented",
    "Tested pass",
    "",
    "N/A",
    "Passed",
  ],
  [
    "IOS-INK-012",
    "iOS Ink Entries",
    "Add Entry",
    "As an ink ledger user, I can add an equal-split expense entry.",
    "AddEntry requires title, amount > 0, at least one split member, selected payer, computes equal split preview, and saves into the ledger.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift",
    "testRailwayCanCreateEditDeleteAndFinalizeInkLedger; testRailwayCanAddFriendSplitExpenseAndRecordSettlement",
    "P0",
    "Implemented",
    "Tested pass",
    "",
    "N/A",
    "Passed",
  ],
  [
    "IOS-INK-013",
    "iOS Ink Entries",
    "Edit Entry",
    "As an ink ledger user, I can edit an existing entry and return to the updated ledger row.",
    "Opening an expense populates AddEntry in edit mode; Update ledger saves changes, clears editing state, and returns to live ledger.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift",
    "testRailwayCanCreateEditDeleteAndFinalizeInkLedger edits a live Railway expense and returns to the updated ledger row",
    "P0",
    "Fixed",
    "Tested pass",
    "Keyboard could leave Update ledger partially off-screen in the UI test path; save/delete now dismiss keyboard and test helper resolves toolbar Done reliably.",
    "Fixed",
    "Passed",
  ],
  [
    "IOS-INK-014",
    "iOS Ink Entries",
    "Delete Entry",
    "As an ink ledger user, I can delete an existing entry and return to the empty ledger state.",
    "Edit mode exposes Delete entry; deleting clears the row, reloads state, and returns to ledger.empty when no entries remain.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift",
    "testRailwayCanCreateEditDeleteAndFinalizeInkLedger deletes a live Railway expense and returns to ledger.empty",
    "P0",
    "Implemented",
    "Tested pass",
    "",
    "N/A",
    "Passed",
  ],
  [
    "IOS-INK-015",
    "iOS Ink Entries",
    "Split Participants",
    "As an ink ledger user, I can include/exclude participants while keeping at least one person in the split.",
    "Split person rows toggle selected state; the last selected participant cannot be removed; per-person equal amount updates from selected count.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift",
    "testRailwayCanAddFriendSplitExpenseAndRecordSettlement verifies the seeded Railway friend is selected in the equal split; prototype test covers selected/not-selected toggling",
    "P1",
    "Fixed",
    "Tested pass",
    "SwiftUI Button row did not toggle reliably while keyboard/ScrollView were active; row now uses custom tap/accessibility action and dismisses keyboard.",
    "Fixed",
    "Passed",
  ],
  [
    "IOS-INK-016",
    "iOS Ink Settle",
    "Settle Screen",
    "As an ink ledger user, I can view simplified settlements for a trip.",
    "Settle screen reads store.settlements(for:), filters user-relevant settlement actions, supports trip selection, refresh, settings, and record payment sheet.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift",
    "testRailwayCanAddFriendSplitExpenseAndRecordSettlement creates a live two-person debt and opens settlementRow.0",
    "P0",
    "Implemented",
    "Tested pass",
    "",
    "N/A",
    "Passed",
  ],
  [
    "IOS-INK-017",
    "iOS Ink Payments",
    "Record Payment",
    "As an ink ledger user, I can record a settlement payment involving me.",
    "RecordPayment modal selects trip/counterparty/direction/method/amount and posts /api/mobile/transactions via InkTripStore.recordSettlement.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift",
    "testRailwayCanAddFriendSplitExpenseAndRecordSettlement records the live Railway settlement and clears the payment path",
    "P0",
    "Implemented",
    "Tested pass",
    "",
    "N/A",
    "Passed",
  ],
  [
    "IOS-INK-018",
    "iOS Ink Finalization",
    "Finalize Ledger and Final Bill",
    "As a ledger user/admin, I can mark a ledger final and review the final bill.",
    "Live ledger exposes finalization for open ledgers; store posts /api/mobile/groups/{id}/finalize; FinalBill shows total/summary and routes back to ledger history.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift; apps/web/app/api/mobile/groups/[id]/finalize/route.ts",
    "testRailwayCanCreateEditDeleteAndFinalizeInkLedger; testRailwayCanAddFriendSplitExpenseAndRecordSettlement; prototype final-bill launch tests",
    "P0",
    "Fixed",
    "Tested pass",
    "Direct final-bill launch initially lacked selected trip state; launch-state preselection now covers final bill and ledger routes.",
    "Fixed",
    "Passed",
  ],
  [
    "IOS-INK-019",
    "iOS Ink Navigation",
    "Bottom Tabs",
    "As an ink app user, I can switch between trips/settle/profile where those tabs are visible.",
    "InkBottomTabs renders visible tab sets per screen and routes through handleTab.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift",
    "testPrototypeSettleRecordPaymentAndBottomTabs",
    "P1",
    "Fixed",
    "Tested pass",
    "Trips screen hid Ledger/Settle tabs and a parent identifier overwrote child tab identifiers; tabs now retain full hit targets and stable identifiers.",
    "Fixed",
    "Passed",
  ],
  [
    "IOS-INK-020",
    "iOS Ink Profile",
    "Profile and Logout",
    "As a signed-in ink app user, I can view account/profile information and sign out.",
    "Profile tab reads the current user/account state and routes logout through AuthStore.",
    "apps/ios/BillBanditApp/Sources/BillBanditInkPrototypeView.swift; apps/ios/BillBanditApp/Sources/BillBanditApp.swift",
    "testRailwayOTPAuthSignsIntoReceiptTrips taps Profile and signs out against Railway-backed auth",
    "P1",
    "Fixed",
    "Tested pass",
    "Profile tab previously opened the New Member account-creation screen for signed-in users; it now shows account profile and Sign out.",
    "Fixed",
    "Passed",
  ],
  [
    "IOS-INK-021",
    "iOS Ink QA",
    "Mock API and Launch Modes",
    "As maintainers, we can run deterministic local and Railway-backed iOS flows.",
    "MockBillBanditAPI, --root=prototype, --ink-screen, --volatile-auth-session, --reset-auth-session, and API_BASE_URL build setting support deterministic tests.",
    "apps/ios/BillBanditApp/Sources/MockBillBanditAPI.swift; apps/ios/BillBanditApp/UITests/BillBanditUITests.swift",
    "Normal iOS suite passes with Railway UI tests skipped by opt-in guard; opt-in Railway UI suite passes 3/3 against production URL",
    "P0",
    "Implemented",
    "Tested pass",
    "",
    "N/A",
    "Passed",
  ],
  [
    "IOS-INK-022",
    "iOS Native Tabs",
    "Dashboard/Groups/Group Detail/Expense Editor",
    "As a user outside the ink shell, I can use the native tab-based dashboard, groups, group detail, add member, expense editor, and settle-up views.",
    "MainTabView hosts DashboardView, GroupsView, GroupDetailView, ExpenseEditorView, AddMemberView, and SettleUpView against mobile API models.",
    "apps/ios/BillBanditApp/Sources/DashboardView.swift; GroupsView.swift; GroupDetailView.swift; ExpenseEditorView.swift; SettleUpView.swift",
    "No focused UI coverage in this pass; user asked to focus on the blue/cream ink build",
    "P2",
    "Deferred",
    "Deferred by scope",
    "Out of current scope unless user reopens native tab UI testing.",
    "N/A",
    "N/A",
  ],
];

const errors = [
  [
    "IOS-ERR-001",
    "iOS Ink Members",
    "Remote add friend/member used username while Railway mobile member route requires email.",
    "Updated AddFriend copy, validation, lookup, store request, MockBillBanditAPI, and unit input to use BillBandit email.",
    "IOS-INK-010",
    "Code audit + mobile API contract",
    "Fixed",
    "High",
    "Passed",
  ],
  [
    "IOS-ERR-002",
    "iOS Ink Entries",
    "Editing an expense could leave Update ledger competing with the keyboard/off-screen hit target in UI testing.",
    "AddEntry save/delete now dismiss keyboard; UI helper taps keyboard.done reliably; focused edit test passed.",
    "IOS-INK-013",
    "XCTest failure in testPrototypeLedgerCanAddEditAndDeleteExpense",
    "Fixed",
    "High",
    "Passed",
  ],
  [
    "IOS-ERR-003",
    "iOS Ink Auth/Entries",
    "XCTest could see multiple keyboard.done accessibility matches and fail to tap the keyboard toolbar.",
    "dismissKeyboardIfNeeded now queries firstMatch by identifier/label and waits for the keyboard to disappear.",
    "IOS-INK-005; IOS-INK-013",
    "XCTest failure in testMockAppleAuthCompletesProfileAndReachesTrips",
    "Fixed",
    "Medium",
    "Passed",
  ],
  [
    "IOS-ERR-004",
    "iOS Ink Auth",
    "Railway OTP smoke assumed the post-auth trips screen would always be empty.",
    "Live test now accepts empty trips, your-expenses copy, no-expenses copy, or tripCard.* rows from real Railway data.",
    "IOS-INK-004; IOS-INK-007",
    "XCTest failure in testRailwayOTPAuthSignsIntoReceiptTrips",
    "Fixed",
    "Medium",
    "Passed",
  ],
  [
    "IOS-ERR-005",
    "iOS Ink Navigation",
    "Trips tab did not navigate reliably from Settle, and the parent trips-screen accessibility identifier overwrote child bottom-tab identifiers.",
    "Expanded bottom-tab hit targets, removed the parent container identifier, restored full tabs on populated Trips, and asserted real trip cards after tab navigation.",
    "IOS-INK-019",
    "XCTest failure in testPrototypeSettleRecordPaymentAndBottomTabs",
    "Fixed",
    "Medium",
    "Passed",
  ],
  [
    "IOS-ERR-006",
    "iOS Ink Entries",
    "Split participant rows did not toggle reliably while a text field kept the keyboard active inside a ScrollView.",
    "Replaced the split row Button with a custom tap/accessibility action row, added stable selected/not-selected accessibility values, and dismisses the keyboard before toggling.",
    "IOS-INK-015",
    "Repeated XCTest failure in testPrototypeLedgerCanAddEditAndDeleteExpense",
    "Fixed",
    "Medium",
    "Passed",
  ],
  [
    "IOS-ERR-007",
    "iOS Ink Profile",
    "Profile tab opened the New Member account-creation screen for signed-in users.",
    "Added ProfileInkScreen with account details and Sign out, wired logout through BillBanditApp, and covered it in the live Railway OTP UI test.",
    "IOS-INK-020",
    "Code audit + user story coverage",
    "Fixed",
    "High",
    "Passed",
  ],
  [
    "IOS-ERR-008",
    "iOS Ink Final Bill",
    "Direct final-bill launch did not preselect a trip, making See all unable to return to the ledger.",
    "Launch-state preselection now includes live ledger, settle, record payment, final bill, and add entry screens.",
    "IOS-INK-018",
    "XCTest failure in testPrototypeFinalBillSeeAllReturnsToLedger",
    "Fixed",
    "Medium",
    "Passed",
  ],
  [
    "IOS-ERR-009",
    "iOS UI Test Harness",
    "The first live Railway expense-edit test appended the edited title instead of replacing the existing title.",
    "Updated replaceText usage so existing expense titles are treated as real content, not placeholders; reran the live Railway ledger CRUD/finalize flow successfully.",
    "IOS-INK-013",
    "XCTest failure in testRailwayCanCreateEditDeleteAndFinalizeInkLedger",
    "Fixed",
    "Medium",
    "Passed",
  ],
  [
    "IOS-ERR-010",
    "iOS Add Friend Flow",
    "The live add-friend test assumed only the Add friend button submits, but keyboard Done can submit after Account found and return to the ledger.",
    "Adjusted the UI test to accept either keyboard submission or explicit save-button submission, then reran the live Railway add-friend/split/settlement/finalize flow successfully.",
    "IOS-INK-010",
    "XCTest failure in testRailwayCanAddFriendSplitExpenseAndRecordSettlement",
    "Fixed",
    "Low",
    "Passed",
  ],
  [
    "WEB-DEF-001",
    "Web UI",
    "Dashboard add-expense Playwright failure is deferred by user request.",
    "Web run had 52 passed, 1 skipped, 1 dashboard add-expense failure; user said to skip web and focus iOS.",
    "Deferred Web",
    "Production Playwright run before scope change",
    "Deferred",
    "Medium",
    "N/A",
  ],
];

const evidence = [
  [
    "2026-06-22",
    "iOS isolated simulator",
    "Created and booted simulator BillBandit Ink QA - Codex (1CF86119-E6D0-406E-BD00-E18F2C57CACF)",
    "Passed",
    "All subsequent iOS test evidence in this workbook uses only this simulator to avoid clashing with other test threads.",
  ],
  [
    "2026-06-22",
    "iOS regression",
    "xcodebuild test -destination id=1CF86119-E6D0-406E-BD00-E18F2C57CACF COMPILER_INDEX_STORE_ENABLE=NO",
    "Passed",
    "13 passed, 0 failed, 3 skipped. The skipped tests are the opt-in Railway UI mutation tests.",
  ],
  [
    "2026-06-22",
    "Railway iOS live UI suite",
    "xcodebuild test -destination id=1CF86119-E6D0-406E-BD00-E18F2C57CACF -only-testing:testRailwayOTPAuthSignsIntoReceiptTrips -only-testing:testRailwayCanCreateEditDeleteAndFinalizeInkLedger -only-testing:testRailwayCanAddFriendSplitExpenseAndRecordSettlement API_BASE_URL=https://billbandit-api.contenthelper.in",
    "Passed",
    "3 passed, 0 failed against Railway production URL with BILLBANDIT_RUN_RAILWAY_UI_TESTS=1.",
  ],
  [
    "2026-06-22",
    "Railway iOS ledger CRUD",
    "testRailwayCanCreateEditDeleteAndFinalizeInkLedger",
    "Passed",
    "Live UI created a Railway ledger, added an expense, edited it, deleted it, saw ledger.empty, marked final, and returned from Final Bill.",
  ],
  [
    "2026-06-22",
    "Railway iOS friends/payments",
    "testRailwayCanAddFriendSplitExpenseAndRecordSettlement",
    "Passed",
    "Live UI seeded a registered friend, added that friend by email, created a two-person split, opened settlementRow.0, recorded payment, and finalized.",
  ],
  [
    "2026-06-22",
    "Railway QA data cleanup",
    "Mobile API finalized active Codex QA ledgers left by failed live-test attempts",
    "Passed",
    "Finalized Codex QA Settle 1782142034 and Codex QA 1782141468 so QA ledgers are not left active in Railway.",
  ],
  [
    "2026-06-22",
    "iOS focused UI",
    "testPrototypeLedgerCanAddEditAndDeleteExpense",
    "Passed",
    "Focused ledger test covers create ledger, add entry, split toggle, edit entry, delete entry, and empty-state return.",
  ],
  [
    "2026-06-22",
    "iOS focused UI",
    "testPrototypeSettleRecordPaymentAndBottomTabs; testPrototypeCanMarkLedgerFinalAndReturnToLedger",
    "Passed",
    "Focused tests cover bottom-tab switching, settlement row, record-payment modal, mark-final flow, final-bill See all return.",
  ],
];

const deferredWeb = [
  [
    "Web UI",
    "Dashboard add expense",
    "Deferred",
    "The production Playwright run found a dashboard add-expense race/context issue. User explicitly asked to skip the web interface for now.",
  ],
  [
    "Web UI/API",
    "Other previously tracked web findings",
    "Deferred",
    "Remain documented from prior audit but are not part of the current blue/cream iOS ink pass.",
  ],
];

const workbook = Workbook.create();
const summary = workbook.worksheets.add("Summary");
const tracker = workbook.worksheets.add("iOS User Stories");
const errorSheet = workbook.worksheets.add("Errors & Fixes");
const evidenceSheet = workbook.worksheets.add("Test Evidence");
const deferredSheet = workbook.worksheets.add("Deferred Web");

for (const sheet of [summary, tracker, errorSheet, evidenceSheet, deferredSheet]) {
  sheet.showGridLines = false;
}

function writeTable(sheet, headers, rows, tableName, headerFill) {
  sheet.getRangeByIndexes(0, 0, 1, headers.length).values = [headers];
  sheet.getRangeByIndexes(1, 0, rows.length, headers.length).values = rows;
  const lastCol = String.fromCharCode("A".charCodeAt(0) + headers.length - 1);
  const table = sheet.tables.add(`A1:${lastCol}${rows.length + 1}`, true, tableName);
  table.style = "TableStyleMedium2";
  sheet.freezePanes.freezeRows(1);
  sheet.getRangeByIndexes(0, 0, 1, headers.length).format = {
    fill: headerFill,
    font: { bold: true, color: "#FFFFFF" },
    wrapText: true,
  };
  sheet.getRangeByIndexes(1, 0, rows.length, headers.length).format = {
    font: { size: 10, color: "#1F2937" },
    wrapText: true,
    borders: {
      insideHorizontal: { style: "thin", color: "#E5E7EB" },
      bottom: { style: "thin", color: "#D1D5DB" },
    },
  };
  return table;
}

const trackerHeaders = [
  "ID",
  "Surface",
  "Area",
  "User Story",
  "Expected Behaviour",
  "Code Evidence",
  "Test Evidence",
  "Priority",
  "Feature Status",
  "Test Status",
  "Errors / Observations",
  "Fix Status",
  "Retest Status",
];
writeTable(tracker, trackerHeaders, stories, "iOSUserStoriesTable", "#0F766E");
const trackerWidths = [95, 105, 145, 310, 435, 300, 285, 70, 115, 135, 330, 110, 115];
for (let i = 0; i < trackerWidths.length; i++) {
  tracker.getRangeByIndexes(0, i, stories.length + 1, 1).format.columnWidthPx = trackerWidths[i];
}
tracker.getRangeByIndexes(1, 0, stories.length, trackerHeaders.length).format.rowHeightPx = 86;
tracker.getRange("A1:M1").format.rowHeightPx = 34;
tracker.getRange(`H2:H${stories.length + 1}`).dataValidation = { rule: { type: "list", values: ["P0", "P1", "P2", "P3"] } };
tracker.getRange(`I2:I${stories.length + 1}`).dataValidation = { rule: { type: "list", values: ["Implemented", "Fixed", "Deferred", "Needs decision"] } };
tracker.getRange(`J2:J${stories.length + 1}`).dataValidation = { rule: { type: "list", values: ["Tested pass", "Needs focused test", "Needs focused UI test", "Deferred by scope", "Tested fail"] } };
tracker.getRange(`L2:L${stories.length + 1}`).dataValidation = { rule: { type: "list", values: ["N/A", "Fixed", "Not started", "Deferred", "Needs decision"] } };
tracker.getRange(`M2:M${stories.length + 1}`).dataValidation = { rule: { type: "list", values: ["Passed", "Pending", "Failed", "N/A"] } };
tracker.getRange(`I2:I${stories.length + 1}`).conditionalFormats.add("containsText", {
  text: "Fixed",
  format: { fill: "#DCFCE7", font: { color: "#166534", bold: true } },
});
tracker.getRange(`I2:I${stories.length + 1}`).conditionalFormats.add("containsText", {
  text: "Deferred",
  format: { fill: "#F3F4F6", font: { color: "#4B5563" } },
});
tracker.getRange(`J2:J${stories.length + 1}`).conditionalFormats.add("containsText", {
  text: "Needs focused",
  format: { fill: "#DBEAFE", font: { color: "#1D4ED8", bold: true } },
});
tracker.getRange(`M2:M${stories.length + 1}`).conditionalFormats.add("containsText", {
  text: "Passed",
  format: { fill: "#DCFCE7", font: { color: "#166534", bold: true } },
});
tracker.getRange(`M2:M${stories.length + 1}`).conditionalFormats.add("containsText", {
  text: "Pending",
  format: { fill: "#FEF3C7", font: { color: "#92400E", bold: true } },
});

const errorHeaders = ["Error ID", "Surface", "Finding", "Resolution / Evidence", "Linked Story", "Discovery", "Fix Status", "Severity", "Retest"];
writeTable(errorSheet, errorHeaders, errors, "ErrorsFixesTable", "#7F1D1D");
const errorWidths = [105, 140, 330, 410, 170, 175, 115, 80, 90];
for (let i = 0; i < errorWidths.length; i++) {
  errorSheet.getRangeByIndexes(0, i, errors.length + 1, 1).format.columnWidthPx = errorWidths[i];
}
errorSheet.getRangeByIndexes(1, 0, errors.length, errorHeaders.length).format.rowHeightPx = 78;
errorSheet.getRange(`G2:G${errors.length + 1}`).dataValidation = { rule: { type: "list", values: ["Fixed", "Not started", "Deferred", "Needs decision", "N/A"] } };
errorSheet.getRange(`I2:I${errors.length + 1}`).dataValidation = { rule: { type: "list", values: ["Passed", "Pending", "N/A", "Failed"] } };

const evidenceHeaders = ["Date", "Layer", "Command / Probe", "Result", "Notes"];
writeTable(evidenceSheet, evidenceHeaders, evidence, "TestEvidenceTable", "#1D4ED8");
const evidenceWidths = [105, 165, 620, 90, 390];
for (let i = 0; i < evidenceWidths.length; i++) {
  evidenceSheet.getRangeByIndexes(0, i, evidence.length + 1, 1).format.columnWidthPx = evidenceWidths[i];
}
evidenceSheet.getRangeByIndexes(1, 0, evidence.length, evidenceHeaders.length).format.rowHeightPx = 70;

const deferredHeaders = ["Surface", "Feature", "Status", "Reason"];
writeTable(deferredSheet, deferredHeaders, deferredWeb, "DeferredWebTable", "#475569");
const deferredWidths = [145, 220, 110, 660];
for (let i = 0; i < deferredWidths.length; i++) {
  deferredSheet.getRangeByIndexes(0, i, deferredWeb.length + 1, 1).format.columnWidthPx = deferredWidths[i];
}
deferredSheet.getRangeByIndexes(1, 0, deferredWeb.length, deferredHeaders.length).format.rowHeightPx = 62;

summary.getRange("A1:H1").merge();
summary.getRange("A1").values = [["BillBandit iOS Ink Feature Status Tracker"]];
summary.getRange("A1").format = {
  fill: "#0F172A",
  font: { bold: true, color: "#FFFFFF", size: 18 },
};
summary.getRange("A1:H1").format.rowHeightPx = 34;
summary.getRange("A2:H2").merge();
summary.getRange("A2").values = [[`Canonical workbook updated ${today}. Scope is the blue/cream native iOS ink build; web interface findings are deferred.`]];
summary.getRange("A2").format = { fill: "#E0F2FE", font: { color: "#075985", size: 11 } };

summary.getRange("A4:B12").values = [
  ["Metric", "Value"],
  ["iOS user stories", ""],
  ["Stories tested pass", ""],
  ["Stories pending focused tests", ""],
  ["Fixed iOS findings", ""],
  ["Pending iOS coverage findings", ""],
  ["Deferred web items", ""],
  ["Railway production URL", "https://billbandit-api.contenthelper.in"],
  ["Latest iOS regression status", "Passed"],
];
summary.getRange("B5").formulas = [[`=COUNTA('iOS User Stories'!A2:A${stories.length + 1})`]];
summary.getRange("B6").formulas = [[`=COUNTIF('iOS User Stories'!J2:J${stories.length + 1},"Tested pass")`]];
summary.getRange("B7").formulas = [[`=COUNTIF('iOS User Stories'!J2:J${stories.length + 1},"Needs focused test")+COUNTIF('iOS User Stories'!J2:J${stories.length + 1},"Needs focused UI test")`]];
summary.getRange("B8").formulas = [[`=COUNTIF('Errors & Fixes'!G2:G${errors.length + 1},"Fixed")`]];
summary.getRange("B9").formulas = [[`=COUNTIF('Errors & Fixes'!I2:I${errors.length + 1},"Pending")`]];
summary.getRange("B10").formulas = [[`=COUNTA('Deferred Web'!A2:A${deferredWeb.length + 1})`]];
summary.getRange("A4:B4").format = {
  fill: "#0F766E",
  font: { bold: true, color: "#FFFFFF" },
};
summary.getRange("A5:B12").format = {
  fill: "#F8FAFC",
  borders: { preset: "all", style: "thin", color: "#E2E8F0" },
  wrapText: true,
};

summary.getRange("D4:F11").values = [
  ["Status", "Story Count", "Finding Count"],
  ["Tested pass", "", ""],
  ["Needs focused test", "", ""],
  ["Needs focused UI test", "", ""],
  ["Deferred by scope", "", ""],
  ["Fixed", "", ""],
  ["Pending", "", ""],
  ["Deferred", "", ""],
];
summary.getRange("E5").formulas = [[`=COUNTIF('iOS User Stories'!J2:J${stories.length + 1},D5)`]];
summary.getRange("E6").formulas = [[`=COUNTIF('iOS User Stories'!J2:J${stories.length + 1},D6)`]];
summary.getRange("E7").formulas = [[`=COUNTIF('iOS User Stories'!J2:J${stories.length + 1},D7)`]];
summary.getRange("E8").formulas = [[`=COUNTIF('iOS User Stories'!J2:J${stories.length + 1},D8)`]];
summary.getRange("F9").formulas = [[`=COUNTIF('Errors & Fixes'!G2:G${errors.length + 1},D9)`]];
summary.getRange("F10").formulas = [[`=COUNTIF('Errors & Fixes'!I2:I${errors.length + 1},D10)`]];
summary.getRange("F11").formulas = [[`=COUNTIF('Errors & Fixes'!G2:G${errors.length + 1},D11)`]];
summary.getRange("D4:F4").format = {
  fill: "#1D4ED8",
  font: { bold: true, color: "#FFFFFF" },
};
summary.getRange("D5:F11").format = {
  fill: "#FFFFFF",
  borders: { preset: "all", style: "thin", color: "#E2E8F0" },
};

summary.getRange("A14:H14").merge();
summary.getRange("A14").values = [["Current iOS Test Loop"]];
summary.getRange("A14").format = {
  fill: "#334155",
  font: { bold: true, color: "#FFFFFF" },
};
summary.getRange("A15:H21").values = [
  ["1", "Created dedicated simulator BillBandit Ink QA - Codex and used only that simulator for final iOS evidence.", "", "", "", "", "", ""],
  ["2", "Fixed remote add-member email contract, profile tab/logout UX, bottom-tab hit targets, final-bill launch state, and split-row keyboard/ScrollView tap handling.", "", "", "", "", "", ""],
  ["3", "Expanded Railway UI coverage for OTP/profile/logout, ledger create/add/edit/delete/finalize, add-friend-by-email, two-person split, settlement row, and record payment.", "", "", "", "", "", ""],
  ["4", "Normal iOS suite passed on the dedicated simulator: 13 passed, 0 failed, 3 Railway UI tests skipped by opt-in guard.", "", "", "", "", "", ""],
  ["5", "Live Railway UI suite passed 3/3 against https://billbandit-api.contenthelper.in on the dedicated simulator.", "", "", "", "", "", ""],
  ["Remaining", "Native tab UI is deferred because this pass is scoped to the blue/cream ink build.", "", "", "", "", "", ""],
  ["Scope", "Web interface testing/fixes are intentionally deferred by user request.", "", "", "", "", "", ""],
];
summary.getRange("A15:H21").format = { wrapText: true, font: { size: 10, color: "#1F2937" } };
summary.getRange("A15:A19").format = { font: { bold: true, color: "#0F766E" } };
summary.getRange("A20:A21").format = { font: { bold: true, color: "#92400E" } };
summary.getRange("A4:H21").format.rowHeightPx = 28;
summary.getRange("A5:B12").format.rowHeightPx = 34;
summary.getRange("A15:H21").format.rowHeightPx = 48;
const summaryWidths = [190, 460, 36, 205, 135, 130, 36, 36];
for (let i = 0; i < summaryWidths.length; i++) {
  summary.getRangeByIndexes(0, i, 22, 1).format.columnWidthPx = summaryWidths[i];
}

const compact = await workbook.inspect({
  kind: "workbook,sheet,table",
  maxChars: 8000,
  tableMaxRows: 6,
  tableMaxCols: 6,
  tableMaxCellChars: 80,
});
await fs.writeFile(`${outputDir}billbandit-feature-status.xlsx.inspect.ndjson`, compact.ndjson);

const formulaErrors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
});
console.log(formulaErrors.ndjson);

const previews = [
  ["Summary", "A1:H22", "feature-tracker-summary.png"],
  ["iOS User Stories", "A1:M12", "feature-tracker-table.png"],
  ["Errors & Fixes", "A1:I12", "feature-tracker-errors.png"],
  ["Test Evidence", "A1:E9", "feature-tracker-evidence.png"],
  ["Deferred Web", "A1:D3", "feature-tracker-deferred-web.png"],
];
for (const [sheetName, range, fileName] of previews) {
  const preview = await workbook.render({ sheetName, range, scale: 1, format: "png" });
  await fs.writeFile(`${outputDir}${fileName}`, new Uint8Array(await preview.arrayBuffer()));
}

await fs.mkdir(outputDir, { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
console.log(outputPath);

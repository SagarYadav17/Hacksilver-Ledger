# Handoff: Hacksilver Ledger — Full App Redesign

## Overview
A full redesign concept for Hacksilver Ledger (Flutter, Material 3, offline-first personal finance). It covers all current features plus the "wanted next" set from `LLM_AGENT_FEATURES.md`: dashboard analytics, transfer filter + search, transaction details sheet, fast-add flow with templates, EMI timeline, account health, category usage stats with merge/archive, recurring pause/resume, sync-mode UI, and app lock. The biggest structural change: the `NavigationDrawer` is replaced by a 5-destination Material 3 `NavigationBar` (Home · Activity · Loans · Accounts · More), with Categories, Recurring, Sync & Backup, and Settings under "More".

## About the Design Files
The files in this bundle are **design references created in HTML** — mockups showing intended look and layout, not production code. The task is to **recreate these designs in the existing Flutter codebase** (`SagarYadav17/Hacksilver-Ledger`), using its established patterns: `ColorScheme.fromSeed`, `ThemeData` in `main.dart`, provider-based state, `google_fonts` Outfit text theme. Do not port HTML/CSS literally — map every element to Material 3 widgets (`NavigationBar`, `SegmentedButton`, `Card`, `FilterChip`, `Switch`, `ListTile`, `showModalBottomSheet`, etc.).

## Fidelity
**High-fidelity.** Colors, spacing, type sizes, and radii below are intentional. However, all hex values are samples of the M3 teal-seed scheme — in Flutter, **use the `ColorScheme` roles named below (not hard-coded hex)** so the existing seed-color picker and dynamic theming keep working.

## Design Tokens

### Color roles (hex = teal-seed sample; light / dark)
- surface: `#F4FBF8` / `#0E1513`
- surfaceContainer (cards on surface): `#FFFFFF` (light uses white cards + `#E8EFEB` tonal fills) / `#1B2320` (dark divider `#252B29`)
- onSurface: `#171D1B` / `#DDE4E1`
- onSurfaceVariant: `#3F4946` / `#BFC9C4`
- outlineVariant (chip/segmented borders): `#BEC9C4` / `#3F4946`
- primary: `#006A60` / `#83D5C6`
- primaryContainer (FAB, highlight banners): `#9EF2E4` / `#005048`
- onPrimaryContainer: `#00201C` / `#9EF2E4`
- secondaryContainer (selected chips, nav pill): `#CDE8E1` / `#334B46`
- Semantic amount colors — income: `#006A60` / `#83D5C6`; expense: `#8C1D18` / `#FFB4AB`; transfer: `#00658F` / `#7FCFFF`. (Today the app uses tertiary for income; the redesign standardizes on green=in, red=out, blue=transfer.)
- Category container tints (light bg / icon): Food `#FFE0B2`/`#7A4F00`, Travel `#D9E2FF`/`#3B5BA9`, Household `#E5DEFF`/`#5B4FA9`, Entertainment `#FFD8E4`/`#8E4963`, Transfer `#C7E7FF`/`#00658F`, Income `#CDE8E1`/`#006A60`. Dark equivalents: `#3A3020`/`#FFE0B2`, `#26304A`/`#B7C8FF`, `#322B4A`/`#CCBEFF`, `#45222F`-ish/`#FFB1C8`, `#12303F`/`#7FCFFF`, `#0F3B34`/`#83D5C6`. In Flutter derive these from the stored category `colorValue` at 15% alpha (existing pattern) or harmonized tonal containers.

### Typography (Outfit, via google_fonts — already in the app)
- Screen title: 22px w500
- Hero amount (balance): 36px w600, letter-spacing −0.5
- Account total / sheet amount: 32px w600
- Add-flow amount entry: 52px w600
- Card stat: 20px w600; row amount: 15–16px w500/600
- List headline: 15px w400/500; supporting: 12px onSurfaceVariant
- Section labels: 12px w600, letter-spacing 0.5, UPPERCASE
- Nav labels: 11px (w600 when active); chips/buttons: 13–14px w500

### Shape & spacing
- Screen padding: 16px horizontal
- Cards: radius 20 (hero 24, list groups 16), no elevation, tonal color
- Buttons/segmented: full-round (radius 24), 12px vertical padding
- FAB: 56×56, radius 16
- Chips: radius 8–10; switches: 44×26 M3 style
- Icons: Material Symbols Rounded, 16–26px (already the platform icon set)

## Screens / Views
IDs match the mockup canvas (`Hacksilver Redesign.dc.html`).

### 1a Dashboard (Home)
- Header: date line (13px variant) + "Good morning" (22px w500), trailing 40px avatar circle.
- Balance hero: primary-filled card radius 24, padding 20 — "Available balance" label, ₹ amount 36px, then two 14-radius inner tiles (white 14% alpha) for month Income / Expense with arrow icons. Replaces the current gradient `SummaryCard`.
- Quick actions row: 4 equal tonal tiles (radius 16, icon 22px primary + 12px label): Expense, Income, Transfer, EMI. Always visible (was empty-state-only CTA).
- Cashflow card: "Cashflow / 6 months" header, grouped bar chart (income bar primary, expense bar outlineVariant; 9px wide, radius 4, gap 3; month labels 10px). Use `fl_chart` or custom painter.
- Recent list: "Recent / See all", 3 rows — 40px circular category-tinted icon, title + "Category · Account" supporting, trailing signed amount in semantic color.
- Bottom `NavigationBar`: Home (active pill secondaryContainer 56×28) · Activity · Loans · Accounts · More.

### 1b Transactions (Activity)
- Title "Activity", M3 search bar (tonal, radius 28, 13px vertical padding).
- Filter chips row: All (selected, secondaryContainer + check) · Income · Expense · **Transfer (new)** · month chip with dropdown arrow (date-range picker).
- List grouped by day: section header "TODAY / −₹1,090" (label + signed day total), each group a white radius-16 card, rows as in 1a with 1px inset dividers.
- FAB (primaryContainer, radius 16) bottom-right above nav.

### 1c Transaction details sheet (new)
- `showModalBottomSheet`, radius 28 top, drag handle 32×4.
- Centered: 52px category icon circle, amount 32px in semantic color, title 15px, chips: category (category tint) + type (tonal).
- Key-value card (white, radius 16): Account, Date, Original amount (FX, e.g. "$5.00 USD"), Note — 13px rows with dividers.
- Action row: outlined Duplicate, outlined Delete (error color), filled Edit. Tapping a row opens this sheet; Edit goes to the existing edit screen.

### 1d Add transaction — fast flow
- Full-screen dialog: close icon + "New entry".
- Type `SegmentedButton`: Expense (selected) / Income / Transfer.
- Amount entry: 52px centered with cursor; below, "INR · HDFC Bank" account/currency selector (dropdown).
- "RECENT & TEMPLATES" chip row: one-tap presets (icon + "Lunch ₹420") that prefill amount + category + title.
- "CATEGORY" 4-column grid of tonal tiles (radius 16, icon + 11px label); selected tile gets category-tint bg + 2px outline in its icon color.
- Bottom row: outlined chips Today (date) and Note (both optional), then filled Save (expands to fill).

### 1e Loans
- Title, then `SegmentedButton`: Borrowed (selected) / Lent — replaces mixed list; clear direction split.
- Two tonal stat tiles: "You owe ₹3,12,400" and "Next EMI 12 Jul".
- Loan cards (white, radius 20, padding 16): 40px radius-12 icon tile, name + "EMI ₹4,860 · due 12 Jul", ACTIVE badge (secondaryContainer, 11px w600); below: paid/left amounts 12px, 8px progress bar (primary on tonal track), "18 of 30 EMIs · closes Jul 2027".
- "CLOSED" section: same card at 65% opacity with check_circle, no progress.

### 1f Loan detail — EMI timeline (new)
- Small app bar: back, loan name, overflow.
- Hero: primary card radius 24 with 76px progress ring (conic 60%, "60%" center), "Remaining ₹58,320 / of ₹1,45,800 · 12 EMIs left".
- Next-due banner: primaryContainer radius 20 — bell icon, "EMI #19 due Sat, 12 Jul", "₹4,860 from HDFC Bank · reminder 2 days before", filled "Pay" pill (records the loan-linked transaction).
- EMI timeline card: vertical stepper — paid steps: filled check_circle (primary) + connector; next-due: 20px ring on primaryContainer; upcoming: outlined ring, muted text. Each step: "EMI #n", date · account, trailing amount.
- Bottom: outlined History and Calendar buttons.

### 1g Accounts
- Title + add icon; "Across 4 accounts" + total 32px.
- Account cards (white, radius 20): 42px radius-12 tinted icon (bank/cash/credit/savings), name + status supporting line ("reconciled 2 Jul" / "needs reconcile" / "Bill due 18 Jul" in card-color), trailing balance 16px w600 + 4-bar mini sparkline (last bar primary, or error-red when trending down). Credit card shows negative balance in expense red.
- "Move money" banner: primaryContainer radius 20 with swap icon + chevron → transfer-focused flow.

### 1h Categories
- Back app bar + add; `SegmentedButton` Expense/Income (existing split).
- Caption "This month · drag to reorder".
- Rows (white radius 16): drag_indicator handle, 38px tinted icon circle, name + amount right-aligned, 6px usage bar (category color share-of-spend), "64 entries · 32% of spend" 11px, trailing overflow.
- Overflow menu: Edit / **Merge into…** / **Archive** (menu card radius 12, shadow).
- Archived row at 55% opacity: "Wedding 2025 — archived / Hidden from pickers, history kept".

### 1i Recurring
- Back app bar + add; summary banner (tonal radius 16): "₹23,360 scheduled this month · 3 upcoming".
- Rows (white radius 16): 40px tinted icon, name + "₹15,000 · monthly · next 1 Aug", trailing M3 `Switch` = **pause/resume (new)**. Paused row: dashed 1px border, amber "Paused · won't generate entries" with pause icon, switch off.
- "GENERATED THIS MONTH" receipt trail: check_circle + "Rent — auto-added 1 Jul" + amount.

### 1j Sync & backup
- "WHERE YOUR DATA LIVES" — three mode cards (white radius 20):
  1. "On this device" — selected (2px primary outline, CURRENT badge), "Fully offline. Nothing leaves your phone."
  2. "Device + cloud copy" — one-way Supabase backup (current sync feature, plain language), chevron → credential onboarding.
  3. "Two-way sync — coming soon" at 60% opacity.
- "CLOUD COPY STATUS" tonal card: cloud_done icon, "Backed up · 3 entries pending", "Last sync today, 9:12 am", filled "Sync now"; divider; history log rows ("Today, 9:12 am — 412 rows · ok", failure row in error color with "retried ✓").
- "LOCAL BACKUP": outlined Export file / Restore… buttons + caption "Restore always asks before replacing data on this device." (confirmation flow).

### 1k Settings ("More" hub)
- APPEARANCE card: theme `SegmentedButton` Light/Dark/System; "Accent color" 28px swatches (selected has 2px offset outline) → drives `seedColor`; Currency dropdown pill "₹ INR".
- PRIVACY card: **App lock** (PIN + fingerprint) switch, **Hide balances** switch — both new.
- DATA card: Sync & backup (with status supporting line), Categories, Recurring — chevron rows (these lived in the drawer before).
- HELP card: Diagnostics & error log (new).

### 1l / 1m Dark theme (Dashboard, Transactions)
Same layouts with dark role mapping above. Hero card uses primaryContainer dark (`#005048`); category tints drop to dark tonal containers; nav bar surface `#1B2320` with `#334B46` active pill.

## Interactions & Behavior
- Bottom nav switches root screens (replace, no stack growth); More opens the Settings hub (1k).
- Transaction row tap → details sheet (1c), NOT edit; sheet Edit → existing `AddTransactionScreen(transaction:)`. Keep swipe-to-delete with confirm dialog.
- FAB / quick actions → fast add (1d) with the corresponding type preselected; template chip tap prefills; Save validates amount > 0 (existing `minTransactionAmount`).
- Loan "Pay" → EMI entry flow, creates loan-linked transaction, advances timeline + progress.
- Recurring switch toggles paused state (new `isPaused` field); paused items skip generation.
- Sync mode card tap selects mode; "Sync now" runs existing one-way sync; failures append to history with retry.
- Standard M3 ripples; sheets/dialogs use existing 300ms `shortAnimationDuration`.

## State Management
Existing providers cover most data. New state needed:
- `TransactionProvider`: transfer filter, search query, date-range filter, grouped-by-day selectors, per-day totals, 6-month cashflow aggregates.
- `RecurringTransactionProvider`: `isPaused` per item (schema + migration).
- `CategoryProvider`: usage stats (count, sum, share), `sortOrder`, `isArchived`, merge operation.
- `LoanProvider`: EMI schedule derivation (paid list + upcoming dates from start date/frequency).
- New `SecurityProvider` (app lock PIN/biometric, hide balances) — persist via existing `SecureStorageService`.
- `SyncProvider`: mode enum (localOnly / cloudCopy), history log persistence.

## Assets
- Icons: Material Symbols Rounded (Google's icon set — `Icons.*_rounded` in Flutter). No custom imagery.
- Font: Outfit via `google_fonts` (already a dependency).

## Files
- `Hacksilver Redesign.dc.html` — the full mockup canvas (13 screens, light + dark). Open in a browser; pan/zoom.
- `android-frame.jsx` — device-frame scaffolding used by the mockup (presentation only; ignore for implementation).

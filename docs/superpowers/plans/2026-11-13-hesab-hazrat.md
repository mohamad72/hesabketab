# Hesab Hazrat Implementation Plan

> Execute inline with superpowers:executing-plans; the user requested direct implementation and then commit/push.

**Goal:** Persian Android Flutter finance app following the supplied specification and visual references.
**Architecture:** Local durable JSON document, atomic journal-before-network writes, pure financial/calendar rules, direct OAuth Sheets adapter with three-way per-field merge. Hidden metadata and named ranges preserve record identity and recurrence/installment links in the same workbook. UI reads local state only.
**Tech Stack:** Flutter 3.47.7, Dart, Google Sign-In, HTTP, path_provider, shamsi_date, shared_preferences (web preview only).
**Spec:** docs/reference/product-spec.fa.md

## Constraints
- No server, service-account key, note field, or fabricated personal financial data.
- Blank actual is distinct from zero; salary day defaults to 10 only if absent.
- Sheets default unit is 1000 toman; app displays toman. Never replace formulas with constants.
- Real financial workbook is read-only during development. Tests use fixtures.
- Work in the supplied empty repository; push is explicitly authorized.

## Review focus
- Interrupted writes/retries: durable journal and idempotent identifiers.
- Old layouts: discover headers/sections and bounds, never infer by fixed columns alone.
- Formula edits: preserve formula and surface unsupported direct change.
- Concurrent deletion/edit and same-field edits: persist conflicts and both versions.
- Empty account edits, zero actual, negative daily spending, short Persian months.

## Tasks
- [x] 1. Scaffold Android/web; write domain tests first for totals, month normalization, recurrence, installment identity and daily-spending idempotence; implement lib/domain.
- [x] 2. Write merge/parser/storage tests first; implement durable local repository and Sheets adapter preserving formulas, identifiers, colors, metadata, and verified sync.
- [x] 3. Implement Persian pastel UI: monthly list and forms, bank balances, installment schedule, month review, reports/charts, settings and conflict resolution. Add widget tests for core flows.
- [x] 4. Add GitHub Actions Android APK build, stable signing instructions, Google OAuth setup and Persian README. Run format/analyze/tests/web build, visually verify preview, review whole branch, commit and push.

## Progress
- Read full user specification; inspected workbook metadata and bounded recent/old layout (read only). No personal amounts copied into source.
- Flutter SDK installed; Android SDK unavailable locally. APK build belongs in GitHub Actions; web build allows local preview.

- Verification: independent review identified raw-row occupancy, initial anchors, serial persistence, bank metadata, day removal and provisional carry. Addressed in code and regression tests.
- Ruling: provider totals are rendered in a dedicated generated workbook tab with individual linked fixed-expense rows, retaining old unallocated aggregates rather than guessing purchase attribution.
- Ruling: forecast displays current baseline and projected line; no invented daily historical balance without transaction history.
- Real OAuth and original workbook writes require on-device configuration; no development writes to the original workbook.

- User revisions: create month at top; inline single/installment choice; all installments stay in selected section; safe plus/minus expressions preserved with per-operand unit conversion; explicitly oriented RTL arrows; shared pastel secondary-button theme; expanded private-config gitignore.

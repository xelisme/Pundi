# HyperBudget Product Context

## What it is

HyperBudget is a personal finance app that combines budget allocation planning with expense tracking. Users set percentage-based allocation rules for income (e.g., 50% savings, 30% investment, 20% discretionary), then record both income and expenses to see how money flows through those categories over time.

## Platform

Mobile-first Flutter app targeting Android and iOS. The codebase includes web/desktop targets but mobile is the primary experience.

## User

Built for personal use by a single individual managing their own finances in Indonesian context (IDR currency, Indonesian localization).

## Core workflows

All workflows are equally critical to the product value:

1. **Income allocation**: Enter income amount (e.g., "5000000" or "50k"), app automatically splits it across categories by configured percentages
2. **Expense tracking**: Record purchases with merchant name, items, amount, and which budget category it charges to
3. **Category balance monitoring**: See at-a-glance how much has been allocated vs. spent in each category
4. **Monthly summaries**: Review income sources, expense destinations, and category balances for the current month

## Key features

- **Flexible income parsing**: Accepts numeric formats like "50000", "50k", "5jt"
- **Allocation categories**: User-defined categories with percentages, colors, icons, descriptions
- **Transaction history**: Chronological record of all income and expense transactions
- **Visual allocation display**: Radial visualization showing category splits
- **Category balancing**: Track what's allocated vs. spent per category
- **Data export**: Share transaction history
- **Persistent storage**: SharedPreferences for categories and transaction history

## Current state

Early prototype with functional core workflows but bland, generic visual design. The app works but needs personality, polish, and distinctive visual identity. Default categories are Indonesian financial planning focused: Tabungan (Savings), Investasi (Investment), Bebas (Discretionary).

## Design priorities

All three qualities are equally important:
- **Speed and efficiency**: Minimal taps, fast input, optimized for daily use
- **Visual appeal and personality**: Beautiful, distinctive, delightful—not generic
- **Clarity and trust**: Clear hierarchy, readable numbers, professional presentation of financial data

## Technical foundation

- Flutter 3.12.2+
- Material 3 design system
- Google Fonts: Inter (body), Poppins (headings)
- Provider for state management
- Current color palette: Teal primary (#14746F), Coral accent/expense (#E86252), Sage green income (#7FA874)
- Indonesian locale (id_ID) with Rupiah formatting
- Navigation: 4-tab bottom nav (Beranda/Home, Riwayat/History, Ringkasan/Summary, Pengaturan/Settings)

## Language

UI copy is in Indonesian (Bahasa Indonesia). User is comfortable with both Indonesian and English for design discussions.

## Out of scope

- Multi-user/family budgets
- Bank account sync
- Bill reminders or recurring transactions
- Budget forecasting or predictive analytics
- Cloud sync via Google account + Google Drive (deferred, see README-sync-issue.md)
- Firestore sync (reverted, see README-sync-issue.md)

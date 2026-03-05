# Departure Board Subscription + Trial Handoff (Website)

This document is a source-of-truth handoff for web copy and pricing/feature pages, based on the current app implementation.

## 1) Commercial model (current app behavior)

- The app uses a **single premium subscription tier**.
- Paywall CTA text currently says: **"Subscribe - GBP2.99 / month"**.
- Supporting paywall copy currently says:
- **"Cancel anytime. Subscription renews monthly."**
- Core message: one plan unlocks everything.

Important implementation note:
- The paywall purchase and restore actions are still marked TODO in code (`SubscribeView`), so the feature gating/trial logic is fully implemented, but StoreKit wiring appears not finished yet.

## 2) Trial model (28 days)

- There is a **28-day free trial** for premium access.
- Trial start date is set on first launch.
- Trial length is based on whole calendar-day difference from first launch.
- Remaining days are calculated as:
- `max(0, 28 - elapsedDays)`.
- Trial is active while remaining days are > 0.
- Trial is expired at 0 days remaining.

Persistence/security details:
- Trial start date is saved in **Keychain**, not UserDefaults.
- This is specifically to prevent reset by clearing app defaults.

What to say on website:
- "Every new user gets full premium access free for 28 days."
- "No feature restrictions during the 28-day trial."

## 3) Entitlement logic (how access is decided)

Premium access is true when either condition is true:
- trial active
- active subscription

Formula:
- `hasPremiumAccess = isTrialActive || hasSubscription`

Behavior implications:
- During trial, users have full premium even without subscription.
- After day 28, premium remains only if subscription is active.
- If both trial expired and no active subscription, premium-only features lock.

Widget sync behavior:
- App writes a shared premium snapshot flag for widget extension use.
- Widgets read this snapshot to decide whether to render full content or locked state.

## 4) Free mode vs Premium mode

### Free mode limits

- Favourites: **max 1** saved favourite board.
- Nearby stations shown: capped to **3**.
- Premium auto-load modes disabled (see below).
- Station Info is locked.
- Service Detail is locked.
- Travel Mode ("earlier/later services") is locked.
- Appearance premium styling options are locked.
- Widget premium appearance options are locked.
- Export/Import favourites backup is locked.
- Widgets and Lock Screen widgets show locked UX.

### Premium mode includes

- Unlimited favourites.
- Nearby stations setting up to 25.
- Show Next Service on favourites.
- Tap Next Service to open Service Detail.
- Split-flap animation in app list.
- Service Detail page access.
- Station Information access.
- Travel Mode (earlier/later browsing via time offset).
- Advanced auto-load modes (favourite-aware).
- Appearance controls (small caps + row themes + vibrancy).
- Widget appearance controls (row theme, operator colours, split-flap).
- Favourites backup (export/import JSON).
- Full Home/Lock Screen widget behavior.

## 5) Premium feature set for website copy

These are the premium value pillars used in the app paywall:

- Home Screen widgets (single + dual station layouts)
- Lock Screen widgets
- Appearance themes/operator livery styles
- Unlimited favourites + next-service enhancements
- Earlier/later train browsing (travel mode)
- Full service detail (calling points, formation/loading where available)
- Station information sheets
- Smart auto-load on launch (favourite-aware modes)
- "Everything in one subscription"

## 6) Auto-load behavior and premium gating

Auto-load modes:
- `off`
- `nearest`
- `favourite`
- `favouriteOrNearest`

Premium rule:
- `favourite` and `favouriteOrNearest` are premium-only.
- Free users are blocked from selecting those modes and are reverted to allowed mode.

Distance behavior:
- Configurable threshold 1-50 miles.
- If multiple favourites are in range, priority is by favourites list order.

## 7) Widget subscription behavior

Home Screen widgets:
- If premium snapshot is false, widgets render a locked state:
- "Unlock Departure Board to continue using widgets"
- If premium, widgets render full live data.

Lock Screen widgets:
- If not premium, lock screen widgets show locked text/icon variants.
- Locked lock-screen widgets deep-link to:
- `departure://unlock/lockscreen`
- App catches this and opens paywall focused on Lock Screen feature page.

## 8) Where/when users hit paywall (major entry points)

- Trial toolbar pill once trial expires ("Subscribe" CTA).
- Trying to add more than 1 favourite in free mode.
- Trying to reorder favourites in free mode.
- Tapping locked favourites.
- Opening Station Info without premium.
- Opening Service Detail without premium.
- Using Travel Mode earlier/later buttons without premium.
- Selecting premium auto-load modes without premium.
- Accessing backup export/import without premium.
- Unlock deep links from widgets/lock screen.

## 9) Trial messaging currently used in-app

Active trial:
- "Free Trial"
- "`N` days remaining" (or "1 day remaining")
- CTA: "Subscribe & Unlock Everything"

Expired trial:
- "Trial Ended"
- "Your 28-day trial has expired."
- CTA: "Subscribe to Continue"

Urgency behavior:
- Trial badges become "urgent" visual state in final 7 days.

## 10) Hidden support flow: one-time second trial

There is a support-code mechanism for a one-time extra trial reset.

Behavior:
- Support code redemption can trigger a **second 28-day trial**, once.
- Uses keychain flag `secondTrialUsed`.
- If already used, user sees "All trials have been used."

Website guidance:
- Do not advertise this publicly as a normal offer.
- Keep this as support/retention tooling unless business wants it public.

## 11) Pricing/legal UI hooks present on paywall

Current paywall bottom actions:
- Restore (placeholder)
- Privacy (placeholder)
- Terms (placeholder)

Website should include:
- clear monthly price
- renewal terms
- cancellation anytime
- links for privacy and terms
- restore purchases guidance (once StoreKit is fully wired)

## 12) Suggested website copy blocks (safe to use now)

### Subscription summary block

"Departure Board Premium is one simple monthly subscription. Get full access to widgets, lock screen widgets, unlimited favourites, smart auto-load, full service detail, station information, and all visual themes."

### Trial block

"Every new user gets 28 days of full Premium access free. No feature limits during trial. After 28 days, subscribe to keep Premium features active."

### Renewal block

"GBP2.99 per month. Renews monthly. Cancel anytime."

## 13) Claims to avoid (until purchase plumbing is complete)

Do not claim the following as fully live unless StoreKit integration is completed and tested:
- "In-app purchase is now live"
- "Restore purchases fully operational"
- "Privacy/Terms buttons from paywall are wired"

Use wording like:
- "Subscription support is built into the app with a 28-day trial and premium gating. Purchase flow is being finalized."

## 14) Technical source map

Primary files used for this handoff:
- `Departure Board/TrialManager.swift`
- `Departure Board/View/SubscribeView.swift`
- `Departure Board/View/SettingsView.swift`
- `Departure Board/View/ContentView.swift`
- `Departure Board/View/DepartureBoardView.swift`
- `DepartureBoardWidget/DepartureBoardWidget.swift`
- `Departure Board/Departure_BoardApp.swift`
- `Departure Board/SharedDefaults.swift`


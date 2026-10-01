# App Store listing draft

Draft text for App Store Connect. Character limits are Apple's.

## Name (30 max)

Habits: Small Things Daily

"Habits" on its own is almost certainly taken; the name must be unique on the store.
The name under the icon on the phone stays "Habits".

## Subtitle (30 max)

Private habit & streak tracker

## Promotional text (170 max)

Build the habits you want and quit the ones you don't, one day at a time. Try it free for a week. No account, no ads, no tracking.

## Keywords (100 max, comma separated)

habit,tracker,routine,streak,daily,goals,checklist,reminder,productivity,health,quit,focus,private

## Description (4000 max)

Habits is a calm, private habit tracker. Pick a few small things, keep them daily, and see how you're doing over time.

TRACK IT YOUR WAY
• Done / not done, an amount in your own unit (pages, glasses, km) or time in minutes
• A built-in timer for time habits that keeps running when you leave the app
• Build good habits or quit bad ones
• Start from suggestions or create your own, in your own categories

SCHEDULES THAT FIT REAL LIFE
• Every day, chosen weekdays, a number of times per week, or dates of the month
• Rest days that never break a streak: weekdays off or single dates
• Start a habit today, tomorrow or on any date
• Archive habits you're pausing and bring them back later

TODAY AT A GLANCE
• Everything due today in a list or a grid
• One tap to mark a habit done, +1 to log an amount

STATISTICS THAT MEAN SOMETHING
• Completion rate, perfect days and best run
• See which weekdays work best for you
• Look at everything, a category, or any mix of habits
• Week, month, six months, year or your own date range

GENTLE REMINDERS
• A reminder per habit, a morning plan, an evening check-in and a weekly report
• Streak rescue warns you before a long streak is lost
• All optional, all adjustable

PRIVATE BY DESIGN
• No account, no ads, no tracking
• Your data never leaves your iPhone
• Export everything as a CSV file whenever you want

Dark and light themes included.

SUBSCRIPTION
Habits is free to download and needs a subscription to use, with a 1-week free trial for new subscribers.
• Monthly: $5.99
• Yearly: $39.99
Payment is charged to your Apple Account after the trial. The subscription renews automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel it in your App Store account settings.
Terms of use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy policy: https://emilhenrikssonn.github.io/habit-tracker/privacy-policy.html

## Categories

Primary: Health & Fitness. Secondary: Productivity.

## Age rating

4+ (no objectionable content, no web access beyond the privacy policy link).

## URLs

- Privacy policy: https://emilhenrikssonn.github.io/habit-tracker/privacy-policy.html
- Support URL: needed, not created yet. A simple page with a contact email is enough.

## Subscriptions (App Store Connect)

Create one subscription group, "Habits", with two auto-renewable subscriptions. The product IDs must
match the app exactly:

| Reference name | Product ID | Period | Price (USD) | Introductory offer |
| --- | --- | --- | --- | --- |
| Yearly | `com.emilhenriksson.habittracker.yearly` | 1 year | 39.99 | Free trial, 1 week, new subscribers |
| Monthly | `com.emilhenriksson.habittracker.monthly` | 1 month | 5.99 | Free trial, 1 week, new subscribers |

Also needed before the subscriptions can be submitted:
- The Paid Applications agreement, with tax and bank details, under Agreements, Tax, and Banking.
- A display name and description for each subscription, and a review screenshot of the paywall.
- The subscriptions must be attached to the 1.0 version when it is submitted for review.
- Terms of use: the app links to Apple's standard licence agreement, so nothing has to be written.

`StoreKit/Products.storekit` mirrors these products for local testing. It is used when the app is run
from Xcode and by the tests; the App Store build talks to the real App Store.

## App privacy

Data collection: "Data Not Collected". Purchases go through Apple and the app stores nothing about them.

## Export compliance

The app uses no encryption of its own; `ITSAppUsesNonExemptEncryption` is set to false in Info.plist.

## Screenshots

In `appstore/screenshots/`, 1320 × 2868 (iPhone 6.9"), taken from the iPhone 16 Pro Max simulator
with sample data. To retake, install a Debug build fresh and launch with `DEMO_DATA=1 SKIP_PAYWALL=1`
(plus `DEMO_VIEW=grid`, `START_TAB=0…3` or `OPEN_ADD=1`).

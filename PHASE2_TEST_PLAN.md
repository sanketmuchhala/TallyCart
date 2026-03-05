# Phase 2 Test Plan

## Trips
1. Create Trip
- Open Trips tab.
- Tap `New Trip`.
- Set date, store, and budget.
- Save.
- Expected: Trip appears in Upcoming with correct title/date/store/budget.

2. Edit Trip Items
- Open a planned trip.
- Add an item with quantity.
- Toggle purchased.
- Edit item name.
- Reorder items.
- Expected: UI updates instantly and persists after app relaunch.

3. Start + Complete Trip
- Open planned trip and tap `Start Trip`.
- Tap `Complete Trip`, enter actual spend.
- Expected: status changes to Done and trip moves to Completed section.

4. Copy from Last Trip
- Create a new trip with `Copy last trip items` enabled.
- Expected: Items from last completed trip appear in new trip.

5. Add Staples on Create
- Add staples in Lists tab.
- Create a new trip with `Include staples` enabled.
- Expected: Staples appear in the new trip as items.

## Suggestions
6. Generate Suggestions
- Open a trip and go to Suggestions.
- Tap `Generate Suggestions`.
- Expected: Necessary and Premium lists appear with reasons.

7. Accept Suggestions
- Select items and tap `Add Selected`.
- Expected: Items added to trip list and removed from suggestions.

8. Dismiss Suggestions
- Select items and tap `Dismiss Selected`.
- Expected: Items removed from suggestions and do not reappear on next generation for same trip.

## Stores
9. Create Store
- Open Stores tab.
- Add a store with name, location, and notes.
- Set as default.
- Expected: Store appears with Default badge.

10. Edit Store
- Tap a store and edit.
- Expected: Store details update and persist after relaunch.

## Preferences
11. Update Preferences
- Open Dashboard and tap Settings.
- Change budget, household size, sensitivity, diet flags, avoid items.
- Expected: Values persist and are used for suggestions.

## Dashboard
12. Monthly Summary
- Complete at least one trip with actual spend.
- Open Dashboard.
- Expected: Monthly spend, budget remaining, and trip count display.

13. Top Items
- Add multiple items across trips.
- Expected: Top items list shows the most frequent items.

## Sync
14. Supabase Sync
- Sign in on device A and create trips and stores.
- Sign in on device B.
- Expected: Data appears on device B after refresh.

15. Sign Out/In
- Sign out and sign back in.
- Expected: Auth gate shows sign-in, then trips reload successfully.

## UI / Accessibility
16. Header Alignment
- Verify Trips, Dashboard, Lists, Stores headers align at the same height.
17. Dark/Light Mode
- Toggle system appearance.
- Expected: all screens legible with semantic colors.

18. Dynamic Type
- Increase text size.
- Expected: no clipped layout or overlapping elements.


# SOLUTION.md

## Overview

I approached the challenge in two phases:

1. **Stabilize the local environment** so the app could actually run end to end with local Supabase.
2. **Fix product bugs** across the main flow and validate them with repeatable end-to-end checks.

To speed up debugging, I created a local Playwright E2E suite outside this repository and used it to detect regressions and validate the core challenge flow. The application fixes themselves are in this repository.

---

## Issues Found and Fixes Applied

### 1. Supabase migrations were not loading correctly

#### Problem
Some migration files were skipped because their filenames did not match the required Supabase pattern:

```txt
<timestamp>_name.sql
```

Examples were being skipped with messages like:

```txt
Skipping migration ... (file name must match pattern "<timestamp>_name.sql")
```

This caused later migrations to fail because base tables such as `public.profiles` and `articles` had never been created.

#### Fix
- Renamed the invalid migration filenames so Supabase would load them.
- Added a baseline schema migration so `supabase db reset` can rebuild the database from scratch in the correct order.

---

### 2. `supabase db reset` failed because base tables did not exist

#### Problem
A migration tried to run:

```sql
ALTER TABLE articles ...
```

before the `articles` table had been created.

#### Fix
Added a baseline migration that creates the required tables before later `ALTER TABLE` migrations run.

---

### 3. Invalid RLS policy syntax on `profiles`

#### Problem
One migration created a `FOR SELECT` policy with `WITH CHECK`:

```sql
CREATE POLICY ...
FOR SELECT
USING (true)
WITH CHECK (false)
```

This is invalid PostgreSQL syntax because `WITH CHECK` only applies to row-writing operations such as `INSERT` or `UPDATE`, not `SELECT`.

#### Fix
Removed the invalid `WITH CHECK` clause from the `FOR SELECT` policy.

---

### 4. Demo login failed because seeded auth string fields were `NULL`

#### Problem
In `supabase/seed.sql`, some auth fields that should contain strings were initialized as `NULL`:

- `confirmation_token`
- `recovery_token`
- `email_change_token_new`
- `email_change`

This caused login-related failures in local auth flows.

#### Fix
Initialized those fields with empty strings instead of `NULL`.

---

### 5. Editing a generated post did not actually persist changes

#### Problem
The `saveEdit` flow showed a success message, but the post content was not actually updated in Supabase.

#### Fix
Implemented the missing Supabase update call so editing a generated post now persists correctly.

---

### 6. Race condition in the onboarding/preferences form

#### Problem
There was a race condition between:
- the user typing into **Preferred topics**
- the async `loadPrefs()` request resolving later

If the user typed before the request finished, the async response overwrote their input.

#### Fix
Added a `useRef`-based dirty flag and routed form changes through a change handler so loaded preferences no longer overwrite user input once editing has started.

---

### 7. Saving preferences overwrote `display_name`

#### Problem
Saving onboarding preferences changed the user’s `display_name`.

Example:
- before: `Demo User A`
- after: `demo.a`

#### Cause
The `savePreferences` logic incorrectly overwrote `display_name` using part of the email.

#### Fix
Removed `display_name` from the preference save payload so saving preferences only updates preference-related fields.

---

### 8. Redeemed points were applied to the wrong user

#### Problem
`redeemPoints()` targeted the first user in the leaderboard instead of the authenticated profile.

#### Fix
Changed the target profile to use `profile.id` instead of the leaderboard leader.

---

### 9. Users could redeem more points than they had

#### Problem
Redeeming points could drive the balance below zero.

#### Fix
- Added frontend validation to block redeem attempts larger than the current balance.
- Added a database-level safeguard with a constraint so `current_month_points` can never become negative.

---

### 10. Article titles displayed incorrect placeholder text

#### Problem
Article cards showed generic labels such as `Article 1` instead of the real article title.

#### Cause
A broken helper was used instead of the actual `article.title`.

#### Fix
Replaced that logic so the UI now renders `article.title` directly.

---

### 11. Scheduled preview used the wrong article image field

#### Problem
The scheduled post preview attempted to read `image_url` instead of the real field name `imageurl`.

#### Fix
Updated the scheduled preview to use `imageurl`, so the article image renders correctly.

---

### 12. Local Edge Function auth was confusing due to Supabase key format

#### Problem
The README instructed copying the local anon key after `supabase start`, but newer Supabase CLI output prominently shows `sb_publishable_*` keys, which are not the correct JWT anon key for this setup.

This caused 401 errors in the fake post generation flow when the wrong key was placed in `.env.local`.

#### Fix
Used the real JWT anon key from:

```bash
supabase status --output env | grep ANON_KEY
```

and updated local setup accordingly during debugging.

---

## How I Tested the App

I tested the app in two ways:

### 1. Manual validation
I manually ran the full expected flow:

1. Sign in as a seeded demo user
2. Complete onboarding and save preferences
3. Refresh and confirm preferences persist
4. View dashboard and redeem points safely
5. Search and load articles
6. Save selected articles
7. Generate a fake post from a saved article
8. Edit the generated post
9. Schedule the post
10. Open the scheduled preview
11. Open the original article
12. Review profile information

### 2. Automated end-to-end testing
I created a Playwright E2E suite outside this repository to validate the main product flow and catch regressions while fixing issues.

That suite was used to verify areas such as:
- onboarding persistence
- dashboard redemption logic
- article extraction/display
- multi-select article save
- generated post editing
- schedule transitions
- scheduled preview rendering
- multi-user isolation

At the end of the process, the suite was green and the main challenge flow was validated end to end.

---

## Local Setup Notes

To run locally, I used:

```bash
npm install
cp .env.example .env.local
supabase start
supabase db reset
supabase functions serve
npm run dev
```

Important note for local Supabase auth:

`VITE_SUPABASE_ANON_KEY` must use the JWT anon key (`eyJ...`), not the `sb_publishable_*` key.

You can get the correct value with:

```bash
supabase status --output env | grep ANON_KEY
```

---

## Final Result

After the fixes:

- onboarding and preferences save correctly
- preferences persist after refresh
- dashboard point redemption behaves correctly and safely
- articles display correctly and can be saved
- fake post generation works through the local Edge Function
- generated posts can be edited and persist correctly
- posts can be scheduled locally
- scheduled preview shows correct article context
- profile displays the expected synthetic user data

The application now works locally with Supabase CLI and Docker as intended by the challenge.

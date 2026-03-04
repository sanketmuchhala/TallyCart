# TallyCart Setup Notes (Local Only)

This file contains local setup details and secrets for Supabase. It is intentionally gitignored.

## Supabase Project
1. Create a project in the Supabase dashboard.
2. Copy the Project URL and anon key.
3. In Xcode, update `TallyCart/Info.plist`:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`

## Google OAuth (Supabase Auth)
1. Enable Google provider in Supabase Auth.
2. Configure Google Cloud OAuth consent screen.
3. Add redirect URIs:
   - Supabase callback: `https://<YOUR_PROJECT_REF>.supabase.co/auth/v1/callback`
   - iOS deep link: `tallycart://login-callback`
4. In Supabase Auth → URL Configuration, add `tallycart://login-callback` to Additional Redirect URLs.

## Database Schema
Run the SQL block provided in the main implementation notes to create:
- `stores`
- `trips`
- `trip_items`
With RLS policies for `auth.uid()` ownership.

## Local Notes
- Keep this file local for per-developer keys or reminders.
- If you change the callback scheme, update:
  - `SupabaseClientProvider.callbackScheme`
  - `CFBundleURLSchemes` in `TallyCart/Info.plist`

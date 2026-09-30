# Roadnote car cost dashboard

A responsive HTML, CSS, and JavaScript dashboard for planning family-car journeys and reviewing estimated costs.

## Run the demo

Open `index.html` in a browser. Demo trips save only in that browser. For online syncing, connect a Supabase project in **Settings → Cloud storage** and sign in.

## Set up shared cloud storage

1. Create a Supabase project.
2. In **SQL Editor**, run the complete contents of `supabase-setup.sql`. It creates the trip tables, household sharing, invite codes, and row-level security rules.
3. In **Project Settings → API Keys**, copy the Project URL and the publishable key (or legacy `anon` key). Never use a `service_role` / secret key in this browser app.
4. Enter the URL and public key in the dashboard under **Settings → Cloud storage**. Use **Check connection** to verify the database API responds.
5. Create an account and sign in. Create the family household, then choose **Create invite code**. Your mom can open the dashboard, create her own account, connect to the same Supabase project, and enter the code to join.
6. Set the actual fuel price, tax, insurance, and consumption values in Settings. Prefilled fixed-cost values are examples.

For an existing Supabase project, rerun the updated SQL in SQL Editor after downloading these files. It adds per-car expense toggles and replaces the invite-code function. The updated generator uses PostgreSQL's built-in UUID function instead of `gen_random_bytes`, which was missing in the prior function's search path. Household data remains protected by row-level security; invite codes expire after seven days and allow up to five joins.

## Features

- Journey distance from a road route when available, with a manual distance option.
- Return journeys double the one-way distance.
- Fuel litres = distance × selected car's litres per 100 km ÷ 100.
- Fuel estimate = litres × saved price per litre.
- Monthly fixed costs include road tax and insurance only for cars whose corresponding Settings toggle is on. Closing a month snapshots the active fixed-cost totals.
- Remove planned or past trips from the overview or agenda.
- Dark mode saves as a device preference.
- The Route Finder page previews a route and estimated fuel cost, then adds it to the agenda.
- Cloud status checks the Supabase API and shows the time of the last successful database request.
- Monthly downloads generate an A4 PDF invoice directly, with journey rows, optional fixed costs, payment details, and automatic pagination. Invoice details are editable in Settings and saved on the current device. The separate Print button opens a cost overview. PDF libraries and subsetted DejaVu fonts are bundled locally.

Fuel and route values are estimates, not fuel receipts or a legally issued invoice. Map search and routing use the public OpenStreetMap Nominatim and OSRM demo services, which may have availability and fair-use limits; manual distance entry remains available.

## Files

- `index.html` — dashboard structure and journey flow
- `styles.css` — responsive styling and dark theme
- `app.js` — UI, route search, calculations, cloud status, and Supabase REST/auth integration
- `supabase-setup.sql` — database schema, sharing functions, and access policies

## Family viewer access
Run `supabase-viewer-access.sql` in the SQL Editor once. Existing `member` memberships become read-only; `owner` memberships retain editing access. The app requires the readiness function before admitting viewers. Share the view-only link shown after generating an invite. New devices use the supplied Supabase publishable configuration automatically; each person signs in with their own Supabase account. Site viewing permission must also be granted through the Site sharing controls.

## Favourite places and starting point
Favourite destinations and the default origin are saved to the signed-in owner’s Supabase user metadata (`roadnote_route_preferences`). They sync with the account and require no SQL migration. Household membership roles continue to come from `household_members`; metadata never grants permissions. New named route endpoints store a versioned JSON object inside the existing label text column, containing the short name and original address; the app also reads all older plain-address trips. Agenda rows disclose the full address on demand.

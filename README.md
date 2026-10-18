# ClosetX

ClosetX is a Flutter fashion app for local designers. Shoppers browse
published T-shirt designs, view them on a 3D shirt, and try them on with their
camera. Designers sign in, create their brand, and upload front and back
artwork for each shirt.

## Run the app

1. Install the Flutter SDK.
2. From the project directory, run `flutter pub get`.
3. Run the web build (3D view and camera try-on run in the browser):

```powershell
flutter run -d chrome --dart-define-from-file=supabase.env.json
```

For an Android emulator or device, pass the same Supabase configuration:

```powershell
flutter run -d <device-id> --dart-define-from-file=supabase.env.json
```

In VS Code, select **ClosetX (Supabase)** from Run and Debug to launch with
the project configuration.

To use a Chromium browser other than Chrome (for example Brave), set
`CHROME_EXECUTABLE` to its `.exe` first.

Use `flutter test` to run the tests and `flutter analyze` to check the project.

## Supabase setup

1. Copy `supabase.env.json.example` to `supabase.env.json` and fill in the
   project URL and the publishable or legacy `anon` key. The file is ignored by
   Git. Never put a `service_role` secret in the app.
2. In **Authentication → URL Configuration**, add the URL you run the web app
   on (for example `http://localhost:5000`) to the redirect URLs so email
   confirmation links return to the app. For quick local testing you can turn
   off **Confirm email** instead.
3. In **Authentication → Users**, set this account's **App metadata** to
   `{"closetx_admin": true}` for each administrator. Admins must sign out and
   sign back in after changing app metadata.

### Database migrations

If the ClosetX app tables already exist in this Supabase project, do not rerun
the base schema. In the Supabase SQL Editor, run
`supabase/migrations/20261007120000_admin_workflows.sql` once. This adds the
designer and design review fields and policies, and creates the `feedback`
table. The dashboard uses the existing `profiles`, `brands`, and `designs`
tables; it does not need a separate admin table.

The dashboard also reads brand logos and design thumbnails. If those columns
are not in the database yet, first run
`supabase/migrations/20261006120000_brand_logos_and_thumbnails.sql`.

For a completely fresh Supabase project, run these migrations in order:

1. `supabase/migrations/20261006000000_closetx_schema.sql`
2. `supabase/migrations/20261006120000_brand_logos_and_thumbnails.sql`
3. `supabase/migrations/20261007120000_admin_workflows.sql`

### Admin dashboard

The static dashboard is in `admin-dashboard/`. Serve the ClosetX project root
over HTTP so the dashboard can load `supabase.env.json` from that root (do not
open the HTML files directly with `file://` or serve only the `web/` folder).
Open `http://localhost:<port>/admin-dashboard/` using your local static-file
server. Sign in with an account marked as an admin above.

For Vercel, set the project root directory to `admin-dashboard` and add
`SUPABASE_URL` and `SUPABASE_ANON_KEY` as Production environment variables.
The `/api/config` function exposes only those public client settings to the
dashboard; never configure a `service_role` key there. Redeploy after changing
the variables. Add `https://admin-dashboard-one-alpha-13.vercel.app/login.html`
to Supabase's Authentication → URL Configuration → Redirect URLs, and use
`https://admin-dashboard-one-alpha-13.vercel.app` as the Site URL so recovery
emails return to the deployed dashboard. The login page accepts recovery links
and lets administrators set a new password.

The dashboard manages designer applications, design approvals, accepted
designers, and feedback submitted from the app's **Profile → Share feedback**
screen. New designer applications and designs remain unavailable to shoppers
until approved. Admin access is checked server-side using Supabase RLS and the
`closetx_admin` app-metadata claim; never use a `service_role` key in the
dashboard.

To enable designer account removal, link the Supabase CLI to the project with
`supabase link --project-ref <project-ref>`, then deploy the
`admin-remove-designer` Edge Function with
`supabase functions deploy admin-remove-designer`. It verifies the requesting
admin, removes the designer's uploaded images, and deletes their Auth account.
The function uses Supabase's server-side `SUPABASE_SERVICE_ROLE_KEY`; never put
a service-role key in the dashboard or app. Removing an account permanently
deletes its profile, brand, and designs as well.

To enable design removal from the approvals dashboard, deploy the
`admin-remove-design` Edge Function with
`supabase functions deploy admin-remove-design`. It verifies the requesting
admin, removes the selected design, and cleans up its uploaded images.

The app only displays published designs fetched from the configured Supabase
project. It does not bundle fallback/sample products. If the project
configuration is missing or a catalog request fails, the app shows a
configuration or connection error instead of displaying stale or sample
content.

### Accounts

- **Shopper**: browses designs. Signing in is optional.
- **Designer**: chosen when creating an account. An admin must accept the
  application before the designer can create a brand and upload designs from
  **Profile → Designer studio**. Each upload needs front and back artwork
  (PNG, JPEG or WebP, up to 10 MB), a price, a category and a shirt colour.
  Designs go to admin review before they can be published; accepted designs
  can later be hidden or deleted from the studio.

Artwork is stored at `design-images/{user_id}/…`; only the owning designer can
write to their folder, and anyone can read published images.

## 3D view and camera try-on

`web/tryon/index.html` is a standalone page that the app embeds in an iframe:

- **three.js** loads the rigged shirt `web/tryon/shirt.glb`: `Shirt_Blank`
  (baked normal and AO maps, shape keys `ChestWide`, `WaistWide`, `SleeveWide`,
  `Longer`) and an invisible `Body_Occluder` mannequin on the rig `Hips`,
  `Spine`, `Chest`, `Neck`, `Shoulder/UpperArm/Forearm/Hand .L/.R` and
  `Hem.F/B/L/R`. Front and back artwork is projected onto the chest and back
  print areas in the rest pose, so prints follow the cloth. The shirt colour
  tints the fabric.
- **MediaPipe Pose Landmarker** (`@mediapipe/tasks-vision`) tracks the body.
  Its 3D world landmarks are retargeted onto the rig: hips and chest turn and
  lean in 3D (so turning sideways or around keeps the shirt on), upper arms and
  forearms aim at the elbows and wrists, and hem bones lag behind for sway. The
  2D landmarks place and size the shirt on screen; the person mask and the
  occluder hide whatever should be behind the body. The nose position decides
  front versus back when MediaPipe mixes up left and right.

The page reads `mode` (`3d` or `camera`), `front`, `back` and `color` from its
query string. It loads three.js, MediaPipe and the pose model from public
CDNs, so it needs an internet connection. The camera needs a secure context
(`localhost` or HTTPS).

The 3D viewer and camera try-on are available in the web build and on Android.
Android serves the bundled viewer from a local loopback address so WebView can
load the 3D assets and use the camera; camera try-on prompts for Android camera
permission. The viewer and pose-tracking libraries load from public CDNs, so
both features need an internet connection. iOS currently shows a notice
instead.

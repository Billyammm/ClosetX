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
`supabase/migrations/20261007120000_admin_workflows.sql` and then
`supabase/migrations/20261008120000_shopper_saved_designs.sql` and
`supabase/migrations/20261009120000_public_design_popularity.sql` once. These
add the designer and design review workflows, shopper design saves, authorized
designer/admin save counts, and public aggregate popularity counts for the
published catalog. The dashboard uses the existing `profiles`, `brands`, and
`designs` tables; it does not need a separate admin table.

The dashboard also reads brand logos and design thumbnails. If those columns
are not in the database yet, first run
`supabase/migrations/20261006120000_brand_logos_and_thumbnails.sql`.

For a completely fresh Supabase project, run these migrations in order:

1. `supabase/migrations/20261006000000_closetx_schema.sql`
2. `supabase/migrations/20261006120000_brand_logos_and_thumbnails.sql`
3. `supabase/migrations/20261007120000_admin_workflows.sql`
4. `supabase/migrations/20261008120000_shopper_saved_designs.sql`
5. `supabase/migrations/20261009120000_public_design_popularity.sql`
6. `supabase/migrations/20261010120000_realtime_published_designs.sql`
7. `supabase/migrations/20261011120000_google_role_setup.sql`

The final migration enables Postgres Changes for `public.designs`. While the
Discover screen is open, the app subscribes to changes and reloads the public
catalog after an admin publishes, updates, or removes a design. Realtime events
only notify rows allowed by the existing design read policies; the catalog is
still queried with `is_published = true`. Apply this migration to an existing
project as well as fresh projects to enable live catalog updates and Google
role setup.

### Google sign-in

The Flutter app supports Google sign-in in addition to email and password.
New Google users choose **Shopper** or **Designer** once after returning from
Google. Designer accounts still require admin approval before they can upload.

To enable it:

1. In Google Cloud Console, create a Web OAuth client and add the Supabase
   callback URL shown in **Supabase → Authentication → Providers → Google**.
2. Enable the Google provider in Supabase and enter the Google client ID and
   client secret.
3. Add `closetx://login-callback/` to the Supabase Authentication redirect URLs
   for Android, and add the web app URL for browser sign-in.
4. Apply `supabase/migrations/20261011120000_google_role_setup.sql`.

The Android app uses the `closetx://login-callback/` deep link. Google sign-in
cannot work until the provider credentials, redirect URLs, and migration are
configured in Supabase.

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
the variables. The dashboard returns password-recovery emails to the same
login URL that requested them. Add the production login URL and any Preview
login URL you intend to use to Supabase's Authentication → URL Configuration
→ Redirect URLs, and set the production dashboard URL as the Site URL. The
login page accepts recovery links and lets administrators set a new password.

#### Admin dashboard versioning

The dashboard version is stored in `admin-dashboard/VERSION` using
`MAJOR.MINOR.PATCH` format and is displayed on the login page and in the
dashboard sidebar. Increment the version when releasing dashboard changes:
use PATCH for compatible fixes, MINOR for compatible features, and MAJOR for
breaking changes.

Use a feature branch instead of committing directly to `main`. Open a pull
request so changes can be reviewed and tested in Vercel Preview before merge.
After merging, Vercel deploys `main` to Production. Tag releases from the
updated `main` branch:

```powershell
git switch main
git pull
git tag -a admin-dashboard-v1.1.0 -m "Admin dashboard v1.1.0"
git push origin admin-dashboard-v1.1.0
```

Replace `1.1.0` with the version recorded in `admin-dashboard/VERSION`.
Keep environment files, Supabase credentials, and service-role keys out of
commits.

The dashboard manages designer applications, design approvals, accepted
designers, shopper saves by design, and feedback submitted from the app's
**Profile → Share feedback** screen. New designer applications and designs
remain unavailable to shoppers until approved. Admin access is checked
server-side using Supabase RLS and the `closetx_admin` app-metadata claim; never
use a `service_role` key in the dashboard.

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

#### Designer application email notifications

The app confirms when a designer application is submitted. When an admin
accepts or declines a pending application, the dashboard calls the
`review-designer-application` Edge Function, which updates the application and
sends the decision to the applicant's registered email address using EmailJS.

1. In EmailJS, find the service ID under **Email Services**, the public and
   private keys under **Account**, and the template ID on the template's
   settings page. The ClosetX application-status template ID is
   `template_sexryer`.
2. Make sure the template's recipient field uses `{{to_email}}`. The function
   provides `to_email`, `to_name`, `subject`, `message`, `designer_name`,
   `application_status`, and `rejection_reason` as template parameters.
3. Set the EmailJS values as Edge Function secrets in the linked Supabase
   project. Replace the example values locally; never paste private keys into
   chat or commit them:

   ```powershell
   supabase secrets set 'EMAILJS_SERVICE_ID=service_xxxxx' 'EMAILJS_TEMPLATE_ID=template_sexryer' 'EMAILJS_PUBLIC_KEY=your_public_key' 'EMAILJS_PRIVATE_KEY=your_private_key'
   ```

4. Remove any Resend secrets if you set them during setup, then deploy the
   function:

   ```powershell
   supabase secrets unset RESEND_API_KEY RESEND_FROM_EMAIL
   supabase functions deploy review-designer-application
   ```

EmailJS keys are stored as Supabase secrets and are never embedded in the app
or dashboard. The Supabase service-role key remains server-side and must never
be added to the Flutter app, dashboard configuration, or source control. An
admin decision is saved even if EmailJS cannot send the message; in that case
the dashboard displays a warning.

The app only displays published designs fetched from the configured Supabase
project. It does not bundle fallback/sample products. If the project
configuration is missing or a catalog request fails, the app shows a
configuration or connection error instead of displaying stale or sample
content.

### Accounts

- **Shopper**: browses designs as a guest or signed in. A shopper account is
  required to save designs; designers cannot use their designer account to
  create shopper saves. Saved designs are private to the shopper, while the
  design's save count is visible to its designer and admins.
- **Designer**: chosen when creating an account. An admin must accept the
  application before the designer can create a brand and upload designs from
  **Profile → Designer studio**. Each upload needs front and back artwork
  (PNG, JPEG or WebP, up to 10 MB), a price, a category and a shirt colour.
  The app confirms submission and emails the registered address when an admin
  accepts or declines the application. Designs go to admin review before they
  can be published; accepted designs can later be hidden or deleted from the
  studio.

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

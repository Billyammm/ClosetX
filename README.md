# ClosetX

ClosetX is a Flutter app concept for an AR fashion platform. Designers submit
shirt designs with 3D garment models, admins review submissions, and consumers
can browse approved designs and use a phone camera for virtual try-on. The
current UI is still a prototype; live authentication, database-backed
workflows, and camera-based AR are not implemented yet.

## Run the app

1. Install the Flutter SDK and the Android or iOS development tools.
2. From the project directory, run `flutter pub get`.
3. Connect a device or start an emulator, then run `flutter run`.

Use `flutter test` to run the widget tests and `flutter analyze` to check the
project.

## Supabase setup

The app can initialize the Supabase client using local Dart defines. Copy
`supabase.env.json.example` to `supabase.env.json`, replace the placeholder with
the project's publishable key or legacy `anon` key, then run:

```powershell
flutter run --dart-define-from-file=supabase.env.json
```

The local config file is ignored by Git. Never put a Supabase `service_role`
secret in a mobile app. Without a local key, the app runs its sample-data
prototype without initializing Supabase.

### Snap Camera Kit

Enable Camera Kit for the ClosetX organization and Android app in
[My Lenses](https://my-lenses.snapchat.com/camera-kit), then copy its Android
API token into the ignored `android/local.properties` file:

```properties
cameraKitApiToken=YOUR_ANDROID_CAMERA_KIT_API_TOKEN
```

Register the Android app ID `com.example.closetx` in Camera Kit. Rebuild after
adding the token. The product detail **Try-On with AR** button opens Snap's
Camera Kit camera with that design's `lens_id` and `lens_group_id`; both
identifiers must refer to a Lens published to the Camera Kit app. The Lens
itself must implement the garment/body-tracking effect in Lens Studio. The SDK
token is supplied through Android app metadata as required by Snap's SDK.

### Existing Supabase schema

The restored project already contains `profiles`, `admins`, `designer_profiles`,
`designs`, `design_likes`, `design_comments`, `favorites`, and `notifications`.
Designs store front/back image URLs, review status, and Lens Studio `lens_id`
and `lens_group_id`. The migration at
`supabase/migrations/20261005150000_closetx_core.sql` preserves those tables
and adds safe profile creation on auth signup plus RLS policies for customer,
designer, and admin access. Admins are identified by membership in `admins`;
consumer accounts use the existing `guest` role, while sign-up metadata can
create only guest or designer profiles. Admin accounts cannot be self-assigned.

Back up the restored Supabase project before running the migration. It replaces
existing RLS policies on its application tables so that the policies match the
access rules documented in the SQL. Review any custom policies first. The
migration was applied to the restored ClosetX project on 2026-10-05; run it in
the Supabase SQL Editor only when setting up another project.

The migration does not create storage buckets: the existing app stores image
URLs and Lens Studio effect identifiers in `designs`. The approved-design
catalog reads `front_image_url`, `back_image_url`, `price`, `category`, and
Lens Studio identifiers. Product details can launch a design's Lens through
Camera Kit when the Android token and published Lens metadata are configured.
Sign-in, designer uploads, and admin moderation are not wired yet.

## Current prototype status

When Supabase is configured, the app loads approved designs from the restored
project. Without the local key, it uses bundled sample garments instead.
Saved items and bag state are still session-only. Try-on uses Snap Camera Kit
and each design's published Lens; body tracking and garment rendering are
provided by that Lens, not implemented by ClosetX itself. Real designer
uploads and admin moderation remain to be implemented. Sample product imagery
is loaded from Unsplash and needs an internet connection; placeholder artwork
is shown if an image cannot be loaded.

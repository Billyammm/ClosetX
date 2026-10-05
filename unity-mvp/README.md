# Unity AR Clothing Try-On MVP

This folder contains a minimal Unity project scaffold for an Android AR clothing try-on MVP.

## What is included
- `Assets/Scripts/GarmentModel.cs`: a lightweight model for garment metadata.
- `Assets/Scripts/BodyTrackingManager.cs`: AR body tracking manager for live overlay anchors.
- `Assets/Scripts/UiManager.cs`: a basic UI controller for garment selection and try-on.

## Setup
1. Open Unity (2022.3+ or later).
2. Create a new Android project in this folder or import this scaffold into an existing project.
3. Install the following packages from Package Manager:
   - AR Foundation
   - ARCore XR Plugin
   - AR Subsystems
4. Create a new scene and add a `AR Session`, `AR Session Origin`, and `AR Camera`.
5. Add `BodyTrackingManager` and `UiManager` scripts to scene GameObjects.
6. Set the `Garment Prefab` field on `UiManager` and hook the selection buttons.

## MVP scope
- Local garment metadata store
- Real-time body tracking anchor support
- Garment overlay placement
- Simple UI for selecting t-shirt, hoodie, and shoes

## Notes
- This scaffold is intended as a starting point for a Unity Android AR build.
- Actual ARCore body tracking requires the device to support ARCore and ARKit compatibility layers are not included.

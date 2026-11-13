# Nairobi Drive

Godot 4.3 driving prototype using procedural original geometry. Renderer: GL Compatibility.

## Live demo

Play the Web build here:

https://teflon-code.github.io/nairobi-drive/

## Run

Open this folder in Godot 4.3 and press **F5**. The project creates a 4.2 km procedural street grid, block buildings with collisions, a van, checkpoint route, minimap, HUD and three lighting presets at runtime. Controls: W/S or arrows drive, A/D steer, Space handbrake, Shift brake, C camera, V vehicle, T time of day, M minimap, R recover, Enter restart.

## Source assets

Uploaded source files are under `assets/source/`. Several large imported/source assets are tracked with Git LFS. The current playable scene builds a deterministic procedural city so it does not depend on importing large source models at startup. Run `git lfs pull` after cloning to download actual LFS assets.

## Export

Install Godot 4.3 export templates. In Project > Export, add Windows Desktop or Web presets; use GL Compatibility for Web. Export the project from the editor. For Windows, export an executable. For Web, export the HTML and `.pck` files and serve them from a static web server.

## GitHub Pages deployment

This repository deploys the exported Web build to GitHub Pages automatically from the `build/procedural-nairobi-drive` branch using the workflow in `.github/workflows/deploy-pages.yml`.

## Physics smoke test

The test uses the real `VehicleBody3D` physics engine and checks acceleration, steering input, braking, ground contact, wall collision and gross rollover. Run on Windows with Godot 4.3 installed:

```bat
godot --headless --path . --rendering-method gl_compatibility --script tests/VehiclePhysicsTest.gd
```

On Linux, use the installed Godot 4.3 binary. For mesh-backed collision tests, use `xvfb` and OpenGL 3; this smoke test uses primitive collision shapes.

# Nairobi Drive

A compact, playable 3D driving prototype for Godot 4.3, built from original procedural geometry, a layered city grid, a drivable vehicle, a checkpoint route, a minimap, and a day-night cycle.

## Features
- Procedural CBD-inspired road grid and block layout
- Playable `VehicleBody3D` + `VehicleWheel3D` prototype
- Chase/cabin/high camera cycle
- 10 checkpoint route with HUD arrow and timer
- Day / sunset / night presets
- Minimap and recover/restart input flow
- Headless physics smoke test script

## Run in Godot
1. Install Godot 4.3.x (`gl_compatibility` renderer recommended).
2. Open the project folder in the editor.
3. Press F5 to run.

## Export (Windows)
1. Open Project > Export.
2. Add a Windows Desktop preset.
3. Set the export template to `export_templates` for Godot 4.3.
4. Use the project root and the `icon.svg` asset.
5. Export the game.

## Export (Web)
1. Open Project > Export.
2. Add a Web preset.
3. Set the renderer to `gl_compatibility`.
4. Choose HTML5 export and export the project.
5. Serve the generated files from a static web server, or use the Godot web export build.

## Headless test
Run the physics smoke test under xvfb with OpenGL 3:

```bash
xvfb-run -a godot --headless --path . --rendering-driver opengl3 --script tests/VehiclePhysicsTest.gd
```

This script checks the vehicle can accelerate, steer, brake, and stay in a stable state in a headless setup.

## Controls
- W / S or Arrow keys: throttle and brake
- A / D or Left / Right: steering
- Space: handbrake
- C: cycle camera mode
- V: switch van / bus
- P: repaint current vehicle
- T: cycle time of day
- M: toggle minimap
- R: recover vehicle
- Enter: restart scene
- H: help overlay

## Notes
This project is intentionally built from original procedural art and clean, exportable Godot script code so it can run in a standard Godot 4.3 environment without a dependency on external asset files.


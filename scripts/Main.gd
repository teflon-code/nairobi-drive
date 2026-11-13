extends Node3D

var vehicle: VehicleDriver
var camera: Camera3D
var world_environment: WorldEnvironment
var checkpoint_root: Node3D
var checkpoints: Array[Node3D] = []
var next_checkpoint_index := 0
var finish_label: Label
var timer_label: Label
var speed_label: Label
var gear_label: Label
var minimap_viewport: SubViewport
var minimap_camera: Camera3D
var minimap_texture: TextureRect
var cycle_index := 0
var camera_mode := 0
var driving_started := false
var map_visible := true
var elapsed_time := 0.0

func _ready() -> void:
    _bind_inputs()
    _build_world()
    _spawn_vehicle()
    _build_checkpoints()
    _build_ui()
    _build_minimap()
    _set_time_cycle(0)
    _update_camera(0.0)
    _update_hud()

func _bind_inputs() -> void:
    var actions := [
        "move_forward", "move_backward", "turn_left", "turn_right",
        "handbrake", "camera_toggle", "switch_vehicle", "time_cycle",
        "minimap_toggle", "recover", "restart", "brake"
    ]
    for action in actions:
        if not InputMap.has_action(action):
            InputMap.add_action(action)

    _bind_key("move_forward", [KEY_W, KEY_UP])
    _bind_key("move_backward", [KEY_S, KEY_DOWN])
    _bind_key("turn_left", [KEY_A, KEY_LEFT])
    _bind_key("turn_right", [KEY_D, KEY_RIGHT])
    _bind_key("handbrake", [KEY_SPACE])
    _bind_key("brake", [KEY_SHIFT])
    _bind_key("camera_toggle", [KEY_C])
    _bind_key("switch_vehicle", [KEY_V])
    _bind_key("time_cycle", [KEY_T])
    _bind_key("minimap_toggle", [KEY_M])
    _bind_key("recover", [KEY_R])
    _bind_key("restart", [KEY_ENTER])

func _bind_key(action_name: String, keys: Array[int]) -> void:
    for key in keys:
        var ev := InputEventKey.new()
        ev.physical_keycode = key
        ev.keycode = key
        InputMap.action_add_event(action_name, ev)

func _build_world() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_MODE_COLOR
    env.background_color = Color(0.58, 0.74, 0.94)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(1.0, 1.0, 1.0)
    env.ambient_light_energy = 1.2
    env.fog_enabled = true
    env.fog_density = 0.005
    env.fog_light_color = Color(0.65, 0.7, 0.8)
    world_environment = WorldEnvironment.new()
    world_environment.environment = env
    add_child(world_environment)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-35.0, 35.0, 0.0)
    sun.light_energy = 1.3
    sun.shadow_enabled = true
    add_child(sun)

    var ground := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(4200.0, 0.6, 4200.0)
    ground.mesh = box
    ground.position = Vector3(0.0, -0.3, 0.0)
    var ground_mat := StandardMaterial3D.new()
    ground_mat.albedo_color = Color(0.20, 0.38, 0.22)
    ground_mat.roughness = 1.0
    ground.set_surface_override_material(0, ground_mat)
    add_child(ground)

    var ground_body := StaticBody3D.new()
    ground_body.position = Vector3.ZERO
    var ground_shape := CollisionShape3D.new()
    var ground_collision := BoxShape3D.new()
    ground_collision.size = Vector3(4200.0, 0.6, 4200.0)
    ground_shape.shape = ground_collision
    ground_body.add_child(ground_shape)
    add_child(ground_body)

    var road_mat := StandardMaterial3D.new()
    road_mat.albedo_color = Color(0.12, 0.12, 0.15)
    road_mat.roughness = 1.0

    for x in range(-1800, 1801, 200):
        var road := MeshInstance3D.new()
        var road_mesh := BoxMesh.new()
        road_mesh.size = Vector3(30.0, 0.1, 4100.0)
        road.mesh = road_mesh
        road.position = Vector3(float(x), 0.05, 0.0)
        road.set_surface_override_material(0, road_mat)
        add_child(road)

    for z in range(-1800, 1801, 200):
        var road := MeshInstance3D.new()
        var road_mesh := BoxMesh.new()
        road_mesh.size = Vector3(4100.0, 0.1, 30.0)
        road.mesh = road_mesh
        road.position = Vector3(0.0, 0.05, float(z))
        road.set_surface_override_material(0, road_mat)
        add_child(road)

    for x in range(-1500, 1501, 180):
        for z in range(-1500, 1501, 180):
            if abs(x) < 220 and abs(z) < 220:
                continue
            var block = MeshInstance3D.new()
            var block_mesh = BoxMesh.new()
            var height := 28.0 + randf() * 60.0
            var width := 50.0 + randf() * 80.0
            var depth := 50.0 + randf() * 80.0
            block_mesh.size = Vector3(width, height, depth)
            block.mesh = block_mesh
            block.position = Vector3(float(x) + randf_range(-40.0, 40.0), height * 0.5, float(z) + randf_range(-40.0, 40.0))
            var mat := StandardMaterial3D.new()
            mat.albedo_color = Color.from_hsv(0.08 + randf() * 0.06, 0.35, 0.72)
            mat.roughness = 0.7
            block.set_surface_override_material(0, mat)
            add_child(block)

            var collision_body := StaticBody3D.new()
            var collision_shape := CollisionShape3D.new()
            var collision_box := BoxShape3D.new()
            collision_box.size = Vector3(width, height, depth)
            collision_shape.shape = collision_box
            collision_body.position = block.position
            collision_body.add_child(collision_shape)
            add_child(collision_body)

    var grass_band := MeshInstance3D.new()
    var grass_mesh := BoxMesh.new()
    grass_mesh.size = Vector3(4600.0, 0.4, 120.0)
    grass_band.mesh = grass_mesh
    grass_band.position = Vector3(0.0, 0.15, -2150.0)
    var grass_mat := StandardMaterial3D.new()
    grass_mat.albedo_color = Color(0.20, 0.52, 0.28)
    grass_band.set_surface_override_material(0, grass_mat)
    add_child(grass_band)

    var grass_band2 := MeshInstance3D.new()
    grass_band2.mesh = grass_mesh
    grass_band2.position = Vector3(0.0, 0.15, 2150.0)
    add_child(grass_band2)

    var grass_band3 := MeshInstance3D.new()
    grass_band3.mesh = BoxMesh.new()
    grass_band3.mesh.size = Vector3(120.0, 0.4, 4600.0)
    grass_band3.position = Vector3(-2150.0, 0.15, 0.0)
    add_child(grass_band3)

    var grass_band4 := MeshInstance3D.new()
    grass_band4.mesh = BoxMesh.new()
    grass_band4.mesh.size = Vector3(120.0, 0.4, 4600.0)
    grass_band4.position = Vector3(2150.0, 0.15, 0.0)
    add_child(grass_band4)

func _spawn_vehicle() -> void:
    vehicle = VehicleDriver.new()
    vehicle.name = "PlayerVehicle"
    add_child(vehicle)
    vehicle.position = Vector3(0.0, 1.2, 1500.0)
    vehicle.rotation_degrees.y = 180.0
    vehicle.configure("van", Color(0.72, 0.18, 0.24))

func _build_checkpoints() -> void:
    checkpoint_root = Node3D.new()
    checkpoint_root.name = "Checkpoints"
    add_child(checkpoint_root)

    var route := [
        Vector3(0.0, 1.0, -1500.0),
        Vector3(200.0, 1.0, -1200.0),
        Vector3(450.0, 1.0, -900.0),
        Vector3(650.0, 1.0, -550.0),
        Vector3(400.0, 1.0, -200.0),
        Vector3(0.0, 1.0, 150.0),
        Vector3(-350.0, 1.0, 450.0),
        Vector3(-700.0, 1.0, 850.0),
        Vector3(-300.0, 1.0, 1200.0),
        Vector3(200.0, 1.0, 1500.0)
    ]

    for point in route:
        var checkpoint := Node3D.new()
        checkpoint.position = point
        checkpoint_root.add_child(checkpoint)

        var ring := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.major_radius = 10.0
        torus.minor_radius = 0.8
        torus.rings = 24
        torus.radial_segments = 32
        ring.mesh = torus
        ring.rotation_degrees.x = 90.0
        var ring_mat := StandardMaterial3D.new()
        ring_mat.albedo_color = Color(0.15, 1.0, 0.72, 0.75)
        ring_mat.emission_enabled = true
        ring_mat.emission = Color(0.18, 1.0, 0.82)
        ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        ring.set_surface_override_material(0, ring_mat)
        checkpoint.add_child(ring)

        var beam := MeshInstance3D.new()
        var beam_mesh := BoxMesh.new()
        beam_mesh.size = Vector3(1.0, 16.0, 18.0)
        beam.mesh = beam_mesh
        beam.position = Vector3.ZERO
        beam.set_surface_override_material(0, ring_mat)
        checkpoint.add_child(beam)

        checkpoints.append(checkpoint)

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)

    speed_label = Label.new()
    speed_label.position = Vector2(24, 24)
    speed_label.add_theme_font_size_override("font_size", 28)
    speed_label.text = "0 km/h"
    canvas.add_child(speed_label)

    gear_label = Label.new()
    gear_label.position = Vector2(24, 60)
    gear_label.add_theme_font_size_override("font_size", 18)
    gear_label.text = "Gear 1"
    canvas.add_child(gear_label)

    timer_label = Label.new()
    timer_label.position = Vector2(24, 92)
    timer_label.add_theme_font_size_override("font_size", 18)
    timer_label.text = "00:00.0"
    canvas.add_child(timer_label)

    var checkpoint_title := Label.new()
    checkpoint_title.position = Vector2(24, 124)
    checkpoint_title.add_theme_font_size_override("font_size", 16)
    checkpoint_title.text = "Checkpoint"
    canvas.add_child(checkpoint_title)

    var checkpoint_label := Label.new()
    checkpoint_label.position = Vector2(24, 146)
    checkpoint_label.add_theme_font_size_override("font_size", 18)
    checkpoint_label.text = "1 / 10"
    canvas.add_child(checkpoint_label)
    vehicle.ui_checkpoint = checkpoint_label

    finish_label = Label.new()
    finish_label.position = Vector2(520, 200)
    finish_label.visible = false
    finish_label.add_theme_font_size_override("font_size", 36)
    finish_label.text = "Run complete! Press Enter to restart."
    canvas.add_child(finish_label)

    var help_label := Label.new()
    help_label.position = Vector2(400, 20)
    help_label.text = "WASD steer/throttle | C camera | V swap vehicle | T time | M minimap | R recover | Enter restart"
    help_label.modulate = Color(1,1,1,0.9)
    canvas.add_child(help_label)

func _build_minimap() -> void:
    minimap_viewport = SubViewport.new()
    minimap_viewport.size = Vector2i(180, 180)
    minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    minimap_viewport.transparent_bg = true
    minimap_viewport.usage = SubViewport.USAGE_3D
    add_child(minimap_viewport)

    minimap_camera = Camera3D.new()
    minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    minimap_camera.size = 1600.0
    minimap_camera.position = Vector3.ZERO
    minimap_camera.rotation_degrees.x = -90.0
    minimap_viewport.add_child(minimap_camera)

    var panel := Panel.new()
    panel.position = Vector2(20, 620)
    panel.size = Vector2(200, 200)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.12, 0.18, 0.7)
    style.border_color = Color(0.9, 0.9, 0.9, 0.9)
    style.border_width_left = 3
    style.border_width_top = 3
    style.border_width_right = 3
    style.border_width_bottom = 3
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)

    minimap_texture = TextureRect.new()
    minimap_texture.position = Vector2(30, 630)
    minimap_texture.size = Vector2(180, 180)
    minimap_texture.texture = minimap_viewport.get_texture()
    panel.add_child(minimap_texture)

func _set_time_cycle(index: int) -> void:
    cycle_index = index
    var presets = [
        {"sky": Color(0.65, 0.76, 0.95), "sun": 1.2, "fog": Color(0.55, 0.66, 0.8), "ambient": 1.0},
        {"sky": Color(0.96, 0.6, 0.44), "sun": 0.8, "fog": Color(0.72, 0.53, 0.42), "ambient": 0.75},
        {"sky": Color(0.10, 0.15, 0.28), "sun": 0.15, "fog": Color(0.08, 0.10, 0.15), "ambient": 0.25}
    ]
    var preset = presets[index]
    world_environment.environment.background_color = preset["sky"]
    world_environment.environment.fog_light_color = preset["fog"]
    world_environment.environment.ambient_light_color = preset["sky"]
    world_environment.environment.ambient_light_energy = preset["ambient"]
    get_child(0).light_energy = preset["sun"]

func _update_hud() -> void:
    if vehicle == null:
        return
    var speed_kmh := abs(vehicle.linear_velocity.length() * 3.6)
    speed_label.text = "%d km/h" % int(speed_kmh)
    gear_label.text = "Gear %d" % vehicle.current_gear
    timer_label.text = "%02d:%05.1f" % [int(elapsed_time / 60.0), fmod(elapsed_time, 60.0)]
    if checkpoints.size() > 0:
        vehicle.ui_checkpoint.text = "%d / %d" % [min(next_checkpoint_index + 1, checkpoints.size()), checkpoints.size()]

func _process(delta: float) -> void:
    if vehicle == null:
        return

    elapsed_time += delta
    var next_point: Node3D = checkpoints[next_checkpoint_index] if next_checkpoint_index < checkpoints.size() else checkpoints[checkpoints.size() - 1]
    if vehicle.global_position.distance_to(next_point.global_position) < 16.0:
        next_checkpoint_index += 1
        if next_checkpoint_index >= checkpoints.size():
            finish_label.visible = true
            finish_label.text = "Run complete! Press Enter to restart."
            return

    if Input.is_action_just_pressed("camera_toggle"):
        camera_mode = (camera_mode + 1) % 3

    if Input.is_action_just_pressed("switch_vehicle"):
        vehicle.switch_vehicle()

    if Input.is_action_just_pressed("time_cycle"):
        _set_time_cycle((cycle_index + 1) % 3)

    if Input.is_action_just_pressed("minimap_toggle"):
        map_visible = not map_visible
        minimap_texture.visible = map_visible

    if Input.is_action_just_pressed("recover"):
        vehicle.global_position = checkpoints[max(0, next_checkpoint_index)].global_position + Vector3(0.0, 1.2, 0.0)
        vehicle.linear_velocity = Vector3.ZERO
        vehicle.angular_velocity = Vector3.ZERO

    if Input.is_action_just_pressed("restart"):
        get_tree().reload_current_scene()

    _update_hud()
    _update_camera(delta)
    _update_minimap()

func _update_camera(delta: float) -> void:
    if camera == null:
        camera = Camera3D.new()
        camera.position = Vector3(0.0, 4.0, 8.0)
        add_child(camera)
        camera.current = true

    var forward := -vehicle.global_transform.basis.z
    match camera_mode:
        0:
            var chase_pos := vehicle.global_position + Vector3(0.0, 4.0, 8.0) - forward * 6.0
            camera.global_position = camera.global_position.lerp(chase_pos, 0.12)
            camera.look_at(vehicle.global_position + Vector3(0.0, 1.5, 0.0), Vector3.UP)
        1:
            var cabin_pos := vehicle.global_position + Vector3(0.0, 2.3, 0.0) - forward * 1.8
            camera.global_position = camera.global_position.lerp(cabin_pos, 0.18)
            camera.look_at(vehicle.global_position + Vector3(0.0, 1.5, -8.0), Vector3.UP)
        2:
            var high_pos := vehicle.global_position + Vector3(0.0, 18.0, 0.0)
            camera.global_position = camera.global_position.lerp(high_pos, 0.08)
            camera.look_at(vehicle.global_position, Vector3.UP)

    var speed_fov := clamp(vehicle.linear_velocity.length() / 28.0, 0.0, 1.0)
    camera.fov = lerp(70.0, 92.0, speed_fov)

func _update_minimap() -> void:
    if minimap_camera == null:
        return
    minimap_camera.global_position = Vector3(vehicle.global_position.x, 260.0, vehicle.global_position.z)
    minimap_camera.look_at(vehicle.global_position, Vector3.UP)
    minimap_texture.texture = minimap_viewport.get_texture()


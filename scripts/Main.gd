extends Node3D

var vehicle: VehicleDriver
var camera: Camera3D
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
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
var map_visible := true
var elapsed_time := 0.0
var finished := false

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
    var actions := ["move_forward", "move_backward", "turn_left", "turn_right", "handbrake", "camera_toggle", "switch_vehicle", "time_cycle", "minimap_toggle", "recover", "restart", "brake"]
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
        var event := InputEventKey.new()
        event.physical_keycode = key
        InputMap.action_add_event(action_name, event)

func _build_world() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.58, 0.74, 0.94)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color.WHITE
    environment.ambient_light_energy = 1.2
    environment.fog_enabled = true
    environment.fog_density = 0.003
    environment.fog_light_color = Color(0.65, 0.7, 0.8)
    world_environment = WorldEnvironment.new()
    world_environment.environment = environment
    add_child(world_environment)

    sun = DirectionalLight3D.new()
    sun.name = "Sun"
    sun.rotation_degrees = Vector3(-35.0, 35.0, 0.0)
    sun.light_energy = 1.3
    sun.shadow_enabled = true
    add_child(sun)

    var ground := MeshInstance3D.new()
    var ground_mesh := BoxMesh.new()
    ground_mesh.size = Vector3(4200.0, 0.4, 4200.0)
    ground.mesh = ground_mesh
    ground.position.y = -0.2
    var ground_mat := StandardMaterial3D.new()
    ground_mat.albedo_color = Color(0.20, 0.38, 0.22)
    ground_mat.roughness = 1.0
    ground.set_surface_override_material(0, ground_mat)
    add_child(ground)

    var floor_body := StaticBody3D.new()
    floor_body.name = "WorldFloor"
    var floor_shape := CollisionShape3D.new()
    var floor_box := BoxShape3D.new()
    floor_box.size = Vector3(4200.0, 0.4, 4200.0)
    floor_shape.shape = floor_box
    floor_body.add_child(floor_shape)
    add_child(floor_body)

    var road_mat := StandardMaterial3D.new()
    road_mat.albedo_color = Color(0.12, 0.12, 0.15)
    road_mat.roughness = 1.0
    for x in range(-1800, 1801, 200):
        _add_road(Vector3(float(x), 0.035, 0.0), Vector3(30.0, 0.07, 4100.0), road_mat)
    for z in range(-1800, 1801, 200):
        _add_road(Vector3(0.0, 0.035, float(z)), Vector3(4100.0, 0.07, 30.0), road_mat)

    var rng := RandomNumberGenerator.new()
    rng.seed = 40613
    for x in range(-1500, 1501, 180):
        for z in range(-1500, 1501, 180):
            if abs(x) < 220 and abs(z) < 220:
                continue
            var height := rng.randf_range(24.0, 72.0)
            var width := rng.randf_range(48.0, 90.0)
            var depth := rng.randf_range(48.0, 90.0)
            var position := Vector3(float(x) + rng.randf_range(-24.0, 24.0), height * 0.5, float(z) + rng.randf_range(-24.0, 24.0))
            _add_building(position, Vector3(width, height, depth), Color.from_hsv(rng.randf_range(0.07, 0.15), 0.25, rng.randf_range(0.55, 0.8)))

    for edge in [-2150.0, 2150.0]:
        var strip := MeshInstance3D.new()
        var strip_mesh := BoxMesh.new()
        strip_mesh.size = Vector3(4600.0, 0.3, 120.0)
        strip.mesh = strip_mesh
        strip.position = Vector3(0.0, 0.12, edge)
        var grass := StandardMaterial3D.new()
        grass.albedo_color = Color(0.18, 0.48, 0.22)
        strip.set_surface_override_material(0, grass)
        add_child(strip)
    for edge in [-2150.0, 2150.0]:
        var strip := MeshInstance3D.new()
        var strip_mesh := BoxMesh.new()
        strip_mesh.size = Vector3(120.0, 0.3, 4600.0)
        strip.mesh = strip_mesh
        strip.position = Vector3(edge, 0.12, 0.0)
        var grass := StandardMaterial3D.new()
        grass.albedo_color = Color(0.18, 0.48, 0.22)
        strip.set_surface_override_material(0, grass)
        add_child(strip)

func _add_road(position: Vector3, size: Vector3, material: Material) -> void:
    var road := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    road.mesh = mesh
    road.position = position
    road.set_surface_override_material(0, material)
    add_child(road)

func _add_building(position: Vector3, size: Vector3, color: Color) -> void:
    var body := StaticBody3D.new()
    body.position = position
    var collision := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = size
    collision.shape = box_shape
    body.add_child(collision)
    var mesh_instance := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = size
    mesh_instance.mesh = box_mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.8
    mesh_instance.set_surface_override_material(0, material)
    body.add_child(mesh_instance)
    add_child(body)

func _spawn_vehicle() -> void:
    vehicle = VehicleDriver.new()
    vehicle.name = "PlayerVehicle"
    add_child(vehicle)
    vehicle.configure("van", Color(0.72, 0.18, 0.24))
    vehicle.position = Vector3(0.0, 1.1, -1770.0)
    vehicle.rotation_degrees.y = 180.0

func _build_checkpoints() -> void:
    var route: Array[Vector3] = [
        Vector3(0.0, 1.5, -1500.0), Vector3(200.0, 1.5, -1200.0),
        Vector3(450.0, 1.5, -900.0), Vector3(650.0, 1.5, -550.0),
        Vector3(400.0, 1.5, -200.0), Vector3(0.0, 1.5, 150.0),
        Vector3(-350.0, 1.5, 450.0), Vector3(-700.0, 1.5, 850.0),
        Vector3(-300.0, 1.5, 1200.0), Vector3(200.0, 1.5, 1500.0)
    ]
    for point in route:
        var checkpoint := Node3D.new()
        checkpoint.position = point
        add_child(checkpoint)
        var ring := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.major_radius = 10.0
        torus.minor_radius = 0.7
        ring.mesh = torus
        ring.rotation_degrees.x = 90.0
        var glow := StandardMaterial3D.new()
        glow.albedo_color = Color(0.15, 1.0, 0.72, 0.7)
        glow.emission_enabled = true
        glow.emission = Color(0.18, 1.0, 0.82)
        glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        ring.set_surface_override_material(0, glow)
        checkpoint.add_child(ring)
        var beam := MeshInstance3D.new()
        var beam_mesh := BoxMesh.new()
        beam_mesh.size = Vector3(0.6, 12.0, 16.0)
        beam.mesh = beam_mesh
        beam.set_surface_override_material(0, glow)
        checkpoint.add_child(beam)
        checkpoints.append(checkpoint)

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "HUD"
    add_child(canvas)
    speed_label = _make_label(canvas, Vector2(24, 22), 28, "0 km/h")
    gear_label = _make_label(canvas, Vector2(24, 58), 18, "Gear 1")
    timer_label = _make_label(canvas, Vector2(24, 86), 18, "00:00.0")
    _make_label(canvas, Vector2(24, 116), 16, "CHECKPOINT")
    var checkpoint_label := _make_label(canvas, Vector2(24, 138), 18, "1 / 10")
    vehicle.ui_checkpoint = checkpoint_label
    finish_label = _make_label(canvas, Vector2(440, 220), 32, "RUN COMPLETE — Enter to restart")
    finish_label.visible = false
    var help := _make_label(canvas, Vector2(390, 18), 16, "W/S throttle  A/D steer  Space handbrake  C camera  V vehicle  T time  M map  R recover  Enter restart")
    help.modulate = Color(1.0, 1.0, 1.0, 0.92)

func _make_label(parent: Control, pos: Vector2, size: int, text_value: String) -> Label:
    var label := Label.new()
    label.position = pos
    label.add_theme_font_size_override("font_size", size)
    label.text = text_value
    parent.add_child(label)
    return label

func _build_minimap() -> void:
    minimap_viewport = SubViewport.new()
    minimap_viewport.size = Vector2i(200, 200)
    minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    minimap_viewport.world_3d = get_world_3d()
    add_child(minimap_viewport)
    minimap_camera = Camera3D.new()
    minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    minimap_camera.size = 900.0
    minimap_camera.current = true
    minimap_viewport.add_child(minimap_camera)
    var canvas := get_node("HUD") as CanvasLayer
    var panel := Panel.new()
    panel.position = Vector2(20, 650)
    panel.size = Vector2(210, 210)
    canvas.add_child(panel)
    minimap_texture = TextureRect.new()
    minimap_texture.position = Vector2(5, 5)
    minimap_texture.size = Vector2(200, 200)
    minimap_texture.texture = minimap_viewport.get_texture()
    panel.add_child(minimap_texture)

func _set_time_cycle(index: int) -> void:
    cycle_index = index
    var sky_colors := [Color(0.65, 0.76, 0.95), Color(0.96, 0.6, 0.44), Color(0.10, 0.15, 0.28)]
    var fog_colors := [Color(0.55, 0.66, 0.8), Color(0.72, 0.53, 0.42), Color(0.08, 0.10, 0.15)]
    var energies := [1.2, 0.8, 0.15]
    var ambient := [1.0, 0.75, 0.25]
    world_environment.environment.background_color = sky_colors[index]
    world_environment.environment.fog_light_color = fog_colors[index]
    world_environment.environment.ambient_light_color = sky_colors[index]
    world_environment.environment.ambient_light_energy = ambient[index]
    sun.light_energy = energies[index]

func _process(delta: float) -> void:
    if vehicle == null:
        return
    if not finished:
        elapsed_time += delta
        var target := checkpoints[next_checkpoint_index]
        if vehicle.global_position.distance_to(target.global_position) < 18.0:
            next_checkpoint_index += 1
            if next_checkpoint_index >= checkpoints.size():
                finished = true
                finish_label.visible = true
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
        var target_index := min(next_checkpoint_index, checkpoints.size() - 1)
        vehicle.global_position = checkpoints[target_index].global_position + Vector3(0.0, 1.0, 0.0)
        vehicle.rotation_degrees.y = 180.0
        vehicle.linear_velocity = Vector3.ZERO
        vehicle.angular_velocity = Vector3.ZERO
    if Input.is_action_just_pressed("restart"):
        get_tree().reload_current_scene()
    _update_hud()
    _update_camera(delta)
    _update_minimap()

func _update_hud() -> void:
    speed_label.text = "%d km/h" % int(vehicle.linear_velocity.length() * 3.6)
    gear_label.text = "Gear %d" % vehicle.current_gear
    timer_label.text = "%02d:%05.1f" % [int(elapsed_time / 60.0), fmod(elapsed_time, 60.0)]
    vehicle.ui_checkpoint.text = "%d / %d" % [min(next_checkpoint_index + 1, checkpoints.size()), checkpoints.size()]

func _update_camera(delta: float) -> void:
    if camera == null:
        camera = Camera3D.new()
        camera.current = true
        add_child(camera)
    var forward := -vehicle.global_transform.basis.z
    var target := vehicle.global_position + Vector3(0.0, 1.5, 0.0)
    var desired: Vector3
    if camera_mode == 0:
        desired = vehicle.global_position - forward * 9.0 + Vector3(0.0, 4.5, 0.0)
    elif camera_mode == 1:
        desired = vehicle.global_position - forward * 1.2 + Vector3(0.0, 2.3, 0.0)
    else:
        desired = vehicle.global_position + Vector3(0.0, 20.0, 0.0)
    camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-delta * 5.0))
    camera.look_at(target + (forward * 18.0 if camera_mode == 1 else Vector3.ZERO), Vector3.UP)
    camera.fov = lerp(70.0, 92.0, clamp(vehicle.linear_velocity.length() / 35.0, 0.0, 1.0))

func _update_minimap() -> void:
    if minimap_camera == null:
        return
    minimap_camera.global_position = Vector3(vehicle.global_position.x, 280.0, vehicle.global_position.z)
    minimap_camera.look_at(vehicle.global_position, Vector3.FORWARD)
    minimap_texture.texture = minimap_viewport.get_texture()

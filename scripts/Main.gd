extends Node3D

const WORLD_SIZE := 4000.0
const ROAD_WIDTH := 24.0
const CHECKPOINT_SPACING := 300.0
const CITY_HALF := 1800.0

var rng := RandomNumberGenerator.new()
var vehicle: VehicleDriver
var camera_node: Camera3D
var chase_mode := 0
var minimap_camera: Camera3D
var minimap_viewport: SubViewport
var minimap_texture: TextureRect
var target_checkpoint_index := 0
var checkpoint_nodes: Array[Node3D] = []
var route_points: Array[Vector3] = []
var checkpoint_root: Node3D
var hud_root: CanvasLayer
var timer_started := 0.0
var finish_screen_visible := false
var phase_index := 0
var cycle_time := 0.0
var vehicle_kind := "van"

@onready var sun: DirectionalLight3D = DirectionalLight3D.new()
@onready var sky_color := Color(0.57, 0.68, 0.92)

func _ready() -> void:
    rng.randomize()
    _install_input_actions()
    _build_environment()
    _build_city()
    _spawn_vehicle()
    _build_minimap()
    _build_hud()
    _build_checkpoint_route()
    _place_player()
    _apply_time_cycle(0)

func _install_input_actions() -> void:
    for action_name in [
        "move_forward","move_backward","turn_left","turn_right","brake",
        "handbrake","camera_change","switch_vehicle","repaint","time_cycle",
        "toggle_minimap","recover","restart","help"
    ]:
        if not InputMap.has_action(action_name):
            InputMap.add_action(action_name)

    _bind_key("move_forward", KEY_W)
    _bind_key("move_forward", KEY_UP)
    _bind_key("move_backward", KEY_S)
    _bind_key("move_backward", KEY_DOWN)
    _bind_key("turn_left", KEY_A)
    _bind_key("turn_left", KEY_LEFT)
    _bind_key("turn_right", KEY_D)
    _bind_key("turn_right", KEY_RIGHT)
    _bind_key("brake", KEY_SPACE)
    _bind_key("handbrake", KEY_SPACE)
    _bind_key("camera_change", KEY_C)
    _bind_key("switch_vehicle", KEY_V)
    _bind_key("repaint", KEY_P)
    _bind_key("time_cycle", KEY_T)
    _bind_key("toggle_minimap", KEY_M)
    _bind_key("recover", KEY_R)
    _bind_key("restart", KEY_ENTER)
    _bind_key("help", KEY_H)

func _bind_key(action_name: String, key_code: int) -> void:
    var ev := InputEventKey.new()
    ev.physical_keycode = key_code
    ev.keycode = key_code
    InputMap.action_add_event(action_name, ev)

func _build_environment() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.63, 0.75, 0.93)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(1.0, 1.0, 1.0)
    environment.ambient_light_energy = 1.0
    environment.tonemap_mode = Environment.TONE_MAPPER_ACES
    environment.fog_enabled = true
    environment.fog_density = 0.006
    environment.fog_light_color = Color(0.53, 0.60, 0.68)
    environment.fog_aerial_perspective = 0.1

    var world_env := WorldEnvironment.new()
    world_env.environment = environment
    add_child(world_env)

    sun.light_energy = 1.4
    sun.rotation_degrees = Vector3(-30, 35, 0)
    sun.shadow_enabled = true
    add_child(sun)

    var ground := MeshInstance3D.new()
    var ground_mesh := BoxMesh.new()
    ground_mesh.size = Vector3(WORLD_SIZE, 0.4, WORLD_SIZE)
    ground.mesh = ground_mesh
    ground.position = Vector3(0.0, -0.2, 0.0)
    var ground_mat := StandardMaterial3D.new()
    ground_mat.albedo_color = Color(0.12, 0.25, 0.18)
    ground_mat.roughness = 1.0
    ground.set_surface_override_material(0, ground_mat)
    add_child(ground)

    var floor_body := StaticBody3D.new()
    floor_body.name = "WorldFloor"
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(WORLD_SIZE, 0.4, WORLD_SIZE)
    shape.shape = box
    floor_body.add_child(shape)
    add_child(floor_body)

func _build_city() -> void:
    var road_material := StandardMaterial3D.new()
    road_material.albedo_color = Color(0.12, 0.12, 0.13)
    road_material.roughness = 0.95

    for x in range(-1800, 1801, 180):
        var road := MeshInstance3D.new()
        var road_mesh := BoxMesh.new()
        road_mesh.size = Vector3(ROAD_WIDTH, 0.08, WORLD_SIZE)
        road.mesh = road_mesh
        road.position = Vector3(float(x), 0.08, 0.0)
        road.set_surface_override_material(0, road_material)
        add_child(road)

    for z in range(-1800, 1801, 180):
        var road := MeshInstance3D.new()
        var road_mesh := BoxMesh.new()
        road_mesh.size = Vector3(WORLD_SIZE, 0.08, ROAD_WIDTH)
        road.mesh = road_mesh
        road.position = Vector3(0.0, 0.08, float(z))
        road.set_surface_override_material(0, road_material)
        add_child(road)

    for x in range(-1500, 1501, 200):
        for z in range(-1500, 1501, 200):
            if abs(x) < 160 and abs(z) < 160:
                continue
            var dist := Vector2(x, z).length()
            if dist < 180.0:
                continue
            var h := 10.0 + (1.0 - clamp(dist / 2200.0, 0.0, 1.0)) * 52.0 + rng.randf_range(0.0, 18.0)
            if rng.randf() < 0.08:
                h += 38.0
            var width := rng.randf_range(18.0, 42.0)
            var depth := rng.randf_range(18.0, 42.0)
            _create_building(Vector3(float(x) + rng.randf_range(-16.0, 16.0), h * 0.5, float(z) + rng.randf_range(-16.0, 16.0)), Vector3(width, h, depth))

    var grass_material := StandardMaterial3D.new()
    grass_material.albedo_color = Color(0.18, 0.48, 0.21)
    grass_material.roughness = 1.0
    for edge in [
        Vector3(0.0, 0.05, -2200.0),
        Vector3(0.0, 0.05, 2200.0),
        Vector3(-2200.0, 0.05, 0.0),
        Vector3(2200.0, 0.05, 0.0)
    ]:
        var strip := MeshInstance3D.new()
        var strip_mesh := BoxMesh.new()
        strip_mesh.size = Vector3(4300.0, 0.2, 110.0)
        if abs(edge.x) > 0.1:
            strip_mesh.size = Vector3(110.0, 0.2, 4300.0)
        strip.mesh = strip_mesh
        strip.position = edge
        strip.set_surface_override_material(0, grass_material)
        add_child(strip)

func _create_building(position: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    var collision := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = size
    collision.shape = box_shape
    body.add_child(collision)

    var mesh := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = size
    mesh.mesh = box_mesh
    mesh.position = Vector3(0.0, size.y * 0.5, 0.0)

    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color.from_hsv(0.1 + rng.randf_range(0.0, 0.08), 0.25, 0.75)
    mat.roughness = 0.82
    mat.metallic = 0.18
    mat.emission_enabled = true
    mat.emission = Color(0.07, 0.08, 0.1) * 0.2
    mesh.set_surface_override_material(0, mat)

    body.add_child(mesh)
    body.position = position
    body.rotation_degrees = Vector3(0.0, rng.randf_range(0.0, 180.0), 0.0)
    add_child(body)

func _spawn_vehicle() -> void:
    vehicle = VehicleDriver.new()
    vehicle.name = "PlayerVehicle"
    add_child(vehicle)
    vehicle.position = Vector3(0.0, 1.0, 1200.0)
    vehicle.rotation_degrees.y = 180.0
    vehicle.configure(vehicle_kind, Color(0.68, 0.18, 0.22))
    vehicle.call_deferred("set_process", true)

func _build_minimap() -> void:
    minimap_viewport = SubViewport.new()
    minimap_viewport.size = Vector2i(256, 256)
    minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    minimap_viewport.transparent_bg = true
    minimap_viewport.usage = SubViewport.USAGE_3D
    minimap_viewport.disable_3d = false
    add_child(minimap_viewport)

    minimap_camera = Camera3D.new()
    minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    minimap_camera.size = 2200.0
    minimap_camera.position = Vector3(0.0, 2200.0, 0.0)
    minimap_camera.rotation_degrees.x = -90.0
    minimap_viewport.add_child(minimap_camera)

    var minimap_root := Node3D.new()
    minimap_root.name = "MinimapRoot"
    minimap_viewport.add_child(minimap_root)

    var world_dup := Node3D.new()
    world_dup.name = "CityCopy"
    minimap_root.add_child(world_dup)

    var map_mat := StandardMaterial3D.new()
    map_mat.albedo_color = Color(0.13, 0.17, 0.20)
    map_mat.roughness = 1.0

    for child in get_children():
        if child is MeshInstance3D:
            var duplicate := MeshInstance3D.new()
            duplicate.mesh = child.mesh
            duplicate.position = child.position
            duplicate.rotation = child.rotation
            duplicate.set_surface_override_material(0, map_mat)
            world_dup.add_child(duplicate)

    var marker_mesh := BoxMesh.new()
    marker_mesh.size = Vector3(20.0, 10.0, 30.0)
    var marker := MeshInstance3D.new()
    marker.mesh = marker_mesh
    marker.position = Vector3(0.0, 5.0, 0.0)
    var marker_mat := StandardMaterial3D.new()
    marker_mat.albedo_color = Color(0.96, 0.32, 0.22)
    marker.set_surface_override_material(0, marker_mat)
    minimap_root.add_child(marker)

    hud_root = CanvasLayer.new()
    add_child(hud_root)

    var map_panel := Panel.new()
    map_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
    map_panel.size_flags_vertical = Control.SIZE_SHRINK_END
    map_panel.custom_minimum_size = Vector2(180, 180)
    map_panel.position = Vector2(20, 20)
    hud_root.add_child(map_panel)

    var cycle := StyleBoxFlat.new()
    cycle.bg_color = Color(0.06, 0.09, 0.14, 0.65)
    cycle.border_color = Color(0.7, 0.8, 1.0, 0.65)
    cycle.border_width_left = 2
    cycle.border_width_top = 2
    cycle.border_width_right = 2
    cycle.border_width_bottom = 2
    cycle.corner_radius_top_left = 90
    cycle.corner_radius_top_right = 90
    cycle.corner_radius_bottom_left = 90
    cycle.corner_radius_bottom_right = 90
    map_panel.add_theme_stylebox_override("panel", cycle)

    minimap_texture = TextureRect.new()
    minimap_texture.texture = minimap_viewport.get_texture()
    minimap_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    minimap_texture.size_flags_horizontal = Control.SIZE_FILL
    minimap_texture.size_flags_vertical = Control.SIZE_FILL
    minimap_texture.position = Vector2(10, 10)
    minimap_texture.custom_minimum_size = Vector2(160, 160)
    minimap_texture.ignore_texture_size = false
    minimap_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    map_panel.add_child(minimap_texture)

func _build_hud() -> void:
    var hud := CanvasLayer.new()
    add_child(hud)

    var label_speed := Label.new()
    label_speed.position = Vector2(20, 20)
    label_speed.add_theme_font_size_override("font_size", 28)
    label_speed.text = "0 km/h"
    label_speed.modulate = Color(1, 1, 1, 1)
    hud.add_child(label_speed)

    var label_gear := Label.new()
    label_gear.position = Vector2(20, 60)
    label_gear.add_theme_font_size_override("font_size", 18)
    label_gear.text = "Gear 1"
    hud.add_child(label_gear)

    var label_clock := Label.new()
    label_clock.position = Vector2(20, 90)
    label_clock.add_theme_font_size_override("font_size", 18)
    label_clock.text = "00:00.0"
    hud.add_child(label_clock)

    var label_checkpoint := Label.new()
    label_checkpoint.position = Vector2(20, 120)
    label_checkpoint.add_theme_font_size_override("font_size", 18)
    label_checkpoint.text = "Checkpoint 1/10"
    hud.add_child(label_checkpoint)

    var arrow := Label.new()
    arrow.position = Vector2(1600, 80)
    arrow.rotation = 0.0
    arrow.add_theme_font_size_override("font_size", 48)
    arrow.text = "↑"
    hud.add_child(arrow)

    var help := Label.new()
    help.position = Vector2(600, 20)
    help.text = "WASD steer / throttle  C camera  V switch vehicle  T cycle time  M minimap  R recover  H help"
    help.modulate = Color(1, 1, 1, 0.9)
    hud.add_child(help)

    var finish := Panel.new()
    finish.position = Vector2(500, 180)
    finish.size = Vector2(600, 220)
    finish.visible = false
    var finish_box := StyleBoxFlat.new()
    finish_box.bg_color = Color(0.04, 0.05, 0.07, 0.8)
    finish_box.border_color = Color(0.9, 0.9, 1.0, 0.9)
    finish_box.border_width_left = 2
    finish_box.border_width_top = 2
    finish_box.border_width_right = 2
    finish_box.border_width_bottom = 2
    finish.add_theme_stylebox_override("panel", finish_box)
    hud.add_child(finish)

    var finish_label := Label.new()
    finish_label.position = Vector2(40, 30)
    finish_label.text = "Run Complete"
    finish_label.add_theme_font_size_override("font_size", 28)
    finish.add_child(finish_label)

    var finish_time_label := Label.new()
    finish_time_label.position = Vector2(40, 90)
    finish_time_label.text = "00:00.0"
    finish_time_label.add_theme_font_size_override("font_size", 22)
    finish.add_child(finish_time_label)

    var finish_hint := Label.new()
    finish_hint.position = Vector2(40, 140)
    finish_hint.text = "Press Enter to restart"
    finish_hint.add_theme_font_size_override("font_size", 18)
    finish.add_child(finish_hint)

    vehicle.hud = {
        "speed": label_speed,
        "gear": label_gear,
        "clock": label_clock,
        "checkpoint": label_checkpoint,
        "arrow": arrow,
        "finish": finish,
        "finish_time": finish_time_label,
        "help": help
    }

func _build_checkpoint_route() -> void:
    checkpoint_root = Node3D.new()
    checkpoint_root.name = "Checkpoints"
    add_child(checkpoint_root)

    route_points = []
    var center_x := 0.0
    var center_z := -1500.0
    for i in range(10):
        var x := center_x + (i % 2) * 240.0 - 120.0
        var z := center_z + float(i) * CHECKPOINT_SPACING
        route_points.append(Vector3(x, 0.0, z))
        if i >= 2 and i < 7:
            x = 260.0 + float(i - 2) * 160.0
            z = -1200.0 + float(i) * 180.0
            route_points.append(Vector3(x, 0.0, z))
        if i == 8:
            route_points.append(Vector3(0.0, 0.0, 1300.0))

    while route_points.size() > 10:
        route_points.remove_at(route_points.size() - 1)

    for i in range(route_points.size()):
        var p := route_points[i]
        var checkpoint := Node3D.new()
        checkpoint.position = p + Vector3(0.0, 2.0, 0.0)
        checkpoint_root.add_child(checkpoint)

        var ring := MeshInstance3D.new()
        var ring_mesh := TorusMesh.new()
        ring_mesh.major_radius = 8.0
        ring_mesh.minor_radius = 0.7
        ring_mesh.rings = 24
        ring_mesh.radial_segments = 32
        ring.mesh = ring_mesh
        ring.rotation_degrees.x = 90.0
        ring.get_node_or_null("")

        var beam := MeshInstance3D.new()
        var beam_mesh := BoxMesh.new()
        beam_mesh.size = Vector3(0.5, 14.0, 12.0)
        beam.mesh = beam_mesh
        beam.position = Vector3(0.0, 4.0, 0.0)

        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.22, 1.0, 0.72, 0.55)
        mat.emission_enabled = true
        mat.emission = Color(0.22, 1.0, 0.72)
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        beam.set_surface_override_material(0, mat)
        ring.set_surface_override_material(0, mat)

        checkpoint.add_child(beam)
        checkpoint.add_child(ring)
        checkpoint_nodes.append(checkpoint)

func _place_player() -> void:
    var start := route_points[0] + Vector3(0.0, 1.0, 0.0)
    vehicle.position = start
    vehicle.rotation_degrees.y = 180.0
    target_checkpoint_index = 0

func _process(delta: float) -> void:
    if vehicle == null:
        return

    var next_position = route_points[target_checkpoint_index]
    if vehicle.global_position.distance_to(next_position) < 25.0:
        target_checkpoint_index += 1
        if target_checkpoint_index >= checkpoint_nodes.size():
            _show_finish_screen()
            return

    if Input.is_action_just_pressed("camera_change"):
        chase_mode = (chase_mode + 1) % 3

    if Input.is_action_just_pressed("switch_vehicle"):
        vehicle_kind = "bus" if vehicle_kind == "van" else "van"
        vehicle.configure(vehicle_kind, Color(0.18, 0.42, 0.77) if vehicle_kind == "bus" else Color(0.68, 0.18, 0.22))

    if Input.is_action_just_pressed("time_cycle"):
        phase_index = (phase_index + 1) % 3
        _apply_time_cycle(phase_index)

    if Input.is_action_just_pressed("toggle_minimap"):
        minimap_texture.visible = not minimap_texture.visible

    if Input.is_action_just_pressed("recover"):
        vehicle.global_position = route_points[max(0, target_checkpoint_index)] + Vector3(0.0, 1.0, 0.0)
        vehicle.linear_velocity = Vector3.ZERO
        vehicle.angular_velocity = Vector3.ZERO

    if Input.is_action_just_pressed("restart"):
        get_tree().reload_current_scene()

    if Input.is_action_just_pressed("repaint"):
        var colors := [
            Color(0.92, 0.25, 0.25),
            Color(0.28, 0.70, 0.80),
            Color(0.95, 0.78, 0.25),
            Color(0.52, 0.82, 0.41),
            Color(0.88, 0.88, 0.95)
        ]
        var next_color := colors[randi() % colors.size()]
        vehicle.configure(vehicle_kind, next_color)

    _update_hud()
    _update_camera(delta)
    _update_minimap()

func _update_hud() -> void:
    if vehicle == null or vehicle.hud == null:
        return

    var speed := abs(vehicle.linear_velocity.length() * 3.6)
    var gear := int(clamp(floor(speed / 8.0), 1.0, 5.0))
    if speed < 1.0:
        gear = 1

    var gear_name := str(gear)
    vehicle.hud["speed"].text = str(int(speed)) + " km/h"
    vehicle.hud["gear"].text = "Gear " + gear_name
    var elapsed := Time.get_ticks_msec() * 0.001
    if timer_started <= 0.0:
        timer_started = elapsed
    var elapsed_time := elapsed - timer_started
    vehicle.hud["clock"].text = "%02d:%05.1f" % [int(elapsed_time / 60.0), fmod(elapsed_time, 60.0)]

    var target = route_points[target_checkpoint_index]
    var direction := (target - vehicle.global_position)
    var angle := atan2(direction.x, direction.z)
    vehicle.hud["arrow"].rotation = -angle
    vehicle.hud["checkpoint"].text = "Checkpoint %d/%d" % [target_checkpoint_index + 1, checkpoint_nodes.size()]

    if finish_screen_visible:
        vehicle.hud["finish"].visible = true
        vehicle.hud["finish_time"].text = vehicle.hud["clock"].text

func _update_camera(delta: float) -> void:
    if camera_node == null:
        camera_node = Camera3D.new()
        camera_node.current = true
        add_child(camera_node)

    var forward := -vehicle.global_transform.basis.z
    var target_position := vehicle.global_position + Vector3(0.0, 2.2, 0.0)
    var desired_offset := Vector3.ZERO

    if chase_mode == 0:
        desired_offset = Vector3(0.0, 3.5, 8.5)
    elif chase_mode == 1:
        desired_offset = Vector3(0.0, 2.6, 0.8)
    else:
        desired_offset = Vector3(0.0, 11.0, 0.0)

    if chase_mode == 0:
        var chase_pos := vehicle.global_position - forward * 9.0 + Vector3(0.0, 4.8, 0.0)
        var ray := PhysicsRayQueryParameters3D.create(chase_pos, target_position)
        ray.collide_with_areas = false
        ray.collide_with_bodies = true
        var hit := get_world_3d().direct_space_state.intersect_ray(ray)
        if hit.size() > 0:
            chase_pos = hit["position"] + (target_position - chase_pos).normalized() * 1.5
        camera_node.global_position = camera_node.global_position.lerp(chase_pos, 1.0 - exp(-delta * 4.0))
        camera_node.look_at(target_position, Vector3.UP)
    elif chase_mode == 1:
        var cabin_pos := vehicle.global_position + Vector3(0.0, 2.4, 0.0) - (forward * 2.0)
        camera_node.global_position = camera_node.global_position.lerp(cabin_pos, 1.0 - exp(-delta * 5.0))
        camera_node.look_at(vehicle.global_position + forward * 20.0 + Vector3(0.0, 1.0, 0.0), Vector3.UP)
    else:
        var high_pos := vehicle.global_position + Vector3(0.0, 25.0, 0.0)
        camera_node.global_position = camera_node.global_position.lerp(high_pos, 1.0 - exp(-delta * 3.0))
        camera_node.look_at(target_position, Vector3.UP)

    var speed_factor := clamp(vehicle.linear_velocity.length() / 40.0, 0.0, 1.5)
    camera_node.fov = lerp(70.0, 95.0, speed_factor)

func _update_minimap() -> void:
    if minimap_camera == null or minimap_viewport == null:
        return

    minimap_camera.global_position = Vector3(vehicle.global_position.x, 240.0, vehicle.global_position.z)
    minimap_camera.look_at(Vector3(vehicle.global_position.x, 0.0, vehicle.global_position.z), Vector3.UP)
    minimap_texture.texture = minimap_viewport.get_texture()

func _show_finish_screen() -> void:
    finish_screen_visible = true
    if vehicle.hud != null:
        vehicle.hud["finish"].visible = true

func _apply_time_cycle(index: int) -> void:
    var presets := [
        {"sky": Color(0.65, 0.73, 0.92), "sun_energy": 1.4, "ambient": 1.0, "fog": Color(0.5, 0.6, 0.7), "headlights": 0.0, "window_lights": 0.0},
        {"sky": Color(0.95, 0.62, 0.42), "sun_energy": 0.85, "ambient": 0.75, "fog": Color(0.7, 0.52, 0.38), "headlights": 0.12, "window_lights": 0.2},
        {"sky": Color(0.12, 0.16, 0.30), "sun_energy": 0.15, "ambient": 0.2, "fog": Color(0.05, 0.09, 0.12), "headlights": 0.9, "window_lights": 1.0}
    ]
    var preset = presets[index]
    var env: Environment = get_node("WorldEnvironment").environment
    env.background_color = preset["sky"]
    env.background_energy_multiplier = 1.0
    env.fog_enabled = true
    env.fog_light_color = preset["fog"]
    env.ambient_light_color = preset["sky"]
    env.ambient_light_energy = preset["ambient"]
    sun.light_energy = preset["sun_energy"]
    sun.rotation_degrees = Vector3(-35.0 + float(index) * 11.0, 35.0, 0.0)
    if vehicle != null:
        vehicle.set_day_phase(preset)

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("help"):
        var visible := vehicle.hud["help"].visible
        vehicle.hud["help"].visible = not visible

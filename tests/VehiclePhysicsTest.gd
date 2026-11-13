extends VehicleBody3D
class_name VehicleDriver

var hud = null
var vehicle_kind := "van"
var body_material: StandardMaterial3D
var rim_material: StandardMaterial3D
var front_wheels: Array[VehicleWheel3D] = []
var rear_wheels: Array[VehicleWheel3D] = []
var body_visual: MeshInstance3D
var roof_visual: MeshInstance3D
var body_color := Color(0.68, 0.18, 0.22)
var accent_color := Color(0.95, 0.95, 0.95)
var gear := 1
var current_phase := {"headlights": 0.0, "window_lights": 0.0}

func configure(kind: String, paint: Color) -> void:
    vehicle_kind = kind
    body_color = paint
    _apply_stats()
    _setup_vehicle_visuals()

func _ready() -> void:
    _apply_stats()
    _setup_wheels()
    _setup_vehicle_visuals()

func _apply_stats() -> void:
    if vehicle_kind == "bus":
        mass = 11000.0
        wheel_base = 5.6
        engine_force = 0.0
        brake = 0.0
        steering = 0.0
        center_of_mass = Vector3(0.0, 0.4, 0.0)
        linear_damp = 0.25
        angular_damp = 0.9
        max_speed = 30.0
        wheel_friction_slip = 2.0
    else:
        mass = 1800.0
        wheel_base = 2.8
        center_of_mass = Vector3(0.0, 0.3, 0.0)
        linear_damp = 0.22
        angular_damp = 0.75
        max_speed = 44.0
        wheel_friction_slip = 2.2

func _setup_wheels() -> void:
    for child in get_children():
        if child is VehicleWheel3D:
            child.queue_free()

    front_wheels.clear()
    rear_wheels.clear()

    var wheel_radius := 0.43
    var wheel_spacing_x := 1.45
    var wheel_spacing_z := 2.2
    if vehicle_kind == "bus":
        wheel_radius = 0.52
        wheel_spacing_x = 1.7
        wheel_spacing_z = 5.3

    for i in range(2):
        var front_wheel := VehicleWheel3D.new()
        front_wheel.name = "FrontWheel_%d" % i
        front_wheel.position = Vector3((-1.0 if i == 0 else 1.0) * wheel_spacing_x, wheel_radius + 0.12, -wheel_spacing_z)
        front_wheel.use_as_steering = true
        front_wheel.use_as_traction = false
        front_wheel.wheel_radius = wheel_radius
        front_wheel.suspension_stiffness = 30.0
        front_wheel.suspension_travel = 0.18
        front_wheel.damping_compression = 2.5
        front_wheel.damping_relaxation = 4.0
        front_wheel.friction_slip = wheel_friction_slip
        front_wheel.wheel_roll_influence = 0.08
        front_wheels.append(front_wheel)
        add_child(front_wheel)
        _build_wheel_mesh(front_wheel)

        var rear_wheel := VehicleWheel3D.new()
        rear_wheel.name = "RearWheel_%d" % i
        rear_wheel.position = Vector3((-1.0 if i == 0 else 1.0) * wheel_spacing_x, wheel_radius + 0.12, wheel_spacing_z)
        rear_wheel.use_as_steering = false
        rear_wheel.use_as_traction = true
        rear_wheel.wheel_radius = wheel_radius
        rear_wheel.suspension_stiffness = 30.0
        rear_wheel.suspension_travel = 0.18
        rear_wheel.damping_compression = 2.5
        rear_wheel.damping_relaxation = 4.0
        rear_wheel.friction_slip = wheel_friction_slip
        rear_wheel.wheel_roll_influence = 0.08
        rear_wheels.append(rear_wheel)
        add_child(rear_wheel)
        _build_wheel_mesh(rear_wheel)

func _build_wheel_mesh(wheel: VehicleWheel3D) -> void:
    var wheel_mesh := MeshInstance3D.new()
    var ring := CylinderMesh.new()
    ring.top_radius = 0.42
    ring.bottom_radius = 0.42
    ring.height = 0.32
    ring.radial_segments = 16
    wheel_mesh.mesh = ring
    wheel_mesh.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.08, 0.08, 0.08)
    material.roughness = 0.8
    material.metallic = 0.25
    wheel_mesh.set_surface_override_material(0, material)
    wheel.add_child(wheel_mesh)

func _setup_vehicle_visuals() -> void:
    var existing := get_node_or_null("VehicleVisualRoot")
    if existing != null:
        existing.queue_free()

    var root := Node3D.new()
    root.name = "VehicleVisualRoot"
    add_child(root)

    var body := MeshInstance3D.new()
    var body_box := BoxMesh.new()
    if vehicle_kind == "bus":
        body_box.size = Vector3(2.5, 2.1, 9.5)
    else:
        body_box.size = Vector3(2.2, 1.8, 4.6)
    body.mesh = body_box
    body.position = Vector3(0.0, 1.2, 0.0)
    body_material = StandardMaterial3D.new()
    body_material.albedo_color = body_color
    body_material.roughness = 0.7
    body_material.metallic = 0.18
    body.set_surface_override_material(0, body_material)
    root.add_child(body)

    var cab := MeshInstance3D.new()
    var cab_box := BoxMesh.new()
    cab_box.size = Vector3(1.8, 1.5, 1.1)
    cab.mesh = cab_box
    cab.position = Vector3(0.0, 1.8, -2.1)
    var cab_mat := StandardMaterial3D.new()
    cab_mat.albedo_color = accent_color
    cab_mat.roughness = 0.7
    cab.set_surface_override_material(0, cab_mat)
    root.add_child(cab)

    var roof := MeshInstance3D.new()
    var roof_box := BoxMesh.new()
    roof_box.size = Vector3(1.8, 0.3, 2.8)
    roof.mesh = roof_box
    roof.position = Vector3(0.0, 2.4, 0.0)
    roof_material = StandardMaterial3D.new()
    roof_material.albedo_color = Color(0.78, 0.82, 0.88)
    roof_material.roughness = 0.9
    roof.set_surface_override_material(0, roof_material)
    root.add_child(roof)

func set_day_phase(preset: Dictionary) -> void:
    current_phase = preset
    if body_material != null:
        body_material.emission_enabled = preset["window_lights"] > 0.5
        body_material.emission = Color(0.18, 0.2, 0.25) * preset["window_lights"]

func _physics_process(delta: float) -> void:
    var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
    var steer := Input.get_action_strength("turn_right") - Input.get_action_strength("turn_left")
    var brake_input := Input.get_action_strength("brake")
    var handbrake := Input.is_action_pressed("handbrake")
    var speed := linear_velocity.length()

    var lateral := abs(linear_velocity.dot(transform.basis.x.normalized()))
    var steer_limit := clamp(atan(lateral * wheel_base / max(speed * speed, 0.2)), 0.035, 0.42)

    for wheel in front_wheels:
        wheel.steering = steer * steer_limit
        wheel.brake = min(1.0, brake_input) * 0.15
    for wheel in rear_wheels:
        wheel.engine_force = -throttle * (1800.0 if vehicle_kind == "van" else 30000.0)
        wheel.brake = min(1.0, brake_input) * 0.8
        if handbrake:
            wheel.friction_slip = 0.9
        else:
            wheel.friction_slip = 2.2 if vehicle_kind == "van" else 2.0

    var is_near_stop := speed < 0.5
    if is_near_stop and throttle < 0.0 and brake_input > 0.0:
        for wheel in rear_wheels:
            wheel.engine_force = 1500.0

    if self.hud != null:
        var speed_kmh := abs(speed * 3.6)
        gear = int(clamp(speed_kmh / 8.0, 1.0, 5.0))
        self.hud["speed"].text = "%d km/h" % int(speed_kmh)
        self.hud["gear"].text = "Gear %d" % gear

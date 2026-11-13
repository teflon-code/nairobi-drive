extends VehicleBody3D
class_name VehicleDriver

const VAN_WHEELBASE := 2.8
const BUS_WHEELBASE := 5.6
const VAN_MAX_SPEED := 44.0
const BUS_MAX_SPEED := 30.0

var vehicle_kind := "van"
var front_wheels: Array[VehicleWheel3D] = []
var rear_wheels: Array[VehicleWheel3D] = []
var current_gear := 1
var ui_checkpoint: Label
var body_material: StandardMaterial3D
var wheel_friction := 2.2
var max_speed := VAN_MAX_SPEED
var _configured := false

func _ready() -> void:
    if not _configured:
        configure("van", Color(0.72, 0.18, 0.24))

func configure(kind: String, paint: Color) -> void:
    vehicle_kind = kind
    _apply_setup()
    _rebuild_visuals(paint)
    _rebuild_wheels()
    _configured = true

func switch_vehicle() -> void:
    if vehicle_kind == "van":
        configure("bus", Color(0.15, 0.4, 0.9))
    else:
        configure("van", Color(0.72, 0.18, 0.24))

func _apply_setup() -> void:
    var is_bus := vehicle_kind == "bus"
    mass = 11000.0 if is_bus else 1800.0
    center_of_mass = Vector3(0.0, 0.6, 0.0) if is_bus else Vector3(0.0, 0.3, 0.0)
    linear_damp = 0.18 if is_bus else 0.12
    angular_damp = 0.9 if is_bus else 0.75
    wheel_friction = 2.0 if is_bus else 2.2
    max_speed = BUS_MAX_SPEED if is_bus else VAN_MAX_SPEED

func _clear_children_named_or_wheels() -> void:
    for child in get_children():
        if child is VehicleWheel3D or child.name == "VehicleRoot":
            remove_child(child)
            child.free()
    front_wheels.clear()
    rear_wheels.clear()

func _rebuild_visuals(paint: Color) -> void:
    var root := get_node_or_null("VehicleRoot")
    if root != null:
        remove_child(root)
        root.free()
    root = Node3D.new()
    root.name = "VehicleRoot"
    add_child(root)

    var is_bus := vehicle_kind == "bus"
    var body_mesh := BoxMesh.new()
    body_mesh.size = Vector3(2.6, 2.1, 9.5) if is_bus else Vector3(2.2, 1.7, 4.6)
    var body := MeshInstance3D.new()
    body.name = "Body"
    body.mesh = body_mesh
    body.position.y = 1.25 if is_bus else 1.15
    body_material = StandardMaterial3D.new()
    body_material.albedo_color = paint
    body_material.metallic = 0.12
    body_material.roughness = 0.68
    body.set_surface_override_material(0, body_material)
    root.add_child(body)

    var glass_mesh := BoxMesh.new()
    glass_mesh.size = Vector3(2.0, 0.9, 0.06) if is_bus else Vector3(1.75, 0.85, 0.06)
    var glass := MeshInstance3D.new()
    glass.name = "FrontGlass"
    glass.mesh = glass_mesh
    glass.position = Vector3(0.0, 1.9, -4.7) if is_bus else Vector3(0.0, 1.7, -2.31)
    var glass_mat := StandardMaterial3D.new()
    glass_mat.albedo_color = Color(0.12, 0.22, 0.29)
    glass_mat.roughness = 0.18
    glass_mat.metallic = 0.3
    glass.set_surface_override_material(0, glass_mat)
    root.add_child(glass)

    var cab_mesh := BoxMesh.new()
    cab_mesh.size = Vector3(1.85, 1.25, 1.4) if not is_bus else Vector3(2.35, 1.7, 2.0)
    var cab := MeshInstance3D.new()
    cab.mesh = cab_mesh
    cab.position = Vector3(0.0, 1.75, -1.65) if not is_bus else Vector3(0.0, 2.05, -3.2)
    var cab_mat := StandardMaterial3D.new()
    cab_mat.albedo_color = Color(0.10, 0.19, 0.24)
    cab_mat.roughness = 0.2
    cab.set_surface_override_material(0, cab_mat)
    root.add_child(cab)

    var collision := CollisionShape3D.new()
    collision.name = "VehicleCollision"
    var shape := BoxShape3D.new()
    shape.size = Vector3(2.15, 1.45, 4.3) if not is_bus else Vector3(2.5, 1.9, 9.0)
    collision.shape = shape
    collision.position.y = 1.2 if not is_bus else 1.3
    add_child(collision)

    for z in [-1.0, 1.0]:
        var bumper := MeshInstance3D.new()
        var bumper_mesh := BoxMesh.new()
        bumper_mesh.size = Vector3(2.2, 0.18, 0.18) if not is_bus else Vector3(2.6, 0.22, 0.22)
        bumper.mesh = bumper_mesh
        bumper.position = Vector3(0.0, 0.45, z * (2.35 if not is_bus else 4.85))
        var bumper_mat := StandardMaterial3D.new()
        bumper_mat.albedo_color = Color(0.12, 0.12, 0.14)
        bumper.set_surface_override_material(0, bumper_mat)
        root.add_child(bumper)

func _rebuild_wheels() -> void:
    for child in get_children():
        if child is VehicleWheel3D:
            remove_child(child)
            child.free()
    front_wheels.clear()
    rear_wheels.clear()

    var is_bus := vehicle_kind == "bus"
    var radius := 0.52 if is_bus else 0.43
    var half_track := 1.0 if is_bus else 0.82
    var axle_z := 4.3 if is_bus else 1.35
    var rest_length := 0.22
    for side in [-1.0, 1.0]:
        var front := _make_wheel("Front", side, radius, half_track, -axle_z, rest_length, true)
        front_wheels.append(front)
        var rear := _make_wheel("Rear", side, radius, half_track, axle_z, rest_length, false)
        rear_wheels.append(rear)

func _make_wheel(label: String, side: float, radius: float, half_track: float, axle_z: float, rest_length: float, steering_wheel: bool) -> VehicleWheel3D:
    var wheel := VehicleWheel3D.new()
    wheel.name = "%sWheel_%s" % [label, "L" if side < 0.0 else "R"]
    wheel.position = Vector3(side * half_track, radius + rest_length * 0.75, axle_z)
    wheel.use_as_steering = steering_wheel
    wheel.use_as_traction = not steering_wheel
    wheel.wheel_radius = radius
    wheel.wheel_rest_length = rest_length
    wheel.suspension_travel = 0.18
    wheel.suspension_stiffness = 28.0 if vehicle_kind == "bus" else 32.0
    wheel.damping_compression = 3.2
    wheel.damping_relaxation = 4.5
    wheel.wheel_friction_slip = wheel_friction
    wheel.wheel_roll_influence = 0.08
    add_child(wheel)
    _attach_wheel_mesh(wheel, radius)
    return wheel

func _attach_wheel_mesh(wheel: VehicleWheel3D, radius: float) -> void:
    var mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = radius
    cylinder.bottom_radius = radius
    cylinder.height = 0.32
    cylinder.radial_segments = 20
    mesh.mesh = cylinder
    mesh.rotation_degrees.x = 90.0
    var rubber := StandardMaterial3D.new()
    rubber.albedo_color = Color(0.07, 0.07, 0.075)
    rubber.roughness = 0.9
    mesh.set_surface_override_material(0, rubber)
    wheel.add_child(mesh)

func _physics_process(_delta: float) -> void:
    var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
    var steering_input := Input.get_action_strength("turn_right") - Input.get_action_strength("turn_left")
    var brake_input := Input.get_action_strength("brake")
    var handbrake := Input.is_action_pressed("handbrake")
    var speed := linear_velocity.length()
    var wheelbase := BUS_WHEELBASE if vehicle_kind == "bus" else VAN_WHEELBASE
    var lateral_accel := 5.5 if vehicle_kind == "bus" else 9.0
    var max_steer := 0.32 if vehicle_kind == "bus" else 0.42
    var steer_limit := clamp(atan(lateral_accel * wheelbase / max(speed * speed, 0.25)), 0.035, max_steer)

    steering = steering_input * steer_limit
    brake = 60.0 if vehicle_kind == "van" else 300.0
    brake *= brake_input
    if handbrake:
        for wheel in rear_wheels:
            wheel.wheel_friction_slip = wheel_friction * 0.45
    else:
        for wheel in rear_wheels:
            wheel.wheel_friction_slip = wheel_friction

    var drive_force := 6400.0 if vehicle_kind == "van" else 30000.0
    if brake_input > 0.0 and speed < 0.6 and throttle < 0.0:
        engine_force = drive_force
    else:
        engine_force = -throttle * drive_force

    var forward_speed := abs(linear_velocity.dot(-global_transform.basis.z))
    if forward_speed > max_speed:
        var direction := linear_velocity.normalized()
        linear_velocity = direction * max_speed

    var downforce := clamp(forward_speed * 18.0, 0.0, 900.0 if vehicle_kind == "van" else 2200.0)
    apply_central_force(Vector3.DOWN * downforce)
    current_gear = clamp(int(forward_speed / (8.0 if vehicle_kind == "van" else 6.0)) + 1, 1, 5)


extends VehicleBody3D
class_name VehicleDriver

var vehicle_kind := "van"
var front_wheels: Array[VehicleWheel3D] = []
var rear_wheels: Array[VehicleWheel3D] = []
var current_gear := 1
var ui_checkpoint: Label
var body_material: StandardMaterial3D
var wheel_material: StandardMaterial3D

func _ready() -> void:
    configure("van", Color(0.72, 0.18, 0.24))

func configure(kind: String, paint: Color) -> void:
    vehicle_kind = kind
    _apply_setup(kind)
    _rebuild_visuals(paint)
    _rebuild_wheels()

func switch_vehicle() -> void:
    if vehicle_kind == "van":
        configure("bus", Color(0.15, 0.4, 0.9))
    else:
        configure("van", Color(0.72, 0.18, 0.24))

func _apply_setup(kind: String) -> void:
    mass = 1800.0 if kind == "van" else 11000.0
    center_of_mass = Vector3(0.0, 0.35, 0.0) if kind == "van" else Vector3(0.0, 0.6, 0.0)
    linear_damp = 0.20 if kind == "van" else 0.25
    angular_damp = 0.75 if kind == "van" else 0.9
    wheel_base = 2.8 if kind == "van" else 5.6
    wheel_friction_slip = 2.2 if kind == "van" else 2.0
    wheel_roll_influence = 0.08

func _rebuild_visuals(paint: Color) -> void:
    for child in get_children():
        if child.name == "VehicleRoot":
            child.queue_free()

    var root := Node3D.new()
    root.name = "VehicleRoot"
    add_child(root)

    var body_box := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    if vehicle_kind == "van":
        box_mesh.size = Vector3(2.2, 1.7, 4.6)
    else:
        box_mesh.size = Vector3(2.6, 2.1, 9.5)
    body_box.mesh = box_mesh
    body_box.position = Vector3(0.0, 1.3, 0.0)
    body_material = StandardMaterial3D.new()
    body_material.albedo_color = paint
    body_material.metallic = 0.12
    body_material.roughness = 0.7
    body_box.set_surface_override_material(0, body_material)
    root.add_child(body_box)

    var cab := MeshInstance3D.new()
    var cab_mesh := BoxMesh.new()
    cab_mesh.size = Vector3(1.8, 1.4, 1.4)
    cab.mesh = cab_mesh
    cab.position = Vector3(0.0, 1.8, -1.8)
    var cab_mat := StandardMaterial3D.new()
    cab_mat.albedo_color = Color(0.85, 0.91, 0.96)
    cab_mat.roughness = 0.7
    cab.set_surface_override_material(0, cab_mat)
    root.add_child(cab)

    var roof := MeshInstance3D.new()
    var roof_mesh := BoxMesh.new()
    roof_mesh.size = Vector3(1.9, 0.4, 2.8)
    roof.mesh = roof_mesh
    roof.position = Vector3(0.0, 2.55, 0.0)
    var roof_mat := StandardMaterial3D.new()
    roof_mat.albedo_color = Color(0.80, 0.82, 0.88)
    roof_mat.roughness = 0.8
    roof.set_surface_override_material(0, roof_mat)
    root.add_child(roof)

func _rebuild_wheels() -> void:
    for child in get_children():
        if child is VehicleWheel3D:
            child.queue_free()

    front_wheels.clear()
    rear_wheels.clear()

    var radius := 0.46 if vehicle_kind == "van" else 0.52
    var axle_width := 1.3 if vehicle_kind == "van" else 1.65
    var axle_length := 2.0 if vehicle_kind == "van" else 4.3

    for i in [-1.0, 1.0]:
        var front := VehicleWheel3D.new()
        front.name = "FrontWheel_%s" % ("L" if i < 0 else "R")
        front.position = Vector3(i * axle_width, radius + 0.1, -axle_length)
        front.use_as_steering = true
        front.wheel_radius = radius
        front.suspension_stiffness = 32.0
        front.suspension_travel = 0.18
        front.damping_compression = 3.0
        front.damping_relaxation = 4.0
        front.use_as_traction = false
        front.friction_slip = wheel_friction_slip
        front.wheel_roll_influence = wheel_roll_influence
        add_child(front)
        front_wheels.append(front)
        _attach_wheel_mesh(front, radius)

        var rear := VehicleWheel3D.new()
        rear.name = "RearWheel_%s" % ("L" if i < 0 else "R")
        rear.position = Vector3(i * axle_width, radius + 0.1, axle_length)
        rear.use_as_steering = false
        rear.wheel_radius = radius
        rear.suspension_stiffness = 32.0
        rear.suspension_travel = 0.18
        rear.damping_compression = 3.0
        rear.damping_relaxation = 4.0
        rear.use_as_traction = true
        rear.friction_slip = wheel_friction_slip
        rear.wheel_roll_influence = wheel_roll_influence
        add_child(rear)
        rear_wheels.append(rear)
        _attach_wheel_mesh(rear, radius)

func _attach_wheel_mesh(wheel: VehicleWheel3D, radius: float) -> void:
    var mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = radius
    cylinder.bottom_radius = radius
    cylinder.height = 0.35
    cylinder.radial_segments = 20
    mesh.mesh = cylinder
    mesh.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.08, 0.08, 0.08)
    mat.metallic = 0.25
    mat.roughness = 0.8
    mesh.set_surface_override_material(0, mat)
    wheel.add_child(mesh)

func _physics_process(delta: float) -> void:
    var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
    var steering_input := Input.get_action_strength("turn_right") - Input.get_action_strength("turn_left")
    var brake_input := Input.get_action_strength("brake")
    var handbrake := Input.is_action_pressed("handbrake")
    var speed := linear_velocity.length()
    var speed_limit := 44.0 if vehicle_kind == "van" else 30.0

    var lateral := abs(linear_velocity.dot(transform.basis.x.normalized()))
    var steer_limit := clamp(atan(lateral * wheel_base / max(speed * speed, 0.25)), 0.035, 0.42)

    for wheel in front_wheels:
        wheel.steering = steering_input * steer_limit
        wheel.brake = brake_input * 0.25

    for wheel in rear_wheels:
        wheel.engine_force = -throttle * (6200.0 if vehicle_kind == "van" else 26000.0)
        wheel.brake = brake_input * 0.65
        if handbrake:
            wheel.friction_slip = 0.9
        else:
            wheel.friction_slip = wheel_friction_slip

    if speed > speed_limit and throttle > 0.0:
        var normal := linear_velocity.normalized()
        linear_velocity = normal * speed_limit

    if abs(speed) < 0.5 and throttle < 0.0 and brake_input > 0.0:
        for wheel in rear_wheels:
            wheel.engine_force = 2000.0

    current_gear = clamp(int(speed_limit > 0.0 and speed > 0.1 ? speed / 10.0 : 1), 1, 5)

    if ui_checkpoint != null:
        ui_checkpoint.text = "Gear %d" % current_gear


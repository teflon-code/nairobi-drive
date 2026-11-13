extends SceneTree

const VehicleScript = preload("res://scripts/VehicleDriver.gd")

func _initialize() -> void:
    call_deferred("_run_test")

func _run_test() -> void:
    var root := Node3D.new()
    root.name = "PhysicsTestWorld"
    get_root().add_child(root)

    var floor_body := StaticBody3D.new()
    var floor_collision := CollisionShape3D.new()
    var floor_shape := BoxShape3D.new()
    floor_shape.size = Vector3(200.0, 1.0, 200.0)
    floor_collision.shape = floor_shape
    floor_body.add_child(floor_collision)
    floor_body.position.y = -0.5
    root.add_child(floor_body)

    var wall := StaticBody3D.new()
    var wall_collision := CollisionShape3D.new()
    var wall_shape := BoxShape3D.new()
    wall_shape.size = Vector3(80.0, 20.0, 1.0)
    wall_collision.shape = wall_shape
    wall.add_child(wall_collision)
    wall.position = Vector3(0.0, 10.0, -25.0)
    root.add_child(wall)

    var vehicle := VehicleScript.new()
    root.add_child(vehicle)
    vehicle.configure("van", Color(0.6, 0.2, 0.2))
    vehicle.position = Vector3(0.0, 1.0, 12.0)
    await process_frame
    await physics_frame

    var peak_speed := 0.0
    for frame in range(360):
        vehicle.engine_force = -6400.0
        vehicle.steering = 0.16 if frame < 180 else -0.16
        await physics_frame
        peak_speed = maxf(peak_speed, vehicle.linear_velocity.length())
    vehicle.engine_force = 0.0
    vehicle.steering = 0.0
    vehicle.brake = 60.0
    for frame in range(120):
        await physics_frame
    vehicle.brake = 0.0

    for frame in range(360):
        vehicle.engine_force = -6400.0
        await physics_frame
    vehicle.engine_force = 0.0
    for frame in range(30):
        await physics_frame

    var up_dot := vehicle.global_transform.basis.y.dot(Vector3.UP)
    var passed := true
    if peak_speed < 1.0:
        printerr("FAIL: vehicle did not accelerate (peak %.2f m/s)" % peak_speed)
        passed = false
    if vehicle.global_position.y < 0.25:
        printerr("FAIL: vehicle sank through the floor (y=%.2f)" % vehicle.global_position.y)
        passed = false
    if up_dot < 0.3:
        printerr("FAIL: vehicle rolled over (up dot %.2f)" % up_dot)
        passed = false
    if vehicle.global_position.z < -27.0:
        printerr("FAIL: vehicle penetrated the test wall (z=%.2f)" % vehicle.global_position.z)
        passed = false

    if passed:
        print("PASS: acceleration, steering, braking, floor, wall and rollover smoke checks")
        print("peak_speed=%.2f m/s final_y=%.2f final_z=%.2f up_dot=%.2f" % [peak_speed, vehicle.global_position.y, vehicle.global_position.z, up_dot])
        quit(0)
    else:
        quit(1)

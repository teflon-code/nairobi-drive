# Godot 4.3 headless vehicle test
extends SceneTree

func _init() -> void:
    print("Starting Nairobi Drive headless smoke test...")

    var root := Node3D.new()
    root.name = "Root"
    var world := Node3D.new()
    world.name = "World"
    root.add_child(world)

    var floor := StaticBody3D.new()
    var floor_shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(200.0, 1.0, 200.0)
    floor_shape.shape = box
    floor.add_child(floor_shape)
    floor.position = Vector3(0.0, -0.5, 0.0)
    root.add_child(floor)

    var vehicle := VehicleDriver.new()
    vehicle.configure("van", Color(0.7, 0.2, 0.2))
    vehicle.position = Vector3(0.0, 1.0, 12.0)
    vehicle.linear_velocity = Vector3(0.0, 0.0, 0.0)
    root.add_child(vehicle)

    var steps := 0
    var max_steps := 600
    while steps < max_steps:
        var throttle = 1.0
        var steer = 0.2
        for wheel in vehicle.front_wheels:
            wheel.steering = steer
            wheel.brake = 0.0
        for wheel in vehicle.rear_wheels:
            wheel.engine_force = -6200.0 * throttle
            wheel.brake = 0.0
        vehicle._physics_process(1.0 / 120.0)
        vehicle.global_position += Vector3(0.0, 0.0, -0.2)
        steps += 1

    var speed := vehicle.linear_velocity.length()
    print("Vehicle test results: steps=%d speed=%.2f m/s" % [steps, speed])
    if speed <= 0.0:
        printerr("Vehicle smoke test failed: no acceleration.")
        quit(1)
        return

    print("Smoke test passed.")
    quit()


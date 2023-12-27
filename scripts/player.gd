extends CharacterBody3D

# Objects and Nodes
@onready var camera_mount = $camera_mount
@onready var animation_player = $visuals/default_character_animations/AnimationPlayer
@onready var visuals = $visuals
@onready var ray_cast_3d = $RayCast3D
@onready var timer = $Timer
@onready var weapon_1 = $"visuals/default_character_animations/Armature | Mannequin_Boy/Skeleton3D/weapon_1"
@onready var weapon_2 = $"visuals/default_character_animations/Armature | Mannequin_Boy/Skeleton3D/weapon_2"


# Movement speed vars
var current_speed = 5.0

# Jumping vars
var jump_velocity = 5
var jumps = 0
var jumps_max = 2
var initial_jump_direction = Vector3.ZERO
var last_input_direction = Vector3.ZERO
var jump_buffer_timer = 0.0

# States
var running = false
var crouching = false
var jumping = false
var falling = false
var shooting = false
var melee_attacking = false 
var aiming = false

# Movement keys
var movement_actions = ["move_left", "move_right", "move_forwards", "move_backwards"]

# Mouse Sensitivity vars
var mouse_sens_horizontal = 0.35
var mouse_sens_vertical = 0.35

# Dashing vars
var dash_speed_air = 10.0
var dash_speed_ground = 40.0
var dash_timer = 0.0
var dash_timer_max = 1.0
var dash_vector = Vector2.ZERO
var is_dashing = false
var has_dashed = false

# Dashing Sequence vars
var key_sequence = []
var max_sequence_len = 2
var sequences = { 
	"dash_left": [65, 65],
	"dash_right": [68, 68],
	"das_forwards": [87, 87],
	"dash_backwards": [83, 83]
}

# Camera rotation
var hasRotated = false

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Lock mouse movement to screen
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Handle weapon visibility
	weapon_1.show()
	weapon_2.hide()
	#weapon_3.hide()

func _input(event):
	# Quit game on ESC
	if Input.is_action_just_pressed("settings"):
		get_tree().quit()

	# Handle front view
	if Input.is_action_just_pressed("front_view") and !hasRotated:
		camera_mount.rotate_y(-deg_to_rad(180))
		hasRotated = true
	elif Input.is_action_just_released("front_view") and hasRotated:
		camera_mount.rotate_y(-deg_to_rad(180))
		hasRotated = false

	# Handle mouse movement
	if event is InputEventMouseMotion: 
		rotate_y(-deg_to_rad(event.relative.x * mouse_sens_horizontal)) 
		camera_mount.rotate_x(-deg_to_rad(event.relative.y * mouse_sens_vertical))
		camera_mount.rotation.x = clamp(camera_mount.rotation.x, deg_to_rad(-60), deg_to_rad(60))

	# Handle key sequence | 2 inputs max
	if event is InputEventKey and !is_dashing:
		for action in movement_actions:
			if Input.is_action_just_pressed(action):
				key_sequence.append(event.keycode)
				timer.start()
				if key_sequence.size() > max_sequence_len:
					key_sequence.pop_at(0)
					if key_sequence.size() == 1:
						key_sequence.slice(0, event.keycode)

				print(key_sequence)

	# Handle weapon swaps
	if Input.is_action_just_pressed("weapon_1"):
		weapon_1.show()
		weapon_2.hide()
	elif Input.is_action_just_pressed("weapon_2"):
		weapon_1.hide()
		weapon_2.show()

func _physics_process(delta):

	# Handle character direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_forwards", "move_backwards")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Add the gravity.
	apply_gravity(delta)

	reset_variables()
	
	# Reset scene when character is >= -20 Y-Axis
	if position.y < -20:
		get_tree().reload_current_scene()

	# Crouching | PUT THIS INSIDE handle_character_movement() function
	if Input.is_action_pressed("crouch") && !is_dashing && !is_on_floor():
		handle_crouching()

	# Standing:
	elif !ray_cast_3d.is_colliding() && jumps <= 1:
		handle_character_dashing(input_dir, direction, delta)

	handle_character_movement(direction)
	handle_character_jumping(input_dir)
	handle_jump_buffer(delta)

	move_and_slide()





# ----------------- Handle Movement STARTS ----------------- #
func handle_character_movement(direction):
	# Moving
	if direction:
		# Running
		if !is_dashing:
			if is_on_floor():
				animation_player.play("melee_running", 0.3)
				velocity.x = direction.x * current_speed
				velocity.z = direction.z * current_speed
				#visuals.look_at(position + direction)

		# Dashing
		else:
			if !is_on_floor():
				has_dashed = true
				velocity.x = direction.x * dash_timer * dash_speed_air
				velocity.z = direction.z * dash_timer * dash_speed_air
			else:
				velocity.x = direction.x * dash_timer * dash_speed_ground
				velocity.z = direction.z * dash_timer * dash_speed_ground

	# Idle
	else:
		if is_on_floor() && !is_dashing:
			animation_player.play("melee_idle")
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)


# ----------------- Handle Jumping START ---------- #
func handle_character_jumping(input_dir):
	if is_on_floor() or jumps < jumps_max:
		if jump_buffer_timer > 0 && !is_dashing:
			jump_buffer_timer = 0
			velocity.y = jump_velocity
			jumps += 1
			animation_player.play("melee_jump")
			last_input_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			# Handle 2nd jump if no direction is applied
			if jumps == 1:
				initial_jump_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

			elif jumps == 2 and input_dir == Vector2.ZERO:
				if initial_jump_direction != Vector3.ZERO && !has_dashed:
					velocity.x = initial_jump_direction.x * jump_velocity
					velocity.z = initial_jump_direction.z * jump_velocity
				elif last_input_direction != Vector3.ZERO:
					velocity.x = last_input_direction.x * jump_velocity
					velocity.z = last_input_direction.z * jump_velocity

func handle_jump_buffer(delta):
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = 0.25
	jump_buffer_timer -= delta

# ------------------ Handle Crouching STARTS ------------------ #
func handle_crouching():
	# Add crouching logic here if needed
	pass


# ----------------- Handle Dashing STARTS ----------------- #
func handle_character_dashing(input_dir, _direction, delta):

	if is_dashing:
		_direction = (transform.basis * Vector3(dash_vector.x, 0, dash_vector.y)).normalized()

		# Handle dashing sequence
	for sequence in sequences.values():
		if key_sequence == sequence && !is_dashing:
			start_dashing(input_dir)
			key_sequence.clear()
		elif is_dashing:
			update_dash_timer(delta)
			if dash_timer <= 0:
				end_dashing()

func start_dashing(input_dir):
	is_dashing = true
	dash_timer = dash_timer_max
	dash_vector = input_dir
	print("dash begins")

func update_dash_timer(delta):
	dash_timer -= delta

func end_dashing():
	is_dashing = false
	print("dash ends")


# ----------------- Handle Variable Reseting STARTS --------------- #
func reset_variables():
	if is_on_floor():
		jumps = 0
		initial_jump_direction = Vector3.ZERO


# ----------------- Handle Gravity STARTS ----------------- #
func apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta


# ----------------- TIMERS --------------------- #
# Handle dashing sequence reset
func _on_timer_timeout():
	key_sequence.clear()


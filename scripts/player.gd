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
var jump_velocity = 4.5
var jumps = 0
var jumps_max = 2
var can_change_jump_direction = false
var initial_jump_direction = Vector3.ZERO

# Movement keys
var actions_to_check = ["move_left", "move_right", "move_forwards", "move_backwards"]

# Mouse Sensitivity vars
var mouse_sens_horizontal = 0.35
var mouse_sens_vertical = 0.35

# Dashing vars
var dash_speed = 10.0
var dash_timer = 0.0
var dash_timer_max = 1.0
var dash_vector = Vector2.ZERO
var is_dashing = false

# Dashing Sequence vars
var key_sequence = []
var max_sequence_len = 2
var sequences = { 
	"dash_left": [65, 65],
	"dash_right": [68, 68],
	"das_forwards": [87, 87],
	"dash_backwards": [83, 83]
}

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
	
	# Handle mouse movement
	if event is InputEventMouseMotion: 
		rotate_y(-deg_to_rad(event.relative.x * mouse_sens_horizontal)) 
		camera_mount.rotate_x(-deg_to_rad(event.relative.y * mouse_sens_vertical))
		camera_mount.rotation.x = clamp(camera_mount.rotation.x, deg_to_rad(-60), deg_to_rad(60))

	# Handle key sequence | 2 inputs max
	if event is InputEventKey:
		for action in actions_to_check:
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

	# Reset Variables
	reset_variables()
	
	# Reset scene when character is >= -20 Y-Axis
	if position.y < -20:
		get_tree().reload_current_scene()

	# Change second jump direction
	change_second_jump_direction()

	# Crouching
	if Input.is_action_pressed("crouch") && !is_dashing && !is_on_floor():
		handle_crouching()

	# Standing:
	elif !ray_cast_3d.is_colliding() && jumps <= 1:
		handle_dashing(input_dir, direction, delta)

	# Handle Movement logic
	character_movement(direction)

	# Handle Jumping logic
	handle_character_jumping(input_dir)

	move_and_slide()





# ----------------- Handle Movement STARTS ----------------- #
func character_movement(direction):
	# Moving
	if direction:
		if !is_dashing:
			if is_on_floor():
				animation_player.play("melee_running", 0.3)
		
			#visuals.look_at(position + direction)
			if is_on_floor() or can_change_jump_direction && !is_dashing:
				velocity.x = direction.x * current_speed
				velocity.z = direction.z * current_speed

		else:
			velocity.x = direction.x * dash_timer * dash_speed
			velocity.z = direction.z * dash_timer * dash_speed

	# Idle
	else:
		if is_on_floor() && !is_dashing:
			animation_player.play("melee_idle")
		if is_on_floor() or can_change_jump_direction:
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)


# ----------------- Handle Jumping START ---------- #
func handle_character_jumping(input_dir):
	if is_on_floor() or jumps < jumps_max:
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
			jumps += 1
			animation_player.play("melee_jump")

			# Handle 2nd jump if no direction is applied
			if jumps == 1:
				initial_jump_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

			elif jumps == 2 and input_dir == Vector2.ZERO:
				velocity.x = initial_jump_direction.x * current_speed
				velocity.z = initial_jump_direction.z * current_speed

func change_second_jump_direction():
	if jumps == 1 && Input.is_action_just_pressed("jump"):
		can_change_jump_direction = true
	elif jumps >= 1:
		can_change_jump_direction = false


# ------------------ Handle Crouching STARTS ------------------ #
func handle_crouching():
	# Add crouching logic here if needed
	pass


# ----------------- Handle Dashing STARTS ----------------- #
func handle_dashing(input_dir, direction, delta):

	if is_dashing:
		direction = (transform.basis * Vector3(dash_vector.x, 0, dash_vector.y)).normalized()

		# Handle dashing sequence
	for sequence in sequences.values():
		if key_sequence == sequence:
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


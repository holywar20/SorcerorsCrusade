extends KinematicBody2D

onready var animationTree = $AnimatedSprite/AnimationTree
onready var sprite = $AnimatedSprite
onready var stateName = $Label

var stateMachine : AnimationNodeStateMachinePlayback
var velocity = Vector2( 0 , 0 )
var currentDelta : float = 0.0

var cameraVelocity = Vector2( 0 , 0 )  # only reflects velocity of inputs. Not using physics for camera, just tracking additional movement inside the script.

const MAX_SPEED = 260
const GROUND_ACCELERATION = 90
const AIR_ACCELERATION = 70

const GROUND_ATTACK_FRICTION = 160
const GROUND_FRICTION = 60

const SLIDE_FRICTION = 15
const AIR_FRICTION = 5

const GRAVITY = 30
const TERMINAL_VELOCITY = 600
const SLIDE_FORCE_ADD = 400
const JUMPFORCE = -800

const RUNNING_GROUND_ATTACK_FORCE = 700

const LOOK_UP_ACCELERATION = 90
const LOOK_UP_MAX_HEIGHT = 200
const LOOK_DOWN_ACCELERATION = 90
const LOOK_DOWN_MAX_DEPTH = 400

var CURRENT_STATE

func _ready():
	stateMachine = animationTree.get("parameters/playback")
	animationTree.active = true
	idle()

func _physics_process(delta : float):
	currentDelta = delta
	# apply any remaining velocity for this frame before figuroug out the next frame.
	
	# Get current input vector
	velocity = move_and_slide( velocity, Vector2.UP )
	var inputVector : Vector2 = calculateInputVector()

	var currentState = stateMachine.get_current_node()
	stateName.set_text( currentState )

	if( velocity.y > 1 ):
		fall()

	if( is_on_floor() ):
		match currentState:
			"DEFENSIVE_GROUND_ATTACK":
				whileDefensiveGroundAttack( inputVector  )
			"OFFENSIVE_GROUND_ATTACK":
				whileOffensiveGroundAttack( inputVector )
			"JUMP":
				whileJump( inputVector )
			"FALL":
				whileFall( inputVector )
			"SLIDING":
				whileSlide( inputVector )
			"CROUCHED":
				whileCrouched( inputVector )
			"RUN" :
				whileRun( inputVector )
			"IDLE":
				whileIdle( inputVector )

	else:
		# If we aren't on the floor, always apply gravity
		velocity.y = min( velocity.y + ( GRAVITY ), TERMINAL_VELOCITY )

		match currentState:
			"JUMP":
				whileJump( inputVector )
			"FALL":
				whileFall( inputVector )

	
func _applyFriction( frictionAmount : int ):
	if( velocity.x > 0 ):
		velocity.x = max( velocity.x - frictionAmount , 0 )
	elif( velocity.x < 0 ):
		velocity.x = min( velocity.x + frictionAmount , 0 )		

func _applyAcceleration( inputVector : Vector2 , acceleration , maxSpeed = MAX_SPEED ):
	if( inputVector.x < 0 ):
		velocity.x = max( velocity.x - ( acceleration * abs(inputVector.x) ) , -maxSpeed )
	elif( inputVector.x > 0 ):
		velocity.x = min( velocity.x + ( acceleration * abs(inputVector.x) ) , maxSpeed )

func calculateInputVector() -> Vector2:
	var inputVector : Vector2 = Vector2.ZERO

	inputVector.x = ( Input.get_action_strength("MOVE_RIGHT") - Input.get_action_strength("MOVE_LEFT") )
	inputVector.y = ( Input.get_action_strength("LOOK_DOWN") - Input.get_action_strength("LOOK_UP") )

	return inputVector

# List of functions that controls the statemachine, deciding which states are permitted and executing any changes we want during that state. 
func whileDefensiveGroundAttack( inputVector : Vector2 ) -> void:
	_applyFriction( GROUND_ATTACK_FRICTION )

func whileOffensiveGroundAttack( inputVector : Vector2 ) -> void:
	_applyFriction( GROUND_ATTACK_FRICTION )

func whileCrouched( inputVector ) -> void:
	
	# Again figure out if we need new states for next frame
	if Input.is_action_pressed("DEFENSIVE_ACTION"):
		defensiveGroundAttack()
	elif Input.is_action_pressed("OFFENSIVE_ACTION"):
		offensiveGroundAttack()
	elif Input.is_action_pressed("JUMP"):
		jump()

	#Then process any camera movement we might need.
	if( inputVector.y < .5 ):
		idle()

func whileDash( inputVector ) -> void:
	pass

func whileJump( inputVector: Vector2 ) -> void:
	_applyFriction( AIR_FRICTION )
	
	if( velocity.x > 0):
		sprite.flip_h = false
	elif( velocity.x < 0 ):
		sprite.flip_h = true

	if( is_on_floor() ):
		idle()
	elif( velocity.y < 0 ):
		fall()

	_applyAcceleration( inputVector , AIR_ACCELERATION )

func whileFall( inputVector: Vector2 ) -> void:
	_applyFriction( AIR_FRICTION )
	
	if( velocity.x > 0):
		sprite.flip_h = false
	elif( velocity.x < 0 ):
		sprite.flip_h = true

	if( is_on_floor() ):
		idle()
	else:
		_applyAcceleration( inputVector , AIR_ACCELERATION )

func whileSlide( inputVector : Vector2 ) -> void:
	_applyFriction( SLIDE_FRICTION )

	if( is_on_floor() && velocity.x == 0 ):
		idle()
	elif( velocity.y < 0 ):
		fall()
	elif Input.is_action_pressed("JUMP"):
		jump()

func whileRun( inputVector: Vector2 ) -> void:
	# Calculate new velocity / friction vectors
	if( inputVector.x == 0 ):
		_applyFriction( GROUND_FRICTION )
	else:
		_applyAcceleration( inputVector , GROUND_ACCELERATION )

	if( velocity.x > 0):
		sprite.flip_h = false
	elif( velocity.x < 0 ):
		sprite.flip_h = true

	# Figure out any allowed state changes.
	if Input.is_action_pressed("DEFENSIVE_ACTION"):
		slide()
		return
	elif Input.is_action_pressed("OFFENSIVE_ACTION"):
		chargingGroundAttack()
		return
	elif Input.is_action_pressed("JUMP"):
		jump()
		return	

	if( velocity.x == 0 ):
		idle()
	elif( !is_on_floor() ):
		fall()

func whileIdle( inputVector: Vector2  ) -> void:
	# First figure out if we should transition.
	if Input.is_action_pressed("DEFENSIVE_ACTION"):
		defensiveGroundAttack()
		return
	elif Input.is_action_pressed("OFFENSIVE_ACTION"):
		offensiveGroundAttack()
		return
	elif Input.is_action_pressed("JUMP"):
		jump()
		return
	elif ( inputVector.y > 0 ):
		crouched()
		return

	# Now calculate new velocity / friction vectors
	if( inputVector.x == 0 ):
		_applyFriction( GROUND_FRICTION )
	else:
		_applyAcceleration( inputVector , GROUND_ACCELERATION )
		run()

# List of functions that actually change state, and provide any one-t  ime change to variables. These functions should only be called on a state change.
# And generally are related to an actual button press.
func chargingGroundAttack() -> void:
	velocity.x += RUNNING_GROUND_ATTACK_FORCE
	stateMachine.travel("OFFENSIVE_GROUND_ATTACK")

func defensiveGroundAttack() -> void: 
	#velocity.x = 0

	#if( sprite.flip_v == true ):
	#	velocity.x = 40
	#elif( sprite.flip_v == false ):
	#	velocity.x = -40

	stateMachine.travel("DEFENSIVE_GROUND_ATTACK")

func crouched() -> void:
	stateMachine.travel("CROUCHED")

func offensiveGroundAttack() -> void:
	velocity.x = 0
	
	stateMachine.travel("OFFENSIVE_GROUND_ATTACK")

func dash() -> void:
	stateMachine.travel("DASH")


func slide() -> void:
	# TODO - not getting velocity for some reason
	if( velocity.x > 0 ):
		velocity.x = SLIDE_FORCE_ADD
	elif( velocity.x < 0):
		velocity.x = -SLIDE_FORCE_ADD

	stateMachine.travel("SLIDING")

func jump() -> void:
	velocity.y = JUMPFORCE
	stateMachine.travel("JUMP")

func fall() -> void:
	stateMachine.travel("FALL")

func run() -> void:
	stateMachine.travel("RUN")

func idle() -> void:
	stateMachine.travel("IDLE")

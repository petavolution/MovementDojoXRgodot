## RoutineLibrary - Collection of pre-defined wellness routines
## Provides yoga, qi gong, and meditation sequences
class_name RoutineLibrary
extends RefCounted

static var _routines: Dictionary = {}
static var _initialized := false


static func get_routine(routine_id: String) -> WellnessRoutine:
	_ensure_initialized()
	return _routines.get(routine_id)


static func get_routines_by_category(category: String) -> Array[WellnessRoutine]:
	_ensure_initialized()
	var result: Array[WellnessRoutine] = []
	for routine in _routines.values():
		if routine.category == category:
			result.append(routine)
	return result


static func get_all_routines() -> Array[WellnessRoutine]:
	_ensure_initialized()
	var result: Array[WellnessRoutine] = []
	for routine in _routines.values():
		result.append(routine)
	return result


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_create_warmup_routines()
	_create_yoga_routines()
	_create_qi_gong_routines()
	_create_meditation_routines()
	_create_combat_prep_routines()


static func _create_warmup_routines() -> void:
	var routine := WellnessRoutine.create_routine(
		"morning_activation",
		"Morning Activation",
		"Wake up your body with full-range movements",
		"warmup"
	)
	routine.difficulty = 1

	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Centering Breath",
			"Stand comfortably. Take 3 deep breaths.",
			15.0, -1
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Reach High",
			"Slowly raise both arms overhead. Stretch tall.",
			20.0, 7  # OVERHEAD_REACH
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Side Stretch Left",
			"Lean to your left side, arm overhead.",
			15.0, 1  # HORIZONTAL_SWEEP
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Side Stretch Right",
			"Lean to your right side, arm overhead.",
			15.0, 1
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Forward Fold",
			"Bend forward, let arms hang down.",
			20.0, 9  # LOW_REACH
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Arm Circles",
			"Make large circles with both arms.",
			30.0, 5  # CIRCULAR
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Free Movement",
			"Move freely, explore your space.",
			60.0, -1
		)
	)

	_routines[routine.id] = routine


static func _create_yoga_routines() -> void:
	# Sun Salutation inspired routine
	var routine := WellnessRoutine.create_routine(
		"vr_sun_salutation",
		"VR Sun Salutation",
		"Adapted sun salutation for VR space",
		"yoga"
	)
	routine.difficulty = 2

	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Mountain Pose",
			"Stand tall, arms at sides, feet together.",
			10.0, 0  # IDLE
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Upward Salute",
			"Inhale, sweep arms overhead, palms together.",
			8.0, 7  # OVERHEAD_REACH
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Forward Fold",
			"Exhale, fold forward from hips, hands toward floor.",
			10.0, 9  # LOW_REACH
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Halfway Lift",
			"Inhale, lift torso halfway, hands on shins.",
			6.0, 3  # THRUST
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Forward Fold",
			"Exhale, fold back down.",
			6.0, 9
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Rise Up",
			"Inhale, sweep arms wide and up to stand.",
			8.0, 2  # VERTICAL_SWEEP
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Mountain Pose",
			"Exhale, return to starting position.",
			10.0, 0
		)
	)

	# Repeat 3 times
	var base_steps := routine.steps.duplicate()
	for i in range(2):
		for step in base_steps:
			routine.add_step(step)

	_routines[routine.id] = routine

	# Warrior Flow
	var warrior := WellnessRoutine.create_routine(
		"warrior_flow",
		"Warrior Flow",
		"Build strength with warrior pose variations",
		"yoga"
	)
	warrior.difficulty = 3

	warrior.add_step(
		WellnessRoutine.RoutineStep.create(
			"Warrior I - Right",
			"Step right foot back, arms overhead, hips forward.",
			30.0, 7
		)
	)
	warrior.add_step(
		WellnessRoutine.RoutineStep.create(
			"Warrior II - Right",
			"Open hips and arms to sides, gaze over front hand.",
			30.0, 1
		)
	)
	warrior.add_step(
		WellnessRoutine.RoutineStep.create(
			"Reverse Warrior - Right",
			"Reach back arm down leg, front arm up.",
			20.0, 8  # BEHIND_REACH + OVERHEAD
		)
	)
	warrior.add_step(
		WellnessRoutine.RoutineStep.create(
			"Transition",
			"Return to center, switch sides.",
			10.0, -1
		)
	)
	warrior.add_step(
		WellnessRoutine.RoutineStep.create(
			"Warrior I - Left",
			"Step left foot back, arms overhead, hips forward.",
			30.0, 7
		)
	)
	warrior.add_step(
		WellnessRoutine.RoutineStep.create(
			"Warrior II - Left",
			"Open hips and arms to sides, gaze over front hand.",
			30.0, 1
		)
	)
	warrior.add_step(
		WellnessRoutine.RoutineStep.create(
			"Reverse Warrior - Left",
			"Reach back arm down leg, front arm up.",
			20.0, 8
		)
	)

	_routines[warrior.id] = warrior


static func _create_qi_gong_routines() -> void:
	var routine := WellnessRoutine.create_routine(
		"gathering_qi",
		"Gathering Qi",
		"Fundamental qi gong practice for energy cultivation",
		"qi_gong"
	)
	routine.difficulty = 1

	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Standing Meditation",
			"Stand with feet shoulder-width, knees soft, arms relaxed.",
			30.0, 0
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Gathering from Earth",
			"Slowly lower hands, palms down, as if pressing energy down.",
			15.0, 9
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Scooping Qi",
			"Turn palms up, slowly raise hands as if lifting energy.",
			15.0, 2
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Gathering to Dantian",
			"Bring hands to lower belly, palms facing body.",
			10.0, 4  # PULL
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Expanding Qi",
			"Push hands outward slowly, expanding energy.",
			15.0, 3  # THRUST
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Return to Center",
			"Draw hands back to dantian.",
			10.0, 4
		)
	)

	# Repeat sequence
	var base_steps := routine.steps.slice(1)  # Skip initial meditation
	for step in base_steps:
		routine.add_step(step)
	for step in base_steps:
		routine.add_step(step)

	_routines[routine.id] = routine

	# Cloud Hands
	var cloud := WellnessRoutine.create_routine(
		"cloud_hands",
		"Cloud Hands",
		"Flowing tai chi movement for upper body mobility",
		"qi_gong"
	)
	cloud.difficulty = 2

	cloud.add_step(
		WellnessRoutine.RoutineStep.create(
			"Opening",
			"Stand relaxed, weight slightly on left foot.",
			10.0, 0
		)
	)
	cloud.add_step(
		WellnessRoutine.RoutineStep.create(
			"Right Hand Rises",
			"Float right hand up, palm facing you, as left lowers.",
			8.0, 5  # CIRCULAR
		)
	)
	cloud.add_step(
		WellnessRoutine.RoutineStep.create(
			"Hands Pass",
			"Hands pass at chest height, shift weight right.",
			8.0, 10  # CROSS_BODY
		)
	)
	cloud.add_step(
		WellnessRoutine.RoutineStep.create(
			"Left Hand Rises",
			"Float left hand up, palm facing you, as right lowers.",
			8.0, 5
		)
	)
	cloud.add_step(
		WellnessRoutine.RoutineStep.create(
			"Hands Pass",
			"Hands pass at chest height, shift weight left.",
			8.0, 10
		)
	)

	# Repeat pattern
	for i in range(5):
		cloud.add_step(cloud.steps[1])
		cloud.add_step(cloud.steps[2])
		cloud.add_step(cloud.steps[3])
		cloud.add_step(cloud.steps[4])

	_routines[cloud.id] = cloud


static func _create_meditation_routines() -> void:
	var routine := WellnessRoutine.create_routine(
		"moving_meditation",
		"Moving Meditation",
		"Slow, mindful movement practice",
		"meditation"
	)
	routine.difficulty = 1

	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Centering",
			"Close your eyes. Feel your breath. Notice your body.",
			60.0, 0
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Slow Reach",
			"Very slowly, raise one hand. Notice every sensation.",
			30.0, 2
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Explore Space",
			"Move hand slowly through space. Feel the air.",
			45.0, 6  # DIAGONAL
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Both Hands",
			"Add your other hand. Create shapes in space.",
			60.0, 5
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Return",
			"Slowly return hands to rest. Breathe.",
			30.0, 0
		)
	)

	_routines[routine.id] = routine


static func _create_combat_prep_routines() -> void:
	var routine := WellnessRoutine.create_routine(
		"saber_warmup",
		"Saber Warmup",
		"Prepare your body for lightsaber training",
		"warmup"
	)
	routine.difficulty = 2

	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Wrist Circles",
			"Rotate your wrists in circles, both directions.",
			20.0, 5
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Shoulder Rolls",
			"Roll shoulders forward, then backward.",
			20.0, 5
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Horizontal Swings",
			"Swing arms side to side across body.",
			30.0, 1
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Vertical Swings",
			"Swing arms up and down.",
			30.0, 2
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Figure Eights",
			"Draw figure-8 patterns with each hand.",
			30.0, 5
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Overhead Reach",
			"Reach high above your head, stretch.",
			15.0, 7
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Behind Back",
			"Reach behind you, open chest.",
			15.0, 8
		)
	)
	routine.add_step(
		WellnessRoutine.RoutineStep.create(
			"Ready Position",
			"Take your combat stance. You are ready.",
			10.0, 0
		)
	)

	_routines[routine.id] = routine

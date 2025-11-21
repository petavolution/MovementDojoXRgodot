## IKBodyAvatar - Full body inverse kinematics avatar for VR
## Creates a visible body representation based on head and hand tracking
class_name IKBodyAvatar
extends Node3D

signal avatar_ready
signal pose_updated

## Avatar components
var head_target: Node3D
var left_hand_target: Node3D
var right_hand_target: Node3D

## Skeleton and mesh
var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D

## IK targets (positioned by tracking)
var ik_head: Node3D
var ik_left_hand: Node3D
var ik_right_hand: Node3D

## Estimated body parts
var estimated_hips: Vector3
var estimated_left_foot: Vector3
var estimated_right_foot: Vector3

## Calibration data
var player_height: float = 1.7
var arm_span: float = 1.7
var shoulder_width: float = 0.4
var torso_length: float = 0.5

## Bone indices
var bone_head: int = -1
var bone_neck: int = -1
var bone_spine: int = -1
var bone_hips: int = -1
var bone_left_shoulder: int = -1
var bone_left_upper_arm: int = -1
var bone_left_forearm: int = -1
var bone_left_hand: int = -1
var bone_right_shoulder: int = -1
var bone_right_upper_arm: int = -1
var bone_right_forearm: int = -1
var bone_right_hand: int = -1
var bone_left_upper_leg: int = -1
var bone_left_lower_leg: int = -1
var bone_left_foot: int = -1
var bone_right_upper_leg: int = -1
var bone_right_lower_leg: int = -1
var bone_right_foot: int = -1

## IK settings
@export var arm_ik_iterations: int = 10
@export var arm_ik_threshold: float = 0.01
@export var spine_bend_factor: float = 0.3
@export var hip_follow_factor: float = 0.5
@export var foot_ground_offset: float = 0.05

## Animation blending
var idle_weight: float = 1.0
var walk_weight: float = 0.0
var movement_velocity: Vector3 = Vector3.ZERO

## Visibility
@export var visible_to_player: bool = false
@export var head_visible: bool = false


func _ready() -> void:
	_setup_avatar()


func setup(head: Node3D, left_hand: Node3D, right_hand: Node3D) -> void:
	head_target = head
	left_hand_target = left_hand
	right_hand_target = right_hand

	avatar_ready.emit()


func set_calibration(height: float, span: float) -> void:
	player_height = height
	arm_span = span
	shoulder_width = span * 0.25
	torso_length = height * 0.3

	_scale_avatar()


func _setup_avatar() -> void:
	# Create skeleton
	skeleton = Skeleton3D.new()
	skeleton.name = "AvatarSkeleton"
	add_child(skeleton)

	# Add bones
	_create_skeleton_bones()

	# Create simple mesh representation
	_create_avatar_mesh()

	# Create IK target nodes
	ik_head = Node3D.new()
	ik_head.name = "IK_Head"
	add_child(ik_head)

	ik_left_hand = Node3D.new()
	ik_left_hand.name = "IK_LeftHand"
	add_child(ik_left_hand)

	ik_right_hand = Node3D.new()
	ik_right_hand.name = "IK_RightHand"
	add_child(ik_right_hand)


func _create_skeleton_bones() -> void:
	# Create a simple humanoid skeleton
	# Hips (root)
	bone_hips = skeleton.add_bone("Hips")
	skeleton.set_bone_rest(bone_hips, Transform3D(Basis(), Vector3(0, 1.0, 0)))

	# Spine
	bone_spine = skeleton.add_bone("Spine")
	skeleton.set_bone_parent(bone_spine, bone_hips)
	skeleton.set_bone_rest(bone_spine, Transform3D(Basis(), Vector3(0, 0.2, 0)))

	# Neck
	bone_neck = skeleton.add_bone("Neck")
	skeleton.set_bone_parent(bone_neck, bone_spine)
	skeleton.set_bone_rest(bone_neck, Transform3D(Basis(), Vector3(0, 0.3, 0)))

	# Head
	bone_head = skeleton.add_bone("Head")
	skeleton.set_bone_parent(bone_head, bone_neck)
	skeleton.set_bone_rest(bone_head, Transform3D(Basis(), Vector3(0, 0.1, 0)))

	# Left arm chain
	bone_left_shoulder = skeleton.add_bone("LeftShoulder")
	skeleton.set_bone_parent(bone_left_shoulder, bone_spine)
	skeleton.set_bone_rest(bone_left_shoulder, Transform3D(Basis(), Vector3(-0.1, 0.25, 0)))

	bone_left_upper_arm = skeleton.add_bone("LeftUpperArm")
	skeleton.set_bone_parent(bone_left_upper_arm, bone_left_shoulder)
	skeleton.set_bone_rest(bone_left_upper_arm, Transform3D(Basis(), Vector3(-0.1, 0, 0)))

	bone_left_forearm = skeleton.add_bone("LeftForearm")
	skeleton.set_bone_parent(bone_left_forearm, bone_left_upper_arm)
	skeleton.set_bone_rest(bone_left_forearm, Transform3D(Basis(), Vector3(-0.25, 0, 0)))

	bone_left_hand = skeleton.add_bone("LeftHand")
	skeleton.set_bone_parent(bone_left_hand, bone_left_forearm)
	skeleton.set_bone_rest(bone_left_hand, Transform3D(Basis(), Vector3(-0.25, 0, 0)))

	# Right arm chain
	bone_right_shoulder = skeleton.add_bone("RightShoulder")
	skeleton.set_bone_parent(bone_right_shoulder, bone_spine)
	skeleton.set_bone_rest(bone_right_shoulder, Transform3D(Basis(), Vector3(0.1, 0.25, 0)))

	bone_right_upper_arm = skeleton.add_bone("RightUpperArm")
	skeleton.set_bone_parent(bone_right_upper_arm, bone_right_shoulder)
	skeleton.set_bone_rest(bone_right_upper_arm, Transform3D(Basis(), Vector3(0.1, 0, 0)))

	bone_right_forearm = skeleton.add_bone("RightForearm")
	skeleton.set_bone_parent(bone_right_forearm, bone_right_upper_arm)
	skeleton.set_bone_rest(bone_right_forearm, Transform3D(Basis(), Vector3(0.25, 0, 0)))

	bone_right_hand = skeleton.add_bone("RightHand")
	skeleton.set_bone_parent(bone_right_hand, bone_right_forearm)
	skeleton.set_bone_rest(bone_right_hand, Transform3D(Basis(), Vector3(0.25, 0, 0)))

	# Left leg chain
	bone_left_upper_leg = skeleton.add_bone("LeftUpperLeg")
	skeleton.set_bone_parent(bone_left_upper_leg, bone_hips)
	skeleton.set_bone_rest(bone_left_upper_leg, Transform3D(Basis(), Vector3(-0.1, -0.05, 0)))

	bone_left_lower_leg = skeleton.add_bone("LeftLowerLeg")
	skeleton.set_bone_parent(bone_left_lower_leg, bone_left_upper_leg)
	skeleton.set_bone_rest(bone_left_lower_leg, Transform3D(Basis(), Vector3(0, -0.45, 0)))

	bone_left_foot = skeleton.add_bone("LeftFoot")
	skeleton.set_bone_parent(bone_left_foot, bone_left_lower_leg)
	skeleton.set_bone_rest(bone_left_foot, Transform3D(Basis(), Vector3(0, -0.45, 0)))

	# Right leg chain
	bone_right_upper_leg = skeleton.add_bone("RightUpperLeg")
	skeleton.set_bone_parent(bone_right_upper_leg, bone_hips)
	skeleton.set_bone_rest(bone_right_upper_leg, Transform3D(Basis(), Vector3(0.1, -0.05, 0)))

	bone_right_lower_leg = skeleton.add_bone("RightLowerLeg")
	skeleton.set_bone_parent(bone_right_lower_leg, bone_right_upper_leg)
	skeleton.set_bone_rest(bone_right_lower_leg, Transform3D(Basis(), Vector3(0, -0.45, 0)))

	bone_right_foot = skeleton.add_bone("RightFoot")
	skeleton.set_bone_parent(bone_right_foot, bone_right_lower_leg)
	skeleton.set_bone_rest(bone_right_foot, Transform3D(Basis(), Vector3(0, -0.45, 0)))


func _create_avatar_mesh() -> void:
	# Create simple capsule/sphere representation for each body part
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "AvatarMesh"
	mesh_instance.skeleton = NodePath("../AvatarSkeleton")

	# For a full implementation, this would use a proper skinned mesh
	# For now, create a simple procedural representation

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.4, 0.6, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Create body parts as separate meshes attached to bones
	_create_body_part("torso", bone_spine, Vector3(0.3, 0.4, 0.15), material)
	_create_body_part("head_mesh", bone_head, Vector3(0.15, 0.18, 0.15), material)
	_create_body_part("left_upper_arm_mesh", bone_left_upper_arm, Vector3(0.06, 0.25, 0.06), material)
	_create_body_part("left_forearm_mesh", bone_left_forearm, Vector3(0.05, 0.25, 0.05), material)
	_create_body_part("right_upper_arm_mesh", bone_right_upper_arm, Vector3(0.06, 0.25, 0.06), material)
	_create_body_part("right_forearm_mesh", bone_right_forearm, Vector3(0.05, 0.25, 0.05), material)
	_create_body_part("left_hand_mesh", bone_left_hand, Vector3(0.08, 0.1, 0.03), material)
	_create_body_part("right_hand_mesh", bone_right_hand, Vector3(0.08, 0.1, 0.03), material)
	_create_body_part("left_upper_leg_mesh", bone_left_upper_leg, Vector3(0.08, 0.4, 0.08), material)
	_create_body_part("left_lower_leg_mesh", bone_left_lower_leg, Vector3(0.06, 0.4, 0.06), material)
	_create_body_part("right_upper_leg_mesh", bone_right_upper_leg, Vector3(0.08, 0.4, 0.08), material)
	_create_body_part("right_lower_leg_mesh", bone_right_lower_leg, Vector3(0.06, 0.4, 0.06), material)


func _create_body_part(part_name: String, bone_idx: int, size: Vector3, material: Material) -> void:
	var bone_attachment := BoneAttachment3D.new()
	bone_attachment.name = part_name + "_attachment"
	bone_attachment.bone_idx = bone_idx
	skeleton.add_child(bone_attachment)

	var mesh := MeshInstance3D.new()
	mesh.name = part_name

	var capsule := CapsuleMesh.new()
	capsule.radius = size.x
	capsule.height = size.y
	capsule.material = material
	mesh.mesh = capsule

	bone_attachment.add_child(mesh)


func _scale_avatar() -> void:
	# Scale skeleton based on calibration
	var height_scale := player_height / 1.7
	skeleton.scale = Vector3(height_scale, height_scale, height_scale)


func _process(delta: float) -> void:
	if head_target == null:
		return

	_update_ik_targets()
	_estimate_body_position()
	_solve_spine_ik()
	_solve_arm_ik(true)  # Left arm
	_solve_arm_ik(false) # Right arm
	_estimate_legs()

	pose_updated.emit()


func _update_ik_targets() -> void:
	if head_target:
		ik_head.global_transform = head_target.global_transform

	if left_hand_target:
		ik_left_hand.global_transform = left_hand_target.global_transform

	if right_hand_target:
		ik_right_hand.global_transform = right_hand_target.global_transform


func _estimate_body_position() -> void:
	if head_target == null:
		return

	var head_pos := head_target.global_position
	var head_forward := -head_target.global_transform.basis.z
	head_forward.y = 0
	head_forward = head_forward.normalized()

	# Estimate hip position below and behind head
	estimated_hips = head_pos - Vector3(0, torso_length + 0.1, 0)
	estimated_hips -= head_forward * 0.05  # Slightly behind

	# Adjust based on hand positions (leaning)
	if left_hand_target and right_hand_target:
		var hand_center := (left_hand_target.global_position + right_hand_target.global_position) / 2.0
		var lean_offset := (hand_center - head_pos) * hip_follow_factor
		lean_offset.y = 0
		estimated_hips += lean_offset

	# Set hip bone position
	global_position = estimated_hips
	global_position.y = 0  # Keep avatar grounded


func _solve_spine_ik() -> void:
	if bone_hips < 0 or bone_spine < 0 or bone_neck < 0 or bone_head < 0:
		return

	var head_pos := ik_head.global_position
	var hip_pos := estimated_hips

	# Calculate spine direction
	var spine_dir := (head_pos - hip_pos).normalized()

	# Apply some forward lean based on hand reach
	var lean_angle := 0.0
	if left_hand_target and right_hand_target:
		var avg_hand_z := (left_hand_target.global_position.z + right_hand_target.global_position.z) / 2.0
		var head_z := head_pos.z
		lean_angle = clampf((head_z - avg_hand_z) * spine_bend_factor, -0.3, 0.3)

	# Set spine rotation
	var spine_basis := Basis.looking_at(spine_dir, Vector3.FORWARD)
	spine_basis = spine_basis.rotated(spine_basis.x, lean_angle)

	skeleton.set_bone_pose_rotation(bone_spine, spine_basis.get_rotation_quaternion())

	# Set head to match tracked rotation
	var head_rot := ik_head.global_transform.basis.get_rotation_quaternion()
	var spine_rot := spine_basis.get_rotation_quaternion()
	var relative_head := spine_rot.inverse() * head_rot
	skeleton.set_bone_pose_rotation(bone_head, relative_head)


func _solve_arm_ik(is_left: bool) -> void:
	var shoulder_bone := bone_left_shoulder if is_left else bone_right_shoulder
	var upper_arm_bone := bone_left_upper_arm if is_left else bone_right_upper_arm
	var forearm_bone := bone_left_forearm if is_left else bone_right_forearm
	var hand_bone := bone_left_hand if is_left else bone_right_hand

	var hand_target := ik_left_hand if is_left else ik_right_hand

	if shoulder_bone < 0 or hand_target == null:
		return

	# Get target position
	var target_pos := hand_target.global_position

	# Get shoulder position (from skeleton)
	var shoulder_global := skeleton.get_bone_global_pose(shoulder_bone).origin + global_position

	# Arm segment lengths
	var upper_arm_length := 0.28 * (player_height / 1.7)
	var forearm_length := 0.25 * (player_height / 1.7)
	var total_arm_length := upper_arm_length + forearm_length

	# Direction to target
	var to_target := target_pos - shoulder_global
	var target_distance := to_target.length()

	# Clamp to reachable distance
	target_distance = clampf(target_distance, 0.1, total_arm_length * 0.98)

	# Two-bone IK solution
	var target_dir := to_target.normalized()

	# Calculate elbow angle using law of cosines
	var cos_elbow := (upper_arm_length * upper_arm_length + forearm_length * forearm_length - target_distance * target_distance) / (2 * upper_arm_length * forearm_length)
	cos_elbow = clampf(cos_elbow, -1.0, 1.0)
	var elbow_angle := acos(cos_elbow)

	# Calculate shoulder angle
	var cos_shoulder := (target_distance * target_distance + upper_arm_length * upper_arm_length - forearm_length * forearm_length) / (2 * target_distance * upper_arm_length)
	cos_shoulder = clampf(cos_shoulder, -1.0, 1.0)
	var shoulder_angle := acos(cos_shoulder)

	# Determine elbow hint direction (outward and slightly back)
	var elbow_hint := Vector3(-1 if is_left else 1, -0.5, -0.3).normalized()

	# Build rotation for upper arm
	var arm_forward := target_dir
	var arm_up := elbow_hint.cross(arm_forward).normalized()
	var arm_right := arm_forward.cross(arm_up)

	var upper_arm_basis := Basis(arm_right, arm_up, -arm_forward)
	upper_arm_basis = upper_arm_basis.rotated(arm_up, -shoulder_angle if is_left else shoulder_angle)

	skeleton.set_bone_pose_rotation(upper_arm_bone, upper_arm_basis.get_rotation_quaternion())

	# Forearm rotation (elbow bend)
	var forearm_basis := Basis.IDENTITY.rotated(Vector3.UP, PI - elbow_angle)
	skeleton.set_bone_pose_rotation(forearm_bone, forearm_basis.get_rotation_quaternion())

	# Hand rotation matches controller
	var hand_rot := hand_target.global_transform.basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(hand_bone, hand_rot)


func _estimate_legs() -> void:
	# Simple leg estimation - feet stay on ground
	var hip_pos := estimated_hips

	# Feet positioned below hips
	estimated_left_foot = Vector3(hip_pos.x - 0.1, foot_ground_offset, hip_pos.z)
	estimated_right_foot = Vector3(hip_pos.x + 0.1, foot_ground_offset, hip_pos.z)

	# Simple IK for legs (just point toward feet)
	_solve_leg_ik(true)
	_solve_leg_ik(false)


func _solve_leg_ik(is_left: bool) -> void:
	var upper_leg_bone := bone_left_upper_leg if is_left else bone_right_upper_leg
	var lower_leg_bone := bone_left_lower_leg if is_left else bone_right_lower_leg
	var foot_bone := bone_left_foot if is_left else bone_right_foot

	var foot_target := estimated_left_foot if is_left else estimated_right_foot

	if upper_leg_bone < 0:
		return

	# Get hip position
	var hip_offset := Vector3(-0.1 if is_left else 0.1, 0, 0)
	var hip_pos := estimated_hips + hip_offset

	# Leg segment lengths
	var upper_leg_length := 0.45 * (player_height / 1.7)
	var lower_leg_length := 0.43 * (player_height / 1.7)

	# Direction to foot
	var to_foot := foot_target - hip_pos
	var target_distance := to_foot.length()

	# Two-bone IK (similar to arms)
	var total_leg_length := upper_leg_length + lower_leg_length
	target_distance = clampf(target_distance, 0.1, total_leg_length * 0.98)

	var cos_knee := (upper_leg_length * upper_leg_length + lower_leg_length * lower_leg_length - target_distance * target_distance) / (2 * upper_leg_length * lower_leg_length)
	cos_knee = clampf(cos_knee, -1.0, 1.0)
	var knee_angle := acos(cos_knee)

	# Upper leg points toward foot with knee bend
	var leg_dir := to_foot.normalized()
	var leg_basis := Basis.looking_at(-leg_dir, Vector3.FORWARD)

	skeleton.set_bone_pose_rotation(upper_leg_bone, leg_basis.get_rotation_quaternion())

	# Lower leg (knee bend)
	var lower_leg_basis := Basis.IDENTITY.rotated(Vector3.RIGHT, PI - knee_angle)
	skeleton.set_bone_pose_rotation(lower_leg_bone, lower_leg_basis.get_rotation_quaternion())


## Visibility control
func set_visible_to_player(vis: bool) -> void:
	visible_to_player = vis
	# In VR, would set layers to hide from player camera but show to mirrors/others


func set_head_visible(vis: bool) -> void:
	head_visible = vis
	# Toggle head mesh visibility

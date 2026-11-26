import re

def update_map():
    with open('/home/chenlian/Projects/game/game-gimersia-projects/chap_1/objek/map.tscn.bak', 'r') as f:
        content = f.read()

    # 1. New ExtResources
    new_ext_resources = """[ext_resource type="Script" uid="uid://bcu0ffec1xovb" path="res://world.gd" id="ext_world"]
[ext_resource type="Script" uid="uid://bk7b3iyruw8qm" path="res://cinematic_camera_rig.gd" id="ext_cam"]
[ext_resource type="Script" uid="uid://cmtuv7nhn74uv" path="res://mc.gd" id="ext_mc"]
[ext_resource type="Script" uid="uid://odn6xk3etr1q" path="res://pressure_plate.gd" id="ext_plate"]
[ext_resource type="Script" uid="uid://bi3ljwkojtdnr" path="res://glowing_platforms.gd" id="ext_plat"]
[ext_resource type="Script" uid="uid://2vpv5pmmhg5" path="res://door_portal.gd" id="ext_door"]
[ext_resource type="Script" uid="uid://4gnr7y8h73lt" path="res://chapter1_puzzle_manager.gd" id="ext_puz"]
[ext_resource type="Script" uid="uid://bi6c48apci1x3" path="res://carry_system.gd" id="ext_carry"]
[ext_resource type="Script" uid="uid://bfbw02giak4w6" path="res://teddy_bear.gd" id="ext_teddy"]
[ext_resource type="Script" path="res://ceiling_lamp.gd" id="ext_lamp"]
[ext_resource type="Script" path="res://vignette_controller.gd" id="ext_vignette_ctrl"]
[ext_resource type="Shader" uid="uid://bfhomscgxqiua" path="res://vignette.gdshader" id="ext_vignette"]
[ext_resource type="AnimationLibrary" path="res://baru/merged_animations.tres" id="ext_merged_anims"]
"""

    # 2. New SubResources (Environment, ShaderMaterial, and all Collision Shapes)
    new_sub_resources = """[sub_resource type="Environment" id="Environment_dark"]
background_mode = 1
background_color = Color(0.015, 0.02, 0.03, 1)
ambient_light_source = 2
ambient_light_color = Color(0.24, 0.28, 0.36, 1)
ambient_light_energy = 0.26
tonemap_mode = 3
tonemap_exposure = 1.05
ssao_enabled = true
ssao_radius = 2.8
ssao_intensity = 2.5
glow_enabled = true
glow_bloom = 0.08
glow_strength = 0.7
fog_enabled = false
volumetric_fog_enabled = true
volumetric_fog_density = 0.014
volumetric_fog_albedo = Color(0.22, 0.26, 0.34, 1)
volumetric_fog_emission = Color(0.005, 0.008, 0.012, 1)
volumetric_fog_length = 32.0

[sub_resource type="ShaderMaterial" id="ShaderMaterial_vignette"]
shader = ExtResource("ext_vignette")
shader_parameter/center_offset = Vector2(0.5, 0.5)
shader_parameter/inner_radius = 0.20
shader_parameter/outer_radius = 0.68
shader_parameter/vignette_color = Color(0, 0, 0, 1)
shader_parameter/vignette_opacity = 0.96
shader_parameter/aspect_correction = 0.70

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_player"]
radius = 0.65
height = 3.6

[sub_resource type="SphereShape3D" id="SphereShape3D_bear"]
radius = 0.55

[sub_resource type="BoxShape3D" id="BoxShape3D_plate"]
size = Vector3(1.8, 0.4, 1.8)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_platform"]
resource_local_to_scene = true
albedo_color = Color(0.2, 0.35, 0.5, 1)
emission_enabled = true
emission = Color(0.25, 0.85, 1, 1)
emission_energy_multiplier = 0.0

[sub_resource type="BoxMesh" id="BoxMesh_platform"]
material = SubResource("StandardMaterial3D_platform")
size = Vector3(2.5, 0.4, 2.0)

[sub_resource type="BoxShape3D" id="BoxShape3D_platform"]
size = Vector3(2.5, 0.4, 2.0)

[sub_resource type="BoxShape3D" id="BoxShape3D_portal"]
size = Vector3(2.0, 3.2, 2.0)

[sub_resource type="BoxShape3D" id="BoxShape3D_boundary_z"]
size = Vector3(170.65, 20.0, 2.0)

[sub_resource type="BoxShape3D" id="BoxShape3D_boundary_x"]
size = Vector3(2.0, 20.0, 33.26)

[sub_resource type="CylinderShape3D" id="CylinderShape3D_table"]
height = 3.3
radius = 2.27

[sub_resource type="BoxShape3D" id="BoxShape3D_rock"]
size = Vector3(1.38, 1.31, 1.28)

[sub_resource type="BoxShape3D" id="BoxShape3D_cardboard_box"]
size = Vector3(1.06, 0.84, 1.06)

[sub_resource type="BoxShape3D" id="BoxShape3D_wooden_duck"]
size = Vector3(562.4, 570.8, 184.6)

[sub_resource type="BoxShape3D" id="BoxShape3D_door"]
size = Vector3(14.0, 206.6, 97.4)

[sub_resource type="BoxShape3D" id="BoxShape3D_lever"]
size = Vector3(0.54, 6.68, 1.37)

[sub_resource type="BoxShape3D" id="BoxShape3D_toy_car"]
size = Vector3(0.92, 0.65, 0.78)

[sub_resource type="BoxShape3D" id="BoxShape3D_teddybear"]
size = Vector3(14.38, 16.27, 10.01)

[sub_resource type="BoxShape3D" id="BoxShape3D_desk_top"]
size = Vector3(0.097, 0.032, 0.158)

[sub_resource type="BoxShape3D" id="BoxShape3D_desk_pedestal"]
size = Vector3(0.097, 0.085, 0.053)

[sub_resource type="BoxShape3D" id="BoxShape3D_desk_back"]
size = Vector3(0.015, 0.055, 0.054)
"""

    # 3. New Nodes (Camera, Lighting, Vignette, Puzzle, etc.)
    new_nodes = """
[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_dark")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.894427, 0, 0.447214, 0.395777, 0.465620, -0.791554, -0.208232, 0.884985, 0.416463, 0, 15, 0)
light_color = Color(0.55, 0.65, 0.85, 1)
light_energy = 0.06
shadow_enabled = false

[node name="CeilingLamp" type="Node3D" parent="." node_paths=PackedStringArray("spot_light", "omni_light")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -59.5, 6.8, 4.0)
script = ExtResource("ext_lamp")
spot_light = NodePath("SpotLight3D")
omni_light = NodePath("OmniLight3D")

[node name="SpotLight3D" type="SpotLight3D" parent="CeilingLamp"]
transform = Transform3D(1, 0, 0, 0, 0, -1, 0, 1, 0, 0, 0, 0)
light_color = Color(1, 0.92, 0.78, 1)
light_energy = 2.0
shadow_enabled = true
spot_range = 24.0
spot_angle = 75.0
spot_attenuation = 1.2

[node name="OmniLight3D" type="OmniLight3D" parent="CeilingLamp"]
light_color = Color(1, 0.88, 0.72, 1)
light_energy = 0.50
omni_range = 16.0
shadow_enabled = false

[node name="SpotLight_Teddy" type="SpotLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0, -1, 0, 1, 0, -27.278, 5.2, -13.65)
light_color = Color(1, 0.90, 0.75, 1)
light_energy = 2.0
shadow_enabled = true
spot_range = 9.0
spot_angle = 45.0

[node name="SpotLight_PressurePlate" type="SpotLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0, -1, 0, 1, 0, -7.22, 4.5, -14.82)
light_color = Color(0.75, 0.90, 1, 1)
light_energy = 1.6
shadow_enabled = true
spot_range = 7.0
spot_angle = 45.0

[node name="SpotLight_Door" type="SpotLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0, -1, 0, 1, 0, 70.24, 13.5, 6.92)
light_color = Color(0.85, 0.95, 1, 1)
light_energy = 2.2
shadow_enabled = true
spot_range = 10.0
spot_angle = 48.0

[node name="CameraRig" type="Node3D" parent="." node_paths=PackedStringArray("target")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -58.0, 7.2, 27.5)
script = ExtResource("ext_cam")
target = NodePath("../Player")
stay_mode = true
edge_threshold_x = 7.0
edge_threshold_z = 6.0
edge_threshold_y = 3.5
shift_speed_x = 3.2
shift_speed_y = 2.8
shift_speed_z = 2.5
follow_offset = Vector3(0, 7.2, 22.0)
pitch_degrees = -15.0
camera_fov = 48.0
sway_enabled = true
sway_amount = 0.14
sway_roll_degrees = 0.35
parallax_lean_amount = 0.035

[node name="Camera3D" type="Camera3D" parent="CameraRig"]
transform = Transform3D(1, 0, 0, 0, 0.965926, 0.258819, 0, -0.258819, 0.965926, 0, 0, 0)
current = true
fov = 48.0

[node name="Player" type="CharacterBody3D" parent="." node_paths=PackedStringArray("anim_player", "visual_node", "carry_system")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -63.53547, 0.1126665, 9.63462)
collision_layer = 2
collision_mask = 5
script = ExtResource("ext_mc")
anim_player = NodePath("../char no light/AnimationPlayer")
visual_node = NodePath("../char no light")
visual_scale = Vector3(2.2, 2.2, 2.2)
carry_system = NodePath("../Chapter1PuzzleManager/CarrySystem")

[node name="CharFillLight" type="OmniLight3D" parent="Player"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.8, 0)
light_color = Color(0.88, 0.93, 1, 1)
light_energy = 0.75
omni_range = 3.6
omni_attenuation = 1.5
shadow_enabled = false

[node name="CollisionShape3D" type="CollisionShape3D" parent="Player"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.8, 0)
shape = SubResource("CapsuleShape3D_player")

[node name="WallRayCast3D" type="RayCast3D" parent="Player"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.2, 0)
target_position = Vector3(0, 0, -1.2)

[node name="WallRayBack" type="RayCast3D" parent="Player"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.2, 0)
target_position = Vector3(0, 0, 1.2)

[node name="WallTopRayCast3D" type="RayCast3D" parent="Player"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 3.4, 0)
target_position = Vector3(0, 0, -2.0)

[node name="LedgeRayCast3D" type="RayCast3D" parent="Player"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 4.2, 0)
target_position = Vector3(0, -4.5, 0)

[node name="body" type="Node3D" parent="Player"]

[node name="Marker3D" type="Marker3D" parent="Player/body"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.6, 0.75)

[node name="HoldPoint" type="Marker3D" parent="Player/body"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.6, 0.75)

[node name="TeddyBearPickup" type="RigidBody3D" parent="." groups=["pickup", "teddy_bear"] node_paths=PackedStringArray("visual_node")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -27.27808, 2.62, -13.65)
collision_layer = 4
collision_mask = 1
mass = 1.0
freeze = true
continuous_cd = true
can_sleep = true
script = ExtResource("ext_teddy")
visual_node = NodePath("../remembered/Sketchfab_Scene7")

[node name="CollisionShape3D" type="CollisionShape3D" parent="TeddyBearPickup"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 0)
shape = SubResource("SphereShape3D_bear")

[node name="PressurePlate" type="Area3D" parent="." node_paths=PackedStringArray("glowing_platforms", "door_portal")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7.220321, 0.05, -14.81594)
collision_layer = 0
collision_mask = 6
script = ExtResource("ext_plate")
glowing_platforms = NodePath("../GlowingPlatforms")
door_portal = NodePath("../DoorPortal")

[node name="CollisionShape3D" type="CollisionShape3D" parent="PressurePlate"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.2, 0)
shape = SubResource("BoxShape3D_plate")

[node name="GlowingPlatforms" type="Node3D" parent="."]
script = ExtResource("ext_plat")

[node name="Platform1" type="StaticBody3D" parent="GlowingPlatforms"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 47, 5.6, 8.5)
visible = false

[node name="MeshInstance3D" type="MeshInstance3D" parent="GlowingPlatforms/Platform1"]
mesh = SubResource("BoxMesh_platform")

[node name="CollisionShape3D" type="CollisionShape3D" parent="GlowingPlatforms/Platform1"]
shape = SubResource("BoxShape3D_platform")
disabled = true

[node name="Platform2" type="StaticBody3D" parent="GlowingPlatforms"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 55, 6.8, 7.5)
visible = false

[node name="MeshInstance3D" type="MeshInstance3D" parent="GlowingPlatforms/Platform2"]
mesh = SubResource("BoxMesh_platform")

[node name="CollisionShape3D" type="CollisionShape3D" parent="GlowingPlatforms/Platform2"]
shape = SubResource("BoxShape3D_platform")
disabled = true

[node name="Platform3" type="StaticBody3D" parent="GlowingPlatforms"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 63, 8.2, 8)
visible = false

[node name="MeshInstance3D" type="MeshInstance3D" parent="GlowingPlatforms/Platform3"]
mesh = SubResource("BoxMesh_platform")

[node name="CollisionShape3D" type="CollisionShape3D" parent="GlowingPlatforms/Platform3"]
shape = SubResource("BoxShape3D_platform")
disabled = true

[node name="Platform4" type="StaticBody3D" parent="GlowingPlatforms"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 68, 9.6, 7)
visible = false

[node name="MeshInstance3D" type="MeshInstance3D" parent="GlowingPlatforms/Platform4"]
mesh = SubResource("BoxMesh_platform")

[node name="CollisionShape3D" type="CollisionShape3D" parent="GlowingPlatforms/Platform4"]
shape = SubResource("BoxShape3D_platform")
disabled = true

[node name="DoorPortal" type="Area3D" parent="." node_paths=PackedStringArray("door_target_node", "target_marker", "fade_layer", "fade_rect", "game_camera", "player")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 70.23725, 10.294997, 6.915813)
script = ExtResource("ext_door")
door_target_node = NodePath("../interact/Sketchfab_Scene5")
target_marker = NodePath("../TargetRoomMarker")
fade_layer = NodePath("../FadeCanvasLayer")
fade_rect = NodePath("../FadeCanvasLayer/ColorRect")
game_camera = NodePath("../CameraRig")
player = NodePath("../Player")

[node name="CollisionShape3D" type="CollisionShape3D" parent="DoorPortal"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.5, 0)
shape = SubResource("BoxShape3D_portal")

[node name="TargetRoomMarker" type="Marker3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 76.5, 10.3, 6.92)

[node name="VignetteLayer" type="CanvasLayer" parent="."]
layer = 15

[node name="VignetteRect" type="ColorRect" parent="VignetteLayer" node_paths=PackedStringArray("player", "camera")]
material = SubResource("ShaderMaterial_vignette")
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("ext_vignette_ctrl")
player = NodePath("../../Player")
camera = NodePath("../../CameraRig/Camera3D")
player_height_offset = 1.4
track_smooth_speed = 30.0
inner_radius = 0.20
outer_radius = 0.68
vignette_opacity = 0.96
aspect_correction = 0.70

[node name="FadeCanvasLayer" type="CanvasLayer" parent="."]
layer = 50

[node name="ColorRect" type="ColorRect" parent="FadeCanvasLayer"]
modulate = Color(1, 1, 1, 0)
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
color = Color(0, 0, 0, 1)

[node name="Chapter1PuzzleManager" type="Node3D" parent="." node_paths=PackedStringArray("player", "carry_system", "pressure_plate", "glowing_platforms", "door_portal", "target_room_marker", "fade_layer", "fade_rect", "game_camera", "world_manager")]
script = ExtResource("ext_puz")
player = NodePath("../Player")
carry_system = NodePath("CarrySystem")
pressure_plate = NodePath("../PressurePlate")
glowing_platforms = NodePath("../GlowingPlatforms")
door_portal = NodePath("../DoorPortal")
target_room_marker = NodePath("../TargetRoomMarker")
fade_layer = NodePath("../FadeCanvasLayer")
fade_rect = NodePath("../FadeCanvasLayer/ColorRect")
game_camera = NodePath("../CameraRig")
world_manager = NodePath("..")

[node name="CarrySystem" type="Node3D" parent="Chapter1PuzzleManager" node_paths=PackedStringArray("player", "hold_point")]
script = ExtResource("ext_carry")
player = NodePath("../../Player")
hold_point = NodePath("../../Player/body/HoldPoint")
pickup_duration = 0.32
pickup_arc_height = 0.35
"""

    # Insert ExtResources after existing ext_resources
    last_ext_idx = content.rfind('[ext_resource')
    end_of_last_ext = content.find('\n\n', last_ext_idx)
    content = content[:end_of_last_ext + 2] + new_ext_resources + '\n' + content[end_of_last_ext + 2:]

    # Insert SubResources before first [node name=
    first_node_idx = content.find('[node name=')
    content = content[:first_node_idx] + new_sub_resources + '\n' + content[first_node_idx:]

    # Add script to main node
    target_main = '[node name="main" type="Node3D" unique_id=1684493147]'
    replacement_main = '[node name="main" type="Node3D" unique_id=1684493147]\nscript = ExtResource("ext_world")'
    assert target_main in content, f"Could not find main node: {target_main}"
    content = content.replace(target_main, replacement_main)

    # Scale char no light to 2.2x to match Player scale
    old_char_node = '[node name="char no light" parent="." unique_id=38472210 instance=ExtResource("20_1kpqx")]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -63.53547, 0.11266649, 9.63462)'
    new_char_node = '[node name="char no light" parent="." unique_id=38472210 instance=ExtResource("20_1kpqx")]\ntransform = Transform3D(2.2, 0, 0, 0, 2.2, 0, 0, 0, 2.2, -63.53547, 0.11266649, 9.63462)'
    assert old_char_node in content, f"Could not find char no light node: {old_char_node}"
    content = content.replace(old_char_node, new_char_node)

    # Add merged animation library to char no light AnimationPlayer
    old_anim_player = '[node name="AnimationPlayer" parent="char no light" index="3" unique_id=1334494879]\n"libraries/idle (2)" = ExtResource("21_almrc")'
    new_anim_player = '[node name="AnimationPlayer" parent="char no light" index="3" unique_id=1334494879]\nlibraries/ = ExtResource("ext_merged_anims")\n"libraries/idle (2)" = ExtResource("21_almrc")'
    assert old_anim_player in content, f"Could not find AnimationPlayer: {old_anim_player}"
    content = content.replace(old_anim_player, new_anim_player)

    # --- INJECT BOUNDARY WALL COLLIDERS INTO chapter 1 kosong/StaticBody3D ---
    target_floor_col = '[node name="CollisionShape3D" type="CollisionShape3D" parent="chapter 1 kosong/StaticBody3D" unique_id=576052671]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4.292217, -0.87868744, 1.3061433)\nshape = SubResource("BoxShape3D_j0stj")'
    boundary_cols = """[node name="CollisionShape3D" type="CollisionShape3D" parent="chapter 1 kosong/StaticBody3D" unique_id=576052671]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4.292217, -0.87868744, 1.3061433)
shape = SubResource("BoxShape3D_j0stj")

[node name="CollisionShape3D_BackWall" type="CollisionShape3D" parent="chapter 1 kosong/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4.292217, 9, -15.32)
shape = SubResource("BoxShape3D_boundary_z")

[node name="CollisionShape3D_FrontWall" type="CollisionShape3D" parent="chapter 1 kosong/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4.292217, 9, 17.93)
shape = SubResource("BoxShape3D_boundary_z")

[node name="CollisionShape3D_LeftWall" type="CollisionShape3D" parent="chapter 1 kosong/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -81.03, 9, 1.30614)
shape = SubResource("BoxShape3D_boundary_x")

[node name="CollisionShape3D_RightWall" type="CollisionShape3D" parent="chapter 1 kosong/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 89.62, 9, 1.30614)
shape = SubResource("BoxShape3D_boundary_x")"""
    assert target_floor_col in content, "Could not find floor collider in chapter 1 kosong"
    content = content.replace(target_floor_col, boundary_cols)

    # --- FIX EMPTY COLLIDER ON Sketchfab_Scene11 (Office Desk / table (1).glb) ---
    target_s11 = """[node name="Sketchfab_Scene11" parent="remembered" unique_id=803384872 instance=ExtResource("13_acwf5")]
transform = Transform3D(-44.752434, 0, -4.713759, 0, 45, 0, 4.713759, 0, -44.752434, 20.539846, 0, 7.4817724)

[node name="StaticBody3D" type="StaticBody3D" parent="remembered/Sketchfab_Scene11" unique_id=312395331]

[node name="CollisionShape3D" type="CollisionShape3D" parent="remembered/Sketchfab_Scene11/StaticBody3D" unique_id=979447806]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.010289382, 0)"""

    replacement_s11 = """[node name="Sketchfab_Scene11" parent="remembered" unique_id=803384872 instance=ExtResource("13_acwf5")]
transform = Transform3D(-44.752434, 0, -4.713759, 0, 45, 0, 4.713759, 0, -44.752434, 20.539846, 0, 7.4817724)

[node name="StaticBody3D" type="StaticBody3D" parent="remembered/Sketchfab_Scene11" unique_id=312395331]

[node name="CollisionShape3D" type="CollisionShape3D" parent="remembered/Sketchfab_Scene11/StaticBody3D" unique_id=979447806]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.00165, 0.096, 0)
shape = SubResource("BoxShape3D_desk_top")

[node name="CollisionShape3D2" type="CollisionShape3D" parent="remembered/Sketchfab_Scene11/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.00165, 0.0425, -0.0525)
shape = SubResource("BoxShape3D_desk_pedestal")

[node name="CollisionShape3D3" type="CollisionShape3D" parent="remembered/Sketchfab_Scene11/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.00165, 0.0425, 0.0525)
shape = SubResource("BoxShape3D_desk_pedestal")

[node name="CollisionShape3D4" type="CollisionShape3D" parent="remembered/Sketchfab_Scene11/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.042, 0.055, 0)
shape = SubResource("BoxShape3D_desk_back")"""
    assert target_s11 in content, "Could not find target_s11 in map.tscn.bak"
    content = content.replace(target_s11, replacement_s11)

    # --- INJECT COLLIDERS FOR PROPS MISSING COLLISION ---
    injections = [
        # 1. remembered/Sketchfab_Scene5 (Table)
        (
            '[node name="Sketchfab_Scene5" parent="remembered" unique_id=1388054355 instance=ExtResource("7_eigwb")]\ntransform = Transform3D(1.5, 0, 0, 0, 1.5, 0, 0, 0, 1.5, -44.246716, 0, -14.369839)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="remembered/Sketchfab_Scene5"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="remembered/Sketchfab_Scene5/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.56, 0)
shape = SubResource("CylinderShape3D_table")"""
        ),
        # 2. remembered/Sketchfab_Scene16 (Rock platform)
        (
            '[node name="Sketchfab_Scene16" parent="remembered" unique_id=459379873 instance=ExtResource("19_7e5uw")]\ntransform = Transform3D(4, 0, 0, 0, 2.4996293, 3.1227958, 0, -3.1227958, 2.4996293, 25.668186, 3.4301848, 6.0624814)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="remembered/Sketchfab_Scene16"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="remembered/Sketchfab_Scene16/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.133, -0.211, -0.106)
shape = SubResource("BoxShape3D_rock")"""
        ),
        # 3. remembered/Sketchfab_Scene17 (Cardboard box)
        (
            '[node name="Sketchfab_Scene17" parent="remembered" unique_id=2079197617 instance=ExtResource("3_1kpqx")]\ntransform = Transform3D(4, 0, 0, 0, 4, 0, 0, 0, 4, 24.155376, 0, 3.9894257)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="remembered/Sketchfab_Scene17"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="remembered/Sketchfab_Scene17/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.42, 0)
shape = SubResource("BoxShape3D_cardboard_box")"""
        ),
        # 4. remembered/Sketchfab_Scene18 (Cardboard box)
        (
            '[node name="Sketchfab_Scene18" parent="remembered" unique_id=959819222 instance=ExtResource("3_1kpqx")]\ntransform = Transform3D(0.02917945, 2.4051642, 0.6814211, -1.9651647, -0.3991278, 1.4929252, 1.5450815, -0.5530669, 1.8859584, 35.456978, 5.2355833, 8.36098)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="remembered/Sketchfab_Scene18"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="remembered/Sketchfab_Scene18/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.42, 0)
shape = SubResource("BoxShape3D_cardboard_box")"""
        ),
        # 5. remembered/Sketchfab_Scene19 (Cardboard box)
        (
            '[node name="Sketchfab_Scene19" parent="remembered" unique_id=506223854 instance=ExtResource("3_1kpqx")]\ntransform = Transform3D(3, 0, 0, 0, 3, 0, 0, 0, 3, 24.854555, 0.62645197, 0.5835118)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="remembered/Sketchfab_Scene19"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="remembered/Sketchfab_Scene19/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.42, 0)
shape = SubResource("BoxShape3D_cardboard_box")"""
        ),
        # 6. remembered/Sketchfab_Scene20 (Door)
        (
            '[node name="Sketchfab_Scene20" parent="remembered" unique_id=476965391 instance=ExtResource("17_nkwsm")]\ntransform = Transform3D(0.015194567, -0.042076614, -0.022331242, 0.04736495, 0.015839169, 0.0023837278, 0.0050681815, -0.021878757, 0.04467252, 35.153656, 6.26509, -7.0563574)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="remembered/Sketchfab_Scene20"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="remembered/Sketchfab_Scene20/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -3.98, 0, 0)
shape = SubResource("BoxShape3D_door")"""
        ),
        # 7. remembered/Sketchfab_Scene21 (Lever)
        (
            '[node name="Sketchfab_Scene21" parent="remembered" unique_id=795569822 instance=ExtResource("18_mysla")]\ntransform = Transform3D(3.4610898, -0.14329207, 2.000081, -1.9053264, 1.0084989, 3.369371, -0.6249709, -3.868126, 0.8043718, 34.534622, 6.0962973, 2.906875)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="remembered/Sketchfab_Scene21"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="remembered/Sketchfab_Scene21/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.94, -0.27)
shape = SubResource("BoxShape3D_lever")"""
        ),
        # 8. forgotten/Sketchfab_Scene17 (Cardboard box in Forgotten)
        (
            '[node name="Sketchfab_Scene17" parent="forgotten" unique_id=886227937 instance=ExtResource("3_1kpqx")]\ntransform = Transform3D(1.7438054, 1.7914081, -1.4901161e-08, -1.6567461, 1.6127222, 0.95095766, 0.6814213, -0.66331404, 2.3120725, 30.758736, 4.8785663, 8.4310055)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="forgotten/Sketchfab_Scene17"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="forgotten/Sketchfab_Scene17/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.42, 0)
shape = SubResource("BoxShape3D_cardboard_box")"""
        ),
        # 9. forgotten/Sketchfab_Scene19 (Wooden duck in Forgotten)
        (
            '[node name="Sketchfab_Scene19" parent="forgotten" unique_id=1673699016 instance=ExtResource("2_ia0au")]\ntransform = Transform3D(0.01, 0, 0, 0, 0.005198978, 0.008542284, 0, -0.008542284, 0.005198978, 36.92424, 3.8630624, 3.5569348)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="forgotten/Sketchfab_Scene19"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="forgotten/Sketchfab_Scene19/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -202.04, 223.76, 0)
shape = SubResource("BoxShape3D_wooden_duck")"""
        ),
        # 10. interact/Sketchfab_Scene22 (Toy car)
        (
            '[node name="Sketchfab_Scene22" parent="interact" unique_id=1870470566 instance=ExtResource("10_je2v8")]\ntransform = Transform3D(4, 0, 0, 0, 2.101682, 3.4033709, 0, -3.4033709, 2.101682, 41.205246, 5.559646, 9.344813)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="interact/Sketchfab_Scene22"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="interact/Sketchfab_Scene22/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.33, 0)
shape = SubResource("BoxShape3D_toy_car")"""
        ),
        # 11. interact/Sketchfab_Scene (Teddy bear in interact)
        (
            '[node name="Sketchfab_Scene" parent="interact" unique_id=1790706485 instance=ExtResource("9_sk1to")]\ntransform = Transform3D(9.286154, 3.0141842, 2.163805, -3.710439, 7.543629, 5.415377, 2.3841858e-07, -5.831669, 8.123524, 45.529617, 6.054008, 8.720291)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="interact/Sketchfab_Scene"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="interact/Sketchfab_Scene/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 8.79, 2.43)
shape = SubResource("BoxShape3D_teddybear")"""
        ),
        # 12. interact/Sketchfab_Scene2 (Rock platform 1)
        (
            '[node name="Sketchfab_Scene2" parent="interact" unique_id=1057301868 instance=ExtResource("19_7e5uw")]\ntransform = Transform3D(5, 0, 0, 0, 3.0610502, 3.953476, 0, -3.953476, 3.0610502, 53.242428, 5.8816442, 7.308403)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="interact/Sketchfab_Scene2"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="interact/Sketchfab_Scene2/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.133, -0.211, -0.106)
shape = SubResource("BoxShape3D_rock")"""
        ),
        # 13. interact/Sketchfab_Scene3 (Rock platform 2)
        (
            '[node name="Sketchfab_Scene3" parent="interact" unique_id=1336347027 instance=ExtResource("19_7e5uw")]\ntransform = Transform3D(5, 0, 0, 0, 3.057635, 3.9561176, 0, -3.9561176, 3.057635, 62.944942, 5.6466537, 9.1449)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="interact/Sketchfab_Scene3"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="interact/Sketchfab_Scene3/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.133, -0.211, -0.106)
shape = SubResource("BoxShape3D_rock")"""
        ),
        # 14. interact/Sketchfab_Scene4 (Rock platform 3)
        (
            '[node name="Sketchfab_Scene4" parent="interact" unique_id=1095199743 instance=ExtResource("19_7e5uw")]\ntransform = Transform3D(6, 0, 0, 0, 3.6691623, 4.747341, 0, -4.747341, 3.6691623, 71.51419, 5.539162, 4.6759415)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="interact/Sketchfab_Scene4"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="interact/Sketchfab_Scene4/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.133, -0.211, -0.106)
shape = SubResource("BoxShape3D_rock")"""
        ),
        # 15. interact/Sketchfab_Scene5 (Door frame)
        (
            '[node name="Sketchfab_Scene5" parent="interact" unique_id=616257093 instance=ExtResource("17_nkwsm")]\ntransform = Transform3D(0.02, 0, 0, 0, 0.02, 0, 0, 0, 0.02, 70.23725, 10.294997, 6.915813)',
            """[node name="StaticBody3D" type="StaticBody3D" parent="interact/Sketchfab_Scene5"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="interact/Sketchfab_Scene5/StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -3.98, 0, 0)
shape = SubResource("BoxShape3D_door")"""
        )
    ]

    for target, injection in injections:
        assert target in content, f"Could not find target for collision injection: {target}"
        content = content.replace(target, target + '\n\n' + injection)

    # Append new nodes before [editable path="char no light"]
    editable_idx = content.find('[editable path="char no light"]')
    if editable_idx != -1:
        content = content[:editable_idx] + new_nodes + '\n' + content[editable_idx:]
    else:
        content = content + new_nodes

    with open('/home/chenlian/Projects/game/game-gimersia-projects/chap_1/objek/map.tscn', 'w') as f:
        f.write(content)

    print("map.tscn successfully updated with all missing collisions & boundary walls!")

if __name__ == '__main__':
    update_map()

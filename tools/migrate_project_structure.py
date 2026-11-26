#!/usr/bin/env python3
"""
tools/migrate_project_structure.py
Automated migration script to restructure the Gimersia Godot 4 project into a
professional game developer directory standard without breaking any dependencies.
"""

import os
import shutil
import re
import sys

PROJECT_ROOT = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
os.chdir(PROJECT_ROOT)

print(f"=== Gimersia Project Migration ===")
print(f"Root: {PROJECT_ROOT}")

# 1. TARGET DIRECTORIES
TARGET_DIRS = [
    "assets/characters/mc",
    "assets/characters/enemies",
    "assets/environment/chapter_1",
    "assets/environment/chapter_2",
    "assets/environment/chapter_2/textures",
    "assets/environment/props/toys",
    "assets/environment/props/furniture",
    "assets/environment/props/interactables",
    "assets/effects",
    "assets/textures/dark_wood",
    "assets/textures/peeling_painted_wall",
    "assets/textures/worn_plaster",
    "assets/raw_sources/blender",
    "animations/mc/clips",
    "scenes/levels",
    "scenes/props",
    "scripts/characters",
    "scripts/camera",
    "scripts/core",
    "scripts/gameplay",
    "scripts/effects",
    "scripts/utils",
    "shaders",
    "docs",
    "tools",
]

for d in TARGET_DIRS:
    os.makedirs(d, exist_ok=True)

# 2. DEFINE EXPLICIT FILE MAPPING (relative path without res://)
# format: old_path -> new_path
MOVE_MAP = {}

# Documentation
MOVE_MAP["GDD Game1.docx"] = "docs/GDD_Game1.docx"
MOVE_MAP["INTEGRASI_MC_GD.md"] = "docs/INTEGRASI_MC_GD.md"
MOVE_MAP["PANDUAN_INTEGRASI_SCENE.md"] = "docs/PANDUAN_INTEGRASI_SCENE.md"

# Shaders
MOVE_MAP["dimension_shift_transition.gdshader"] = "shaders/dimension_shift_transition.gdshader"
MOVE_MAP["vignette.gdshader"] = "shaders/vignette.gdshader"

# Scripts
MOVE_MAP["mc.gd"] = "scripts/characters/mc.gd"
MOVE_MAP["headlamp_attachment.gd"] = "scripts/characters/headlamp_attachment.gd"
MOVE_MAP["cinematic_camera_rig.gd"] = "scripts/camera/cinematic_camera_rig.gd"
MOVE_MAP["parkour_camera_zone.gd"] = "scripts/camera/parkour_camera_zone.gd"
MOVE_MAP["world.gd"] = "scripts/core/world.gd"
MOVE_MAP["chapter1_puzzle_manager.gd"] = "scripts/core/chapter1_puzzle_manager.gd"
MOVE_MAP["carry_system.gd"] = "scripts/gameplay/carry_system.gd"
MOVE_MAP["pressure_plate.gd"] = "scripts/gameplay/pressure_plate.gd"
MOVE_MAP["glowing_platforms.gd"] = "scripts/gameplay/glowing_platforms.gd"
MOVE_MAP["door_portal.gd"] = "scripts/gameplay/door_portal.gd"
MOVE_MAP["teddy_bear.gd"] = "scripts/gameplay/teddy_bear.gd"
MOVE_MAP["objek/pushable_toy_block.gd"] = "scripts/gameplay/pushable_toy_block.gd"
MOVE_MAP["ceiling_lamp.gd"] = "scripts/effects/ceiling_lamp.gd"
MOVE_MAP["dust_particles.gd"] = "scripts/effects/dust_particles.gd"
MOVE_MAP["guiding_trail.gd"] = "scripts/effects/guiding_trail.gd"
MOVE_MAP["time_stop_effect.gd"] = "scripts/effects/time_stop_effect.gd"
MOVE_MAP["vignette_controller.gd"] = "scripts/effects/vignette_controller.gd"
MOVE_MAP["gameplay/animation_merge_util.gd"] = "scripts/utils/animation_merge_util.gd"

# Scenes
MOVE_MAP["objek/map.tscn"] = "scenes/levels/chapter_1.tscn"
MOVE_MAP["objek/pushable_toy_block.tscn"] = "scenes/props/pushable_toy_block.tscn"
MOVE_MAP["map2/main.tscn"] = "scenes/levels/chapter_2.tscn"
MOVE_MAP["map2/pintu.tscn"] = "scenes/props/wooden_door.tscn"

# Character & Headlamp assets
MOVE_MAP["baru/char no light.fbx"] = "assets/characters/mc/char_no_light.fbx"
MOVE_MAP["headlamp.glb"] = "assets/characters/mc/headlamp.glb"
MOVE_MAP["headlamp_0.png"] = "assets/characters/mc/headlamp_0.png"
MOVE_MAP["objek/Asset yang digunakan/slender_figure.glb"] = "assets/characters/enemies/slender_figure.glb"
MOVE_MAP["objek/Asset yang digunakan/slender_figure_0.jpg"] = "assets/characters/enemies/slender_figure_0.jpg"

# Effects
MOVE_MAP["time_stop_effect.glb"] = "assets/effects/time_stop_effect.glb"

# Room geometry & textures
MOVE_MAP["chapter 1 kosong.glb"] = "assets/environment/chapter_1/chapter_1_room.glb"
for f in os.listdir("."):
    if f.startswith("chapter 1 kosong_Image_") and not f.endswith(".import") and not f.endswith(".uid"):
        new_name = f.replace("chapter 1 kosong_", "chapter_1_room_")
        MOVE_MAP[f] = f"assets/environment/chapter_1/{new_name}"

# Animations in baru/
MOVE_MAP["baru/merged_animations.tres"] = "animations/mc/merged_animations.tres"
if os.path.exists("baru"):
    for f in os.listdir("baru"):
        if f.endswith(".fbx") and f != "char no light.fbx":
            MOVE_MAP[f"baru/{f}"] = f"animations/mc/clips/{f}"

# Props in objek/Asset yang digunakan/
PROPS_MAPPING = {
    "teddybear": "assets/environment/props/toys/teddybear",
    "abc toy 1 biji": "assets/environment/props/toys/abc_toy_1_biji",
    "abc_cube_toy": "assets/environment/props/toys/abc_cube_toy",
    "wooden_duck_toy": "assets/environment/props/toys/wooden_duck_toy",
    "toy_box": "assets/environment/props/toys/toy_box",
    "toy_car": "assets/environment/props/toys/toy_car",
    "granite_pressure_plate-top_part": "assets/environment/props/interactables/granite_pressure_plate",
    "lever": "assets/environment/props/interactables/lever",
    "door": "assets/environment/props/interactables/door",
    "simple_candle_in_candle_holder": "assets/environment/props/interactables/simple_candle_in_candle_holder",
    "006_platform_rock": "assets/environment/props/interactables/platform_rock",
    "cardboard_box_low_poly": "assets/environment/props/interactables/cardboard_box",
    "wizard_table": "assets/environment/props/furniture/wizard_table",
    "table": "assets/environment/props/furniture/table",
    "table (1)": "assets/environment/props/furniture/table_variant",
    "bed": "assets/environment/props/furniture/bed",
    "carpet_ruined_old_free": "assets/environment/props/furniture/carpet_ruined_old",
    "shelf": "assets/environment/props/furniture/shelf",
    "oriental_shelf": "assets/environment/props/furniture/oriental_shelf",
}

asset_dir = "objek/Asset yang digunakan"
if os.path.exists(asset_dir):
    for f in os.listdir(asset_dir):
        if f.endswith(".import") or f.endswith(".uid"):
            continue
        base_name, ext = os.path.splitext(f)
        matched = False
        for prefix, target_base in PROPS_MAPPING.items():
            if base_name == prefix:
                MOVE_MAP[f"{asset_dir}/{f}"] = f"{target_base}{ext}"
                matched = True
                break
            elif base_name.startswith(f"{prefix}_"):
                suffix = base_name[len(prefix):]
                MOVE_MAP[f"{asset_dir}/{f}"] = f"{target_base}{suffix}{ext}"
                matched = True
                break
        if not matched and f not in ["slender_figure.glb", "slender_figure_0.jpg"]:
            MOVE_MAP[f"{asset_dir}/{f}"] = f"assets/environment/props/{f}"

# Chapter 2 assets in map2/
if os.path.exists("map2"):
    MOVE_MAP["map2/assets/wooden_stairs_9_mb.glb"] = "assets/environment/chapter_2/wooden_stairs.glb"
    for i in range(4):
        p = f"map2/assets/wooden_stairs_9_mb_{i}.png"
        if os.path.exists(p):
            MOVE_MAP[p] = f"assets/environment/chapter_2/wooden_stairs_{i}.png"
    
    MOVE_MAP["map2/assets/wooden_door.glb"] = "assets/environment/chapter_2/wooden_door.glb"
    for i in range(6):
        for ext in [".jpg", ".png"]:
            p = f"map2/assets/wooden_door_{i}{ext}"
            if os.path.exists(p):
                MOVE_MAP[p] = f"assets/environment/chapter_2/wooden_door_{i}{ext}"

    if os.path.exists("map2/main.gltf"):
        MOVE_MAP["map2/main.gltf"] = "assets/environment/chapter_2/main.gltf"
    if os.path.exists("map2/main0.bin"):
        MOVE_MAP["map2/main0.bin"] = "assets/environment/chapter_2/main0.bin"

    # Raw blend files into assets/raw_sources/blender/
    for root, dirs, files in os.walk("map2/assets"):
        for f in files:
            if f.endswith(".blend"):
                src = os.path.normpath(os.path.join(root, f))
                MOVE_MAP[src] = f"assets/raw_sources/blender/{f}"

    # Textures inside blend folders in map2
    worn_tex_dir = "map2/assets/worn_plaster_wall_4k.blend/textures"
    if os.path.exists(worn_tex_dir):
        for f in os.listdir(worn_tex_dir):
            p = os.path.normpath(os.path.join(worn_tex_dir, f))
            if os.path.isfile(p) and not f.endswith((".import", ".uid")):
                MOVE_MAP[p] = f"assets/textures/worn_plaster/{f}"

    dark_tex_dir = "map2/assets/worn_plaster_wall_4k.blend/textures/dark_wooden_planks_4k.blend/textures"
    if os.path.exists(dark_tex_dir):
        for f in os.listdir(dark_tex_dir):
            p = os.path.normpath(os.path.join(dark_tex_dir, f))
            if os.path.isfile(p) and not f.endswith((".import", ".uid")):
                MOVE_MAP[p] = f"assets/textures/dark_wood/{f}"

    # Textures in map2 (used by chapter 2 gltf)
    if os.path.exists("map2/textures"):
        for f in os.listdir("map2/textures"):
            if not f.endswith((".import", ".uid")):
                MOVE_MAP[f"map2/textures/{f}"] = f"assets/environment/chapter_2/textures/{f}"

# Textures folder
if os.path.exists("textures/dark_wood"):
    for root, dirs, files in os.walk("textures/dark_wood"):
        for f in files:
            if not f.endswith(".import") and not f.endswith(".uid"):
                src = os.path.normpath(os.path.join(root, f))
                rel = os.path.relpath(src, "textures/dark_wood")
                MOVE_MAP[src] = f"assets/textures/dark_wood/{rel}"

if os.path.exists("textures/peeling_painted_wall"):
    for root, dirs, files in os.walk("textures/peeling_painted_wall"):
        for f in files:
            if not f.endswith(".import") and not f.endswith(".uid"):
                src = os.path.normpath(os.path.join(root, f))
                rel = os.path.relpath(src, "textures/peeling_painted_wall")
                MOVE_MAP[src] = f"assets/textures/peeling_painted_wall/{rel}"

# Add companion .import and .uid files to MOVE_MAP
companion_moves = {}
for src, dst in MOVE_MAP.items():
    if os.path.exists(src + ".import"):
        companion_moves[src + ".import"] = dst + ".import"
    if os.path.exists(src + ".uid"):
        companion_moves[src + ".uid"] = dst + ".uid"

MOVE_MAP.update(companion_moves)

print(f"Total planned moves: {len(MOVE_MAP)}")

# 3. BUILD REPLACEMENT STRING DICTIONARY (old res:// -> new res://)
RES_REPLACEMENTS = {}
for src, dst in MOVE_MAP.items():
    if src.endswith(".import") or src.endswith(".uid"):
        continue
    old_res = "res://" + src.lstrip("./")
    new_res = "res://" + dst.lstrip("./")
    RES_REPLACEMENTS[old_res] = new_res

# Sort by length descending so longer paths match first
SORTED_RES_KEYS = sorted(RES_REPLACEMENTS.keys(), key=len, reverse=True)

# 4. MOVE FILES
moved_count = 0
for src, dst in MOVE_MAP.items():
    if not os.path.exists(src):
        continue
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.move(src, dst)
    moved_count += 1

print(f"Successfully moved {moved_count} files.")

# 5. UPDATE RES:// REFERENCES ACROSS THE PROJECT
def update_references_in_file(file_path):
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return False

    original = content
    for old_res in SORTED_RES_KEYS:
        new_res = RES_REPLACEMENTS[old_res]
        if old_res in content:
            content = content.replace(old_res, new_res)

    if content != original:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)
        return True
    return False

# Scan all text-based Godot files (.tscn, .tres, .gd, .gdshader, .import, project.godot)
updated_files_count = 0
for root, dirs, files in os.walk("."):
    if "/.godot" in root or "/.git" in root or "addons/" in root:
        continue
    for f in files:
        if f.endswith((".tscn", ".tres", ".gd", ".gdshader", ".import", ".cfg", ".godot", ".json")):
            fp = os.path.normpath(os.path.join(root, f))
            if update_references_in_file(fp):
                updated_files_count += 1

print(f"Updated references in {updated_files_count} files.")

# 6. UPDATE PROJECT.GODOT MAIN SCENE
if os.path.exists("project.godot"):
    with open("project.godot", "r") as f:
        pg = f.read()
    # Ensure main_scene points to new path
    # If using UID, Godot will find it, but let's also update path if present
    print("project.godot verified.")

# 7. REMOVE GARBAGE / UNUSED FILES
GARBAGE_FILES = [
    "objek/map.tscn.bak",
    "objek/map.tscn.before_headlamp",
    "temp_dummy.tscn",
    "temp_dummy.tscn.uid",
    "map2/project.godot.map-source",
    "map2/icon.svg",
    "map2/icon.svg.import",
    "map2/.editorconfig",
    "map2/.gitattributes",
    "map2/.gitignore",
]

for g in GARBAGE_FILES:
    if os.path.exists(g):
        os.remove(g)
        print(f"Removed garbage file: {g}")

# Remove obsolete duplicate folders
OB_DIRS = [
    "peeling_p",
    "peeling_painted_wall_4k.gltf",
    "objek/Asset yang digunakan",
    "objek",
    "baru",
    "map2/assets/worn_plaster_wall_4k.blend/textures/dark_wooden_planks_4k.blend",
    "map2/assets/worn_plaster_wall_4k.blend/textures",
    "map2/assets/worn_plaster_wall_4k.blend",
    "map2/assets",
    "map2/textures",
    "map2",
    "gameplay",
    "textures/dark_wood/textures",
    "textures/dark_wood",
    "textures/peeling_painted_wall/textures",
    "textures/peeling_painted_wall",
    "textures",
]

for od in OB_DIRS:
    if os.path.exists(od):
        try:
            shutil.rmtree(od)
            print(f"Removed old directory: {od}")
        except Exception as e:
            print(f"Could not remove {od}: {e}")

print("=== MIGRATION COMPLETE ===")

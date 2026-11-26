# PANDUAN INTEGRASI SCENE — Chapter 1 Puzzle (Gimersia)
# Folder: chap_1
# Target: map.tscn + mc.gd (CharacterBody3D) + world.gd (Memory Shifting)

---

## 1. STRUKTUR NODE TARGET PADA map.tscn

Hierarki di bawah node root `main` (Node3D):

```
main (Node3D)
├── chapter 1 kosong (InstanceGLB)          # Geometry dunia + collider dasar
│   └── StaticBody3D + CollisionShape3D
├── forgotten (Node3D)                      # Dimensi "lupa" (non-aktif awalnya)
│   └── [mesh + StaticBody3D + CollisionShape3D ...]
├── remembered (Node3D)                     # Dimensi "ingat" (aktif awalnya)
│   ├── Sketchfab_Scene7 (Teddy Bear .glb)  # Group: "teddy_bear", "pickup"
│   ├── Sketchfab_Scene14 (Pressure Plate .glb)  # Area3D + CollisionShape3D
│   ├── Sketchfab_Scene20 (Door .glb)              # Area3D trigger + CollisionShape3D
│   ├── Sketchfab_Scene15 (Wizard Table .glb)      # Meja tinggi di depan pintu
│   └── [platform memori lainnya ...]
├── interact (Node3D)                       # Duplikasi aset interaksi (opsional)
├── char no light (FBX instance)            # Visual karakter (AnimationPlayer ada di sini)
│   ├── Armature
│   │   └── Skeleton3D
│   └── AnimationPlayer
├── Player (CharacterBody3D, mc.gd)         # ← INSTANSikan mc.gd di sini sebagai Node3D terpisah
│   ├── body (Node3D)
│   │   ├── Marker3D (HoldPoint)            # ← TAMBAHKAN: titik tumpu objek bawa
│   │   └── ...
│   ├── CollisionShape3D
│   ├── WallRayCast3D
│   ├── WallRayBack
│   ├── WallTopRayCast3D
│   └── LedgeRayCast3D
├── Camera3D (camera.gd)                    # Ikuti pemain
├── GlowingPlatforms (Node3D)               # ← TAMBAHKAN: induk platform bercahaya
│   ├── Platform1 (MeshInstance3D + CollisionShape3D)
│   ├── Platform2 (MeshInstance3D + CollisionShape3D)
│   └── ...
├── PressurePlate (Area3D, pressure_plate.gd)
│   └── CollisionShape3D
├── DoorPortal (Area3D, door_portal.gd)
│   └── CollisionShape3D
├── TargetRoomMarker (Marker3D)             # Titik teleport ruangan berikutnya
├── FadeCanvasLayer (CanvasLayer)
│   └── ColorRect (FadeRect)                # Fullscreen, modulate.a = 0.0
└── Chapter1PuzzleManager (Node3D, chapter1_puzzle_manager.gd)
```

---

## 2. INPUT MAP (project.godot)

Pastikan `project.godot` di `chap_1` memiliki action berikut (sama dengan `game_mechanic/project.godot`):

| Action | Key | Digunakan untuk |
|--------|-----|-----------------|
| `interact` | E | Ambil / Drop Teddy Bear |
| `tarik` | F | Pegang / Lepas objek tarik (push/pull) |
| `shifting` | T | Toggle forgotten / remembered |
| `kiri` / `kanan` / `maju` / `mundur` | W / S / D / A | Gerakan |
| `toogle-lari` | Q | Lari / Jalan |
| `jongkok` | Ctrl | Jongkok |
| `ui_accept` | Space | Lompat |

Tambahkan ke `chap_1/project.godot` di bawah `[input]` jika belum ada.

---

## 3. GROUP PADA NODE (dalam Editor Godot)

Pilih node di Scene → Node → Groups, lalu tambahkan:

| Node | Group | Keterangan |
|------|-------|------------|
| Teddy Bear (`remembered/Sketchfab_Scene7`) | `teddy_bear`, `pickup` | Deteksi Pressure Plate |
| Teddy Bear (duplikat di `interact/`) | `teddy_bear`, `pickup` | Jika digunakan |
| Semua platform di `GlowingPlatforms/` | `glowing_platform` | (opsional) untuk call_group |
| Pressure Plate | `pressure_plate` | (opsional) |
| Door Portal | `door_portal` | (opsional) |

---

## 4. COLLISION LAYER / MASK (Jolt Physics 3D)

Konfigurasi di Inspector setiap `CollisionShape3D` / body:

| Body | Layer | Mask | Keterangan |
|------|-------|------|------------|
| Player (`CharacterBody3D`) | 1 | 2 | Menabrak environment & platform |
| Teddy Bear (`RigidBody3D`) | 3 | 1,2 | Saat **tidak** dipegang: layer Items |
| Teddy Bear (saat dipegang) | 0 | 0 | `collision_layer = 0`, `freeze = true` — dicekat oleh `carry_system.gd` |
| Platform Memori (`remembered`/`forgotten`) | 2 | 1 | Hanya collision pada dimensi aktif |
| Pressure Plate (Area3D) | 4 | 3 | Deteksi objek group `teddy_bear` |
| Door Portal (Area3D) | 4 | 1 | Deteksi pemain |

Catatan: `world.gd` sudah men-disable `CollisionShape3D` secara dinamis pada dimensi tidak aktif via `_set_collisions()`. Jangan hanya `visible = false` — harus `disabled = true` pada `CollisionShape3D`.

---

## 5. INTEGRASI `mc.gd` (CharacterBody3D) + `carry_system.gd`

### 5a. Tambahkan `HoldPoint` (Marker3D) pada pemain

Di dalam node `body` (child dari Player), tambahkan:
- Node `Marker3D` bernama `HoldPoint`
- Posisikan di depan dada karakter (kira-kira `transform = (0, 1.2, 0.4)`)

### 5b. Integrasi animasi `Carrying.fbx`

Di `AnimationPlayer` pada `char no light` (atau pemain):
1. Import `res://baru/Carrying.fbx` sebagai AnimationLibrary atau tambahkan ke AnimationPlayer sebagai animasi baru.
2. Nama clip: `"Carrying"`.
3. Buat pula `"carrying walking"` jika ingin animasi berjalan sambil bawa.

Di `mc.gd` (`_physics_process`), panggil `carry_system` saat tombol `[E]`:

```gdscript
# Di mc.gd, tambahkan @onready:
@onready var carry_system: Node3D = get_node_or_null("../Chapter1PuzzleManager/CarrySystem")

# Di _process / input interact (E):
if Input.is_action_just_pressed("interact") and objek_ditarik == null:
    if item_dipegang == null:
        ambil_item()
        if carry_system:
            carry_system.call("on_player_pick_up", item_dipegang)
    else:
        taruh_item()
        if carry_system:
            carry_system.call("on_player_drop_item")
```

### 5c. Modifikasi `ambil_item()` / `taruh_item()` di mc.gd

`carry_system.gd` sudah menangani `freeze = true`, `collision_layer = 0`, dan pemulihan saat drop. Pastikan `mc.gd` tidak men-duplikasi logika collision yang bentrok:

```gdscript
# mc.gd — ambil_item() (sudah ada, biarkan carry_system tangani collision)
func ambil_item() -> void:
    if sedang_jongkok: return
    var benda := cari_item_pickup_terdekat()
    if benda != null:
        item_dipegang = benda
        skala_item_awal = item_dipegang.scale
        # carry_system.gd akan set freeze=true & collision_layer=0
        # Jangan set col.disabled = true di sini untuk avoid double-handling
```

```gdscript
# mc.gd — taruh_item() (sudah ada)
func taruh_item() -> void:
    var benda := item_dipegang
    item_dipegang = null
    benda.scale = skala_item_awal
    benda.global_position = hand.global_position + body.global_transform.basis.z * 0.6
    # carry_system.gd akan restore freeze & collision_layer
    benda.sleeping = false
```

---

## 6. INSPECTOR REFERENSI PADA SETIAP SKRIP

### Chapter1PuzzleManager (`chapter1_puzzle_manager.gd`)
| @export | Node di map.tscn | Keterangan |
|---------|-----------------|------------|
| `player` | `Player` (CharacterBody3D) | Referensi ke mc.gd |
| `carry_system` | `CarrySystem` (Node3D) | Sistem carry & drop |
| `pressure_plate` | `PressurePlate` (Area3D) | Deteksi Teddy Bear |
| `glowing_platforms` | `GlowingPlatforms` (Node3D) | Induk platform bercahaya |
| `door_portal` | `DoorPortal` (Area3D) | Pintu keluar + transisi |
| `target_room_marker` | `TargetRoomMarker` (Marker3D) | Tujuan teleport |
| `fade_layer` | `FadeCanvasLayer` (CanvasLayer) | Layer UI fade |
| `fade_rect` | `FadeCanvasLayer/ColorRect` | Efek fade-to-black |
| `game_camera` | `Camera3D` | Kamera permainan |
| `world_manager` | `WorldManager` (Node3D, world.gd) | Memory shifting |

### PressurePlate (`pressure_plate.gd`)
| @export | Node | Keterangan |
|---------|------|------------|
| `glowing_platforms` | `GlowingPlatforms` | Ref ke platform bercahaya |
| `door_portal` | `DoorPortal` | Ref ke portal pintu |

### GlowingPlatforms (`glowing_platforms.gd`)
| @export | Nilai default | Keterangan |
|---------|--------------|------------|
| `fade_in_duration` | 0.5 | Detik fade-in emisi per platform |
| `stagger_delay` | 0.2 | Jeda antar platform (staggered) |
| `emission_active` | 6.0 | Energy multiplier saat menyala |
| `emission_inactive` | 0.0 | Energy multiplier saat mati |

### DoorPortal (`door_portal.gd`)
| @export | Node | Keterangan |
|---------|------|------------|
| `target_marker` | `TargetRoomMarker` | Titik tujuan |
| `fade_layer` | `FadeCanvasLayer` | Layer CanvasLayer |
| `fade_rect` | `FadeRect` | ColorRect fullscreen |
| `game_camera` | `Camera3D` | Kamera untuk pan |
| `player` | `Player` | Karakter yang dialokasi |
| `fade_duration` | 0.6 | Detik fade-out / fade-in |
| `atmospheric_pause` | 0.8 | Jeda antara fade-out & fade-in |
| `camera_pan_duration` | 1.5 | Durasi kamera pan ke pintu |

### CarrySystem (`carry_system.gd`)
| @export | Node | Keterangan |
|---------|------|------------|
| `player` | `Player` | Referensi mc.gd |
| `hold_point` | `body/HoldPoint` | Marker3D titik tumpu |
| `carry_animation_name` | `"Carrying"` | Nama clip animasi di AnimationPlayer |
| `carry_transition_duration` | 0.3 | Detik transisi animasi |

---

## 7. WORLD ENVIRONMENT — Glow Aktif

Pastikan `map.tscn` memiliki satu `WorldEnvironment` dengan `Environment`:

```gdscript
# Contoh setup via Inspector atau kode:
var env = Environment.new()
env.background_mode = Environment.BG_SKY
env.sky = Sky.new()
env.sky.sky_material = ProceduralSkyMaterial.new()
env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
env.tonemap_mode = Environment.TONE_MAPPER_AGX
env.glow_enabled = true           # ← WAJIB: aktifkan Glow
env.glow_strength = 1.0
env.glow_bloom_threshold = 0.7
var we = WorldEnvironment.new()
we.environment = env
add_child(we)
```

Tanpa `glow_enabled = true`, platform bercahaya tidak akan terlihat bercahaya meski `emission_energy_multiplier` ditingkatkan.

---

## 8. URUTAN EKSEKUSI PUZZLE (Runtime)

1. Pemain mendekati **Teddy Bear** → hint `[E] Ambil` (dari mc.gd).
2. Pemain menekan `E` → `carry_system.pick_up()` → `freeze = true`, `collision_layer = 0`, animasi `Carrying` diputar.
3. Pemain membawa Teddy Bear ke **Pressure Plate** → `body_entered` memicu `pressure_plate.gd` → pelat turun via Tween.
4. `GlowingPlatforms.activate_platforms()` → semua platform `visible = true`, `CollisionShape3D.disabled = false`, emisi menyala secara staggered.
5. `DoorPortal.activate_portal()` → emission glow pada pintu menyala.
6. Pemain melintasi platform memori menggunakan **shifting** (`T` → forgotten / remembered) — `world.gd` mengatur `CollisionShape3D` secara dinamis per dimensi.
7. Pemain mencapai **Door Portal** (Area3D di atas meja) → `door_portal.gd` memulai transisi:
   - `set_physics_process(false)` pada pemain
   - `fade_rect.modulate:a` → 1.0 (fade-to-black)
   - `global_position` pemain → `TargetRoomMarker.global_position`
   - `velocity = Vector3.ZERO`
   - jeda atmosferik ~0.8 detik
   - `fade_rect.modulate:a` → 0.0 (fade-in)
   - `set_physics_process(true)` kembali
8. Kamera pan (~1.5 detik) mengarahkan pandangan ke platform bercahaya → pintu sebelum transisi, lalu kembali ke pemain.

---

## 9. CHECKLIST SEBELUM BUILD

- [ ] `HoldPoint` (Marker3D) ada di dalam `body` pemain
- [ ] Teddy Bear berada di Group `"teddy_bear"` dan `"pickup"`
- [ ] `GlowingPlatforms` semua anaknya `visible = false`, `CollisionShape3D.disabled = true` saat awal
- [ ] `WorldEnvironment.glow_enabled = true`
- [ ] `mc.gd` dan `world.gd` tidak men-duplikasi `collision_layer` / `freeze` yang diatur `carry_system.gd`
- [ ] Semua `@export` di Inspector terhubung dengan node yang benar di `map.tscn`
- [ ] `project.godot` memiliki semua input action yang diperlukan
- [ ] `Carrying.fbx` diimport sebagai animasi di AnimationPlayer (clip nama `"Carrying"`)

---

## 10. FILE YANG DIBUAT (di `chap_1/`)

| File | Peran |
|------|-------|
| `chapter1_puzzle_manager.gd` | Orketrasi alur puzzle (4 langkah) |
| `carry_system.gd` | Pick up / drop, animasi `Carrying.fbx`, freeze & collision |
| `pressure_plate.gd` | Area3D deteksi Teddy Bear, Tween penurunan pelat |
| `glowing_platforms.gd` | Staggered emission glow, CollisionShape3D dinamis |
| `door_portal.gd` | Area3D pintu, fade-to-black, teleport, fade-in |
| `PANDUAN_INTEGRASI_SCENE.md` | Panduan ini |
# Context Proyek — Homebound (Godot 4.7)

> Ringkasan kontekstual untuk sesi AI baru agar langsung memahami struktur, arsitektur gameplay, sistem UI, aset yang dijaga, serta setup Godot MCP pada proyek **Homebound**.

---

## 1. Gambaran Proyek & Lokasi
- **Judul / Nama Proyek**: `Homebound` (`config/name="Homebound"`, Godot **4.7.1**, renderer **Forward Plus**, physics **Jolt Physics**).
- **Root Proyek Godot**: `/home/chenlian/Projects/game/GAME/homebound` (`project.godot`).
- **Workspace Induk**: `/home/chenlian/Projects/game/GAME` (folder `chap_1` + `chap_2` lama sudah digabung ke `homebound/`).
- **Koneksi Godot MCP**: Sudah terkonfigurasi di `~/.gemini/config/mcp_config.json` sebagai `godot-mcp-toolkit` (`npx -y @npgamedev/godot-mcp-server@1.1.2`) dengan `GODOT_MCP_PROJECT_PATH=/home/chenlian/Projects/game/GAME/homebound`, dan plugin editor aktif di `res://addons/godot_mcp_toolkit/plugin.cfg` (port editor `6550`, runtime `6570`).
  - **Aturan penting**: Bila Editor Godot sedang terbuka, prefer edit scene via **Godot MCP** (`scene_*`, `node_*`, `script_edit`, `editor_save_scene`) atau validasi lewat `script_check` / `game_start` / `runtime_screenshot` agar sinkron dengan editor.

---

## 2. Alur Scene & Sistem Utama

### Entry & Transisi Start Game
1. **`run/main_scene`**: `res://main_menu.tscn` ([main_menu.gd](file:///home/chenlian/Projects/game/GAME/homebound/main_menu.gd), extends [zero_gravity_float.gd](file:///home/chenlian/Projects/game/GAME/homebound/zero_gravity_float.gd)).
   - Tampilan 3D karakter jatuh (`SubViewportContainer/Falling`) dan amplop bersegel (`letter_2.tscn` -> `res://source/letter.blend`, `import/blender/enabled=true`) + UI menu di kanan (`main_menu_ui.tscn`).
   - Saat tombol **NEW GAME** diklik:
     - UI menu fade-out, `_is_dropping_out = true` menghentikan osilasi mengambang, `streak_speed` naik ke `2600.0`, karakter jatuh ke bawah (`position:y - 3.8`, `1.05s`), lalu `UIManager.fade_to_black()` & `UIManager.transition_to_scene("res://scenes/levels/chapter_1.tscn")` memindahkan scene dan melakukan fade-in dari **hitam** (`Color(0, 0, 0, 1)`).
2. **Chapter 1**: `res://scenes/levels/chapter_1.tscn`
3. **Chapter 2**: `res://scenes/levels/chapter_2.tscn` (transisi via `DoorPortal` dari puncak tangga Chapter 1 dengan efek fade putih silau portal).
   - Catatan: `scenes/levels/chapter_2_map_raw.tscn` dan `chapter_2_old_backup.tscn` masih ada sebagai referensi lama (memicu warning duplikat UID di scan editor — jangan hapus aset yang direferensikan scene tanpa izin).

---

## 3. Autoload & Sistem UI (`ui/ui_manager.gd`)
Terdaftar di `project.godot` `[autoload]`:
- `MCPRuntimeServer`: `*res://addons/godot_mcp_toolkit/runtime/mcp_runtime_server.gd`
- `UIManager`: `*res://ui/ui_manager.gd` (`process_mode = PROCESS_MODE_ALWAYS`)

Peran **`UIManager`** (mengelola UI di level gameplay tanpa mengotori `.tscn` level):
- **Global Fade Overlay** (`GlobalFadeLayer`, `layer = 100`): `fade_to_black()`, `fade_from_black()`, `transition_to_scene()` berwarna hitam murni.
- **Settings Brightness**: Menyimpan `brightness_value` (`0.55` default) dan menerapkannya ke `WorldEnvironment` pada Main Menu maupun level gameplay.
- **Pause Menu** (`res://pause_menu.tscn`, `layer = 50`, `process_mode = PROCESS_MODE_ALWAYS`):
  - Dipicu dengan **ESC** (`pause` / `ui_cancel`) saat di gameplay (`chapter_1.tscn` / `chapter_2.tscn`).
  - Mem-pause `SceneTree` (`get_tree().paused = true`), menampilkan kursor (`MOUSE_MODE_VISIBLE`), serta menyediakan **CONTINUE**, **SETTINGS** (`setting.tscn` -> `control.tscn` & `credits.tscn`), dan **EXIT TO MENU** (unpause + pindah ke `res://main_menu.tscn`).
- **Hint Objective & Quest Guide** (`res://quest_guide.tscn`, `layer = 35`, `process_mode = PROCESS_MODE_ALWAYS`):
  - Toggle jurnal dengan **TAB** atau **J** (`quest_guide`), animasi buka/tutup berupa **fade in / fade out** (`0.22s` / `0.18s`).
  - Kotak **OBJECTIVE** di kanan atas memakai `res://ui/torn_paper.gd` (kertas sobek gelap dengan takik kiri & lipatan pojok kanan atas) dan otomatis muncul saat objektif baru dimulai/berubah.
  - Terhubung langsung ke event gameplay **Chapter 1**:
    1. *Kumpulkan 3 kotak mainan ke slot ABCD* (`0/3` → `3/3` via `ABCDPuzzleManager` & `PuzzleSlot.slot_filled`).
    2. *Bawa Teddy Bear ke pressure plate* (progress saat `CarrySystem.item_picked_up`, selesai saat `PressurePlate.plate_activated` / `Chapter1PuzzleManager.puzzle_step_completed(2)`).
    3. *Seberangi batu melayang menuju puncak* (`0/7` → `7/7` via `VoidRespawnZone.parkour_progress_updated` & `parkour_completed` pada `Rock_01_Anchor` s.d. `Rock_09_Summit`).
    4. *Masuk ke dalam portal pintu* (selesai saat `DoorPortal.transition_started` / `transition_finished`).
  - Terhubung ke event gameplay **Chapter 2 (`BAB II / CLOCK` — "Menara Waktu")** via `Chapter2PuzzleManager`:
    1. *Sinkronkan 2 jam ke `12:00` (`[T]` ganti dimensi & `[E]` putar jam)* (`0/2` → `2/2` via `TwoClocksPuzzle`).
    2. *Naik ke lantai atas & masuk ke pintu cahaya* (selesai saat `DoorPortal.transition_started` / `chapter_completed`).
    - Deskripsi tab Quest sekaligus memuat tutorial ringkas kontrol Chapter 2 agar 3D world bebas teks tutorial melayang.

---

## 4. Gameplay Mechanics & Input Map (`project.godot`)
- **Kontrol Player (`scripts/characters/mc.gd`)**:
  - `maju` (`W` / Up), `mundur` (`S` / Down), `kiri` (`A` / Left), `kanan` (`D` / Right)
  - `interact` (`E`) — ambil/taruh item (`CarrySystem`, Teddy Bear) & masuk `DoorPortal`
  - `tarik` (`F`) — dorong/tarik balok (`PushableToyBlock`)
  - `toogle-lari` (`Shift` / `Q`), `jongkok` (`Ctrl` / `C`)
  - `shifting` (`T`) — **JANGAN DIHAPUS**: dipakai oleh `WorldManager` (`scripts/core/world.gd`) untuk berpindah dimensi **Dunia Ingatan (Remembered)** ↔ **Dunia Terlupakan (Forgotten)**.
- **Kontrol UI**:
  - `pause` (`Esc`), `quest_guide` (`Tab` / `J`).
- **Fade Awal Chapter 1**:
  - `scripts/core/world.gd` memaksa `FadeCanvasLayer/ColorRect.color = Color(0, 0, 0, 1)` (hitam) di scene selain `chapter_2` saat fade-in awal level; `scripts/door_portal.gd` hanya mengubah warnanya menjadi putih hangat saat cutscene masuk portal dijalankan.

---

## 5. Status Optimasi & Aset yang Dipertahankan
- Proyek sudah diaudit & dikompresi (ukuran `homebound/` ~**1.09 GB** di luar `.git`, cache `.godot/imported` ~**473 MB**):
  - Tekstur 4K sudah di-downscale ke maks **2048px** (`.png`, `.jpg`, `.exr` zip16) dan tekstur UI maks **1024×1024** / **1920×1080**; seluruh `.import` tekstur memakai `compress/mode=2` (VRAM Compressed) dan `mipmaps/generate=true`.
  - Stale cache `.godot/imported` & orphan assets non-esensial sudah dibersihkan.
- **Aset penting untuk Chapter 2 & 3 yang wajib dipertahankan** (meski belum direferensikan `.tscn`):
  - `res://assets/chap 2/grandfather_clock.glb`
  - `res://assets/chap 2/simple_clock.glb`
  - `res://assets/chap 2/wall_clock__ps1_style.glb`
  - `res://assets/effects/time_stop_effect.glb`
  - `res://assets/characters/enemies/slender_figure.glb`
  - `res://assets/characters/mc/headlamp.glb`
  - Seluruh klip animasi di `res://animations/mc/clips/` (30 file `.fbx`)

---

## 6. Dokumen Referensi Lain di Proyek
- [homebound/docs/GDD_Game1.docx](file:///home/chenlian/Projects/game/GAME/homebound/docs/GDD_Game1.docx)
- [homebound/docs/INTEGRASI_MC_GD.md](file:///home/chenlian/Projects/game/GAME/homebound/docs/INTEGRASI_MC_GD.md)
- [homebound/docs/PANDUAN_INTEGRASI_SCENE.md](file:///home/chenlian/Projects/game/GAME/homebound/docs/PANDUAN_INTEGRASI_SCENE.md)

---

## 7. Aturan Pembaruan & Log Sesi Harian
> **Aturan**: Setiap kali user menyatakan ingin mengakhiri percakapan hari ini, AI harus mencatat ringkasan progres, perubahan file, verifikasi, dan hal yang belum selesai (jika ada) ke bagian ini sebelum menutup sesi.

### 2026-11-26
- Mengaudit & mengompresi aset `chap_1` + `chap_2` (downscale tekstur 4K ke 2048px, VRAM compress `.import`, bersihkan stale `.godot/imported` & orphan non-esensial, mempertahankan aset penting Chapter 2/3) lalu menggabungkannya ke proyek tunggal `homebound/` (~1.09 GB non-`.git`).
- Mengompresi & mengintegrasikan paket `game-ui` (`main_menu`, `pause_menu`, `quest_guide`, `hint objective`, `setting`, `control`, `credits`) ke `homebound/` melalui Autoload `UIManager`, lengkap dengan koneksi 4 progres objektif Chapter 1, Input Map `pause` (`Esc`) & `quest_guide` (`Tab`/`J`), serta mempertahankan `[T]` `shifting`.
- Mengubah animasi buka/tutup Quest Guide menjadi fade in/out, menambahkan animasi karakter jatuh + fade hitam saat Start Game, mengganti fade awal Chapter 1 dari putih ke hitam, serta memperbaiki self-intersection `LEFT_TEAR` di `ui/torn_paper.gd` agar kotak **OBJECTIVE** tampil bergerigi dengan lipatan pojok.
- Menghubungkan MCP `godot-mcp-toolkit` di `~/.gemini/config/mcp_config.json` dan memverifikasi `main_menu.tscn` & `chapter_1.tscn` via `game_start` + `runtime_screenshot`.

### 2026-11-27
- **Overhaul Nuansa Horor & Lighting Chapter 1 (`scenes/levels/chapter_1.tscn`, `scripts/core/world.gd`)**:
  - Mengkalibrasi `Environment_dark` (`volumetric_fog_enabled = true`, ambient slate dingin, ACES & desaturasi) dan dual-mood `[T]` shifting (*Remembered* amber/terpuruk vs *Forgotten* dingin/terlupakan) di `scripts/core/world.gd`, ditambah post-process shader vignette/grain (`shaders/horror_post_process.gdshader`) pada `HorrorPostRect`.
  - Mengkalibrasi 11+ `SpotLight3D` (termasuk `SpotLight_Spawn`, `SpotLight_ParkourMid`, `SpotLight_ParkourSummit`), `scripts/gameplay/lamp_proximity_fader.gd` (`min_energy_ratio = 0.28` + flicker halus), `Player/PlayerRimLight`, `scripts/effects/dust_particles.gd` (`DustParticles`), material lantai `assets/textures/dark_wood/dark_wood_floor.tres` pada `LantaiBaru`, serta `CenterCarpet` (`persian_malayer_carpet.glb`), seluruhnya tetap terlihat di Editor 3D Viewport.
- **Parkour Batu Melayang + Shifting + Void Respawn (`scenes/levels/chapter_1.tscn`)**:
  - Menghapus tangga putih lama `GlowingPlatforms` (`Platform1..19`) beserta prop melayang lama yang dihapus user.
  - Membuat 7 batu parkour (`Rock_01_Anchor`, `Rock_02_Forgotten`, `Rock_04_Remembered`, `Rock_06_Anchor`, `Rock_07_Remembered`, `Rock_08_Forgotten`, `Rock_09_Summit`) dengan `scripts/gameplay/parkour_rock.gd` (checkpoint & sensor langkah), `shaders/ghost_rock.gdshader` (efek Fresnel transparan saat dimensi tidak aktif), dan `BoxShape3D` collision rata permukaan batu (`0–2 cm`), serta `scripts/gameplay/void_respawn_zone.gd` untuk auto-respawn dengan fade hitam ke anchor terakhir saat jatuh ke void.
  - Memperbarui objektif ke-3 di `quest_guide.gd` dan `ui/ui_manager.gd` menjadi `"Seberangi batu melayang menuju puncak"` (`0/7` → `7/7`) serta penyesuaian di `scripts/core/chapter1_puzzle_manager.gd`.
- **Perbaikan Kamera Tembus Tembok Pembatas (`scripts/camera/cinematic_camera_rig.gd`)**:
  - Menambahkan batas ruangan `room_divider_enabled` (`room_divider_x = 23.6`, `room1_max_cam_x = 14.5`, `room2_min_cam_x = 34.5`) agar kamera tidak masuk ke dalam dinding partisi antar ruangan, serta `_update_wall_occlusion()` untuk memudarkan `Plane_004` (`transparency = 0.88`) saat kamera melintasinya.
- **Perbaikan Pintu Keluar Hilang saat Gameplay (`scripts/core/world.gd`)**:
  - Mengubah `apply_dimension_state()` agar `exit_door` dan `door_portal` tetap `visible = true`, `monitoring = true`, `monitorable = true` di kedua dimensi (*Remembered* maupun *Forgotten*), sehingga `DoorPortal/WoodenDoor` di puncak `Rock_09_Summit` tidak lagi menghilang saat pemain memakai `[T]` di akhir parkour.
- **Verifikasi**: `script_check` pada skrip yang diubah bersih, dan playtest runtime via MCP (`game_start`, `runtime_screenshot`, `debugger_get_log`, `game_stop`) memverifikasi pencahayaan, collision parkour, transisi kamera melewati partisi, serta visibilitas `DoorPortal` di mode *Remembered* dan *Forgotten* tanpa error.

### 2026-11-28
- **Pembersihan Puzzle & Setup Awal Chapter 2 (`scenes/levels/chapter_2.tscn`)**:
  - Menghapus node puzzle `MissingTimePuzzle`, `ErasedRoomPuzzle`, dan `PendulumPuzzleZone` (bandul pendulum `Pendulum_1..3` beserta `PendulumBridge_1..2` & `PendulumStep_A..B`) dari `chapter_2.tscn` sesuai permintaan user, sehingga yang aktif di scene hanya `Chapter2PuzzleManager`, `TwoClocksPuzzle` (`ClockStationRemembered` & `ClockStationForgotten`), dan `DoorPortal` pintu keluar (`target_scene_path = "res://main_menu.tscn"`, dipindah ke root scene beserta `CollisionShape3D`, `WoodenDoor`, `DoorInnerGlow`, `InteractionPrompt`, dan `ExitBeaconLight`).
  - Script `.gd` puzzle yang dihapus dari scene (`scripts/gameplay/missing_time_puzzle.gd`, `missing_time_dial.gd`, `erased_room_puzzle.gd`, `memory_fragment_pickup.gd`, `closet_hide_spot.gd`, `pendulum_puzzle_zone.gd`, `clock_pendulum.gd`, `pendulum_bridge_platform.gd`, `scripts/ai/the_eraser_ai.gd`) tetap disimpan di disk untuk penyusunan puzzle berikutnya.
- **Puzzle Jam Kuning, Kamera Fokus, Cutscene Pintu & Pembersihan Teks 3D (`scripts/gameplay/clock_dial_station.gd`, `two_clocks_puzzle.gd`, `static_door.gd`, `scripts/core/world.gd`)**:
  - Menggunakan aset jam kuning beranimasi `res://assets/chap 2/clock_loop_animation.glb` pada `ClockDialStation` melalui helper `Chapter2PuzzleManager.spawn_yellow_clock()` & `set_yellow_clock_hour()`.
  - Menghapus seluruh teks 3D melayang yang mengganggu di map: menghapus `TwoClocksSyncArch` (`SINKRONKAN 2 JAM → 12:00`, orb indikator biru/oranye, serta pelat lantai `SyncPlateRemembered` / `SyncPlateForgotten`) di `two_clocks_puzzle.gd`, menghapus `StatusLabel` & `InteractionPrompt` dari `clock_dial_station.gd`, dan menghapus teks `[E] Buka Pintu` / `[E] Tutup Pintu` pada `static_door.gd` (hanya menampilkan `[E] Terkunci` / `Terkunci...` jika pintu terkunci, lalu `_stay_open = true` setelah dibuka otomatis).
  - Memindahkan panduan kontrol (`[T]` ganti dimensi & `[E]` putar jarum jam ke `12:00`) ke tab **Quest** (`quest_guide.gd` `_quests[1]` & sinkronisasi di `ui/ui_manager.gd`).
  - Menambahkan zoom kamera fokus ke jam saat `[E]` ditekan (`ClockDialStation._enter_camera_focus()` / `release_camera_focus()`, otomatis kembali setelah `1.4s` idle, saat pemain bergerak menjauh, atau saat berpindah dimensi `[T]`), serta cutscene otomatis membuka `pintu2` (`TwoClocksPuzzle._play_door_open_cutscene()` dengan `TwoClocksDoorCutsceneCam` + cahaya reveal) ketika kedua jam mencapai `12:00`.
  - Menambahkan debounce `_toggle_cooldown = 0.20` pada `WorldManager.toggle_dimension()` di `scripts/core/world.gd`. (Catatan: shader `HorrorPostRect`/`VignetteRect` di `VignetteLayer` `CanvasLayer` dan override `WorldEnvironment` runtime di `world.gd` hanya aktif saat game berjalan, bukan di 3D Viewport editor.)
- **Verifikasi**: `script_check` valid pada seluruh skrip yang diubah, `chapter_2.tscn` disimpan via `editor_save_scene`, dan uji `godot --headless --quit-after 30 res://scenes/levels/chapter_2.tscn` bersih (`HEADLESS_CLEAN`).

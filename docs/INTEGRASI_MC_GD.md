# ============================================================================
# SNIPPET INTEGRASI carry_system.gd ke mc.gd
# Tempatkan di file game_mechanic/mc.gd (atau panggil dari scene pemain)
# ============================================================================

# --- Tambahkan di bagian @onready (di mc.gd) ---
@onready var carry_system: Node3D = get_node_or_null("../Chapter1PuzzleManager/CarrySystem")
# Atau jika CarrySystem langsung di bawah Player:
# @onready var carry_system: Node3D = get_node_or_null("CarrySystem")

# --- Di fungsi ambil_item() di mc.gd, tambahkan panggilan carry_system ---
func ambil_item() -> void:
    if sedang_jongkok:
        return

    var benda := cari_item_pickup_terdekat()
    if benda != null:
        item_dipegang = benda
        skala_item_awal = item_dipegang.scale

        # Nonaktifkan fisika & collision — tangani oleh carry_system.gd
        item_dipegang.freeze = true
        var col := item_dipegang.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if col:
            col.disabled = true

        # Panggil carry_system untuk animasi + tracking
        if carry_system:
            carry_system.call("pick_up", item_dipegang)

# --- Di fungsi taruh_item() di mc.gd, tambahkan panggilan carry_system ---
func taruh_item() -> void:
    var benda := item_dipegang
    item_dipegang = null

    benda.scale = skala_item_awal
    benda.global_position = hand.global_position + body.global_transform.basis.z * 0.6

    # Pulihkan collision & fisika — tangani oleh carry_system.gd
    var col := benda.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if col:
        col.disabled = false

    benda.freeze = false
    benda.sleeping = false

    # Panggil carry_system untuk reset animasi
    if carry_system:
        carry_system.call("drop")

# --- Di _process di mc.gd, pastikan hint interaksi menunjukkan [E] Drop saat memegang ---
# (Sudah ada di baris 184-188 mc.gd asli, biarkan seperti yang ada)

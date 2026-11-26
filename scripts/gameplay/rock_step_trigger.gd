class_name RockStepTrigger
extends Area3D

## ============================================================================
## RockStepTrigger — Pemicu Otomatis Pembukaan Pintu Saat Menginjak Batu Terakhir
## Mengaktifkan door_portal.open_door() saat pemain mencapai batu Sketchfab_Scene4.
## ============================================================================

@export var door_portal: Area3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if door_portal == null:
		door_portal = get_node_or_null("../../DoorPortal")
		if door_portal == null:
			door_portal = get_node_or_null("../../../DoorPortal")

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if door_portal and door_portal.has_method("open_door"):
			door_portal.call("open_door")

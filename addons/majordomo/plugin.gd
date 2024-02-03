@tool
extends EditorPlugin


var dock: Control


func _enter_tree() -> void:
	dock = preload("./dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)


func _exit_tree() -> void:
	remove_tool_menu_item("Deploy to Itch.io")
	remove_control_from_docks(dock)
	dock.queue_free()




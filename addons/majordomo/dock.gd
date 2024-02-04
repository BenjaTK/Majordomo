@tool
extends Control


const CONFIGURATION_SAVE_DIR := "user://majordomo.cfg"

var thread: Thread

@onready var butler_menu: MenuButton = %Butler
@onready var game_menu: MenuButton = %Game
@onready var log_out_confirmation: ConfirmationDialog = $LogOutConfirmation
@onready var edit_directory_button: Button = %EditDirectoryButton
@onready var path_to_exports: LineEdit = %PathToExports
@onready var file_dialog: FileDialog = $FileDialog
@onready var username_line_edit: LineEdit = %UsernameLineEdit
@onready var game_line_edit: LineEdit = %GameLineEdit
@onready var version_line_edit: LineEdit = %VersionLineEdit
@onready var save_button: Button = %SaveButton
@onready var info_button: Button = %InfoButton
@onready var channel_selection_dialog: ConfirmationDialog = %ChannelSelectionDialog
@onready var channel_selection_container: VBoxContainer = %ChannelSelectionContainer
@onready var if_changed_check_box: CheckBox = %IfChangedCheckBox


func _ready() -> void:
	butler_menu.get_popup().id_pressed.connect(_on_butler_item_pressed)
	game_menu.get_popup().id_pressed.connect(_on_game_item_pressed)
	edit_directory_button.icon = EditorInterface.get_base_control().get_theme_icon("Folder", "EditorIcons")
	save_button.icon = EditorInterface.get_base_control().get_theme_icon("Save", "EditorIcons")
	info_button.icon = EditorInterface.get_base_control().get_theme_icon("NodeInfo", "EditorIcons")
	_load()


func deploy(channel: String) -> void:
	var path: String = path_to_exports.text + "/%s/" % channel
	if not DirAccess.dir_exists_absolute(path):
		return

	var output: Array
	var arguments: Array = ["push", path, "%s/%s:%s" % [username_line_edit.text, game_line_edit.text, channel]]
	if not version_line_edit.text.is_empty():
		arguments.append("--userversion=%s" % version_line_edit.text)
	if if_changed_check_box.button_pressed:
		arguments.append("--if-changed")

	var error: Error = OS.execute("butler", arguments, output, true, false)
	if error != OK:
		_print_output_as_error_message(output, channel)
	else:
		print_rich('[b]Succesfully deployed to channel "%s"[/b]' % channel)


func _on_butler_item_pressed(id: int) -> void:
	match id:
		0: #Long in
			var output: Array[String]
			var error: Error = OS.execute("butler", ["login"], output)
			if output[0].contains("local credentials are valid"):
				push_warning("Already logged in to Butler!")

			if error != OK:
				push_error("Failed to log in to Butler")
		1: #Log out
			log_out_confirmation.popup_centered()
		3:
			OS.shell_open("https://itchio.itch.io/butler")
		4:
			OS.shell_open("https://itch.io/docs/butler/")


func _on_game_item_pressed(id: int) -> void:
	match id:
		0: #Open in browser
			var url: String = "https://%s.itch.io/%s" % [username_line_edit.text, game_line_edit.text]
			OS.shell_open(url)
		1:
			var url: String = "https://%s.itch.io/%s" % [username_line_edit.text, game_line_edit.text]
			DisplayServer.clipboard_set(url)

func _on_log_out_confirmation_confirmed() -> void:
	var error: Error = OS.execute("butler", ["logout", "--assume-yes"])
	if error != OK:
		push_error("Failed to log out of Butler")


func _on_file_dialog_dir_selected(dir: String) -> void:
	path_to_exports.text = dir


func _on_edit_directory_button_pressed() -> void:
	file_dialog.popup_centered_ratio(0.5)


func _save() -> void:
	var config_file: ConfigFile = ConfigFile.new()
	config_file.set_value("config", "exports-path", _get_exports_path())
	config_file.set_value("config", "username", username_line_edit.text)
	config_file.set_value("config", "game", game_line_edit.text)
	config_file.set_value("config", "version", version_line_edit.text)
	config_file.set_value("config", "only_if_changed", if_changed_check_box.button_pressed)
	var error: Error = config_file.save(CONFIGURATION_SAVE_DIR)
	if error != OK:
		return


func _load() -> void:
	var config_file: ConfigFile = ConfigFile.new()
	var error: Error = config_file.load(CONFIGURATION_SAVE_DIR)
	if error != OK:
		return
	path_to_exports.text = config_file.get_value("config", "exports-path", "")
	username_line_edit.text = config_file.get_value("config", "username", "")
	game_line_edit.text = config_file.get_value("config", "game", "")
	version_line_edit.text = config_file.get_value("config", "version", "")
	if_changed_check_box.button_pressed = config_file.get_value("config", "only_if_changed", false)


func _on_save_button_pressed() -> void:
	_save()




func _print_output_as_error_message(output: Array, channel: String) -> void:
	var error_message: String = 'Itch.io deploy to channel "%s" failed with output(s):' % channel
	for i: String in output:
		for j: String in i.split("\n"):
			if j.is_empty():
				continue
			error_message += '\n\t%s' % j
	push_error(error_message)


func _on_deploy_all_button_pressed() -> void:
	var exports_path: String = _get_exports_path()
	if not DirAccess.dir_exists_absolute(exports_path):
		push_error("Exports folder not found")
		return

	for directory in DirAccess.get_directories_at(exports_path):
		thread = Thread.new()
		thread.start(deploy.bind(directory))


func _get_exports_path() -> String:
	return path_to_exports.text


func _on_deploy_only_button_pressed() -> void:
	var exports_path: String = _get_exports_path()
	if not DirAccess.dir_exists_absolute(exports_path):
		push_error("Exports folder not found")
		return

	for child in channel_selection_container.get_children():
		child.queue_free()

	for directory in DirAccess.get_directories_at(exports_path):
		var selector: CheckBox = CheckBox.new()
		selector.text = directory
		channel_selection_container.add_child(selector)

	channel_selection_dialog.popup_centered()


func _on_channel_selection_dialog_confirmed() -> void:
	for child in channel_selection_container.get_children():
		if not child is CheckBox:
			continue

		if child.button_pressed:
			thread = Thread.new()
			thread.start(deploy.bind(child.text))
			#deploy(child.text)


func _on_info_button_pressed() -> void:
	OS.shell_open("https://github.com/BenjaTK/Majordomo/tree/main#readme")


func _exit_tree() -> void:
	_save()
	thread.wait_to_finish()

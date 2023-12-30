extends VBoxContainer


var tja_path: String = ""
var song_path: String = ""
var metadata: Dictionary = {}


func _ready():
	%SongTitleLabel.text = metadata["title"]


func play_common(diff: String):
	var mod = ModManager.loaded_mods.filter(func(m): return m["file_name"] == "taiko")[0]
	var mod_path = "res://modules/" + mod["file_name"]
	var scene_path = mod_path + "/mod/scenes/game/gameplay.tscn"
	
	var scene_parameters: Dictionary = {
		"tja_path": tja_path,
		"song_path": song_path,
		"difficulty": diff
	}
	
	SceneChanger.goto_scene(scene_path, scene_parameters)


func _on_play_easy_button_pressed():
	play_common("Easy")


func _on_play_normal_button_pressed():
	play_common("Normal")


func _on_play_hard_button_pressed():
	play_common("Hard")


func _on_play_oni_button_pressed():
	play_common("Oni")


func _on_play_ura_button_pressed():
	play_common("Ura")


func _on_play_edit_button_pressed():
	play_common("Edit")

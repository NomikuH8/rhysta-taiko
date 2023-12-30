extends Node


@export var song_container_scene: PackedScene


var songs: Dictionary = {}
var category_scene: PackedScene


func _ready():
	get_songs()
	#spawn_categories()
	spawn_songs()


func get_songs():
	var mod = ModManager.loaded_mods.filter(func(m): return m["file_name"] == "taiko")[0]
	var mod_path = "res://modules/" + mod["file_name"]
	var songs_path = mod_path + "/songs"
	
	var songs_dir = DirAccess.open(songs_path)
	songs_dir.list_dir_begin()
	
	var song_list = {}
	var category_filename = songs_dir.get_next()
	while category_filename != "":
		if not songs_dir.current_is_dir():
			category_filename = songs_dir.get_next()
			continue
		
		song_list[category_filename] = []
		
		var category_dir = DirAccess.open(songs_path + "/" + category_filename)
		category_dir.list_dir_begin()
		var song_filename = category_dir.get_next()
		while song_filename != "":
			if not category_dir.current_is_dir():
				song_filename = category_dir.get_next()
				continue
			
			song_list[category_filename].push_back(song_filename)
			song_filename = category_dir.get_next()
		
		category_filename = songs_dir.get_next()
		category_dir.list_dir_end()
	
	songs_dir.list_dir_end()
	songs = song_list


func spawn_categories():
	for category in songs.keys():
		var cat = category_scene.instantiate()
		cat.category = category


func spawn_songs():
	var mod = ModManager.loaded_mods.filter(func(m): return m["file_name"] == "taiko")[0]
	var mod_path = "res://modules/" + mod["file_name"]
	var songs_path = mod_path + "/songs"
	
	for category in songs.keys():
		for song in songs[category]:
			var song_path = songs_path + "/" + category + "/" + song
			var metadata = {}
			
			var song_dir = DirAccess.open(song_path)
			song_dir.list_dir_begin()
			var filename = song_dir.get_next()
			
			var found_tja = false
			var tja_path: String = ""
			
			while filename != "":
				if not filename.ends_with(".tja"):
					filename = song_dir.get_next()
					continue
				
				found_tja = true
				tja_path = song_path + "/" + filename
				metadata = TJAParser.parse_from_file(tja_path, true)
				
				filename = song_dir.get_next()
			
			song_dir.list_dir_end()
			
			if not found_tja:
				continue
			
			var song_container = song_container_scene.instantiate()
			song_container.song_path = song_path
			song_container.tja_path = tja_path
			song_container.metadata = metadata
			%MainContainer.add_child(song_container)

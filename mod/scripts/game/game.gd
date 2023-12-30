extends Node


var tja: Dictionary = {}
var tja_path: String = ""
var song_path: String = ""
var difficulty: String = ""
var time_begin: float
var time_delay: float
var game_started: bool = false
var current_bpm: float = 120
var current_measure: String = "4/4"

var note_types: Dictionary = {
	"0": { "name": false, "txt": false },
	"1": { "name": "don", "txt": "Don" },
	"2": { "name": "ka", "txt": "Ka" },
	"3": { "name": "daiDon", "txt": "DON" },
	"4": { "name": "daiKa", "txt": "KA" },
	"5": { "name": "drumroll", "txt": "Drum rollー!!" },
	"6": { "name": "daiDrumroll", "txt": "DRUM ROLLー!!" },
	"7": { "name": "balloon", "txt": "Balloon" },
	"8": { "name": false, "txt": false },
	"9": { "name": "balloon", "txt": "Balloon" },
	"A": { "name": "daiDon", "txt": "DON" },
	"B": { "name": "daiKa", "txt": "KA" },
	"F": { "name": "adlib", "txt": false },
	"G": { "name": "green", "txt": "???" }
}

var note_types_ex: Dictionary = {
	"don": "Do",
	"ka": "Ka",
	"daiDon": "DON",
	"daiKa": "KA"
}


@onready var player: AudioStreamPlayer = $Player


func _ready():
	tja = TJAParser.parse_from_file(tja_path)
	current_bpm = float(tja["metadata"]["bpm"])
	import_music()
	spawn_circles()
	time_begin = Time.get_ticks_usec()
	time_delay = AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	player.play()


func _process(_delta: float):
	var time = (Time.get_ticks_usec() - time_begin) / 1000000.0
	time -= time_delay
	time = max(0, time)
	
	if not game_started and time >= -float(tja["metadata"]["offset"]):
		game_started = true


func import_music():
	var stream: AudioStream
	
	if tja["metadata"]["wave"].ends_with(".ogg"):
		stream = AudioStreamOggVorbis.load_from_file(song_path + "/" + tja["metadata"]["wave"])
	
	player.stream = stream


func get_courses():
	var courses = {}
	TJAParser.parse_from_file(tja_path, false)


func spawn_circles():
	pass


func is_all_don(note_chain: Array, start_pos: int):
	for i in range(note_chain.size()):
		if i < start_pos: continue
		
		var note = note_chain[i]
		if not ["don", "daiDon"].has(note["type"]):
			return false
	
	return true


func check_chain(note_chain: Array, is_last: bool):
	var all_don_pos = null
	var chain_range = note_chain.size() - (1 if is_last else 0)
	for i in range(chain_range):
		var note = note_chain[i]
		if all_don_pos == null and is_last and  is_all_don(note_chain, i):
			all_don_pos = i
		var index = (i - all_don_pos) % 2 if all_don_pos != null else 0
		note["text"] = note_types_ex[note["type"]][index]


func push_measure():
	pass

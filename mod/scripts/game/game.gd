extends Node


var tja: Dictionary = {}
var tja_path: String = ""
var song_path: String = ""
var difficulty: String = ""
var time_begin: float
var time_delay: float
var game_started: bool = false
var course: Dictionary = {}


@onready var player: AudioStreamPlayer = $Player


func _ready():
	tja = TJAParser.parse_from_file(tja_path)
	import_music()
	get_courses()
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
	course = TJAParser.parse_from_file(tja_path, false)
	print(course)


func spawn_circles():
	pass

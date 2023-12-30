class_name TJAParser
extends Node


static var note_types: Dictionary = {
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

static var note_types_ex: Dictionary = {
	"don": "Do",
	"ka": "Ka",
	"daiDon": "DON",
	"daiKa": "KA"
}


static func parse_from_file(path: String, only_metadata: bool = false) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	
	if only_metadata:
		return parse_only_metadata(text)
	
	return parse(text)


static func parse(text: String) -> Dictionary:
	var returned = {
		"metadata": parse_only_metadata(text),
		"courses": parse_only_courses_metadata(text),
		"events": parse_courses(text)
	}
	return returned


static func parse_only_metadata(text: String) -> Dictionary:
	var returned = {}
	
	# Take only the metadata section
	var meta_text_lines = text.replace("\r", "").split("\n\n")[0].split("\n")
	for line in meta_text_lines:
		if line.is_empty() or line.begins_with("//"):
			continue
		
		var key_value = line.split(":", true, 1)
		var key = key_value[0].to_lower()
		var value = key_value[1]
		
		if key == "subtitle":
			returned[key] = value.replace("--", "")
		else:
			returned[key] = value
	
	return returned


static func parse_only_courses_metadata(text: String) -> Dictionary:
	var courses = {}
	
	var text_lines = text.replace("\r", "").split("\n")
	var current_course: String = ""
	for line in text_lines:
		if line.is_empty() or line.begins_with("//") or not (
			line.begins_with("COURSE")
			or line.begins_with("LEVEL")
			or line.begins_with("BALLOON")
			or line.begins_with("SCOREINIT")
			or line.begins_with("SCOREDIFF")
		):
			continue
		
		if line.begins_with("COURSE"):
			current_course = line.split(":")[-1]
			courses[current_course] = {
				"course": current_course
			}
			continue
		
		if line.find(":") < 0 or line.begins_with("#"):
			continue
		
		var key_value = line.split(":")
		var key = key_value[0].to_lower()
		var value = key_value[1]
		if key == "balloon":
			courses[current_course]["balloon"] = value.split(",")
			continue
		
		courses[current_course][key] = value
		
	return courses


static func parse_courses(text: String) -> Array:
	var courses_metadata = parse_only_courses_metadata(text)
	var tja_metadata = parse_only_metadata(text)
	
	var courses = []
	var text_lines = text.replace("\r", "").split("\n")
	for course in courses_metadata.keys():
		var next_will_be_course = false
		var course_started = false
		var current_bpm = float(tja_metadata["bpm"])
		var last_bpm = current_bpm
		var scroll = 1
		var gogo = false
		var last_gogo = false
		var measure = 4
		var ms = float(tja_metadata["offset"])
		var barline: bool = false
		var branches: Array = []
		var measures: Array[Dictionary] = []
		var circles: Array = []
		var current_measure: Array[Dictionary] = []
		var current_lyric: String = ""
		var section_begin: bool = true
		var last_drumroll: Dictionary = {}
		var balloons: Array = tja_metadata["balloon"] if "balloon" in tja_metadata else []
		var balloon_id: int = 0
		var first_note: bool = true
		var circle_id: int = 0
		var events: Array = []
		var lyrics: Array = []
		
		var branch: bool = false
		var current_branch: Dictionary = {}
		var branch_first_measure: bool = false
		
		var is_all_don = func(note_chain: Array, start_pos: int):
			for i in range(note_chain.size()):
				if i < start_pos: continue
				
				var note = note_chain[i]
				if not ["don", "daiDon"].has(note["type"]):
					return false
			
			return true
		
		var check_chain = func(note_chain: Array, measure_length, is_last: bool):
			var all_don_pos = null
			var chain_range = note_chain.size() - (1 if is_last else 0)
			for i in range(chain_range):
				var note = note_chain[i]
				if all_don_pos == null and is_last and  is_all_don.call(note_chain, i):
					all_don_pos = i
				var index = (i - all_don_pos) % 2 if all_don_pos != null else 0
				note["text"] = note_types_ex[note["type"]][index]
		
		var insert_note = func(circle: Dictionary):
			if current_bpm != last_bpm or gogo != last_gogo:
				circle["event"] = true
				last_bpm = current_bpm
				last_gogo = gogo
			if not current_lyric.is_empty():
				circle["lyrics_line"] = current_lyric
				current_lyric = ""
			current_measure.push_back(circle)
		
		var insert_blank_note = func(circle: Dictionary = {}):
			if current_bpm != last_bpm or gogo != last_gogo:
				insert_note.call({
					"type": "event",
					"bpm": current_bpm,
					"scroll": scroll,
					"gogo": gogo
				})
			elif circle.keys().size() == 0:
				var circle2 = {
					"bpm": current_bpm,
					"scroll": scroll
				}
				if not current_lyric.is_empty():
					circle["lyrics_line"] = current_lyric
					current_lyric = ""
				current_measure.push_back(circle)
			
			if circle.keys().size() > 0:
				if not current_lyric.is_empty():
					circle["lyrics_line"] = current_lyric
					current_lyric = ""
				current_measure.push_back(circle)
		
		var push_measure = func():
			var speed: int = 0
			if current_measure.size() > 0:
				var note = current_measure[0]
				speed = note["bpm"] * note["scroll"] / 60
			else:
				speed = current_bpm * scroll / 60
			
			measures.push_back({
				"ms": ms,
				"original_ms": ms,
				"speed": speed,
				"visible": barline,
				"branch": current_branch,
				"branch_first": branch_first_measure
			})
			branch_first_measure = false
			if current_measure.size() == 0:
				var ms_per_measure = 60000 * measure / current_bpm
				ms += ms_per_measure
				return
			
			for note in current_measure:
				if first_note and note["type"] != "event":
					first_note = false
					if ms < 0:
						#this.soundOffset = ms
						ms = 0
				
				note["start"] = ms
				if note.keys().has("end_drumroll"):
					note["end_drumroll"]["end_time"] = ms
					note["end_drumroll"]["original_end_time"] = ms
				var ms_per_measure = 60000 * measure / note["bpm"]
				ms += ms_per_measure / current_measure.size()
			
			var note_chain: Array[Dictionary] = []
			
			for i in range(current_measure.size()):
				var note = current_measure[i]
				if "type" in note:
					circle_id += 1
					
					var circle = {
						"id": circle_id,
						"start": note["start"],
						"type": note["type"],
						"txt": note["txt"],
						"speed": note["bpm"] * note["scroll"] / 60,
						"gogo_time": note["gogo"],
						"end_time": note["end_time"],
						"required_hits": note["required_hits"],
						"beat_ms": 60000 / note["bpm"],
						"branch": current_branch,
						"section": note["section"]
					}
					
					if ["don", "ka", "daiDon", "daiKa"].has(circle["type"]):
						note_chain.push_back(circle)
					else:
						if note_chain.size() > 1 and current_measure.size() >= 8:
							check_chain.call(note_chain, current_measure.size(), false)
						note_chain = []
					
					if last_drumroll == note:
						last_drumroll = circle
					
					if "event" in note:
						events.push_back(circle)
					
					if note["type"] != "event":
						circles.push_back(circle)
				elif (
					not (current_measure.size() < 24 and (
						not current_measure[i + 1]
						or current_measure[i + 1]["type"])
					)
					and current_measure.size() < 48 and (
							not current_measure[i + 2]
							or not "type" in current_measure[i + 2]
							or not current_measure[i + 3]
							or not "type" in current_measure[i + 3]
						)
					):
						if note_chain.size() > 1 and current_measure.size() >= 8:
							check_chain.call(note_chain, current_measure.size(), true)
						note_chain = []
				
				if "lyrics_line" in note:
					if lyrics.size() != 0:
						lyrics[-1]["end"] = note["start"]
					lyrics.push_back({
						"start": note["start"],
						"text": note["lyrics_line"]
					})
		
		
		var measure_ended: bool = false
		
		for line in text_lines:
			if line.is_empty() or line.begins_with("//"):
				continue
			
			if line.find("//") >= 0:
				line = line.substr(0, line.find("//"))
			
			if line.begins_with("COURSE:" + course):
				next_will_be_course = true
				continue
			
			if not next_will_be_course:
				continue
			
			if line.begins_with("#START"):
				course_started = true
				continue
			
			if not course_started:
				continue
			
			# In case it's lyric
			if line.begins_with("#LYRIC"):
				#events[course].push_back({
					#"type": "lyric",
					#"text": line.replace("#LYRIC ", "")
				#})
				current_lyric = line.replace("#LYRIC ", "")
				continue
			
			# In case it's bpmchange
			if line.begins_with("#BPMCHANGE"):
				current_bpm = float(line.replace("#BPMCHANGE ", ""))
				continue
			
			if line.begins_with("#SCROLL"):
				scroll = int(line.replace("#SCROLL ", ""))
				continue
			
			# In case it's measure
			if line.begins_with("#MEASURE"):
				var measure_raw = line.replace("#MEASURE ", "").split("/")
				measure = int(measure_raw[0]) / int(measure_raw[1]) * 4
				continue
			
			if line.begins_with("#DELAY"):
				ms += float(line.replace("#DELAY ", "")) * 1000
				continue
			
			if line.begins_with("#BARLINEON"):
				barline = true
				continue
			
			if line.begins_with("#BARLINEOFF"):
				barline = false
				continue
			
			if line.begins_with("#BRANCHSTART"):
				var value = line.replace("#BRANCHSTART ", "").split(",")
				var requirement = {
					"advanced": float(value[1]),
					"master": float(value[2])
				}
				var active: String = ""
				
				if requirement["advanced"] > 0:
					active = "normal" if requirement["master"] > 0 else "master"
				else:
					active = "advanced" if requirement["master"] > 0 else "master"
				
				var branch_obj = {
					"ms": ms,
					"original_ms": ms,
					"active": active,
					"type": "drumroll" if value[0].strip_edges().to_lower() == "r" else "accuracy",
					"requirement": requirement
				}
				
				branches.push_back(branch_obj)
				
				if measures.size() == 1 and branch_obj["type"] == "drumroll":
					pass
				# TODO: finish this branchstart
			
			for char in line.to_upper().split(""):
				if ["0"].has(char):
					insert_blank_note.call()
					continue
				
				if ["1", "2", "3", "4", "A", "B", "F", "G"].has(char):
					var type = note_types[char]
					var circle = {
						"type": type["name"],
						"txt": type["txt"],
						"gogo": gogo,
						"bpm": current_bpm,
						"scroll": scroll,
						"section": section_begin
					}
					section_begin = false
					if last_drumroll.keys().size() > 0:
						circle["end_drumroll"] = last_drumroll
						last_drumroll = {}
					
					insert_note.call(circle)
					continue
				
				if ["5", "6", "7", "9"].has(char):
					var type = note_types[char]
					var circle = {
						"type": type["name"],
						"txt": type["txt"],
						"gogo": gogo,
						"bpm": current_bpm,
						"scroll": scroll,
						"section": section_begin
					}
					section_begin = false
					if last_drumroll.keys().size() > 0:
						if char == "9":
							insert_blank_note.call({
								"end_drumroll": last_drumroll,
								"bpm": current_bpm,
								"scroll": scroll,
								"section": section_begin
							})
							section_begin = false
							last_drumroll = {}
						else:
							insert_blank_note.call()
						continue
					
					if ["7", "9"].has(char):
						if balloons.size() - 1 >= balloon_id:
							var hits = balloons[balloon_id]
							if hits < 1:
								hits = 1
							circle["required_hits"] = hits
							balloon_id += 1
						
						last_drumroll = circle
						insert_note.call(circle)
						continue
					
				if ["8"].has(char):
					if last_drumroll.keys().size() == 0:
						insert_blank_note.call({
							"bpm": current_bpm,
							"scroll": scroll
						})
						continue
					
					insert_blank_note.call({
						"end_drumroll": last_drumroll,
						"bpm": current_bpm,
						"scroll": scroll,
						"section": section_begin
					})
					
					section_begin = false
					last_drumroll = {}
					continue
				
				if [","].has(char):
					if current_measure.size() == 0 and (
						current_bpm != last_bpm
						or gogo != last_gogo
						or not current_lyric.is_empty()
					):
						insert_blank_note.call()
					
					push_measure.call()
					current_measure = []
					continue
				
				var alphabet = [
					"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
					"M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X",
					"Y", "Z"
				]
				
				if alphabet.has(char):
					insert_blank_note.call()
			
			if line.begins_with("#END"):
				next_will_be_course = false
		
		push_measure.call()
		
		if last_drumroll.keys().size() > 0:
			last_drumroll["end_time"] = ms
			last_drumroll["original_end_time"] = ms
		
		courses[course] = {
			"circles": circles
		}
	
	return courses

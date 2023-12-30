class_name TJAParser
extends Node


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
			and line.begins_with("LEVEL")
			and line.begins_with("BALLOON")
			and line.begins_with("SCOREINIT")
			and line.begins_with("SCOREDIFF")
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


static func parse_courses(text: String) -> Dictionary:
	var courses_metadata = parse_only_courses_metadata(text)
	var tja_metadata = parse_only_metadata(text)
	var events = {}
	
	var text_lines = text.replace("\r", "").split("\n")
	for course in courses_metadata.keys():
		var next_will_be_course = false
		var course_started = false
		var current_bpm = tja_metadata["bpm"]
		var last_bpm = current_bpm
		var scroll = 1
		var gogo = false
		var last_gogo = false
		var measure = 4
		var ms = tja_metadata["offset"]
		var barline: bool = false
		var branches: Array = []
		var measures: Array = []
		var circles: Array = []
		var current_measure: Array = []
		var current_lyric: String = ""
		
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
		
		if not events.has(course):
			events[course] = []
		
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
			
			if line.begins_with("#END"):
				next_will_be_course = false
	
	return events

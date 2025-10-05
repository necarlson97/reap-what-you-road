extends Destination
class_name School

func spawn_agents(parent: Node2D) -> Array[Agent]:
	# For now - just hardcode some stuff, but might be able to abstract away
	# as like a dict or something
	var agents: Array[Agent]
	
	for h: Home in get_appartments():
		var from = h.get_grid_cell()
		var to = get_grid_cell()
		var p = Pedestrian.create(parent, from, to)
		agents.append(p)
		await _sleep(0.1)
	await _sleep(0.1)
	
	for h: Home in get_houses():
		var from = h.get_grid_cell()
		var to = get_grid_cell()
		var p = Pedestrian.create_slow(parent, from, to)
		agents.append(p)
		await _sleep(0.1)
	await _sleep(0.1)
	
	for h: Home in get_mansions():
		var from = h.get_grid_cell()
		var to = get_grid_cell()
		var c = Car.create_async(parent, from, to, Car)
		agents.append(c)
		await _sleep(0.5)
		  
	return agents

func get_description() -> String:
	return """
School:
	* First, summons a walker from apparment
	* Then, summons a slow-walker from every house
	* Then, summons a driver from every mansion
""".strip_edges()

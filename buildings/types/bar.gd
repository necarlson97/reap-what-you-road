extends Destination
class_name Bar

func spawn_agents(parent: Node2D) -> Array[Agent]:
	# For now - just hardcode some stuff, but might be able to abstract away
	# as like a dict or something
	var agents: Array[Agent]
	for h: Home in get_appartments():
		var from = h.get_grid_cell()
		var to = get_grid_cell()
		agents.append(Pedestrian.create_slow(parent, from, to))
		await _sleep(0.1)
	await _sleep(0.1)
	
	for h: Home in get_houses():
		var from = get_grid_cell()
		var to = h.get_grid_cell()
		agents.append(Car.create_drunk(parent, from, to))
		await _sleep(.5)
		  
	return agents

func get_description() -> String:
	return """
Bar:
	* First, summons a slow-walker from all appartments
	* Then, sends a drunk-driver to all houses
""".strip_edges()

extends Destination
class_name Resturant

func spawn_agents(parent: Node2D) -> Array[Agent]:
	# For now - just hardcode some stuff, but might be able to abstract away
	# as like a dict or something
	var agents: Array[Agent]
	for h: Home in all_homes():
		var from = h.get_grid_cell()
		var to = get_grid_cell()
		agents.append(await Pedestrian.create(parent, from, to))
		await _sleep(0.1)
	await _sleep(0.1)
	
	for h: Home in all_homes():
		var from = get_grid_cell()
		var to = h.get_grid_cell()
		agents.append(await Pedestrian.create_slow(parent, from, to))
		await _sleep(0.1)
	
	await _sleep(0.5)
	for h: Home in all_homes():
		var from = get_grid_cell()
		var to = h.get_grid_cell()
		agents.append(await Car.create(parent, from, to))
		await _sleep(0.5)
		  
	return agents

func get_description() -> String:
	return """
Resturant:
	* First, summons a walker from homes of all types
	* Then, send a slow-walker to homes of all types
	* Then, send a driver to homes of all types
""".strip_edges()

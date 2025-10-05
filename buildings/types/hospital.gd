extends Destination
class_name Hospital

func spawn_agents(parent: Node2D) -> Array[Agent]:
	# For now - just hardcode some stuff, but might be able to abstract away
	# as like a dict or something
	var agents: Array[Agent]
	for h: Home in get_houses():
		var from = get_grid_cell()
		var to = h.get_grid_cell()
		agents.append(await Car.create_fast(parent, from, to))
		await _sleep(0.5)
	await _sleep(0.5)
	
	for h: Home in get_appartments():
		var from = h.get_grid_cell()
		var to = get_grid_cell()
		agents.append(await Car.create_fast(parent, from, to))
		await _sleep(0.5)
		  
	return agents

func get_description() -> String:
	return """
Hospital:
	* First, sends a fast-driver to all houses
	* Then, summons a fast-driver from all appartments
""".strip_edges()

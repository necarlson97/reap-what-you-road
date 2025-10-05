extends Destination
class_name Court

func spawn_agents(parent: Node2D) -> Array[Agent]:
	# For now - just hardcode some stuff, but might be able to abstract away
	# as like a dict or something
	var agents: Array[Agent]
	for h: Home in get_mansions():
		var from = h.get_grid_cell()
		var to = get_grid_cell()
		agents.append(await Car.create_slow(parent, from, to))
		await _sleep(0.2)
	await _sleep(0.2)
	
	for h: Home in get_appartments():
		var from = h.get_grid_cell()
		var to = get_grid_cell()
		agents.append(await Pedestrian.create_slow(parent, from, to))
		await _sleep(0.1)
	await _sleep(0.1)
	
	for h: Home in get_mansions() + get_appartments():
		var from = get_grid_cell()
		var to = h.get_grid_cell()
		agents.append(await Car.create_fast(parent, from, to))
		await _sleep(0.5)
		  
	return agents

func get_description() -> String:
	return """
Cout:
	* First, summons a slow-driver from all mansions
	* Then, summons a slow-walker to from all appartments
	* Then, sends a fast-driver to all apparments AND mansions
""".strip_edges()

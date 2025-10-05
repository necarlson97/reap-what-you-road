extends Destination
class_name Nightclub

func spawn_agents(parent: Node2D) -> Array[Agent]:
	# For now - just hardcode some stuff, but might be able to abstract away
	# as like a dict or something
	var agents: Array[Agent]
	for h: Home in get_appartments():
		var from = h.get_grid_cell()
		var to = get_grid_cell()
		agents.append(Pedestrian.create_runner(parent, from, to))
		await _sleep(0.3)
	await _sleep(0.3)
	
	for h: Home in get_mansions():
		var from = h.get_grid_cell()
		var to = get_grid_cell()
		agents.append(Car.create_distracted(parent, from, to))
		await _sleep(0.5)
		  
	return agents

func get_description() -> String:
	return """
Gas Sation:
	* First, summons a runner from all appartments
	* Then, summons a distracted-driver to all mansions
""".strip_edges()

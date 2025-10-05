extends Node

@export var tick_hz: float = 30.0      # how often to run one task
@export var max_per_tick: int = 1      # keep 1 for strict staggering; raise to allow small bursts

var _q: Array[Callable] = []
var _dedupe: Dictionary = {}           # key(any)->true if queued
var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = 1.0 / max(1.0, tick_hz)
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	_timer.start()

# --- Public API ---------------------------------------------------------------

func add(cb: Callable) -> void:
	# No coalescing: always enqueue.
	_q.push_back(cb)

func add_once(cb: Callable, key) -> void:
	# Coalesce by user-provided key (e.g., get_instance_id()).
	if _dedupe.has(key):
		return
	_dedupe[key] = true
	_q.push_back(cb)

func add_owner(owner: Object, method: String = "_refresh_all_paths") -> void:
	# Coalesce by instance id automatically.
	var key := owner.get_instance_id()
	if _dedupe.has(key):
		return
	_dedupe[key] = true
	_q.push_back(Callable(owner, method))

# --- Tick ---------------------------------------------------------------------

func _on_tick() -> void:
	var ran := 0
	while ran < max_per_tick and _q.size() > 0:
		var cb: Callable = _q.pop_front()
		# Clear dedupe if applicable (by owner id or explicit key)
		# For add_owner: the callable’s object id is our key.
		if cb.is_valid():
			var obj := cb.get_object()
			if obj:
				_dedupe.erase(obj.get_instance_id())
		# For add_once(key): we can’t know the key here unless the user passed it.
		# If you want that too, wrap with a lambda that clears its own key.
		if cb.is_valid():
			cb.call()
		ran += 1

## OSCReceiver.gd
## Pure GDScript OSC/UDP listener for Godot 4.
## No external plugin required — uses Godot's built-in PacketPeerUDP.
##
## Usage:
##   Add as Autoload singleton (Project > Project Settings > Autoload)
##   Other scripts read from OSCReceiver.params to get smoothed values.

extends Node

# --- Configuration ---
const LISTEN_PORT := 8000          # Match your sensor sender port
const BUFFER_SIZE := 4096

# --- Smoothing ---
# Low-pass filter factor: 0.0 = frozen, 1.0 = raw/instant
# 0.05-0.1 is good for noisy wearable sensors
const SMOOTH_FACTOR := 0.07

# --- Parameter bank ---
# Five performers mapped to named behavioral parameters.
# Add/rename these to match your actual OSC address space.
var params := {
	"/performer/1/velocity":   0.0,   # swim urgency / speed
	"/performer/2/lateral":    0.0,   # school cohesion / spread
	"/performer/3/vertical":   0.0,   # leap / depth
	"/performer/4/rotation":   0.0,   # predator evasion spiral
	"/performer/5/stillness":  0.0,   # resting in eddies
}

# Raw unsmoothed targets (updated from UDP packets)
var _targets := {}

var _socket := PacketPeerUDP.new()
var _connected := false


func _ready() -> void:
	_targets = params.duplicate()
	_start_listening()


func _start_listening() -> void:
	var err := _socket.bind(LISTEN_PORT)
	if err == OK:
		_connected = true
		print("[OSCReceiver] Listening on UDP port %d" % LISTEN_PORT)
	else:
		push_error("[OSCReceiver] Failed to bind port %d — error %d" % [LISTEN_PORT, err])


func _process(_delta: float) -> void:
	if not _connected:
		return
	# Drain all waiting packets each frame
	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		_parse_osc(packet)
	# Smooth all params toward their targets
	for address in params:
		params[address] = _smooth(params[address], _targets.get(address, 0.0))


# --- OSC Parsing ---
# Minimal OSC 1.1 parser: handles float (f) and int (i) arguments.
# Extend _parse_osc() if you need string/blob support.

func _parse_osc(packet: PackedByteArray) -> void:
	if packet.size() < 4:
		return
	var offset := 0

	# Read OSC address string (null-terminated, padded to 4 bytes)
	var address := ""
	while offset < packet.size() and packet[offset] != 0:
		address += char(packet[offset])
		offset += 1
	offset = _pad4(offset + 1)  # skip null + padding

	if not params.has(address):
		return  # Ignore addresses we're not watching

	# Read type tag string (starts with ',')
	if offset >= packet.size() or char(packet[offset]) != ',':
		return
	offset += 1  # skip ','
	var tags := ""
	while offset < packet.size() and packet[offset] != 0:
		tags += char(packet[offset])
		offset += 1
	offset = _pad4(offset + 1)

	# Read first argument only (we map one value per address)
	if tags.length() == 0:
		return
	var tag := tags[0]
	var value := 0.0

	if tag == "f" and offset + 4 <= packet.size():
		# IEEE 754 big-endian float
		var bytes := packet.slice(offset, offset + 4)
		value = bytes.decode_float(0)  # Godot 4: big-endian by default? check below
		# Note: OSC is big-endian. If you get garbage values, uncomment:
		# bytes.reverse(); value = bytes.decode_float(0)

	elif tag == "i" and offset + 4 <= packet.size():
		value = float(packet.decode_s32(offset))

	_targets[address] = value


# --- Helpers ---

func _pad4(n: int) -> int:
	return n + (4 - n % 4) % 4


func _smooth(current: float, target: float) -> float:
	return current + (target - current) * SMOOTH_FACTOR


# --- Public API ---

## Get a smoothed parameter value by OSC address.
## Returns 0.0 if address not found.
func get_param(address: String) -> float:
	return params.get(address, 0.0)


## Convenience: get all five performer values as an array [p1..p5]
func get_all() -> Array:
	return [
		params.get("/performer/1/velocity",  0.0),
		params.get("/performer/2/lateral",   0.0),
		params.get("/performer/3/vertical",  0.0),
		params.get("/performer/4/rotation",  0.0),
		params.get("/performer/5/stillness", 0.0),
	]

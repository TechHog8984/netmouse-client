extends Node2D

func logstr(message: String) -> void:
    $OutputLabel.text += message + '\n'

var websocket_url = "ws://192.168.2.0:22322"
var socket = WebSocketPeer.new()


func _ready():
    $StopButton.disabled = true
    $IpDropdown.item_selected.connect(_on_ip_select)
    $StopButton.pressed.connect(stop)
    $StartButton.pressed.connect(_on_start_button)

var has_connected = false
var has_initialized = false

func start():
    logstr("Initiating connection to %s" % websocket_url)
    $StartButton.disabled = true
    var err = socket.connect_to_url(websocket_url)
    if err == OK:
        has_connected = true
    else:
        logstr("Failed to make connection")
        
func _on_start_button():
    $StartButton.disabled = true
    start()

func _on_ip_select(num):
    stop()
    websocket_url = "ws://192.168.2.%d:22322" % num
    start()

func stop():
    if has_connected:
        socket.close()
    has_connected = false
    has_initialized = false
    $StopButton.disabled = true
    $StartButton.disabled = false

var last_event_time = Time.get_ticks_msec()
var queue: Array[int] = []

var last_reconnect_time = last_event_time

func _process(_delta):
    if has_connected:
        socket.poll()

        var state = socket.get_ready_state()

        if state == WebSocketPeer.STATE_OPEN:
            if has_initialized:
                var elapsed = Time.get_ticks_msec() - last_event_time
                if (not queue.is_empty() and elapsed > 50):
                    var release12 = false
                    var press1 = false
                    var press2 = false
                    var release3 = false
                    var press3 = false
                    while not queue.is_empty():
                        var num = queue.pop_front()
                        if num == 0:
                            release12 = true
                        elif num == 1:
                            press1 = true
                        elif num == 2:
                            release12 = true
                        elif num == 3:
                            press1 = false
                            press2 = true
                        elif num == 4:
                            release3 = true
                        elif num == 5:
                            press1 = false
                            press2 = false
                            press3 = true
                    if release12:
                        socket.send_text("click0")
                    if press1:
                        socket.send_text("click1")
                    if press2:
                        socket.send_text("click2")
                    if release3:
                        socket.send_text("click3")
                    if press3:
                        socket.send_text("click4")
            else:
                logstr("Connection is open.")
                var size = DisplayServer.screen_get_size()
                socket.send_text("screensize" + str(size.x) + "," + str(size.y))
                $StopButton.disabled = false
            has_initialized = true

            while socket.get_available_packet_count():
                var packet = socket.get_packet()
                if socket.was_string_packet():
                    var packet_text = packet.get_string_from_utf8()
                    $ResponseLabel.text = "Response: %s" % packet_text
                else:
                    $ResponseLabel.text = "Response: [binary data with %d bytes]" % packet.size()

        elif state == WebSocketPeer.STATE_CLOSING:
            pass

        elif state == WebSocketPeer.STATE_CLOSED:
            if (has_initialized):
                var code = socket.get_close_code()
                logstr("WebSocket closed with code: %d. Clean: %s" % [code, code != -1])
                $StopButton.disabled = true
                $StartButton.disabled = true

            has_initialized = false
            var time = Time.get_ticks_msec()
            var elapsed = (time - last_reconnect_time)
            if (elapsed > 2000):
                last_reconnect_time = time
                logstr("Attempting reconnect...")
                start()
                $StopButton.disabled = false

func _unhandled_input(event):
    if has_initialized:
        if event is InputEventScreenDrag:
            var velocity = event.velocity
            socket.send_text("move" + str(velocity.x) + "," + str(velocity.y))
        elif event is InputEventScreenTouch:
            if event.canceled:
                return
            if event.index < 1:
                return

            last_event_time = Time.get_ticks_msec()

            var num = 1 if event.pressed else 0
            num += (event.index - 1) * 2
            queue.push_back(num)

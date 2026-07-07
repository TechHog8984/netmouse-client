extends Node2D

func logstr(message: String) -> void:
    $OutputLabel.text += message + '\n'

@export var websocket_url = "ws://192.168.2.208:8080"
var socket = WebSocketPeer.new()


func _ready():
    logstr("Connecting to %s..." % websocket_url)
    var err = socket.connect_to_url(websocket_url)
    if err == OK:
        logstr("Connection attempt successful.")
    else:
        logstr("Unable to connect.")
        set_process(false)

var has_initialized = false

var last_event_time = Time.get_ticks_msec()
var queue: Array[int] = []

var last_reconnect_time = last_event_time

func _process(_delta):
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
            socket.send_text("screensize" + str(DisplayServer.screen_get_size()))
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

        has_initialized = false
        var time = Time.get_ticks_msec()
        var elapsed = (time - last_reconnect_time)
        if (elapsed > 2000):
            last_reconnect_time = time
            logstr("Attempting reconnect...")
            socket.connect_to_url(websocket_url)

func _unhandled_input(event):
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

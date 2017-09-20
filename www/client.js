/// Global variables describing play state
var player = {
	uuid: localStorage.getItem("uuid") + "", // Will be "null" or "none" if not known
	x: 0,
	y: 0,
	avatar: new Image(),
};

var room = {
	uuid: '',
	name: '',
	items: [],
	item_places: [],
	players: [],
};

var ws; // Websocket connection
var gamecanvas; // html5 canvas element game is painted on

/// Event handlers


window.onload = function() {
	gamecanvas = document.getElementById('gamecanvas');
	
	var port_piece = location.port == '' ? '' : ':'+location.port;
	ws = new WebSocket('ws://'+location.hostname+port_piece+'/ws');
	
	clear_room();
	
	ws.onopen = function() {
		console.log("Socket opened");
		fullRender();
		ws.send(JSON.stringify({
			task: "player_connected",
			uuid: player.uuid
		}));
		notify("Server connected.");
	};
	
	ws.onmessage = function(event) {
		var data = JSON.parse(event.data);
		switch (data.ev_name) {
			case 'exec':
				console.log(data["instructions"]);
				//eval(data["instructions"]);
				window.eval(data["instructions"]);
				break;
			default:
				console.log("Unknown event, raw data: '"+event.data+"'");
				break;
		}
	};
	
	ws.onclose = function() {
		console.log("Socket closed");
		notify("Lost connection with server.");
		// TODO alert user, clean up, etc.
	};
};

function on_user_keypress(e) {
    e = e || window.event;
    switch (e.keyCode) {
    	case 37: // Left arrow
    		move(-20, 0);
    		break;
    	case 38: // Up arrow
    		move(0, -20);
    		break;
    	case 39: // Right arrow
	    	move(20, 0);
    		break;
    	case 40: // Down arrow
    		move(0, 20);
    		break;
    	default:
    		console.log('Pressed: '+e.keyCode);
    		break;
    }
}
document.addEventListener("keydown", on_user_keypress, false);

function on_user_right_click(e) {
	e.preventDefault();
	var x = e.clientX * window.devicePixelRatio;
	var y = e.clientY * window.devicePixelRatio;
	
	console.log(e);
	return false;
}
document.addEventListener('contextmenu', on_user_right_click, false);

var last_mouse_move = new Date().getTime();
function mouse_move(ev) {
	var now = new Date().getTime();
	if (now - last_mouse_move < 100) return; // Only handle events once every 100ms
	last_mouse_move = now;
	var x = ev.clientX;
	var y = ev.clientY;
	
	x += 100;
	y += 100;
	
	
	for (var i=0; i<room.item_places.length; i++) {
		var place = room.item_places[i];
		var item_index = getItemIndex(place.item_uuid);
		var item = room.items[item_index];
		// see app.d has_collided
		var x_collide = x+(item.width/window.devicePixelRatio) > place.x && x < place.x+(item.width/window.devicePixelRatio);
		var y_collide = y+(item.height/window.devicePixelRatio) > place.y && y < place.y+(item.height/window.devicePixelRatio);
		
		if (x_collide && y_collide) {
			// Remove any existing notifications
			var notifications = document.getElementsByClassName('notification');
			for (var i=0; i<notifications.length; i++) {
				notifications[i].remove();
			}
			notify_specific(item.greentext, x-100, y-100);
		}
	}
	
	//console.log(ev);
}
document.onmousemove = mouse_move; 

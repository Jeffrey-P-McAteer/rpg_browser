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
	
	ws.onopen = function() {
		console.log("Socket opened");
		fullRender();
		ws.send(JSON.stringify({
			task: "player_connected",
			uuid: player.uuid
		}));
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
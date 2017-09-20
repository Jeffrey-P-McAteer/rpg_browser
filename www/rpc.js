/**
 * These functions are designed to allow the server to more directly alter game state
 * through RPC calls
 */

function render() {
	var ctx = gamecanvas.getContext('2d');
	ctx.clearRect(0, 0, gamecanvas.width, gamecanvas.height);
	// Draw the room
	ctx.fillStyle = "#839496"; // base0
	ctx.font = '36px sans';
	ctx.fillText('RPG Browser Client', 10, 40);
	
	ctx.font = '26px sans';
	ctx.fillText(room.name, 10, 80);
	
	
	ctx.font = '12px sans';
	// Draw the objects
	for (var i = 0; i<room.item_places.length; i++) {
		rend_item_place(ctx, room.item_places[i]);
	}
	
	// Draw us
	rend_player(ctx, player);
	
	// Draw the players
	for (var i=0; i<room.players.length; i++) {
		rend_player(ctx, room.players[i]);
	}
}

function fullRender() {
	gamecanvas.width = window.innerWidth - 5;
	gamecanvas.style.width = gamecanvas.width + "px";
	gamecanvas.width *= window.devicePixelRatio;
	
	gamecanvas.height = window.innerHeight - 5;
	gamecanvas.style.height = gamecanvas.height + "px";
	gamecanvas.height *= window.devicePixelRatio;
	
	render();
}
window.onresize = fullRender;

function clear_room() {
	window.player = {
		uuid: localStorage.getItem("uuid") + "", // Will be "null" or "none" if not known
		x: 0,
		y: 0,
		avatar: new Image(),
	};

	window.room = {
		uuid: '',
		name: '',
		items: [],
		item_places: [],
		players: [],
	};
}

var move_lock = false;
function move(delta_x, delta_y) {
	if (move_lock) return;
	// Do local move
	player.x += delta_x;
	player.y += delta_y;
	// Inform server
	ws.send(JSON.stringify({
		task: 'player_moved',
		uuid: player.uuid,
		x: player.x,
		y: player.y,
		avatar: player.avatar.src
	}));
	move_lock = true;
	render();
}

function constructItemPlace(item_p) {
	var i = getItemPlaceIndex(item_p.uuid);
	if (i != -1) {
		console.log("Not constructing itemplace, we already have ",item_p.uuid);
		return;
	}
	console.log("Constructing itemplace ",item_p.uuid);
	room.item_places.push(item_p);
	// Ask for actual item
	ws.send(JSON.stringify({
		task: "get_item_data",
		uuid: item_p.item_uuid,
	}));
	render();
}

function constructItem(item) {
	var i = getItemIndex(item.uuid);
	if (i != -1) return;
	item.background = new Image();
	item.background.src = item.background_url;
	room.items.push(item);
	render();
}

function setRoomName(name) {
	room.name = name;
}

function createPlayer(p) {
	if (typeof p.avatar === "string") {
		var tmp = p.avatar;
		p.avatar = new Image();
		p.avatar.src = tmp;
	}
	if (p.uuid == player.uuid) {
		setPlayerTo(p); // log error?
		return;
	}
	var i = getPlayerIndex(p.uuid);
	if (i == -1) {
		room.players.push(p);
		render();
	}
	else { // Update with location data (possibly avatar data as well?)
		room.players[i].x = player.x;
		room.players[i].y = player.y;
	}
	movePlayer(p.uuid, p.x, p.y);
}

function setPlayerTo(p) {
	if (typeof p.avatar === "string") {
		var tmp = p.avatar;
		p.avatar = new Image();
		p.avatar.src = tmp;
	}
	player = p;
	localStorage.setItem("uuid", player.uuid);
	render();
}

function deletePlayer(uuid) {
	var index_of_player = getPlayerIndex(uuid);
	if (index_of_player === -1) return;
	room.players.splice(index_of_player, 1);
	render();
}

function movePlayer(uuid, x, y) {
	if (uuid == player.uuid) {
		player.x = x;
		player.y = y;
		return;
	}
	var index_of_player = getPlayerIndex(uuid);
	if (index_of_player == -1) {
		ws.send(JSON.stringify({
			task: "get_player_data",
			uuid: uuid,
		}));
		console.log("[ Error ] We don't know player "+uuid);
		return;
	}
	room.players[index_of_player].x = x;
	room.players[index_of_player].y = y;
	render();
}


// Supporting functions

function getPlayerIndex(uuid) {
	var index_of_player = -1;
	for (var i=0; i<room.players.length; i++) {
		if (room.players[i].uuid === uuid) {
			index_of_player = i;
			break;
		}
	}
	return index_of_player;
}

function getItemPlaceIndex(uuid) { // items in room.item_places
	var index_of_item = -1;
	for (var i=0; i<room.item_places.length; i++) {
		if (room.item_places[i].uuid === uuid) {
			index_of_item = i;
			break;
		}
	}
	return index_of_item;
}

function getItemIndex(uuid) { // for items in room.items
	var index_of_item = -1;
	for (var i=0; i<room.items.length; i++) {
		if (room.items[i].uuid === uuid) {
			index_of_item = i;
			break;
		}
	}
	return index_of_item;
}

function rend_player(ctx, p) {
	ctx.drawImage(p.avatar, p.x, p.y, 80, 80);
	ctx.fillText(p.uuid.split("-")[0], p.x, p.y-20);
}

function rend_item_place(ctx, itm_p) {
	// This will be slow and should be avoided
	var item_i = getItemIndex(itm_p.item_uuid);
	if (item_i == -1) {
		console.log("We do not have the item for item place ", itm_p.uuid);
		return;
	}
	var item = room.items[item_i];
	ctx.drawImage(item.background, itm_p.x, itm_p.y, item.width, item.height);
	
}
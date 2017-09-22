import std.uuid;

import vibe.vibe;
import ddbc;

import room;
import item;
import database;
import app:all_player_sockets,construct_exec,construct_exec_str,dbconn,simple_ascii;

struct Player {
	// Identifying info
	@("TEXT")
	string uuid;
	
	// Visuals
	@("TEXT")
	string avatar;
	
	@("TEXT")
	string nickname;
	
	// Location data
	@("LONG")
	long x;
	
	@("LONG")
	long y;
	
	@("TEXT")
	string room_uuid;
	
	@("TEXT")
	string inventory_table;
}

struct PythonPlayer { // For use with python API
	string uuid;
	string avatar;
	string nickname;
	long x;
	long y;
	
	void notify(string message) {
		all_player_sockets[uuid].send(construct_exec("notify('"~message.replace("'", "\"")~"');").toString());
	}
}

PythonPlayer player_to_pythonplayer(Player p) {
	PythonPlayer pp;
	pp.uuid = p.uuid;
	pp.avatar = p.avatar;
	pp.nickname = p.nickname;
	pp.x = p.x;
	pp.y = p.y;
	return pp;
}

Player create_player() {
	Player p;
	p.uuid = randomUUID().toString();
	p.avatar = "player_avatars/default.png";
	p.nickname = "player-nickname";
	p.inventory_table = "inventory_for_"~p.uuid;
	return p;
}

void spawn_in(Player p, Room r) {
	p.x = r.get_spawn_coord(r.spawn_x);
	p.y = r.get_spawn_coord(r.spawn_y);
	p.room_uuid = r.uuid;
}

string to_json(Player p) { // todo sanitize the inputs for all player elements to prevent XSS
	return  "{"~
			  "uuid:\""~simple_ascii(p.uuid)~"\","~
			  "avatar:\""~p.avatar~"\","~
			  "nickname:\""~simple_ascii(p.nickname)~"\","~
			  "x:"~to!string(p.x)~","~
			  "y:"~to!string(p.y)~","~
			"}";
}

/// Renders player in a given room. Inserts/updates player into database
void go_to_room(Player p, Room r) {
	if (!all_player_sockets.get(p.uuid, null)) {
		logInfo("p.uuid == "~p.uuid~", we do not know them.");
		return;
	}
	Room old_room = dbconn.get!Room(p.room_uuid);
	p.x = r.get_spawn_coord(r.spawn_x);
	p.y = r.get_spawn_coord(r.spawn_y);
	p.room_uuid = r.uuid;
	
	string obj = p.to_json();
	dbconn.insertSingle!Player(p);
	
	// Add player to r.table_of_players
	dbconn.insert_player_table_item(p.uuid, r.table_of_players);
	
	// Remove player from old_room.table_of_players
	if (old_room.uuid.length > 2) { // Check that the room is actually valid
		dbconn.remove_player_table_item(p.uuid, old_room.table_of_players);
	}
	
	WebSocket ws = all_player_sockets[p.uuid];
	// Remove old data
	ws.send(construct_exec_str("clear_room();"));
	foreach(player; dbconn.players(old_room)) {
		if (player.uuid == p.uuid) continue; // Ignore our player
		if (!all_player_sockets.get(player.uuid, null)) continue; // Skip players in the room who we do not have a socket for (why are they here?)
		all_player_sockets[player.uuid].send(construct_exec_str("deletePlayer('"~p.uuid~"');"));
	}
	
	// Add new data
	ws.send(construct_exec_str("setPlayerTo("~obj~");"));
	ws.send(construct_exec_str("setRoomName('"~r.name~"');")); // todo fix xss vuln
	
	foreach(item_place; dbconn.places(r)) {
		ws.send(construct_exec_str("constructItemPlace("~item_place.ip_to_json()~");"));
	}
	
	// Notify other players in room that player has joined
	foreach(player; dbconn.players(r)) {
		if (player.uuid == p.uuid) continue; // Ignore our player
		if (!all_player_sockets.get(player.uuid, null)) continue; // Skip players in the room who we do not have a socket for (why are they here?)
		all_player_sockets[player.uuid].send(construct_exec_str("createPlayer("~obj~");"));
		// Also send player the other player's data
		ws.send(construct_exec_str("createPlayer("~player.to_json()~");"));
	}
}

Room get_room(Player p, Connection dbconn) {
	return dbconn.get!Room(p.room_uuid);
}

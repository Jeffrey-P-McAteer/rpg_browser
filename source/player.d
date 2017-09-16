import std.uuid;

import vibe.vibe;
import ddbc;

import room;
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
void go_to_room(ref Player p, Room r) {
	if (!all_player_sockets.get(p.uuid, null)) {
		logInfo("p.uuid == "~p.uuid~", we do not know them.");
		return;
	}
	p.x = r.get_spawn_coord(r.spawn_x);
	p.y = r.get_spawn_coord(r.spawn_y);
	p.room_uuid = r.uuid;
	
	string obj = p.to_json();
	dbconn.insertSingle!Player(p);
	
	WebSocket ws = all_player_sockets[p.uuid];
	ws.send(construct_exec_str("setPlayerTo("~obj~");"));
}

Room get_room(Player p, Connection dbconn) {
	return dbconn.get!Room(p.room_uuid);
}

/// stdlib imports
import std.stdio;
import std.uuid;

/// 3rd party imports
import core.thread;
import vibe.vibe;
import vibe.data.json;
import ddbc;
import pyd.pyd, pyd.embedded;

/// Our imports
import database;
import webapp;
import player;
import room;
import item;

// Global arg data for server
bool VERBOSE = false;
ushort http_port = 8080;
string db_conn_url = "sqlite:rpg_browser_db.sqlite";
string web_assets_dir = "./www/";

// Global variables for this server
Connection dbconn;
WebSocket[string] all_player_sockets;

void main(string[] args) {
	import std.getopt;
	import std.stdio;
	
	auto helpInfo = getopt(
		args,
		"db_conn_url|c",	 "See https://code.dlang.org/packages/ddbc for examples. Creates sqlite db ./rpg_browser_db.sqlite if not specified.", &db_conn_url,
		"verbose|v", 		 "Print additional debugging information", &VERBOSE,
		"http_port|p", 		 "Port HTTP server will listen on", &http_port,
		"web_assets_dir|d",  "Location of static web resources", &web_assets_dir,
	);
	
	if (helpInfo.helpWanted) {
		defaultGetoptPrinter("Usage: "~args[0], helpInfo.options);
		return;
	}
	
	server_init();
	start_web_server();
}

/// Performs all setup tasks before main loops spawn off
void server_init() {
	py_init();
	dbconn = createConnection(db_conn_url);
	dbconn.init_db();
}

void start_web_server() {
	auto router = new URLRouter;
	router.registerWebInterface(new WebApp());
	router.get("/ws", handleWebSockets(&on_websocket_connection));
	router.get("*", serveStaticFiles(web_assets_dir));
	
	auto settings = new HTTPServerSettings;
	settings.port = http_port;
	settings.bindAddresses = ["::", /*"0.0.0.0"*/]; // All ipv6, all ipv4 addresses ("::" also causes listening on 0.0.0.0/0)
	debug settings.options &= ~HTTPServerOption.errorStackTraces;
	try {
		listenHTTP(settings, router);
	}
	catch (Exception ex) {
		import std.process:execute;
		writeln("Cannot start webserver: "~ex.msg);
		writeln("Attempting to kill rpg_browser process with 'killall'...");
		execute(["killall", "rpg_browser"]);
		execute(["sleep", "1"]); // shaddup
		try {
			listenHTTP(settings, router);
		}
		catch (Exception ex2) {
			writeln("Cannot start webserver: "~ex.msg);
			return;
		}
	}
	runApplication(); // does not return
}

/// Handles connections to websockets, runs async
void on_websocket_connection(scope WebSocket sock) {
	string player_uuid;
	try {
		while (sock.connected) {
			string msg = sock.receiveText().strip();
			string msg_copy = msg;
			if (msg.length < 1) continue;
			Json data = parseJson(msg);
			switch (data["task"].get!string()) {
				case "player_connected":
					player_uuid = player_connected(sock, data);
					break;
				
				case "player_moved":
					Player p = dbconn.get!Player(player_uuid);
					player_moved(sock, data, p);
					break;
				
				case "get_player_data":
					get_player_data(sock, data);
					break;
				
				case "get_item_data":
					get_item_data(sock, data);
					break;
				
				default:
					logInfo("Unknown message: "~msg_copy);
					break;
			}
		}
	}
	catch (Exception ex) {
		bool is_unknown = !(ex.msg.indexOf("Connection closed while reading message") > -1);
		if (is_unknown) {
			logInfo(ex.toString());
		}
	}
	// Cleanup
	all_player_sockets.remove(player_uuid);
	Player p = dbconn.get!Player(player_uuid);
}

/// Returns player_uuid
string player_connected(WebSocket sock, Json data) {
	string player_uuid = data["uuid"].get!string;
	if (player_uuid == "null") {
		player_uuid = randomUUID().toString();
	}
	// Players always spawn in the room "default", which is special to each server
	Room def_room = dbconn.get_default_room();
	Player p = Player(player_uuid,
				 "player_avatars/default.png", // Default player avatar image
				 "player-nickname",
				 def_room.get_spawn_coord(def_room.spawn_x),
				 def_room.get_spawn_coord(def_room.spawn_y),
				 );
	Player existing = dbconn.get!Player(player_uuid);
	if (existing.uuid.length > 2) {
		p = existing;
	}
	all_player_sockets[player_uuid] = sock;
	p.go_to_room(def_room);
	
	return player_uuid;
}

void player_moved(WebSocket sock, Json data, Player player) {
	Player orig = player;
	// ^ kept so we can refer to previous player location data
	Player p = orig;
	p.x = data["x"].to!long;
	p.y = data["y"].to!long;
	Room r = p.get_room(dbconn);
	ItemPlacement[] item_places = dbconn.places(r);
	foreach (place; item_places) {
		bool x_collide = p.x+50 > place.x && p.x < place.x+50;
		bool y_collide = p.y+50 > place.y && p.y < place.y+50;
		if (x_collide && y_collide) {
			Item i = dbconn.get!Item(place.item_uuid);
			auto context = new InterpContext();
			i.handle_collision(place, p, orig, dbconn, sock, context, &send_to_player, &send_to_all);
		}
	}
	
	foreach(s; all_player_sockets) {
		if (!s.connected) continue;
		s.send(construct_exec("movePlayer('%s', %d, %d)", p.uuid, p.x, p.y).toString());
	}
	dbconn.update(p);
}

void get_player_data(WebSocket sock, Json data) {
	Player p = dbconn.get!Player(data["uuid"].get!string);
	sock.send(construct_exec("createPlayer(%s)", p.to_json()).toString());
}

void get_item_data(WebSocket sock, Json data) {
	string uuid = data["uuid"].to!string;
	logInfo("get_item_data called");
}

// ABOVE funcs handle player socket messages

// Functions used as API endpoints for eval-ed python code

void send_to_player(string uuid, string message) {
	if (all_player_sockets[uuid].connected) {
		all_player_sockets[uuid].send(construct_exec(message).toString());
	}
}

void send_to_all(string message) {
	foreach(s; all_player_sockets) {
		if (!s.connected) continue;
		s.send(construct_exec(message).toString());
	}
}

// Helpers

bool is_local_conn(WebSocket sock) {
	string from_ip = sock.request.clientAddress.toString();
	return from_ip.indexOf("127.0.0.1") == 0 || from_ip.indexOf("[0:0:0:0:0:0:0:1]") == 0;
}

string construct_exec_str(string, Args...)(string instructions, Args args) {
	return construct_exec(instructions, args).toString();
}

Json construct_exec(string, Args...)(string instructions, Args args) {
	Json root = Json.emptyObject;
	root["ev_name"] = "exec";
	root["instructions"] = format(instructions, args);
	return root;
}

/// Removes any sort of "control characters" (parens, quotes, etc.) and returns only
/// [a-z][A-Z][0-9], spaces, periods, hyphens, colons, and probably a subset of unicode glyphs.
/// Basically a whitelist for "goody-two-shoes" strings.
string simple_ascii(string s) {
	return s; // todo make simple_ascii do something useful
}
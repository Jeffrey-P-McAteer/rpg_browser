import std.uuid;
import ddbc;
import pyd.pyd, pyd.embedded;
import vibe.vibe;

import database;
import player;

struct ItemPlacement {
	@("TEXT")
	string uuid; // UUID of the placement
	
	@("TEXT")
	string item_uuid; // UUID of the actual item
	
	@("LONG")
	long x;
	@("LONG")
	long y;
	
}

/// What the item is
struct Item {
	@("TEXT")
	string uuid;
	
	@("TEXT")
	string background_url; // image of bg, like 'http://server.com:9090/bgs/fence.jpg'
	
	@("LONG")
	long width;
	@("LONG")
	long height;
	
	@("TEXT")
	string greentext; // Quick description, like "A plain, boring fence. Your friend Tom says it's fun to paint."
	
	@("TEXT")
	string on_player_collide; // Python eval-d when a player collides with item. Common use is to put the player back (a "collision")
}

/**
 * Constructs environment for executing python code when an item has been trodden over.
 */
void handle_collision(Item i, ItemPlacement ip, Player p, Player old_p,
					  Connection dbconn, WebSocket sock, InterpContext ctx,
					  void function(string, string) send_to_player, void function(string)  send_to_all, void function(string, string) send_player_to_room) {
	ctx.send_to_all = send_to_all;
	ctx.send_to_player = send_to_player;
	ctx.send_player_to_room = send_player_to_room;
	
	ctx.item = i.uuid;
	ctx.player = p;
	ctx.untrusted_code = i.on_player_collide;
	// Run python scriptlet in a restricted environment
	string[] whitelist = [
		"send_to_all", "send_to_player", "send_player_to_room",
		"item", "player"
	];
	try {
		ctx.py_stmts("exec(untrusted_code, "~
			"{\"__builtins__\":None},"~
			"{"~ // Whitelist of allowed local functions
				whitelist_chunk_from_list(whitelist)~
			"})");
	}
	catch (Exception ex) {
		// Should we mark the item until it is changed?
		send_to_player(p.uuid, "alert('this item tried to do something nasty')");
		logInfo(to!string(ex));
	}
	send_to_player(p.uuid, "notify('"~i.greentext.replace("'", " ")~"')");
}

string whitelist_chunk_from_list(string[] whitelist) {
	string s;
	foreach (itm; whitelist) {
		s ~= "\""~itm~"\":"~itm~",";
	}
	return s;
}

ItemPlacement create_place(Connection dbconn) {
	string uuid = randomUUID().toString();
	return dbconn.create_place(uuid);
}

ItemPlacement create_place(Connection dbconn, string uuid) {
	ItemPlacement existing_place = dbconn.get!ItemPlacement(uuid);
	if (existing_place.uuid.length > 1) return existing_place;
	ItemPlacement ip = ItemPlacement(uuid, "the-item-uuid", 0, 0);
	ItemPlacement copy = ip;
	dbconn.insert!ItemPlacement(copy);
	return ip;
}

Item create_item(Connection dbconn) {
	string uuid = randomUUID().toString();
	return dbconn.create_item(uuid);
}

Item create_item(Connection dbconn, string uuid) {
	Item existing_item = dbconn.get!Item(uuid);
	if (existing_item.uuid.length > 1) return existing_item;
	Item item = Item(uuid, "http://site.com/background-url.jpg", 0, 0, "Empty greentext", "# Python code");
	Item copy = item;
	dbconn.insert!Item(copy);
	return item;
}

string i_to_json(Item i) {
	return "{"~
			 "uuid:\""~i.uuid~"\","~
			 "background_url:\""~i.background_url~"\","~
			 "width:"~to!string(i.width)~","~
			 "height:"~to!string(i.height)~","~
			 "greentext:\""~i.greentext~"\","~
		   "}";
}

string ip_to_json(ItemPlacement ip) {
	return "{"~
			 "uuid:\""~ip.uuid~"\","~
			 "item_uuid:\""~ip.item_uuid~"\","~
			 "x:"~to!string(ip.x)~","~
			 "y:"~to!string(ip.y)~","~
		   "}";
}
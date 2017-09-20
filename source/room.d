import std.string;
import std.uuid;

import ddbc;
import vibe.vibe;

import app:dbconn;
import database;
import player;
import item;

struct Room {
	@("TEXT")
	string uuid;
	
	@("TEXT")
	string name;
	
	@("TEXT")
	string description;
	
	@("LONG")
	long spawn_x;
	@("LONG")
	long spawn_y;
	@("LONG")
	long spawn_radius;
	// Players will spawn randomly within [(spawn_x - spawn_radius), (spawn_x + spawn_radius)]
	
	@("TEXT")
	string table_of_players;
	
	@("TEXT")
	string table_of_item_placements;
}

// Represents a single player UUID held in table_of_players, which is serialized into Room.players
struct PlayerTableItem {
	@("TEXT")
	string uuid;
}

// Represents a single item UUID held in table_of_item_placements, which is serialized into Room.items
struct ItemTableItem { // Each of these is of TYPE ItemPlacement, not Item.
	@("TEXT")
	string uuid;
}

Room create_room(Connection dbconn) {
	string uuid = randomUUID().toString();
	return dbconn.create_room(uuid);
}

Room create_room(Connection dbconn, string uuid) {
	Room existing_room = dbconn.get!Room(uuid);
	if (existing_room.uuid.length > 1) return existing_room;
	Room r = Room(uuid, "Boring name", "Empty description", 150, 200, 100);
	
	string post = r.uuid.replace("-", "_");
	r.table_of_players = "players_for_"~post;
	r.table_of_item_placements = "item_places_for_"~post;
	dbconn.ensure_table_exists(r.table_of_players, fullSQLSchemaFromType!PlayerTableItem());
	dbconn.ensure_table_exists(r.table_of_item_placements, fullSQLSchemaFromType!ItemTableItem());
	
	Room copy = r;
	dbconn.insert!Room(copy);
	
	return r;
}

Room get_default_room(Connection dbconn) {
	return dbconn.create_room("default");
}

long get_spawn_coord(Room r, long x_or_y) {
	import std.random;
	return uniform(x_or_y - r.spawn_radius, x_or_y + r.spawn_radius);
}

Player get_player(Connection dbconn, Room r, string uuid) {
	Player[] ps = dbconn.players(r);
	foreach (p; ps) {
		if (p.uuid == uuid) {
			return p;
		}
	}
	Player p;
	return p;
}

Player[] players(Connection dbconn, Room r) {
	Player[] p;
	PlayerTableItem[] ptis = dbconn.get_player_table_items(r.table_of_players);
	foreach(pt; ptis) {
		//dbconn.get_player(r, pt.player_uuid);
		p ~= dbconn.get!Player(pt.uuid);
	}
	return p;
}

ItemPlacement[] places(Connection dbconn, Room r) {
	ItemPlacement[] ips;
	ItemTableItem[] uuids = dbconn.get_item_table_items(r.table_of_item_placements);
	foreach(uuid; uuids) {
		ips ~= dbconn.get!ItemPlacement(uuid.uuid);
	}
	return ips;
}

PlayerTableItem[] get_player_table_items(Connection dbconn, string table_name) {
	PlayerTableItem[] results;
	if (table_name.length < 1) { // Why does this happen?
		return results;
	}
	Statement stmt = dbconn.createStatement();
	scope(exit) stmt.close();
	
	auto rs = stmt.executeQuery("SELECT * FROM "~table_name);
	while (rs.next()) {
		results ~= PlayerTableItem(rs.getString(1));
	}
	return results;
}

ItemTableItem[] get_item_table_items(Connection dbconn, string table_name) {
	Statement stmt = dbconn.createStatement();
	scope(exit) stmt.close();
	auto rs = stmt.executeQuery("SELECT * FROM "~table_name);
	ItemTableItem[] results;
	while (rs.next()) {
		results ~= ItemTableItem(rs.getString(1));
	}
	return results;
}

void insert_player_table_item(Connection dbconn, string uuid, string table_name) {
	auto stmt = dbconn.createStatement();
	scope(exit) stmt.close();
	PlayerTableItem[] existing = dbconn.get_player_table_items(table_name);
	foreach (e; existing) {
		if (e.uuid == uuid) {
			return; // Don't add duplicate entries
		}
	}
	stmt.executeUpdate("INSERT INTO "~table_name~" (uuid) VALUES (\""~uuid~"\")");
}

void remove_player_table_item(Connection dbconn, string uuid, string table_name) {
	auto stmt = dbconn.createStatement();
	scope(exit) stmt.close();
	assert(table_name.length > 1);
	stmt.executeUpdate("DELETE FROM "~table_name~" WHERE uuid=\""~uuid~"\"");
}
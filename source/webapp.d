import vibe.vibe;

import database;
import room;
import item;
import player;

import app:dbconn;

/// Vibe.d application endpoints
class WebApp {
	
	void get() {
		getClient();
	}
	
	void getClient() {
		render!("client.dt");
	}
	
	void getServer() {
		render!("server.dt", dbconn); // todo work here
	}
	
	void postDelete_db() {
		dbconn.reset_db();
		redirect("server");
	}
	
	void postNew_room() {
		dbconn.create_room();
		redirect("server");
	}
	
	void postEdit_room(string room_uuid) {
		Room room = dbconn.get!Room(room_uuid);
		render!("edit_room.dt", dbconn, room);
	}
	
	static string[] getItemPlacements(HTTPServerRequest req, HTTPServerResponse res) {
		string[] item_places;
		foreach (key; req.form.byKey()) {
			if (key.indexOf("r_placements_") != 0) continue;
			string val = req.form[key];
			item_places ~= val;
		}
		return item_places;
	}
	
	@before!getItemPlacements("r_item_place_uuids")
	void postSaveroom(Room r, string[] r_item_place_uuids, string action) {
		Room old = dbconn.get!Room(r.uuid);
		// We don't trust the client to edit this data manually
		r.table_of_players = old.table_of_players;
		r.table_of_item_placements = old.table_of_item_placements;
		
		ItemPlacement[] r_ips = dbconn.places(r);
		
		// Forget everything we know
		dbconn.dropTable(r.table_of_item_placements);
		dbconn.ensure_table_exists(r.table_of_item_placements, fullSQLSchemaFromType!ItemTableItem());
		
		// Add UUIDs in r_item_place_uuids to r.table_of_item_placements
		foreach(uuid; r_item_place_uuids) {
			ItemPlacement new_ip = dbconn.get!ItemPlacement(uuid);
			if (new_ip.uuid.length < 1) continue; // This UUID does not exist, ideally we'd yell @ user
			dbconn.insertManual!ItemTableItem(ItemTableItem(new_ip.uuid), r.table_of_item_placements);
		}
		
		dbconn.update!Room(r);
		redirect("server");
	}
}

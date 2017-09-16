import std.process:escapeShellCommand;
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
	
	/// New buttons
	
	void postNew_room() {
		dbconn.create_room();
		redirect("server");
	}
	
	void postNew_item_place() {
		dbconn.create_place();
		redirect("server");
	}
	
	void postNew_item() {
		dbconn.create_item();
		redirect("server");
	}
	
	/// Edits
	
	void postEdit_room(string room_uuid) {
		Room room = dbconn.get!Room(room_uuid);
		render!("edit_room.dt", dbconn, room);
	}
	
	void postEdit_item_place(string item_place_uuid) {
		ItemPlacement place = dbconn.get!ItemPlacement(item_place_uuid);
		render!("edit_place.dt", dbconn, place);
	}
	
	void postEdit_item(string item_uuid) {
		Item item = dbconn.get!Item(item_uuid);
		render!("edit_item.dt", dbconn, item);
	}
	
	/// Saves
	
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
	
	void postSaveitem(Item i, string action) {
		if (action == "Save") {
			dbconn.update!Item(i);
		}
		else if (action == "Delete") {
			string s = "uuid="~escapeShellCommand(i.uuid);
			logInfo(s);
			try {
				dbconn.del!Item(s);
			}
			catch (Exception ex) { // Someone is trying to inject bad things
				logInfo(ex.msg);
			}
		}
		else {
			logInfo("Unknown action POST to saveitem: "~action);
		}
		redirect("server");
	}
	
	void postSaveplace(ItemPlacement ip, string action) {
		if (action == "Save") {
			dbconn.update!ItemPlacement(ip);
		}
		else if (action == "Delete") {
			string s = "uuid="~escapeShellCommand(ip.uuid);
			logInfo(s);
			try {
				dbconn.del!ItemPlacement(s);
			}
			catch (Exception ex) { // Someone is trying to inject bad things
				logInfo(ex.msg);
			}
		}
		else {
			logInfo("Unknown action POST to saveplace: "~action);
		}
		redirect("server");
	}
	
}

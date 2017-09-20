import ddbc;
import vibe.vibe;

import room;
import player;
import item;

/// Global db connection for server
Connection server_dbconn;

/// Setup new database
void init_db(Connection dbconn) {
	server_dbconn = dbconn;
	auto stmt = dbconn.createStatement();
	scope(exit) stmt.close();
	stmt.executeUpdate(`CREATE TABLE IF NOT EXISTS `~getTableNameForType!Player()~` (`~fullSQLSchemaFromType!Player()~`)`);
	stmt.executeUpdate(`CREATE TABLE IF NOT EXISTS `~getTableNameForType!Room()~` (`~fullSQLSchemaFromType!Room()~`)`);
	stmt.executeUpdate(`CREATE TABLE IF NOT EXISTS `~getTableNameForType!Item()~` (`~fullSQLSchemaFromType!Item()~`)`);
	stmt.executeUpdate(`CREATE TABLE IF NOT EXISTS `~getTableNameForType!ItemPlacement()~` (`~fullSQLSchemaFromType!ItemPlacement()~`)`);
	
	// Create room "default"
	dbconn.get_default_room();
	
}

/// Remove all of our data from a database
void destroy_db(Connection dbconn = server_dbconn) {
	// TODO check if sqlite or other, drop & re-create database if proper mysql backend.
	auto stmt = dbconn.createStatement();
	scope(exit) stmt.close();
	auto rs = stmt.executeQuery("SELECT name FROM sqlite_master WHERE type='table'");
	string[] tables; // Alternative - could we track every table we create?
	while (rs.next()) {
		tables ~= rs.getString(1);
	}
	foreach(table; tables) {
		auto rm_stmt = dbconn.createStatement();
		rm_stmt.executeUpdate("DROP TABLE IF EXISTS "~table);
		rm_stmt.close();
	}
}

/// Combine destroying and initing db
void reset_db(Connection dbconn = server_dbconn) {
	dbconn.destroy_db();
	dbconn.init_db();
}

/// Specific helpers for get/update/delete custom table/type names.

/// Type-sensitive get/update/delete methods used for the global object tables.

T[] get(T)(Connection dbconn = server_dbconn) {
	Statement stmt = dbconn.createStatement();
	scope(exit) stmt.close();
	stmt.executeQuery("SELECT * FROM "~getTableNameForType!T());
	T[] results;
	foreach(ref e; stmt.select!T) {
		results ~= e;
	}
	return results;
}

// Gets first item with uuid == uuid
T get(T)(Connection dbconn, string uuid) {
	Statement stmt = dbconn.createStatement();
	scope(exit) stmt.close();
	stmt.executeQuery("SELECT * FROM "~getTableNameForType!T()~" WHERE uuid=\""~uuid~"\""); // SQL Injection Alert
	T result;
	result.uuid = "";
	foreach(ref e; stmt.select!T.where("uuid=\""~uuid~"\"")) {
		return e;
	}
	return result;
}

/// Inserts a new row in a DB table defined by the datatype.
void insert(T)(Connection dbconn, T data) {
	auto stmt = dbconn.prepareStatement("INSERT INTO "~getTableNameForType!T()~
										" ("~lightSQLSchemaFromType!T()~") VALUES ("~
										prepStmtSQLSchemaFromType!T()~")");
	scope(exit) stmt.close();
	int i = 0;
	foreach (member_name; __traits(allMembers, T)) {
		i++;
		auto data_val = __traits(getMember, data, member_name);
		static if (__traits(isArithmetic, data_val)) {
			stmt.setLong(i, data_val);
		}
		else {
			stmt.setString(i, data_val);
		}
	}
	stmt.executeUpdate();
}

/**
 * Inserts a new row in a DB table based on a manually given table name
 */
void insertManual(T)(Connection dbconn, T data, string table_name) {
	auto stmt = dbconn.prepareStatement("INSERT INTO "~table_name~
										" ("~lightSQLSchemaFromType!T()~") VALUES ("~
										prepStmtSQLSchemaFromType!T()~")");
	scope(exit) stmt.close();
	int i = 0;
	foreach (member_name; __traits(allMembers, T)) {
		i++;
		auto data_val = __traits(getMember, data, member_name);
		static if (__traits(isArithmetic, data_val)) {
			stmt.setLong(i, data_val);
		}
		else {
			stmt.setString(i, data_val);
		}
	}
	stmt.executeUpdate();
}

/// Updates a field based on T.uuid, which must be present
void update(T)(Connection dbconn, T data) {
	auto stmt = dbconn.prepareStatement("UPDATE "~getTableNameForType!T()~
										" SET "~prepStmtUpdateSQLSchemaFromType!T()~
										" WHERE uuid=\""~data.uuid~"\""); // todo remove sql injection vuln
	scope(exit) stmt.close();
	int i = 0;
	foreach (member_name; __traits(allMembers, T)) {
		i++;
		auto data_val = __traits(getMember, data, member_name);
		static if (__traits(isArithmetic, data_val)) {
			stmt.setLong(i, data_val);
		}
		else {
			stmt.setString(i, data_val);
		}
	}
	stmt.executeUpdate();
}

/// Inserts a new row in a DB table defined by the datatype, only if it does not already exist by 'uuid' parameter
void insertSingle(T)(Connection dbconn, T data) {
	T existing = dbconn.get!T(data.uuid);
	if (existing.uuid.length < 2) {
		dbconn.insert!T(data);
	}
	else {
		dbconn.update!T(data);
	}
}

void del(T)(Connection dbconn, string condition) {
	auto stmt = dbconn.prepareStatement("DELETE FROM "~getTableNameForType!T()~" WHERE "~condition);
	scope(exit) stmt.close();
	stmt.executeUpdate();
}


void dropTable(Connection dbconn, string table_name) {
	auto stmt = dbconn.prepareStatement("DROP TABLE "~table_name);
	scope(exit) stmt.close();
	stmt.executeUpdate();
}

/// Bridges between internal datatypes and databast types

/**
 * Given the input type, generate the full (varname TYPE) sql schema for it.
 */
string fullSQLSchemaFromType(T)() {
	import std.traits;
	string schema;
	foreach (member_name; __traits(allMembers, T)) {
		auto ts = __traits(getAttributes, __traits(getMember, T, member_name) );
		string sql_type = ts[0];
		schema ~= member_name~" "~sql_type~", ";
	}
	return schema[0..(schema.length - 2)]; // Trim last ", "
}

/**
 * Given the input type, generate the full (varname) sql schema for it.
 */
string lightSQLSchemaFromType(T)() {
	import std.traits;
	string schema;
	foreach (member_name; __traits(allMembers, T)) {
		schema ~= member_name~", ";
	}
	return schema[0..(schema.length - 2)]; // Trim last ", "
}

/**
 * Given the input type, generate the (?, ?) prepared statement string.
 */
string prepStmtSQLSchemaFromType(T)() {
	import std.traits;
	string schema;
	foreach (member_name; __traits(allMembers, T)) {
		schema ~= "?, ";
	}
	return schema[0..(schema.length - 2)]; // Trim last ", "
}

/**
 * Given the input type, generate the (phone_number=?, street_name=?) prepared statement string for updating a record.
 */
string prepStmtUpdateSQLSchemaFromType(T)() {
	import std.traits;
	string schema;
	foreach (member_name; __traits(allMembers, T)) {
		schema ~= member_name~"=?, ";
	}
	return schema[0..(schema.length - 2)]; // Trim last ", "
}

/// Helping methods

void ensure_table_exists(Connection dbconn, string name, string schema) {
	auto stmt = dbconn.createStatement();
	scope(exit) stmt.close();
	stmt.executeUpdate(`CREATE TABLE IF NOT EXISTS `~name~` (`~schema~`)`);
	
}

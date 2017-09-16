# RPG Browser

## What?
This is an environment with which adhering RPG servers and clients may communicate over an HTTP connection.
Servers do not need to know about eachother to have items, stats, skills, etc... pass between them. These things
will be defined by python snippets and saved to the client, then the client will upload them to new servers.

to avoid tampering, servers may ask eachother for a set of object names -> hashes of implementation and reject unknown
objects. To gain items like infinity-damage swords one would need to host their own server with an infinity-damage sword,
have their character visit that server and get the sword, then go to another server with the sword. This hack will work so
long as the server under control of the attacker remains up and can verify the hash of the infinity-damage sword.

## Why?
I'm trying to find meaning in life. No, actually I wish I could be an avid gamer, but I always get hung up on irrelevant "This game mechanic ought to work like this" issues. This game will let you build whatever game mechanics you like, to the point it becomes very easy to "cheat", except you can't cheat if the problems are all creative, can you? That infinity damage sword won't do much good if your character is so scared they can't go within arms reach of a monster.

I forsee this platform opening a new gaming subculture, centered around creative social problems. There already exist genres for strictly "creative" games, but the entire game has been predetermined by someone, and often this causes the correct choice to be simple and not creative at all.

## How?

Every server holds a table of:

### Rooms
A room has a table of ItemPlaces, a wrapper around items which specify their location. The room also contains a table of pointers to Players, which is how we determine who is in what room.

### Items
Every item will have a snippet of python source code. The builtins are disabled, and the purpose is to have an environment where arbitrary computation may happen to determine what happens when a player collides with the item. There may also be a set of "events" which may cause the snippet to be evaluated, probably stored in an EVENT_NAME variable with values like "collision", "added_to_inventory", "attacked", etc. Other useful metadata will be accessible, such as the room data, player data, and the player's previous location.

### Players
Every player will have 
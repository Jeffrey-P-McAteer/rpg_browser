function add_item_placement() {
	var room_item_places = document.getElementById('room_item_places');
	
	var p = document.createElement('p');
	p.id = "r_placements_"+room_item_places.childElementCount;
	
	var i = document.createElement('input');
	i.type = 'text';
	i.name = "r_placements_"+room_item_places.childElementCount;
	p.appendChild(i);
	
	var b = document.createElement('input');
	b.type = 'button';
	b.value = 'Remove';
	p.appendChild(b);
	
	room_item_places.appendChild(p);
}

function remove_item_placement(id) {
	document.getElementById(id).outerHTML = '';
}

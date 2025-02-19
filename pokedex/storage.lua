local defsave = require "defsave.defsave"
local json = require "defsave.json"
local md5 = require "utils.md5"
local utils = require "utils.utils"
local profiles = require "pokedex.profiles"
local pokedex = require "pokedex.pokedex"
local log = require "utils.log"
local dex = require "pokedex.dex"
local M = {}

local storage = {}
local active = {}
local counters = {}
local sorting = {}
local initialized = false

local function get_id(pokemon)
	local m = md5.new()
	m:update(json.encode(pokemon))
	return md5.tohex(m:finish())
end

local function getKeysSortedByValue(tbl, sortFunction)
	local keys = {}
	for key in pairs(tbl) do
		table.insert(keys, key)
	end

	table.sort(keys, function(a, b)
		return sortFunction(tbl[a], tbl[b])
	end)

	return keys
end

function M.is_party_full()
	local counter = 0
	for _, _ in pairs(active) do
		counter = counter + 1
	end
	return counter >= 6
end

local function sort_on_index(a, b)
	return function(a, b) 
		local c = pokedex.get_index_number(a.species.current)
		local d = pokedex.get_index_number(b.species.current)
		return c < d  
	end
end

local function sort_on_caught(a, b)
	return function(a, b) 
		return a.number < b.number  
	end
end

local function sort_on_level(a, b)
	return function(a, b) return a.level.current > b.level.current end
end

local function sort_alphabetical(a, b)
	return function(a, b) return a.species.current < b.species.current end
end

function M.list_of_ids_in_storage()
	local f = M.get_sorting_method()
	return getKeysSortedByValue(storage, f(a, b))
end

local function sort_on_slot(a, b)
	return function(a, b) return (a.slot or 7) < (b.slot or 7) end
end

function M.list_of_ids_in_inventory()
	return getKeysSortedByValue(active, sort_on_slot(a, b))
end

function M.is_inventory_pokemon(id)
	for x, _ in pairs(active) do
		if x == id then
			return true
		end
	end
	return false
end

function M.get_copy(id)
	local pokemon = utils.deep_copy(storage[id] and storage[id] or active[id])
	return pokemon
end

local function get(id)
	return storage[id] and storage[id] or active[id]
end

local function get_party()
	local p = {}
	for _, pokemon in pairs(active) do
		table.insert(p, pokemon.species.current)
	end
	return p
end

function M.set_nickname(id, nickname)
	local p = get(id)
	if not nickname == p.species.current then
		p.nickname = nickname
	end
end

function M.get_nickname(id)
	return get(id) and get(id).nickname or nil
end

function M.update_pokemon(pokemon)
	local id = pokemon.id
	if storage[id] then
		storage[id] = pokemon
	elseif active[id] then
		active[id] = pokemon
	end
	M.save()
end

function M.set_evolution_at_level(id, level)
	local p = get(id)
	if type(p.level.evolved) == "number" then
		local old = p.level.evolved
		p.level.evolved = {}
		if old ~= 0 then
			table.insert(pokemon.level.evolved, old)
		end
	end
	
	table.insert(p.level.evolved, level)
	M.save()
end

function M.get_sorting_method()
	if sorting.method == "alphabetical" then
		return sort_alphabetical
	elseif sorting.method == "level" then
		return sort_on_level
	elseif sorting.method == "index" then
		return sort_on_index
	elseif sorting.method == "caught" then
		return sort_on_caught
	else
		return sort_on_index
	end
end

function M.set_sorting_method(method)
	sorting.method = method
end

function M.set_pokemon_move_pp(id, move, pp)
	local p = get(id)
	p.moves[move].pp = pp
	M.save()
	return p.moves[move].pp
end

function M.set_pokemon_exp(id, exp)
	local p = get(id)
	p.exp = exp
	M.save()
end

function M.set_pokemon_loyalty(id, loyalty)
	local p = get(id)
	local c =  math.min(math.max(loyalty, -3), 3)
	p.loyalty = c
	M.save()
end

function M.get_pokemon_loyalty(id)
	return get(id).loyalty or 0
end

function M.get_pokemon_exp(id)
	return get(id).exp
end

function M.get_pokemon_current_hp(id)
	return get(id).hp.current
end

function M.set_pokemon_current_hp(id, hp)
	local p = get(id)
	p.hp.current = hp
	M.save()
end

function M.get_pokemon_current_level(id)
	return get(id).level.current
end

function M.set_pokemon_max_hp(id, hp)
	local p = get(id)
	p.hp.max = hp
	p.hp.edited = true
	M.save()
end

function M.release_pokemon(id)
	storage[id] = nil
	active[id] = nil
	counters.released = next(counters) ~= nil and counters.released + 1 or 1
	profiles.update(profiles.get_active_slot(), counters)
	profiles.set_party(get_party())
	M.save()
end

function M.get_total()
	return counters.caught - counters.released
end

function M.add(pokemon)
	for i=#pokemon.moves, 1, -1 do
		if pokemon.moves[i] == "" or pokemon.moves[i] == "None" then
			table.remove(pokemon.moves, i)
		end
	end
	counters.caught = next(counters) ~= nil and counters.caught + 1 or 1
	pokemon.number = counters.caught
	local id = get_id(pokemon)
	pokemon.id = id
	profiles.update(profiles.get_active_slot(), counters)
	if M.is_party_full() then
		storage[id] = pokemon
	else
		pokemon.slot = #M.list_of_ids_in_inventory() + 1
		active[id] = pokemon
	end
	dex.set(pokemon.species.current, dex.states.CAUGHT)
	profiles.set_party(get_party())
	M.save()
	profiles.save()
end

function M.save()
	if profiles.get_active_slot() then
		local profile = profiles.get_active_file_name()
		defsave.set(profile, "storage", storage)
		defsave.set(profile, "active", active)
		defsave.set(profile, "counters", counters)
		defsave.set(profile, "sorting", sorting)
		defsave.save(profile)
	end
end

function M.load(profile)
	local file_name = profile.file_name
	if not defsave.is_loaded(file_name) then
		local loaded = defsave.load(file_name)
	end
	storage = defsave.get(file_name, "storage")
	active = defsave.get(file_name, "active")
	counters = defsave.get(file_name, "counters")
	sorting = defsave.get(file_name, "sorting")
	-- Default counters
	if next(counters) == nil then
		counters = {caught=0, released=0, seen=0}
	end
end

function M.init()
	if not initialized then
		M.load(profiles.get_active())
		initialized = true
	end
end

local function assign_slot_numbers()
	log.info("Assigning slot numbers")
	local index = 1
	for id, pokemon in pairs(active) do
		pokemon.slot = index
		index = index + 1
	end
end

function M.swap(storage_id, inventory_id)
	local storage_pokemon = utils.deep_copy(storage[storage_id])
	local inventory_pokemon = utils.deep_copy(active[inventory_id])
	local slot = inventory_pokemon.slot 
	if not slot then
		assign_slot_numbers()
		inventory_pokemon = utils.deep_copy(active[inventory_id])
		slot = inventory_pokemon.slot 
	end
	storage_pokemon.slot = slot
	storage[inventory_id] = inventory_pokemon
	active[inventory_id] = nil
	
	active[storage_id] = storage_pokemon
	storage[storage_id] = nil
	profiles.set_party(get_party())
	M.save()
end

function M.move_to_storage(id)
	local pokemon = utils.deep_copy(active[id])
	if not pokemon.slot then
		assign_slot_numbers()
	end
	
	for p_id, data in pairs(active) do
		data.slot = data.slot - 1
	end
	pokemon.slot = nil
	storage[id] = pokemon
	active[id] = nil
	profiles.set_party(get_party())
	M.save()
end

function M.free_space_in_inventory()
	local index = 0
	for _, _ in pairs(active) do
		index = index + 1
	end
	return index < 6, index + 1
end

function M.move_to_inventory(id)
	local free, slot = M.free_space_in_inventory()
	if free then
		local pokemon = utils.deep_copy(storage[id])
		pokemon.slot = slot
		active[id] = pokemon
		storage[id] = nil
		profiles.set_party(get_party())
		M.save()
	else
		assert(false, "Your party is full")
	end
end

return M
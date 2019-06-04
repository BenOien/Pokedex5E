local _pokemon = require "pokedex.pokemon"
local pokedex = require "pokedex.pokedex"
local _feats = require "pokedex.feats"
local gooey = require "gooey.gooey"
local party_utils = require "screens.party.utils"

local M = {}

local active_ability_lists = {[1]={}, [2]={}}
local active_page

local m = {fully="star_full", partial="star_partial"}

local function setup_entry(nodes, name, desc, p, i, support)

	local root_node = gui.clone(nodes["pokemon/ability/root"])
	local star_node = gui.clone(nodes["pokemon/ability/support"])
	local name_node = gui.clone(nodes["pokemon/ability/name"])
	local desc_node = gui.clone(nodes["pokemon/ability/description"])
	local background_node = gui.clone(nodes["pokemon/ability/background"])
	
	gui.set_parent(background_node, root_node)
	gui.set_parent(name_node, root_node)
	gui.set_parent(desc_node, root_node)
	gui.set_parent(star_node, root_node)
	gui.set_inherit_alpha(background_node, false)
	gui.set_inherit_alpha(name_node, false)
	gui.set_inherit_alpha(desc_node, false)
	gui.set_inherit_alpha(star_node, false)
	gui.set_enabled(star_node, true)
	gui.set_enabled(root_node, true)
	print(name, m[support])
	gui.play_flipbook(star_node, m[support] or "transparent")
	gui.set_position(root_node, p)
	gui.set_text(name_node, name:upper())
	gui.set_text(desc_node, desc)
	local desc_height, name_height = gui.get_text_metrics_from_node(desc_node).height, gui.get_text_metrics_from_node(name_node).height
	local size = gui.get_size(background_node)
	size.y = desc_height + name_height
	gui.set_size(background_node, size)
	local n = gui.get_position(name_node, p)
	local d = gui.get_position(desc_node, p)
	n.y = size.y * 0.55
	d.y = n.y - name_height * 1.2
	gui.set_position(name_node, n)
	gui.set_position(desc_node, d)

	size.y = size.y + 5
	gui.set_size(root_node, size)

	p.y = p.y - desc_height - name_height
	return root_node
end

local function setup_features(nodes, pokemon)
	local function _setup(list, name, desc, index, p, support)
		local root_node = setup_entry(nodes, name, desc, p, index, support)
		local id = party_utils.set_id(root_node)
		table.insert(list.data, id)
		
	end

	local p = vmath.vector3(0, 0, 0)
	local index = 0
	local list = {}
	list.data = {}
	list.id = _pokemon.get_id(pokemon)
	list.stencil = party_utils.set_id(nodes["pokemon/tab_stencil_2"])

	local abilities = _pokemon.get_abilities(pokemon)
	local feats = _pokemon.get_feats(pokemon)
	if next(abilities) then
		for i, name in pairs(abilities) do
			index = index + 1
			local desc = pokedex.get_ability_description(name)
			local sup = pokedex.get_ability_support(name)
			_setup(list, name, desc, index, p, sup)
		end
		table.insert(active_ability_lists[active_page], list)
	end
	if next(feats) then
		for i, name in pairs(feats) do
			index = index + 1
			local desc = _feats.get_feat_description(name)
			local sup = _feats.get_feat_support(name)
			_setup(list, name, desc, index, p, sup)
		end
		table.insert(active_ability_lists[active_page], list)
	end
end

function M.clear(page)
	for a, list in pairs(active_ability_lists[page]) do
		for b, data in pairs(list.data) do
			gui.delete_node(gui.get_node(data))
		end
	end
	active_ability_lists[page] = {}
end

function M.create(nodes, pokemon, page)
	active_ability_lists[page] = {}
	active_page = page
	gui.set_enabled(nodes["pokemon/ability/root"], false)
	setup_features(nodes, pokemon)
	-- Update initial positions
	for _, list in pairs(active_ability_lists[active_page]) do
		if list ~= nil then
			gooey.static_list(list.id, list.stencil, list.data)
		end
	end
end

function M.on_input(action_id, action)
	if active_ability_lists[active_page] == nil or next(active_ability_lists[active_page]) == nil then
		return 
	end
	for _, list in pairs(active_ability_lists[active_page]) do
		if list ~= nil and next(list.data) ~= nil then
			gooey.static_list(list.id, list.stencil, list.data, action_id, action, function() end, function() end)
		end
	end
end

return M
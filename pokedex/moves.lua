local type_data = require "utils.type_data"
local file = require "utils.file"
local utils = require "utils.utils"
local log = require "utils.log"

local M = {}


local movedata = {}
local move_machines

local initialized = false

function M.get_move_data(move)
	if movedata[move] then
		return movedata[move]
	else
		local e = string.format("Can not find move data for: '%s'", tostring(move))
		gameanalytics.addErrorEvent {
			severity = "Error",
			message = e
		}
		log.error(e)
		return movedata["Error"]
	end
end

function M.get_move_pp(move)
	return M.get_move_data(move).PP
end


function M.get_move_type(move)
	return M.get_move_data(move).Type
end

local function get_type_data(move)
	if type_data[M.get_move_type(move)] then
		return type_data[M.get_move_type(move)]
	end
	log.error(string.format("Can not find type data for: '%s'", tostring(move)))
end

function M.get_move_color(move)
	return get_type_data(move).color
end

function M.get_move_icon(move)
	return get_type_data(move).icon
end

local function list()
	local l = {}
	for m, d in pairs(movedata) do
		table.insert(l, m)
	end
	table.sort(l)
	return l
end

function M.get_TM(number)
	if move_machines[number] then
		return move_machines[number]
	else
		local e = string.format("Can not find TM: '%s'", tostring(number))
		gameanalytics.addErrorEvent {
			severity = "Error",
			message = e
		}
		log.error(e)
		return move_machines[999]
	end
end

function M.init()
	if not initialized then
		movedata = file.load_json_from_resource("/assets/datafiles/moves.json")
		move_machines = file.load_json_from_resource("/assets/datafiles/move_machines.json")
		M.list = list()
		initialized = true
	end
end

return M
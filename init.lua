--[[
Autoponics-Open, the open source version of Autoponics
Copyright (C) 2015  Andida Syahendar Dwi Putra

This template should be generated by generator.go
]]--

-- set CPU Frequency to 80MHz
node.setcpufreq(node.CPU80MHZ)

-- Set wifi mode to access point only
wifi.setmode(wifi.SOFTAP)
wifi.ap.config({
	ssid = 	'{{SSID}}', -- must be randomized with signature AUTOPONICS-RANDOM6CHARSHERE
	pwd = 	'{{PASSWORD}}', -- must be more than 8 characters and randomized
	auth = 	AUTH_WPA2_PSK,
	max = 	2 -- maximum of 2 connections only
})
wifi.ap.setip({
	ip =		'192.168.1.1',
	netmask = 	'255.255.255.0',
	gateway = 	'192.168.1.1'
})

-- the global flags table
local flags = {}

-- the global querie handlers
local queryHandlers = {
	info = function(val)

	end,
	set_hour = function(val)

	end,
	set_day = function(val)

	end,
	pump_out = function(val)

	end,
	pour_in = function(val)

	end,
	cycle_water_every = function(val)

	end,
	light = function(val)

	end,
	light_on_from_to = function(val)

	end
}

-- the receiver handler
local recvHandler = function(clientConn, requestPayload)
	-- only serve GET HTTP method
	local _, _, method, path, vars = string.find(requestPayload, '([A-Z]+) (.+)?(.+) HTTP')
	if method == nil then
		_, _, method, path = string.find(requestPayload, '([A-Z]+) (.+) HTTP')
	end

	-- check method, if not GET return 405
	if method ~= 'GET' then
		local response = '{"error":true,"code":405,"errorMessage":"Invalid method"}'
		clientConn:send(response)
		clientConn:close()
		collectgarbage()
		return
	end

	-- put all the query strings into a table
	local GET = {}
	if vars ~= nil then
		for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
			GET[k] = v
		end
	end

	-- prepare the response
	-- should be in this format:
	--[[
		{
			error: boolean,
			errorMessage: string,
			code: integer
			message: Table
		}
	]]--
	local data = {
		error = 		false,
		errorMessage = 	'',
		code =			200,
		message =		{}
	}

	-- process here based on the GET table
	-- this device's cycle is 24h a day and 365 days a year regardless
	--[[
		'?info=1' = get device info, including cycles and schedules
		'?set_hour=0:24' 					= set current hour in a day
		'?set_day=1:365' 					= set current day in a year
		'?pump_out=0|1' 					= 0 turn off, 1 turn on, will automatically turn off if below threshold, will be affected by cycler
		'?pour_in=0|1' 						= 0 turn off, 1 turn on, will automatically turn off if above threshold, will be affected by cycler
		'?cycle_water_every=1:365|-1' 		= cycle the water (pump out, then pour in) every x days, if -1, turn auto cycle off, defaulted to off
		'?light=0|1' 						= 0 turn off, 1 turn on, will be affected by scheduler
		'?light_on_from_to=0:24|-1' 		= 0 is 00:00, 24 is 24:00, set the light scheduler, -1 will turn off scheduler, defaulted to off

		-- below this is not supported yet --

		'?water_plant=0|1:3600'				= start to water plant for x seconds or stop
		'?water_plant_every_day=0:365|-1' 	= set to water plant every x days, defaulted to off
		'?water_plant_every_hour=0:24|-1' 	= set to water plant in x hour of this day, defaulted to off
		'?feed_every_day=0:365|-1'
		'?feed_every_hour=0:24|-1'
		'?feed=0|1:3600'
		'?fertilize_every=1:365|-1'
		'?fertilize=0|1:3600'
	]]--
	for query, val in pairs(GET) do
		-- if the query param has a handler, process, if not error and break
		if type(queryHandlers[query]) ~= 'function' then 
			data.error = true
			data.errorMessage = 'Failed to process query ' .. query .. ': query parameter not found'
			data.code = 400
			break
		end
		local reply, ok = queryHandlers[query](val)
		if ok ~= true then
			data.error = true
			data.errorMessage = 'Failed to process query ' .. query .. ' with value ' .. val
			data.code = 500
			break
		end
		data.message = reply
	end

	-- json data
	local response = cjson.encode(data)
	clientConn:send(response)
	clientConn:close()
	collectgarbage()
end

-- the connection handler
local connHandler = function(conn)
	conn:on('receive', recvHandler)
end

-- the cycler handler
local cyclerHandler = function()

end

-- the scheduler checker, check every minutes
tmr.alarm(0, 1000 * 60, 1, cyclerHandler)

-- create the server with 30s timeout for inactive client
local srv = net.createServer(net.TCP, 30)
srv:listen(80, connHandler)
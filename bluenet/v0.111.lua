-- VARIABLES --
local computerID = os.getComputerID()
local msgReset = 300
local opened = {
}

local msgTimeout = {
}

local msgReceived = {
}
-- VARIABLES --


-- FUNCTIONS --
local function check( ... )
	local tArgs = { ... }
	local state = tArgs[ 1 ]

	for k, v in pairs( tArgs ) do
		if not state then
			break
		end

		state = state and v
	end

	return state and function() end or error
end

local function getLen( tbl )
	local len = 0

	for k, v in pairs( tbl ) do
		len = len + 1
	end

	return len
end

function open( channel )
	check( type( channel ) == "number", channel > 0, channel < 65537 )( "Invalid Channel", 2 )

	if opened[ channel ] then
		return true
	end

	for k, v in pairs( rs.getSides() ) do
		if peripheral.getType( v ) == "modem" then
			opened[ channel ] = v
			peripheral.call( v, "open", channel )
			return true
		end
	end

	error( "No wireless modem found", 2 )
end

function close( channel )
	check( type( channel ) == "number", channel > 0, channel < 65537 )( "Invalid Channel", 2 )

	if opened[ channel ] then
		peripheral.call( opened[ channel ], "close", channel )
		opened[ channel ] = nil
	end

	return true
end

function send( msg, recipient, channel, signature, replyID )
	local len = getLen( opened )
	check( len > 0 )( "No opened channels", 2 )
	check( channel and opened[ channel ] or not channel )( "Channel " .. ( channel or "" ) .. " is not opened", 2 )
	channel = opened[ channel ] and channel or next( opened )

	local toSend = {
		msg = msg;
		signature = signature;
		recipient = recipient;
		id = math.random( 1, 2147483647 ) .. "-" .. computerID;
		protocol = "bluenet";
		fromID = computerID;
		replyID = replyID;
	}

	msgReceived[ toSend.id ] = true
	msgTimeout[ os.startTimer( msgReset ) ] = toSend.id

	peripheral.call( opened[ channel ], "transmit", channel, channel, toSend )

	return toSend.id
end

function receive( timeout, replyID )
	local timer

	if timeout then
		timer = os.startTimer( timeout )
	end

	while true do
		local e = { coroutine.yield() }

		if e[1] == "bluenet_message" then
			if replyID then
				if e[6] == replyID then
					return e[3]
				end
			else
				return e[3]
			end
		elseif e[1] == "timer" and e[2] == timer then
			return
		end
	end
end

function main()
	while true do
		local e = { coroutine.yield() }

		if e[1] == "modem_message" then
			if type( e[5] ) == "table" and e[5].protocol == "bluenet" then
				if computerID == e[5].recipient then
					os.queueEvent( "bluenet_message", e[5].id, e[5].msg, e[5].fromID, e[5].signature, e[5].replyID )
				elseif not e[5].recipient and not msgReceived[ e[5].id ] then
					os.queueEvent( "bluenet_message", e[5].id, e[5].msg, e[5].fromID, e[5].signature, e[5].replyID )
					peripheral.call( opened[ e[3] ], "transmit", e[3], e[3], e[5] )
				elseif not msgReceived[ e[5].id ] then
					peripheral.call( opened[ e[3] ], "transmit", e[3], e[3], e[5] )
				end

				msgReceived[ e[5].id ] = true
				msgTimeout[ os.startTimer( msgReset ) ] = e[5].id
			end
		elseif e[1] == "timer" and msgTimeout[ e[2] ] then
			msgReceived[ msgTimeout[ e[2] ] ] = nil
			msgTimeout[ e[2] ] = nil
		end
	end
end
-- FUNCTIONS --

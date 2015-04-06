-- VARIABLES --
local coroutines = {
}
-- VARIABLES --


-- FUNCTIONS --
local function resumeCoroutines( ... )
	for k, v in pairs( coroutines ) do
		if coroutine.status( v.co ) ~= "dead" and v.running and not v.filter or ( { ... } )[1] == v.filter then
			local ok, resp = coroutine.resume( v.co, ... )

			if ok then
				v.filter = resp
			else
				error( resp )
			end
		end
	end
end

function add( func )
	local meta, object = {
		__call = function( self, ... )
			if not self.running then
				local ok, resp = coroutine.resume( self.co, ... )

				if not ok then
					error( resp, 2 )
				else
					self.filter = resp
				end
			end
		end;
	}, {}

	object = {
		co = coroutine.create( function()
			local self = object
			while true do
				local params = { coroutine.yield() }
				self.running = true
				local ok, err = pcall( function() self.func( unpack( params ) ) end )

				if not ok then
					error( err )
				end
				self.running = false
			end
		end );
		func = func;
		running = false;
	}

	setmetatable( object, meta )
	coroutine.resume( object.co )
	coroutines[ object.co ] = object

	return object
end

function remove( object )
	coroutines[ object.co ] = nil
end

function yield( ... )
	local res = { coroutine.yield( ... ) }
	resumeCoroutines( unpack( res ) )
	return unpack( res )
end
-- FUNCTIONS --

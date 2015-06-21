-- Variables --
local color = {
	-- Lookup table for colors, faster than calculating --
	[ "0" ]	=	32768;
	[ "1" ]	=	16384;
	[ "2" ] =	8192;
	[ "3" ] =	4096;
	[ "4" ] =	2048;
	[ "5" ] =	1024;
	[ "6" ] =	512;
	[ "7" ] =	256;
	[ "8" ] =	128;
	[ "9" ] =	64;
	[ "a" ] =	32;
	[ "b" ] =	16;
	[ "c" ] =	8;
	[ "d" ] =	4;
	[ "e" ] =	2;
	[ "f" ] =	1;
}

local lookup = {
	-- Lookup table for color names --
	white		=	"f";
	orange		=	"e";
	magenta		=	"d";
	lightBlue	=	"c";
	yellow		=	"b";
	lime		=	"a";
	pink		=	"9";
	gray		=	"8";
	grey		=	"8";
	lightGray	=	"7";
	lightGrey	=	"7";
	cyan		=	"6";
	purple		=	"5";
	blue		=	"4";
	brown		=	"3";
	green		=	"2";
	red			=	"1";
	black		=	"0";
}

xSize, ySize = term.getSize()
-- Variables --

-- Functions --
local function blit ( text, fg, bg )
	while #text > 0 do
		local fg_match, bg_match = fg:match( fg:sub( 1, 1 ) .. "+" ), bg:match( bg:sub( 1, 1 ) .. "+" )
		local fg_color, bg_color = fg_match and fg_match:sub( 1, 1 ), bg_match and bg_match:sub( 1, 1 )
		local len = math.min( fg_match and #fg_match or #text, bg_match and #bg_match or #text )

		if fg_color and color[ fg_color ] then
			term.setTextColor( color[ fg_color ] )
		end

		if bg_color and color[ bg_color ] then
			term.setBackgroundColor( color[ bg_color ] )
		end

		term.write( text:sub( 1, len ) )
		text, fg, bg = text:sub( len+1 ), fg:sub( len+1 ), bg:sub( len+1 )
	end
end

local function bAssert ( state, msg, errLevel )
	--[[
		Basically a better assert in that way that it faults the caller, not the called function
	]]--
	if not state then
		error( msg, 3+( type( errLevel ) == "number" and errLevel or 0 ) )
	end
end

local function getSize ( raw, x1, x2 )
	raw = type( raw ) == "string" and raw or tostring( raw )
	local pos = 0

	for k in raw:gmatch( "(-?%d+%.?%d*%%?)%s*,?" ) do
		if k:match( "-?%d+%.?%d*%%" ) then
			pos = pos + math.floor( k:match( "(-?%d+%.?%d*)%%" )/100*( x2-x1+1 )+0.5 )
		elseif k:match( "-?%d+" ) then
			pos = pos + k
		end
	end

	return pos
end

local function validColor ( sel_color, default )
	if type( sel_color ) == "number" then
		for k, v in pairs( color ) do
			if sel_color == v then
				return k
			end
		end
	elseif type( sel_color ) == "string" then
		if color[ sel_color ] then
			return sel_color
		elseif lookup[ sel_color ] then
			return lookup[ sel_color ]
		end
	end

	return lookup[ default ]
end

local function getBounds ( self, parent )
	local bounds, coords = parent and parent.getBounds() or {
		x1	=	1;
		x2	=	xSize;
		y1	=	1;
		y2	=	ySize;
	}, {}

	-- x-Size --

	coords.x1	=	self.left and bounds.x1+getSize( self.left, bounds.x1, bounds.x2 )
	coords.x2	=	self.right and bounds.x2-getSize( self.right, bounds.x1, bounds.x2 )

	if not ( coords.x1 and coords.x2 ) and self.width then
		coords.x1	=	not coords.x1 and coords.x2-( getSize( self.width, bounds.x1, bounds.x2 )-1 ) or coords.x1
		coords.x2	=	not coords.x2 and coords.x1+( getSize( self.width, bounds.x1, bounds.x2 )-1 ) or coords.x2
	end

	-- y-Size --

	coords.y1	=	self.top and bounds.y1+getSize( self.top, bounds.y1, bounds.y2 )
	coords.y2	=	self.bottom and bounds.y2-getSize( self.bottom, bounds.y1, bounds.y2 )

	if not ( coords.y1 and coords.y2 ) and self.height then
		coords.y1	=	not coords.y1 and coords.y2-( getSize( self.height, bounds.y1, bounds.y2 )-1 ) or coords.y1
		coords.y2	=	not coords.y2 and coords.y1+( getSize( self.height, bounds.y1, bounds.y2 )-1 ) or coords.y2
	end

	return coords
end

local function createEnvironment ( obj )
	local env = setmetatable( {}, { __index = _G } )

	env.self = obj
	return env
end

local function setEnvironment ( obj, env )
	for k, v in pairs( obj ) do
		if type( v ) == "function" then
			setfenv( v, env )
		end
	end
end

local function insertVariables ( text, variables )
	return text:gsub( "$$(.+);", function ( varName )
		return variables[ varName ] or "(var:" .. varName .. ")"
	end )
end

local function formatText ( text, default_fg, default_bg )
	local new_text, fg, bg = "", "", ""
	local curr_fg, curr_bg = "o", "o"

	while #text > 0 do
		local match = text:match( "^[^&$]+" )

		if match then
			new_text = new_text .. match
			fg = fg .. curr_fg:rep( #match )
			bg = bg .. curr_bg:rep( #match )
			text = text:sub( #match+1 )
		else
			local colorMatch = text:match( "^[&$][%wOo];" )

			if colorMatch then
				curr_fg = colorMatch:match( "^&([%wOo]);" ) or curr_fg
				curr_bg = colorMatch:match( "^$([%wOo]);" ) or curr_bg
				text = text:sub( #colorMatch+1 )
			else
				new_text = new_text .. text:sub( 1, 1 )
				text = text:sub( 2 )
			end
		end
	end

	return new_text, fg:gsub( "[Oo]", default_fg ), bg:gsub( "[Oo]", default_bg )
end

local function splitText ( text, fg, bg )
	
end

local function newButton ( args, parent )
	bAssert( args.left and args.right or ( args.left or args.right ) and args.width, "x-Size not defined", 1 )
	bAssert( args.top and args.bottom or ( args.top or args.bottom ) and args.height, "y-Size not defined", 1 )

	local button = {
		getBounds = function ()
			return getBounds( self, parent )
		end;

		draw = function ()
			local coords = self.getBounds()
			local height = ( coords.y2-coords.y1+1 )
							-getSize( self.margin_top or self.margin or 0, coords.y1, coords.y2 )
							-getSize( self.margin_bottom or self.margin or 0, coords.y1, coords.y2 )
			local width = ( coords.x2-coords.x1+1 )
							-getSize( self.margin_left or self.margin or 0, coords.x1, coords.x2 )
							-getSize( self.margin_right or self.margin or 0, coords.x1, coords.x2 )

			for y = coords.y1, coords.y2 do
				term.setCursorPos( coords.x1, y )
				term.blit( ( " " ):rep( coords.x2-coords.x1+1 ), "", ( self.bg_color ):rep( coords.x2-coords.x1+1 ) )
			end

			for i = 1, math.min( height, #self.text ) do
				local text, fg, bg = formatText( insertVariables( self.text[ i ], self.vars ), self.fg_color, self.bg_color )
				text, fg, bg = text:sub( 1, width ), fg:sub( 1, width ), bg:sub( 1, width )

				term.setCursorPos( coords.x1+getSize( self.margin_left or self.margin or 0, coords.x1, coords.x2 ), coords.y1+getSize( self.margin_top or self.margin or 0, coords.y1, coords.y2 )+i-1 )
				term.blit( text, fg, bg )
			end
		end;

		left			=	args.left;
		right			=	args.right;
		top				=	args.top;
		bottom			=	args.bottom;
		width			=	args.width;
		height			=	args.height;
		bg_color		=	validColor( args.bg_color, "lightGray" );
		fg_color		=	validColor( args.fg_color, "white" );
		margin			=	args.margin or 0;
		margin_left		=	args.margin or args.margin_left or 0;
		margin_right	=	args.margin or args.margin_right or 0;
		margin_top		=	args.margin or args.margin_top or 0;
		margin_bottom	=	args.margin or args.margin_bottom or 0;
		text			=	args.text or {};
		vars			=	args.vars or {};
		childs			=	{};
	}

	local env = createEnvironment( button )
	env.parent = parent
	setEnvironment( button, env )

	return button
end

local function newTextArea ( args, parent )
end

function createCanvas ( args )
	bAssert( args.left and args.right or ( args.left or args.right ) and args.width, "x-Size not defined" )
	bAssert( args.top and args.bottom or ( args.top or args.bottom ) and args.height, "y-Size not defined" )

	local canvas = {
		getBounds = function ()
			return getBounds( self )
		end;

		drawAll = function()
			local coords = self.getBounds()

			for y = coords.y1, coords.y2 do
				term.setCursorPos( coords.x1, y )
				term.blit( ( " " ):rep( coords.x2-coords.x1+1 ), "", ( self.bg_color ):rep( coords.x2-coords.x1+1 ) )
			end

			for k, v in pairs( self.childs ) do
				v.draw()
			end
		end;

		draw = function( name )
			bAssert( self.childs[ name ], "No such child '" .. name .. "'" )

			self.childs[ name ].draw()
		end;

		add = function( args )
			local available = {
				button = newButton;
			}
			bAssert( type( args ) == "table", "Arguments must be given in a table" )
			bAssert( type( args.name ) == "string" and not self.childs[ args.name ], "Name invalid or already taken" )
			bAssert( available[ args.type ], "Type " .. tostring( args.type ) .. " is not defined" )

			self.childs[ args.name ] = available[ args.type ]( args, self )
		end;

		left		=	args.left;
		right		=	args.right;
		top			=	args.top;
		bottom		=	args.bottom;
		width		=	args.width;
		height		=	args.height;
		bg_color	=	validColor( args.bg_color, "7" );
		childs		=	{};
	}

	local env = createEnvironment( canvas )
	setEnvironment( canvas, env )

	return canvas
end
-- Functions --

-- Later Implementations --
if not term.blit then
	term.blit = blit
end
-- Later Implementations --

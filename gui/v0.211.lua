local function validColor( clr, default )
    clr = tonumber( clr )
    return clr and clr > 0 and clr < 32769 and clr or default
end

function setLen( str, len )
    if #str:gsub( "[&$][%xrlmo];", "" ) <= len then
        return str
    elseif len <= 1 then
        return "."
    else
        local pos = 1
        local sub = 1

        while pos < #str do
            if sub == len-1 then
                return str:sub( 1, pos ) .. "."
            end

            local match = str:sub( pos ):match( "^[&$][%xrlmo];")

            if not match then
                pos = pos + 1
                sub = sub + 1
            end

            match = str:sub( pos ):match( "^[&$][%xrlmo];")

            if match then
                pos = pos + #match
            end
        end

        return str
    end
end

function setVars( text, vars )
    text = text:gsub( "$$([%w_]+);", function( match )
        return vars[ match ] or "(var:" .. match .. ")"
    end)

    return text
end

local function tryWrite( text, pattern, obj, default )
    local match = text:match( pattern )

    if match then
        if match:match( "[&$]%x;" ) then
            obj[ match:sub( 1, 1 ) == "&" and "setTextColor" or "setBackgroundColor" ]( math.pow( 2, 15-tonumber( match:sub( 2, 2 ), 16 ) ) )
        elseif match:match( "[&$][Oo];" ) then
            local isFg = match:sub( 1, 1 ) == "&"

            if default and default[ isFg and "fg" or "bg" ] then
                obj[ isFg and "setTextColor" or "setBackgroundColor" ]( default[ isFg and "fg" or "bg" ] )
            end
        else
            obj.write( match )
        end

        return text:sub( #match+1 )
    end
end

function advPrint( text, y1, x1, x2, obj, default )
    obj = obj or term
    y1 = y1 or 1
    x1 = x1 or 1
    x2 = x2 or obj.getSize()
    local x3 = x1

    local ort = text:match( "^[&$]([rlm]);" )

    if ort then
        if ort == "m" then
            x3 = math.floor( ( ( x2-x1+1 )-#text:gsub( "[&$][%xrlmo];", "" )+1 )/2+0.5 )+x1-1
        elseif ort == "l" then
            x3 = x1
        elseif ort == "r" then
            x3 = x2-#text:gsub( "[&$][%xrlmo];", "" )+1
        end

        text = text:sub( 4 )
    end

    obj.setCursorPos( x3, y1 )

    while #text > 0 do
        text = tryWrite( text, "^[&$][%xrlmOo];", obj, default ) or
            tryWrite( text, "^%w+", obj, default ) or
            tryWrite( text, "^.", obj, default )
    end
end

local function format( text, xSize )
    local xPos, formatted = 1, { "" }

    for k in text:gmatch( "%s*%S+" ) do
        if #k:gsub( "[$&][%xrlm];", "" ) > xSize-xPos then
            local _, matches = k:gsub( "[$&][%xrlm];", "" )
            if #k-matches*2 > xSize then
                local rest = xSize-#formatted[ #formatted ]:gsub( "[$&][%xrlm];", "" )
                local currPos, actPos = 1, 1

                while currPos < #k do
                    if not k:sub( currPos ):match( "^[$&][%xrlm];" ) then
                        if actPos == rest-1 then
                            break
                        end
                        currPos = currPos + 1
                        actPos = actPos + 1
                    else
                        currPos = currPos + 3
                    end
                end

                formatted[ #formatted ] = formatted[ #formatted ] .. k:sub( 1, currPos ) .. "-"
                formatted[ #formatted+1 ] = k:sub( currPos+1 )
                xPos = #k:sub( currPos+1 )
            else
                k = k:match( "%S+" )
                formatted[ #formatted+1 ] = k
                xPos = #k
            end
        else
            formatted[ #formatted ] = formatted[ #formatted ] .. k
            xPos = xPos + #k:gsub( "[$&][%xrlm];", "" )
        end
    end

    return formatted
end

function textArea( arg )
    assert( arg.x1 and arg.x2 and arg.y1 and arg.y2, "Missing boundaries" )
    assert( arg.txt, "No text given" )

    arg.margin = tonumber( arg.margin ) or 1
    local new = {
        formatText = function( self )
            local txt = {}
            for k, v in pairs( self.txt.txt ) do
                local res = format( self.setVars( v, self.txt.vars or {} ), self.x2-self.x1-self.margin*2+1 )

                for k1, v1 in pairs( res ) do
                    txt[ #txt+1 ] = v1
                end
            end

            return txt
        end;

        draw = function( self )
            local txt = self:formatText()
            self.obj.setBackgroundColor( self.bg )

            for y = self.y1, self.y2 do
                self.obj.setCursorPos( self.x1, y )
                self.obj.write( ( " " ):rep( self.x2-self.x1+1 ) )

                if txt[ y-self.y1+1-self.margin ] then
                    self.advPrint( txt[ y-self.y1+1-self.margin ], y, self.x1+self.margin, self.x2-self.margin, self.obj, { fg=self.fg; bg=self.bg } )
                end
            end
        end;

        setText = function( self, txt )
            local new = {}
            if type( txt ) == "table" then
                for k, v in pairs( txt ) do
                    local res = format( v, self.x2-self.x1-arg.margin*2+1 )

                    for k1, v1 in pairs( res ) do
                        new[ #new+1 ] = v1
                    end
                end
            else
                txt = tostring( txt )
                local res = format( txt, self.x2-self.x1-arg.margin*2+1 )

                for k, v in pairs( res ) do
                    new[ #new+1 ] = v
                end
            end

            self.txt = new
            self:draw()
        end;

        x1 = math.min( arg.x1, arg.x2 );
        x2 = math.max( arg.x1, arg.x2 );
        y1 = math.min( arg.y1, arg.y2 );
        y2 = math.max( arg.y1, arg.y2 );

        txt = arg.txt;
        advPrint = advPrint;
        setVars = setVars;
        format = format;
        obj = arg.wrap or term;
        bg = validColor( arg.bg, 256 );
        fg = validColor( arg.fg, 32768 );
        margin = arg.margin;
    }

    return new
end

function area( arg )
    assert( arg.x1 and arg.x2 and arg.y1 and arg.y2, "Missing boundaries" )

    local new = {
        draw = function( self )
            self.obj.setBackgroundColor( self.bg )
            for i = self.y1, self.y2 do
                self.obj.setCursorPos( self.x1, i )
                self.obj.write( ( self.char ):rep( self.x2-self.x1+1 ) )
            end
        end;

        evHandle = function()
        end;

        bg = validColor( arg.bg, 256 );
        char = arg.char and #arg.char == 1 and arg.char or " ";
        obj = arg.obj or term;

        x1 = math.min( arg.x1, arg.x2 );
        x2 = math.max( arg.x1, arg.x2 );
        y1 = math.min( arg.y1, arg.y2 );
        y2 = math.max( arg.y1, arg.y2 );
    }

    return new
end

function read( arg )

    assert( arg.x1 and arg.x2 and arg.y1, "Missing boundaries" )

    local new = {
        draw = function( self )
            local txt = self.txt:sub( self.xScroll+1, self.xScroll+self.x2-self.x1+1 )
            self.obj.setCursorPos( self.x1, self.y1 )
            self.obj.setBackgroundColor( self.bg )
            self.obj.setTextColor( self.fg )

            self.obj.write( txt )
            self.obj.write( ( " " ):rep( self.x2-self.x1-#txt+1 ) )
            self.obj.setCursorPos( self.x1+self.xPos-1, self.y1 )
        end;

        setCursor = function( self, x1, forceUpdate )
            if x1 ~= self.xScroll+self.xPos then
                local update = false
                if x1 < self.xScroll+1 then
                    self.xPos = 1
                    self.xScroll = math.max( 0, x1-1 )
                    update = true
                elseif x1 > self.xScroll+self.x2-self.x1+1 then
                    self.xPos = self.x2-self.x1+1
                    self.xScroll = math.min( #self.txt+1, x1 ) - self.xPos
                    update = true
                else
                    self.xPos = math.min( #self.txt+1, x1-self.xScroll )
                end

                if update or forceUpdate then
                    self:draw()
                else
                    self.obj.setCursorPos( self.x1+self.xPos-1, self.y1 )
                end
            end
        end;

        insert = function( self, txt )
            self.txt = self.txt:sub( 1, self.xScroll+self.xPos-1 ) .. txt .. self.txt:sub( self.xScroll+self.xPos )
        end;

        evHandle = function( self, ... )
            local e = { ... }

            if e[1] == "char" or e[1] == "paste" then
                if self.filter then
                    e[2] = self.filter( e[2] )
                end

                self:insert( e[2] or "" )
                self:setCursor( self.xScroll+self.xPos+#( e[2] or "" ), true )
            elseif e[1] == "key" then
                if e[2] == 14 then
                    self.txt = self.txt:sub( 1, self.xScroll+self.xPos-2 ) .. self.txt:sub( self.xScroll+self.xPos )
                    self:setCursor( self.xScroll+self.xPos-1, true )
                elseif e[2] == 28 or e[2] == 15 then
                    os.queueEvent( "advread_complete", self.txt )
                elseif e[2] == 199 then
                    self:setCursor( 1 )
                elseif e[2] == 203 then
                    self:setCursor( self.xPos+self.xScroll-1 )
                elseif e[2] == 205 then
                    self:setCursor( self.xPos+self.xScroll+1 )
                elseif e[2] == 207 then
                    self:setCursor( #self.txt+1 )
                elseif e[2] == 211 then
                    self.txt = self.txt:sub( self.xScroll+self.xPos ) .. self.txt:sub( self.xScroll+self.xPos+2 )
                    self:draw()
                end
            elseif e[1] == "mouse_click" or self.obj.setTextScale and e[1] == "monitor_touch" then
                self.lastX = nil
                if e[1] == "monitor_touch" then
                    e[2] = 1
                end

                if e[3] >= self.x1 and e[3] <= self.x2 and e[4] == self.y1 then
                    self.lastX = e[3]
                    self:setCursor( self.xScroll+e[3]-self.x1+1 )
                end
            elseif e[1] == "mouse_drag" then
                if self.lastX then
                    local dir = self.lastX - e[3]
                    self.lastX = e[3]
                    if self.xScroll+dir > -1 and self.xScroll+self.x2-self.x1+dir < #self.txt+1 then
                        self.xScroll = self.xScroll + dir
                        self:draw()
                    end
                end
            end
        end;

        focus = function( self, cursorBlink )
            self.obj.setCursorPos( self.x1+self.xPos-1, self.y1 )

            if cursorBlink == true and self.obj.setCursorBlink then
                self.obj.setCursorBlink( true )
            end
        end;

        x1 = arg.x1;
        x2 = arg.x2;
        y1 = arg.y1;
        obj = arg.wrap or term;
        filter = type( arg.filter ) == "function" and arg.filter;
        txt = arg.txt or "";
        xScroll = arg.txt and math.max( 0, #arg.txt-arg.x2+arg.x1-1 ) or 0;
        xPos = arg.txt and math.min( arg.x2-arg.x1+1, #arg.txt+1 ) or 1;
        bg = validColor( arg.bg, 256 );
        fg = validColor( arg.fg, 32768 );

        isElement = true;
    }

    return new
end

function list( arg )
    assert( arg.x1 and arg.x2 and arg.y1 and arg.y2, "Missing boundaries" )

    for k, v in pairs( arg.txt ) do
        if type( v ) == "string" then
            arg.txt[ k ] = {
                txt = v;
                fg = validColor( arg.unselfg, 32768 );
                bg = validColor( arg.unselbg, 256 );
                selfg = validColor( arg.selfg, 32768 );
                selbg = validColor( arg.selbg, 8 );
            }
        elseif type( v ) == "table" then
            arg.txt[ k ] = {
                txt = v.txt or "";
                fg = validColor( v.fg, 32768 );
                bg = validColor( v.bg, 256 );
                selfg = validColor( v.selfg, 32768 );
                selbg = validColor( v.selbg, 8 );
            }

            for k1, v1 in pairs( v ) do
                if not arg.txt[ k ][ k1 ] then
                    arg.txt[ k ][ k1 ] = v1
                end
            end
        end
    end

    local new = {
        drawBar = function( self )
            if not self.barType then
                local maxlen, overhang, pos, len = self.y2-self.y1-self.margin*2+1, #self.txt-self.y2+self.y1+self.margin*2

                if #self.txt < maxlen then
                    len = maxlen
                else
                    len = math.ceil( maxlen/overhang )
                end

                if self.spos == overhang then
                    pos = maxlen-len+1
                elseif self.spos == 1 then
                    pos = 1
                elseif #self.txt > maxlen and self.spos > 1 then
                    pos = math.ceil( ( self.spos-1 )*( 1/( overhang-1 ) )*( self.y2-self.y1-self.margin*2-len ) )+1
                end

                for i = 1, maxlen do
                    self.obj.setCursorPos( self.x2-self.margin, self.y1+self.margin+i-1 )

                    if i >= pos and i < pos+len then
                        self.obj.setBackgroundColor( self.scrollfg )
                    else
                        self.obj.setBackgroundColor( self.scrollbg )
                    end

                    self.obj.write( " " )
                end
            else
                self.obj.setCursorPos( self.x2-self.margin, self.y1+self.margin )
                self.obj.setTextColor( self.spos > 1 and self.scrollfg or self.scrollbg )
                self.obj.setBackgroundColor( self.bg )
                self.obj.write( "^" )
                self.obj.setCursorPos( self.x2-self.margin, self.y2-self.margin )
                self.obj.setTextColor( self.spos < #self.txt-self.y2+self.y1+self.margin*2 and self.scrollfg or self.scrollbg )
                self.obj.write( "v" )
            end
        end;

        drawOptions = function( self )
            for i = 1, math.min( self.y2-self.y1-self.margin*2+1, #self.txt ) do
                self.obj.setCursorPos( self.x1+self.margin, self.y1+self.margin+i-1 )
                self.obj.setBackgroundColor( self.sel == i+self.spos-1 and self.txt[ i+self.spos-1 ].selbg or self.txt[ i+self.spos-1 ].bg )
                self.obj.setTextColor( self.sel == i+self.spos-1 and self.txt[ i+self.spos-1 ].selfg or self.txt[ i+self.spos-1 ].fg )
                self.obj.setCursorPos( self.x1+self.margin, self.y1+self.margin+i-1 )

                self.obj.write( ( " " ):rep( self.x2-self.x1-self.margin*2-1 ) )

                local txt = self.setLen( self.txt[ i+self.spos-1 ].txt, self.x2-self.x1-self.margin*2-1 )

                self.advPrint( txt, self.y1+self.margin+i-1, self.x1+self.margin, self.x2-self.margin, self.obj )
            end
        end;

        draw = function( self )
            self.obj.setBackgroundColor( self.bg )

            for i = self.y1, self.y2 do
                self.obj.setCursorPos( self.x1, i )
                self.obj.write( ( " " ):rep( self.x2-self.x1+1 ) )
            end

            self:drawBar()
            self:drawOptions()
        end;

        evHandle = function( self, ... )
            local e = { ... }

            if e[1] == "mouse_click" or self.obj.setTextScale and e[1] == "monitor_touch" then
                self.lastY = nil

                if e[1] == "monitor_touch" then
                    e[2] = 1
                end

                if e[3] >= self.x1+self.margin and e[3] < self.x2-self.margin+1 and e[4] >= self.y1+self.margin and e[4] <= self.y2-self.margin then
                    local yPos, xPos = e[4]+self.spos-self.y1-self.margin, e[3]-self.x1-self.margin+1
                    self.lastY = e[4]

                    if e[2] == 1 then
                        if xPos < self.x2-self.x1-self.margin and self.txt[ yPos ] then
                            self.sel = yPos
                            self:drawOptions()
                        elseif self.barType and xPos == self.x2-self.x1-self.margin+1 then
                            local dir = e[4] == self.x1+self.margin and -1 or yPos == self.y2-self.y1-self.margin+1 and 1 or 0

                            if self.spos+dir > 0 and self.spos+dir < #self.txt-self.y2+self.y1+self.margin*2+1 then
                                self.spos = self.spos + dir
                                self:drawBar()
                                self:drawOptions()
                            end
                        end
                    end
                end
            elseif e[1] == "mouse_scroll" then
                if e[3] >= self.x1 and e[3] <= self.x2 and e[4] >= self.y1 and e[4] <= self.y2 then
                    if self.spos+e[2] > 0 and self.spos+e[2] < #self.txt-self.y2+self.y1+self.margin*2+1 then
                        self.spos = self.spos + e[2]
                        self:drawOptions()
                        self:drawBar()
                    end
                end
            elseif e[1] == "mouse_drag" then
                if self.lastY then
                    local diff = self.lastY-e[4]
                    self.lastY = e[4]

                    if self.spos+diff > 0 and self.spos+diff < #self.txt-self.y2+self.y1+self.margin*2+1 then
                        self.spos = self.spos + diff
                        self:drawOptions()
                        self:drawBar()
                    end
                end
            elseif e[1] == "key" then
                if e[2] == 200 then
                    if self.sel+self.spos > 2 then
                        self.spos = self.spos - ( self.sel-self.spos == 0 and 1 or 0 )
                        self.sel = self.sel - 1
                        self:drawBar()
                        self:drawOptions()
                    end
                elseif e[2] == 208 then
                    if self.sel < #self.txt then
                        self.spos = self.spos + ( self.sel-self.spos == self.y2-self.y1-self.margin*2 and 1 or 0 )
                        self.sel = self.sel + 1
                        self:drawBar()
                        self:drawOptions()
                    end
                end
            end
        end;

        getAttr = function( self, attr )
            if self.sel then
                return self.txt[ self.sel ][ attr ]
            end
        end;

        updateTxt = function( self, arg )
            for k, v in pairs( arg ) do
                if type( v ) == "string" then
                    arg[ k ] = {
                        txt = v;
                        fg = validColor( arg.unselfg, 32768 );
                        bg = validColor( arg.unselbg, 256 );
                        selfg = validColor( arg.selfg, 32768 );
                        selbg = validColor( arg.selbg, 8 );
                    }
                elseif type( v ) == "table" then
                    arg[ k ] = {
                        txt = v.txt or "";
                        fg = validColor( v.fg, 32768 );
                        bg = validColor( v.bg, 256 );
                        selfg = validColor( v.selfg, 32768 );
                        selbg = validColor( v.selbg, 8 );
                    }

                    for k1, v1 in pairs( v ) do
                        if not arg[ k ][ k1 ] then
                            arg[ k ][ k1 ] = v1
                        end
                    end
                end
            end

            self.txt = arg;
            self:draw()
        end;

        advPrint = advPrint;
        setLen = setLen;
        obj = arg.wrap or term;
        scrollbg = validColor( arg.scrollbg, 128 );
        scrollfg = validColor( arg.scrollfg, 8 );
        bg = validColor( arg.bg, 256 );
        margin = tonumber( arg.margin ) and tonumber( arg.margin ) or 1;
        spos = 1;
        sel = 0;
        txt = arg.txt;
        barType = arg.altBar;

        x1 = math.min( arg.x1, arg.x2 );
        x2 = math.max( arg.x1, arg.x2 );
        y1 = math.min( arg.y1, arg.y2 );
        y2 = math.max( arg.y1, arg.y2 );

        isElement = true;
    }

    return new
end

function button( arg )
    assert( arg.x1 and arg.x2 and arg.y1 and arg.y2, "Missing boundaries" )

    for k, v in pairs( arg.txt ) do
        if type( v ) == "string" then
            arg.txt[ k ] = {
                txt = v;
            }
        elseif type( v ) == "table" then
            arg.txt[ k ] = {
                txt = v.txt or "";
            }

            for k1, v1 in pairs( v ) do
                if not arg.txt[ k ][ k1 ] then
                    arg.txt[ k ][ k1 ] = v1
                end
            end
        end
    end

    local new = {
        draw = function( self )
            self.obj.setBackgroundColor( self.bg )

            for i = self.y1, self.y2 do
                self.obj.setCursorPos( self.x1, i )
                self.obj.write( ( " " ):rep( self.x2-self.x1+1 ) )
            end

            local pos = math.floor( ( ( self.y2-self.y1+1 )-#self.txt )/2+0.5 ) + self.y1

            for i = 1, #self.txt do
                self.advPrint( setLen( self.txt[i].txt, self.x2-self.x1+1 ), pos+i-1, self.x1, self.x2, self.obj, { fg=self.fg, bg=self.bg } )
            end
        end;

        evHandle = function( self, ... )
            local e = { ... }

            if e[1] == "mouse_click" or self.obj.setTextScale and e[1] == "monitor_touch" then
                if e[1] == "monitor_touch" then
                    e[2] = 1
                end

            	if e[3] >= self.x1 and e[3] <= self.x2 and e[4] >= self.y1 and e[4] <= self.y2 then
                    return true
                end
            end
        end;

        advPrint = advPrint;
        setLen = setLen;
        obj = arg.wrap or term;
        bg = validColor( arg.bg, 256 );
        fg = validColor( arg.fg, 32768 );
        x1 = math.min( arg.x1, arg.x2 );
        x2 = math.max( arg.x1, arg.x2 );
        y1 = math.min( arg.y1, arg.y2 );
        y2 = math.max( arg.y1, arg.y2 );
        txt = arg.txt;

        isElement = true;
    }

    return new
end

function statusBar( arg )
	assert( arg.x1 and arg.x2 and arg.y1 and arg.y2, "Missing boundaries" )
	arg.ort = arg.ort == "horizontal" and arg.ort or "vertical"

	local new = {
		draw = function( self )
			self.obj.setBackgroundColor( self.bg )

			for y = self.y1+self.margin, self.y2-self.margin do
				self.obj.setCursorPos( self.x1+self.margin, y )
				self.obj.write( ( " " ):rep( self.x2-self.x1-self.margin*2+1 ) )
			end

			for y = self.y1+self.margin+self.padding, self.y2-self.margin-self.padding do
				self.obj.setCursorPos( self.x1+self.margin+self.padding, y )
				if self.ort == "horizontal" then
                    local len = math.floor( ( self.x2-self.x1-self.margin*2-self.padding*2+1 )*( self.percentage/100 )+0.5 )
                    self.obj.setBackgroundColor( self.fg )
					self.obj.write( ( " " ):rep( len ) )
                    term.setBackgroundColor( self.barBg )
                    self.obj.write( ( " " ):rep( self.x2-self.x1-self.padding*2-self.margin*2-len+1 ) )
				else
					if y >= self.y1+self.margin+self.padding+math.floor( ( 1-self.percentage/100 )*( self.y2-self.y1-self.margin*2-self.padding*2+1 ) ) then
						self.obj.setBackgroundColor( self.fg )
                    else
                        self.obj.setBackgroundColor( self.barBg )
                    end
					self.obj.write( ( " " ):rep( self.x2-self.x1-self.margin*2-self.padding*2+1 ) )
				end
			end
		end;

		margin = tonumber( arg.margin ) and arg.margin or 0;
		padding = tonumber( arg.padding ) and arg.padding or 0;
		ort = arg.ort;
		bg = validColor( arg.bg, 256 );
        barBg = validColor( arg.barBg, 256 );
		fg = validColor( arg.fg, 32 );
		y1 = math.min( arg.y1, arg.y2 );
		y2 = math.max( arg.y1, arg.y2 );
		x1 = math.min( arg.x1, arg.x2 );
		x2 = math.max( arg.x1, arg.x2 );
		percentage = tonumber( arg.percentage ) and arg.percentage or 100;
		isElement = true;
		obj = arg.wrap or term;
	}

	return new
end

function checkHitmap( arg )
    assert( type( arg ) == "table" and arg.x1 and arg.y1 and type( arg.hitmap ) == "table", "Too few or invalid arguments" )

    arg.hits = arg.hits or {}

    for k, v in pairs( arg.hitmap ) do
        if type ( v ) == "table" and not v.isElement then
            arg.hits[k] = checkHitmap( { x1 = arg.x1; y1 = arg.y1; hitmap = v } )
        elseif type( v ) == "table" and arg.x1 >= v.x1 and arg.x1 <= v.x2 and arg.y1 >= v.y1 and arg.y1 <= v.y2 then
            arg.hits[k] = v
        end
    end

    return arg.hits
end

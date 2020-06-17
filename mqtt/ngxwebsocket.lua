-- module table
local ngxwebsocket = {}

-- load required stuff
local string_sub = string.sub
local client = require("resty.websocket.client")
local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end
-- Open network connection to .host and .port in conn table
-- Store opened websocket to conn table
-- Returns true on success, or false and error text on failure
function ngxwebsocket.connect(conn)
	local wb, err = client:new()
	local ok, err = wb:connect(conn.uri)--wb:connect('ws://'..conn.host..':'..conn.port..'/mqtt')
	if not ok then
		return false, "socket:connect failed: "..err
	end
	wb:set_timeout(0x7FFFFFFF)
	--[[if conn.secure then
		socket:sslhandshake()
	end]]
	conn.sock = wb
	conn.binary_frame = nil
	conn.frame_offset = 1
	return true
end

-- Shutdown network connection
function ngxwebsocket.shutdown(conn)
	conn.sock:close()
end

-- Send data to network connection
function ngxwebsocket.send(conn, data, i, j)
	if i then
		return conn.sock:send_binary(string_sub(data, i, j))
	else
		return conn.sock:send_binary(data)
	end
end
local function _dump(data)
    local len = #data
    local bytes = new_tab(len, 0)
    for i = 1, len do
        bytes[i] = string.format("%02X", string.byte(data, i))
    end
    return table.concat(bytes, " ")
end
-- Receive given amount of data from network connection
function ngxwebsocket.receive(conn, size)
	if conn.binary_frame == nil then
		repeat	
			local data, typ, err = conn.sock:recv_frame()
			if typ == 'binary' then
				conn.binary_frame = data
				conn.frame_offset = 1
				trace(_dump(data), typ)
				break
			elseif typ == 'ping' then
				conn.sock:send_pong()
			elseif typ == 'close' then
				return nil, 'close'
			end
		until typ ~= 'binary'
	end
	if conn.binary_frame ~= nil then
		local frag = string_sub(conn.binary_frame,conn.frame_offset,conn.frame_offset+size-1)
		trace(_dump(frag), conn.frame_offset, size)
		conn.frame_offset = conn.frame_offset + size
		if conn.frame_offset >= conn.binary_frame:len() then
			conn.binary_frame = nil
			conn.frame_offset = 1
		end
		return frag, nil
	end
	return nil, 'no data'
end

-- Set connection's socket to non-blocking mode and set a timeout for it
function ngxwebsocket.settimeout(conn, timeout)
	if not timeout then
		conn.sock:set_timeout(0x7FFFFFFF)
	else
		conn.sock:set_timeout(timeout * 1000)
	end
end

-- export module table
return ngxwebsocket

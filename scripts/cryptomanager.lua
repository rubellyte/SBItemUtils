require "/scripts/norx.lua"
require "/scripts/JSON.lua"

crypto = {}

function crypto.encrypt(plaintext, key)
  -- expects "plaintext" to be a JSON value
  if key:len() < 32 then
    -- pad key with spaces
    key = key..string.rep(" ", 32-key:len())
  elseif key:len() > 32 then
    -- throw away extra if key is too long
    -- interface should prevent this
    key = key:sub(1, 32)
    sb.logWarn("ItemUtils: Throwing away part of key!")
  end
  local to_enc = JSON:encode(plaintext)
  local raw = norx.aead_encrypt(key, key, to_enc)
  return crypto.hexlify(raw)
end

function crypto.decrypt(encrypted, key)
  -- expects "encrypted" to be a serialized JSON value
  if key:len() < 32 then
    -- pad key with spaces
    key = key..string.rep(" ", 32-key:len())
  elseif key:len() > 32 then
    -- throw away extra if key is too long
    -- interface should prevent this
    key = key:sub(1, 32)
    sb.logWarn("ItemUtils: Throwing away part of key!")
  end
  local raw = crypto.unhexlify(encrypted, true)
  local jsonData = norx.aead_decrypt(key, key, raw)
  return JSON:decode(jsonData)
end

-- hextos and stohex from Pure Lua Crypto (https://github.com/philanc/plc)

function crypto.hexlify(s, ln, sep)
	-- stohex(s [, ln [, sep]])
	-- return the hex encoding of string s
	-- ln: (optional) a newline is inserted after 'ln' bytes 
	--	ie. after 2*ln hex digits. Defaults to no newlines.
	-- sep: (optional) separator between bytes in the encoded string
	--	defaults to nothing (if ln is nil, sep is ignored)
	-- example: 
	--	stohex('abcdef', 4, ":") => '61:62:63:64\n65:66'
	--	stohex('abcdef') => '616263646566'
	--
  local byte = string.byte
  local strf = string.format
  local concat = table.concat
	if #s == 0 then return "" end
	if not ln then -- no newline, no separator: do it the fast way!
		return (s:gsub('.', 
			function(c) return strf('%02X', byte(c)) end
			))
	end
	sep = sep or "" -- optional separator between each byte
	local t = {}
	for i = 1, #s - 1 do
		t[#t + 1] = strf("%02X%s", s:byte(i),
				(i % ln == 0) and '\n' or sep) 
	end
	-- last byte, without any sep appended
	t[#t + 1] = strf("%02X", s:byte(#s))
	return concat(t)	
end --stohex()

function crypto.unhexlify(hs, unsafe)
	-- decode an hex encoded string. return the decoded string
	-- if optional parameter unsafe is defined, assume the hex
	-- string is well formed (no checks, no whitespace removal).
	-- Default is to remove white spaces (incl newlines)
	-- and check that the hex string is well formed
	local tonumber = tonumber
  local char = string.char
	if not unsafe then
		hs = string.gsub(hs, "%s+", "") -- remove whitespaces
		if string.find(hs, '[^0-9A-Za-z]') or #hs % 2 ~= 0 then
			error("invalid hex string")
		end
	end
	return hs:gsub(	'(%X%X)', 
		function(c) return char(tonumber(c, 16)) end
		)
end -- hextos
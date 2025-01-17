local select = select
local tostring = tostring
local type = type
local unpack = unpack
local strfind, strjoin, strlen, strsub = string.find, string.join, string.len, string.sub
local twipe = table.wipe

local S_IsDevClient = S_IsDevClient
local S_IsInterfaceDevClient = S_IsInterfaceDevClient

local LOCAL_ToStringAllTemp = {}
local function tostringall(...)
	local n = select('#', ...)
	-- Simple versions for common argument counts
	if (n == 1) then
		return tostring(...)
	elseif (n == 2) then
		local a, b = ...
		return tostring(a), tostring(b)
	elseif (n == 3) then
		local a, b, c = ...
		return tostring(a), tostring(b), tostring(c)
	elseif (n == 0) then
		return
	end

	local needfix
	for i = 1, n do
		local v = select(i, ...)
		if (type(v) ~= "string") then
			needfix = i
			break
		end
	end
	if (not needfix) then return ... end

	twipe(LOCAL_ToStringAllTemp)
	for i = 1, needfix - 1 do
		LOCAL_ToStringAllTemp[i] = select(i, ...)
	end
	for i = needfix, n do
		LOCAL_ToStringAllTemp[i] = tostring(select(i, ...))
	end
	return unpack(LOCAL_ToStringAllTemp)
end

function printc(...)
	if S_Print then
		S_Print(strjoin(" ", tostringall(...)))
	end
end

function printec(...)
	if S_PrintConsole then
		S_PrintConsole(strjoin(" ", tostringall(...)))
	end
end

if IsOnGlueScreen() then
	_G.print = printc
	_G.tostringall = tostringall
else
	local UnitName = UnitName
	local SendAddonMessage = SendAddonMessage

	function SendServerMessage(prefix, ...)
		if select("#", ...) > 1 then
			SendAddonMessage(prefix, strjoin(" ", tostringall(...)), "WHISPER", UnitName("player"))
		else
			SendAddonMessage(prefix, ..., "WHISPER", UnitName("player"))
		end
	end
end

function GetTexCoordsByMask(ws, hs, x, y, w, h)
	return {x/ws, x/ws + w/ws, y/hs, y/hs + h/hs}
end

function GetSpriteFromImage(x, y, w, h, iw, ih)
	return (x*w)/iw, ((x+1)*w)/iw, (y*h)/ih, ((y+1)*h)/ih
end

function C_Split(str, delimiter)
	local ret = {}

	if delimiter == "" then
		for i = 1, strlen(str) do
			ret[i] = strsub(str, i, i)
		end
		return ret
	end

	local currentPos = 1

	for i = 1, strlen(str) do
		local startPos, endPos = strfind(str, delimiter, currentPos, true)
		if not startPos then break end
		ret[i] = strsub(str, currentPos, startPos - 1)
		if ret[i] == "" then
			ret[i] = nil
		end
		currentPos = endPos + 1
	end

	ret[#ret + 1] = strsub(str, currentPos)
	if ret[#ret] == "" then
		ret[#ret] = nil
	end

	return ret
end

function AnimationStopAndPlay(object, ...)
	local numVarArg = select("#", ...)
	if numVarArg > 0 then
		for i = 1, numVarArg do
			local obj = select(i, ...)
			if obj and obj:IsPlaying() then
				obj:Stop()
			end
		end
	end

	if object then
		if object:IsPlaying() then
			object:Stop()
		end

		object:Play()
	end
end

function isOneOf(val, ...)
	for i = 1, select("#", ...) do
		if select(i, ...) == val then
			return true
		end
	end
	return false
end

function IsDevClient(skipDevOverride)
	if not skipDevOverride then
		if IsOnGlueScreen() then
			if DEV_GLUE_DISABLE_GM then
				return false
			end
		else
			if DEV_GAME_DISABLE_GM then
				return false
			end
		end
	end
	if type(S_IsDevClient) == "function" then
		return S_IsDevClient()
	end
	return false
end

function IsInterfaceDevClient(skipDevOverride)
	if not skipDevOverride then
		if IsOnGlueScreen() then
			if DEV_GLUE_DISABLE_GM then
				return false
			end
		else
			if DEV_GAME_DISABLE_GM then
				return false
			end
		end
	end
	if type(S_IsInterfaceDevClient) == "function" then
		return S_IsInterfaceDevClient()
	end
	return false
end

function PackNumber(n1, n2)
	return bit.bor(n1, bit.lshift(n2, 16))
end

function UnpackNumber(n)
	local n1 = bit.band(n, 0xFFFF)
	local n2 = bit.band(bit.rshift(n, 16), 0xFFFF)

	return n1, n2
end
AuraUtil = {};

local function FindAuraRecurse(predicate, unit, filter, auraIndex, predicateArg1, predicateArg2, predicateArg3, ...)
	if ... == nil then
		return nil; -- Not found
	end
	if predicate(predicateArg1, predicateArg2, predicateArg3, ...) then
		return ...;
	end
	auraIndex = auraIndex + 1;
	return FindAuraRecurse(predicate, unit, filter, auraIndex, predicateArg1, predicateArg2, predicateArg3, UnitAura(unit, auraIndex, filter));
end

-- Find an aura by any predicate, you can pass in up to 3 predicate specific parameters
-- The predicate will also receive all aura params, if the aura data matches return true
function AuraUtil.FindAura(predicate, unit, filter, predicateArg1, predicateArg2, predicateArg3)
	local auraIndex = 1;
	return FindAuraRecurse(predicate, unit, filter, auraIndex, predicateArg1, predicateArg2, predicateArg3, UnitAura(unit, auraIndex, filter));
end

do
	local function NamePredicate(auraNameToFind, _, _, auraName)
		return auraNameToFind == auraName;
	end

	-- Finds the first aura that matches the name
	-- Notes:
	--		aura names are not unique!
	--		aura names are localized, what works in one locale might not work in another
	--			consider that in English two auras might have different names, but once localized they have the same name, so even using the localized aura name in a search it could result in different behavior
	--		the unit could have multiple auras with the same name, this will only find the first
	function AuraUtil.FindAuraByName(auraName, unit, filter)
		return AuraUtil.FindAura(NamePredicate, unit, filter, auraName);
	end
end

do
	local function ForEachAuraHelper(unit, filter, func, index, maxCount, ...)
		if (...) == nil then
			-- no more auras
			return nil;
		end

		if func(...) then
			-- if func returns true then no further slots are needed, so don't return continuationToken
			return nil;
		end

		return index + 1;
	end

	function AuraUtil.ForEachAura(unit, filter, maxCount, func)
		if maxCount and maxCount <= 0 then
			return;
		end
		local index = 1;
		repeat
			index = ForEachAuraHelper(unit, filter, func, index, maxCount, UnitAura(unit, index, filter));
		until index == nil;
	end
end

-- This is a new optimization to improve the performance of unit aura processing.
-- isFullUpdate, updatedAuraInfos are now provided by the UNIT_AURA event.
-- isRelevantFunc should be a callback that takes in the aura info and returns whether the aura is relevent to the system.
-- See CompactUnitFrame_UpdateAurasInternal in CompactUnitFrame.lua for example usage.
function AuraUtil.ShouldSkipAuraUpdate(isFullUpdate, updatedAuraInfos, isRelevantFunc, ...)
	if isFullUpdate == nil then
		isFullUpdate = true;
	end
	-- Early out if the update cannot affect the frame
	local skipUpdate = false;
	if not isFullUpdate and updatedAuraInfos ~= nil and isRelevantFunc ~= nil then
		skipUpdate = true;
		for _, auraInfo in ipairs(updatedAuraInfos) do
			if isRelevantFunc(auraInfo, ...) then
				skipUpdate = false;
				break;
			end
		end
	end
	return skipUpdate;
end
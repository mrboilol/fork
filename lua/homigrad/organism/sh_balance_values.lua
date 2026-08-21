hg = hg or {}
hg.organism = hg.organism or {}

function hg.organism.GetLimitingReserve(...)
	local reserve = 1
	for index = 1, select("#", ...) do
		local rawValue = select(index, ...)
		local value = tonumber(rawValue)
		if value ~= nil then
			reserve = math.min(reserve, math.Clamp(value, 0, 1))
		end
	end
	return reserve
end

function hg.organism.GetSmoothSeverity(value, startValue, fullValue, exponent)
	value = tonumber(value) or 0
	startValue = tonumber(startValue) or 0
	fullValue = math.max(tonumber(fullValue) or 1, startValue + 0.0001)
	local normalized = math.Clamp((value - startValue) / (fullValue - startValue), 0, 1)
	return normalized ^ math.max(tonumber(exponent) or 1, 0.01)
end

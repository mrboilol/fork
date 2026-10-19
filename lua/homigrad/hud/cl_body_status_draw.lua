local math_sqrt = math.sqrt
local math_sin = math.sin
local math_cos = math.cos
local math_atan2 = math.atan2

local HALF_SEGMENTS = include("homigrad/hud/cl_body_status_data.lua").HALF_SEGMENTS

local capsulePoly, halfPoly = {}, {}
for i = 1, HALF_SEGMENTS + 1 do
	halfPoly[i] = {x = 0, y = 0}
end
for i = 1, (HALF_SEGMENTS + 1) * 2 do
	capsulePoly[i] = {x = 0, y = 0}
end

local function capsuleVertices(ax, ay, bx, by, r, out)
	local angle = math_atan2(by - ay, bx - ax)
	local startB = angle - math.pi * 0.5
	local startA = angle + math.pi * 0.5
	local offset = HALF_SEGMENTS + 1
	for i = 0, HALF_SEGMENTS do
		local step = i / HALF_SEGMENTS * math.pi
		local vertexB, vertexA = out[i + 1], out[offset + i + 1]
		vertexB.x, vertexB.y = bx + math_cos(startB + step) * r, by + math_sin(startB + step) * r
		vertexA.x, vertexA.y = ax + math_cos(startA + step) * r, ay + math_sin(startA + step) * r
	end
end

local function polyCapsule(ax, ay, bx, by, r)
	capsuleVertices(ax, ay, bx, by, r, capsulePoly)
	surface.DrawPoly(capsulePoly)
end

local ringInner = {}
for i = 1, (HALF_SEGMENTS + 1) * 2 do
	ringInner[i] = {x = 0, y = 0}
end
local ringQuad = {{x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}}

local function drawLine(ax, ay, bx, by, width)
	local dx, dy = bx - ax, by - ay
	local length = math_sqrt(dx * dx + dy * dy)
	if length <= 0 then return end

	local px, py = -dy / length * width * 0.5, dx / length * width * 0.5
	ringQuad[1].x, ringQuad[1].y = ax - px, ay - py
	ringQuad[2].x, ringQuad[2].y = bx - px, by - py
	ringQuad[3].x, ringQuad[3].y = bx + px, by + py
	ringQuad[4].x, ringQuad[4].y = ax + px, ay + py
	surface.DrawPoly(ringQuad)
end

local function polyCapsuleRing(ax, ay, bx, by, outer, inner)
	capsuleVertices(ax, ay, bx, by, outer, capsulePoly)
	capsuleVertices(ax, ay, bx, by, inner, ringInner)
	local count = #capsulePoly
	for i = 1, count do
		local j = i % count + 1
		local o1, o2, i1, i2 = capsulePoly[i], capsulePoly[j], ringInner[i], ringInner[j]
		ringQuad[1].x, ringQuad[1].y = o1.x, o1.y
		ringQuad[2].x, ringQuad[2].y = o2.x, o2.y
		ringQuad[3].x, ringQuad[3].y = i2.x, i2.y
		ringQuad[4].x, ringQuad[4].y = i1.x, i1.y
		surface.DrawPoly(ringQuad)
	end
end

local function polyHalfCircle(x, y, r, startAngle)
	for i = 0, HALF_SEGMENTS do
		local angle = startAngle + i / HALF_SEGMENTS * math.pi
		local vertex = halfPoly[i + 1]
		vertex.x, vertex.y = x + math_cos(angle) * r, y + math_sin(angle) * r
	end
	surface.DrawPoly(halfPoly)
end

local function polyHalfRing(x, y, outer, inner, startAngle)
	for i = 0, HALF_SEGMENTS - 1 do
		local angleA = startAngle + i / HALF_SEGMENTS * math.pi
		local angleB = startAngle + (i + 1) / HALF_SEGMENTS * math.pi
		local ax, ay = math_cos(angleA), math_sin(angleA)
		local bx, by = math_cos(angleB), math_sin(angleB)
		ringQuad[1].x, ringQuad[1].y = x + ax * outer, y + ay * outer
		ringQuad[2].x, ringQuad[2].y = x + bx * outer, y + by * outer
		ringQuad[3].x, ringQuad[3].y = x + bx * inner, y + by * inner
		ringQuad[4].x, ringQuad[4].y = x + ax * inner, y + ay * inner
		surface.DrawPoly(ringQuad)
	end
end

return {
	Capsule = polyCapsule,
	CapsuleRing = polyCapsuleRing,
	HalfCircle = polyHalfCircle,
	HalfRing = polyHalfRing,
	Line = drawLine,
}

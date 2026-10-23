ABL.NoJIT()
ABL.BloodMap = ABL.BloodMap or {}
local B = ABL.BloodMap
local C = ABL.Config
local K = C.BloodMap
local floor, abs, min, max = math.floor, math.abs, math.min, math.max

local CELL = 16
local grid, recs = {}, {}
local head = 0
B.ver = 0

local function Key(ix, iy, iz) return ((ix + 32768) * 65536 + (iy + 32768)) * 65536 + (iz + 32768) end

local function Unlink(r)
	local list = grid[r.key]
	if not list then return end
	for i = #list, 1, -1 do
		if list[i] == r then
			list[i] = list[#list]
			list[#list] = nil
			break
		end
	end
	if #list == 0 then grid[r.key] = nil end
end

function B.Add(x, y, z, nx, ny, nz, r, m, wetT)
	if not (ABL.InWorld(x, y, z) and ABL.Finite3(nx, ny, nz) and r > 0 and r < 1e3) then return end
	head = head % K.cap + 1
	local old = recs[head]
	if old then Unlink(old) end
	local key = Key(floor(x / CELL), floor(y / CELL), floor(z / CELL))
	local rec = {
		x = x, y = y, z = z, nx = nx, ny = ny, nz = nz, r = min(r, K.maxR), m = math.Clamp(m or 1, 0, 1),
		born = CurTime(), wetT = (wetT or 0) * C.sv.drying:GetFloat(), key = key,
	}
	recs[head] = rec
	local list = grid[key]
	if not list then list = {} grid[key] = list end
	list[#list + 1] = rec
	B.ver = B.ver + 1
	rec.ver = B.ver
	return rec
end

function B.Since(ver, x, y, z, R)
	local n = B.ver - (ver or 0)
	if n <= 0 then return false end
	if n >= K.cap then return true end
	local i = head
	for _ = 1, n do
		local r = recs[i]
		if not r or r.ver <= ver then break end
		local lim = R + r.r
		local dx, dy, dz = r.x - x, r.y - y, r.z - z
		if dx * dx + dy * dy + dz * dz < lim * lim then return true end
		i = i > 1 and i - 1 or K.cap
	end
	return false
end

function B.Wet(rec, now)
	if rec.wetT <= 0 then return 0 end
	return max(0, 1 - ((now or CurTime()) - rec.born) / rec.wetT)
end

function B.Query(x, y, z, nx, ny, nz, R, out)
	local n = 0
	local reach = R + K.maxR
	local ix0, ix1 = floor((x - reach) / CELL), floor((x + reach) / CELL)
	local iy0, iy1 = floor((y - reach) / CELL), floor((y + reach) / CELL)
	local iz0, iz1 = floor((z - reach) / CELL), floor((z + reach) / CELL)
	for ix = ix0, ix1 do
		for iy = iy0, iy1 do
			for iz = iz0, iz1 do
				local list = grid[Key(ix, iy, iz)]
				if list then
					for i = 1, #list do
						local r = list[i]
						if r.nx * nx + r.ny * ny + r.nz * nz > 0.9 then
							local dx, dy, dz = r.x - x, r.y - y, r.z - z
							if abs(dx * nx + dy * ny + dz * nz) < 3 then
								local lim = R + r.r
								if dx * dx + dy * dy + dz * dz < lim * lim then
									n = n + 1
									out[n] = r
								end
							end
						end
					end
				end
			end
		end
	end
	for i = n + 1, #out do out[i] = nil end
	return n
end

local tmp = {}
function B.Coverage(x, y, z, nx, ny, nz, R, before)
	local n = B.Query(x, y, z, nx, ny, nz, R, tmp)
	if n == 0 then return 0, 0 end
	local now = CurTime()
	local cov, wet = 0, 0
	local area = 3.14159 * R * R
	for i = 1, n do
		local r = tmp[i]
		if not before or r.born < before then
			cov = cov + min(3.14159 * r.r * r.r, area) * r.m
			wet = max(wet, B.Wet(r, now) * r.m)
		end
		tmp[i] = nil
	end
	return min(1, cov / area), wet
end

function B.Clear()
	for k in pairs(grid) do grid[k] = nil end
	for i = #recs, 1, -1 do recs[i] = nil end
	head = 0
	B.ver = B.ver + 1
end

function B.Count()
	local n = 0
	for _ in pairs(grid) do n = n + 1 end
	return #recs, n
end

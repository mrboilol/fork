AddCSLuaFile()

if not CLIENT then return end
-- Please note: this effect simulates the PAL 720x576 25f-fps system. For NTSC you will need to replace the following values: 720->640; 576->480; 25->30; 288->240

-- terms used in this file:
--  INTERLACED: Display of frames, when the signal generator produces two half-frames which the TV draws through the lines, adding them on top of each other.
--   Example:
--    Progressive   Interlaced
--       1  2          1  2
--       3  4          5  6
--       5  6          3  4
--       7  8          7  8
--  OSD: ON-SCREEN-DISPLAY. Its a signal generator that creates its own signal and synchronizes it with the input signal, overlapping the input signal with its own.
--  FRAME-SYNC(VERTICAL SYNC): Frame synchronization. From this the TV starts drawing the frame. This is vertical sync.
--  HORIZONTAL SYNCHRONIZATION: This is the beginning of each line in the frame. If this synchronization is delayed, the line will be shifted.
--  CHROMA: Colour Channel
--  LUMA: Brightness Channel

-- If you dont understand something - you should contact more knowledgeable people.

local KAMIKAZE_VHS_CFG_LOADING = true -- Default value: true. When editing switch the value to 'false' if you want to change the values in this file. this also disables automatic config saving.
-- Also, please do not enable resource-intensive filters by default and
-- filters that vary greatly over time(such as wrinkle or noise overlay) or set them to the lowest settings, like a wave filter.

local cachedcurtime = CurTime()
local rt = render.GetScreenEffectTexture(0)
local blurmat = CreateMaterial("kamikazevhs/blurxmat","g_blurx",{["$basetexture"]=rt:GetName()})--,["$vertexalpha"] = "1",["$translucent"] = "1"})--Material("pp/blurx")
local morphrt = GetRenderTarget("kamikazevhs/morphrt",720,576)
local morphmat = CreateMaterial("kamikazevhs/morphmat","g_refract",{["$fbtexture"] = rt:GetName(),["$normalmap"] = morphrt:GetName(),["$refractamount"] = 1,["$bluramout"] = 0})
local morphrt2 = GetRenderTarget("kamikazevhs/morphrt2",720,576)
local morphmat2 = CreateMaterial("kamikazevhs/morphmat2","g_refract",{["$fbtexture"] = rt:GetName(),["$normalmap"] = morphrt2:GetName(),["$refractamount"] = 1,["$bluramout"] = 0})
local matred = CreateMaterial("kamikazevhs/redmat","UnLitGeneric",{
    ["$basetexture"] = rt:GetName(),
    ["$color2"] = "[1 0 0]",
    ["$ignorez"] = 1,
    ["$additive"] = 1
})
local matgreen = CreateMaterial("kamikazevhs/greenmat","UnLitGeneric",{
    ["$basetexture"] = rt:GetName(),
    ["$color2"] = "[0 1 0]",
    ["$ignorez"] = 1,
    ["$additive"] = 1
})
local matblue = CreateMaterial("kamikazevhs/bluemat","UnLitGeneric",{
    ["$basetexture"] = rt:GetName(),
    ["$color2"] = "[0 0 1]",
    ["$ignorez"] = 1,
    ["$additive"] = 1
})
local colormod = CreateMaterial("kamikazevhs/colormod","g_colourmodify",{["$fbtexture"] = rt:GetName(),["$pp_colour_addr"] = 0,["$pp_colour_addg"] = 0,["$pp_colour_addb"] = 0,["$pp_colour_brightness"] = 0.1,["$pp_colour_inv"] = 0,["$pp_colour_colour"] = 0,["$pp_colour_contrast"] = 1,["$pp_colour_mulr"] = 0,["$pp_colour_mulg"] = 0,["$pp_colour_mulb"] = 0,})
local interlacedbufferrt = GetRenderTargetEx("kamikazevhs/interlacedbufferrt",ScrW(),ScrH(),
    RT_SIZE_NO_CHANGE,
    3,
    bit.bor(2, 256),
    0,
    IMAGE_FORMAT_BGR888) -- remove alpha channel for buffer. update 09.06.2025
local interlacedbuffermat = CreateMaterial("kamikazevhs/interlacedbuffermat","UnLitGeneric",{["$basetexture"] = interlacedbufferrt:GetName(),["$ignorez"] = "1",["$translucent"] = "1",["$alpha"] = "1"})
local interlacedcopyrt = GetRenderTarget("kamikazevhs/interlacedcopyrt",ScrW(),ScrH())
local interlacedcopymat = CreateMaterial("kamikazevhs/interlacedcopymat","UnLitGeneric",{["$basetexture"] = interlacedcopyrt:GetName(),["$ignorez"] = "1",["$translucent"] = "1"})

local noisert = GetRenderTarget("kamikazevhs/noisert",720,576)
local noisemat = CreateMaterial("kamikazevhs/noisemat","UnLitGeneric",{["$basetexture"] = noisert:GetName(),["$ignorez"] = "1",["$translucent"] = "1",["$vertexalpha"] = "1"})

local noiseoverlayrt = GetRenderTargetEx("kamikazevhs/noiseoverlayrt",720,576,
    RT_SIZE_NO_CHANGE,
    3,
    bit.bor(2, 256),
    0,
    IMAGE_FORMAT_BGR888) -- remove alpha channel for buffer.
local noiseoverlaymat = CreateMaterial("kamikazevhs/noiseoverlaymat","UnLitGeneric",{["$basetexture"] = noiseoverlayrt:GetName()})

local screencopymat = CreateMaterial("kamikazevhs/screencopymat","GMODScreenspace",{["$basetexture"]=rt:GetName(),["$translucent"] = "0",["$ignorez"] = "1"})
local tubedelayrt = GetRenderTargetEx("kamikazevhs/tubedelayrt",ScrW(),ScrH(),
    RT_SIZE_NO_CHANGE,
    2,
    bit.bor(2, 256),
    0,
    IMAGE_FORMAT_BGR888) -- remove alpha channel for buffer.
local tubedelaymat = CreateMaterial("kamikazevhs/tubedelaymat","UnLitGeneric",{["$basetexture"] = tubedelayrt:GetName(),["$ignorez"] = "1",["$translucent"] = "1"})

-- i have not been able to get this system to work yet, so i will leave it here for a while
--[[
local lensdistortionrt = GetRenderTarget("kamikazevhs/lensdistortionrt",512,512)
local lensdistortionmat = CreateMaterial("kamikazevhs/lensdistortionmat","g_refract",{["$fbtexture"] = rt:GetName(),["$normalmap"] = lensdistortionrt:GetName(),["$refractamount"] = 1,["$bluramout"] = 0})
--lensdistortionmat:SetFloat("$refractamount","-0.125")
render.PushRenderTarget(lensdistortionrt)
local cx,cy = 512/2,512/2
for j = 1,512 do--ScrW() do
    for i = 1,512 do--ScrH() do
        local distx,disty = (i-cx)/255,(j-cy)/255
        local distc = math.sqrt(((i-cx)^2) + ((j-cy)^2))/256
        render.SetViewPort(i,j,1,1)
        render.Clear((distx*255)+127,(disty*255)+127,(distc*255)+127,255,true,true)
    end
end
render.PopRenderTarget()
]]

local screenratio = 4/3-- PAL has a large horizontal resolution(possible) but an aspect ratio of 4:3.

-- prepare wave and lines
render.PushRenderTarget(morphrt)
render.Clear(127,127,0,255,true,true)
render.PopRenderTarget()
render.PushRenderTarget(morphrt2)
render.Clear(127,127,0,255,true,true)
render.PopRenderTarget()
--

-- fill the buffer for noise overlay
render.PushRenderTarget(noiseoverlayrt)
render.Clear(0,0,0,255,true,true)
for y = 0,576 do
    for x = math.random(0,20),720,20 do
        render.SetViewPort(x,y,20,1)
        if math.random(0,1) == 1 then
            render.Clear(255,255,255,255,true,true)
        else
            render.Clear(0,0,0,255,true,true)
        end
    end
end
render.PopRenderTarget()
--

-- prepare tube delay rt
render.PushRenderTarget(tubedelayrt)
render.Clear(0,0,0,255,true,true)
render.PopRenderTarget()
--

KAMIKAZE_VHS_CFG = {}

-- these variables have been moved to convars due to their use, this may be useful in the future
local KAMIKAZE_VHS_CFG_enabled = CreateClientConVar("kamikaze_vhs_enabled", "0", true, false, nil, 0, 1 )
local KAMIKAZE_VHS_CFG_autodisable = CreateClientConVar("kamikaze_vhs_autodisable", "0", true, false, nil, 0, 1 )

local KAMIKAZE_VHS_CFG_osdautocurtime = CreateClientConVar("kamikaze_vhs_osdautocurtime", "1", true, false, nil, 0, 1 )

if KAMIKAZE_VHS_CFG_autodisable:GetInt() == 1 then
     KAMIKAZE_VHS_CFG_enabled:SetInt(0)
end
--

KAMIKAZE_VHS_CFG.currenthookclass = "PostDrawHUD"

KAMIKAZE_VHS_CFG.framesynchro = 576
KAMIKAZE_VHS_CFG.shuttlering = 0
KAMIKAZE_VHS_CFG.paused = false

KAMIKAZE_VHS_CFG.testtable = nil-- = Material("crt_testpicture_full.png")

KAMIKAZE_VHS_CFG.osd = {
    middletext = nil,
    hours = 2,
    minutes = 22,
    seconds = 15,
    days = 9,
    months = 1,
    years = 2025,
    fixsize = {m = {" ",2},s = {"0",2},ms = {" ",4},f = {"0",2},h = {" ",2},h12 = {" ",2}}, -- fixed size
    dateenabled = true,
    datepos = 3,
    -- 1: LEFTTOP;2: RIGHTTOP;3:LEFTDOWN;4:RIGHTDOWN;
    datetbl = {
        "%h",":","%mi",":","%s","\n","%d",".","%m",".","%y"
    },
    vcr_text_enabled = false,
    vcr_text = "PLAY",
    timepassageenabled = true,
}

KAMIKAZE_VHS_CFG.postclrmod = {
    ["pp_colour_addr"] = 0,
    ["pp_colour_addg"] = 0,
    ["pp_colour_addb"] = 0,
    ["pp_colour_brightness"] = 0,
    ["pp_colour_colour"] = 1,
    ["pp_colour_inv"] = 0,
    ["pp_colour_contrast"] = 1,
    ["pp_colour_mulr"] = 0,
    ["pp_colour_mulg"] = 0,
    ["pp_colour_mulb"] = 0,
}
KAMIKAZE_VHS_CFG.presize = false
KAMIKAZE_VHS_CFG.viewtype = 0
local KAMIKAZE_VHS_CFG_dspenabled = CreateClientConVar("kamikaze_vhs_dspenabled", "0", true, false, nil, 0, 1 )
KAMIKAZE_VHS_CFG.wave = {enabled = true,freq = 4,detail = 2,amp = 0.025,noise = 0}
KAMIKAZE_VHS_CFG.lines = {enabled = false,amp = 2,bottomline = {enabled = false,height = 8,amp = 5,noise = 0,randamp = 4,randclr = 0},upperline = {enabled = false,height = 64,scale = -0.1,noise = 0,randamp = 0}}
KAMIKAZE_VHS_CFG.sharpen = {enabled = true,size = 1,value = 3}
KAMIKAZE_VHS_CFG.cameraclrdist = {r = 0,g = 0,b = 0}
KAMIKAZE_VHS_CFG.interlaced = {enabled = true,pos = 0,blend = 1}
-- please note that the variable is called channelssettings, not channelsettings
KAMIKAZE_VHS_CFG.channelssettings = {
    chroma_line_drop = false,
    chroma_line_drop_maxdrops = 1,
    chroma_blur = 4,
    chroma_offsetx = 0,
    chroma_offsety = 0,
    chroma_noise_enabled = false,--true,
    chroma_noise_scalex = 16,
    chroma_noise_scaley = 8,
    chroma_noise_alpha = 0.004125,
    
    general_blur = 1.5,
    luma_noise_enabled = false,--true,
    luma_noise_scalex = 32,
    luma_noise_scaley = 18,
    luma_noise_alpha = 0.025,
}
KAMIKAZE_VHS_CFG.comets = {factor = 50000,enabled = false,size = 0.5}
KAMIKAZE_VHS_CFG.noise_overlay = {
    enabled = false,
    gapenabled = false,
    gappos = 0.5,
    gapsize = 0.25,
    gapanim = false,
}
KAMIKAZE_VHS_CFG.wrinkle = {
    enabled = false,
    anim = true,
    animspeed = 0.25,
    pos = 0,
    size = 0.25,
}
KAMIKAZE_VHS_CFG.videofader = {
    enabled = false,
    alpha = 0,
    r = 1,
    g = 1,
    b = 1,
    anim = 0,
    animspeed = 1,
}
KAMIKAZE_VHS_CFG.tubedelay = {
    enabled = false,
    addalpha = 0.02,
    drawalpha = 0.2
}


-- please, do not copy this table using direct assignment,
-- since you are not copying the table, but a pointer to it.
-- in fact, any action on the copy of the table will be reflected in the original table!
-- The correct example is:
-- KAMIKAZE_VHS_CFG = table.Copy(KAMIKAZE_VHS_CFG_DEFAULT)
-- the same for child elements.
KAMIKAZE_VHS_CFG_DEFAULT = table.Copy(KAMIKAZE_VHS_CFG)

local function cfg_readstring(cfile)
    return cfile:Read(cfile:ReadByte())
end

local function cfg_readdata(cfile)
    local type = cfile:ReadByte()
    local name = cfg_readstring(cfile)
    if not name then return end
    if type == 3 then
        return name,cfile:ReadBool()
    elseif type == 2 then
        local tbl = {}
        for i = 1,cfile:ReadByte() do
            local name,data = cfg_readdata(cfile)
            if name then tbl[tonumber(name) or name] = data else break end
            -- there is an obvious problem here - keys are always serialized as strings and lua wont be able to index them correctly.
            -- of course, this can be fixed, but for now it works
        end
        return name,tbl
    elseif type == 1 then
        return name,cfg_readstring(cfile)
    elseif type == 0 then
        return name,cfile:ReadDouble()
    end
    return name,nil
end

local function LoadCFG()
    local cfile = file.Open("kamikazevhscfg.dat","rb","DATA")
    if cfile then
        if cfile:Read(9) == "KVHSE2CFG" then
            cfile:Skip(4) -- skip date stamp
            local name,data = cfg_readdata(cfile)
            if name == "KAMIKAZE_VHS_CFG" then
                table.Merge(KAMIKAZE_VHS_CFG,data)
                --for k,v in pairs(data) do
                --    KAMIKAZE_VHS_CFG[k] = v
                --end
            end
        end
        cfile:Close()
    end
end

if KAMIKAZE_VHS_CFG_LOADING then LoadCFG() end
KAMIKAZE_VHS_CFG.presize = false
KAMIKAZE_VHS_CFG.viewtype = 0

-- OSD support

local osdfontsize = math.min(ScrH()/8,ScrW()/8)
surface.CreateFont("KamikazeVHSFont", {
    font = "Real Vhs Font", -- this font is not monospaced for some reason
    extended = false, -- this font only supports ascii set
    size = osdfontsize,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
})

local function getdateosd_monthdays()
    local days = {31,28,31,30,31,30,31,31,30,31,30,31}

    if (KAMIKAZE_VHS_CFG.osd.months == 2 and ((KAMIKAZE_VHS_CFG.osd.years % 4 == 0 and KAMIKAZE_VHS_CFG.osd.years % 100 ~= 0) or (KAMIKAZE_VHS_CFG.osd.years % 400 == 0))) then
        return 29
    end

    return days[KAMIKAZE_VHS_CFG.osd.months]
end

local function getdateosd_value(val,type)
    local val = tostring(val)
    local tbl = KAMIKAZE_VHS_CFG.osd.fixsize[type]
    if tbl then
        local diff = tbl[2]-#val
        if diff < 0 then
            val = string.sub(val,1,diff)
        elseif diff > 0 then
            val = string.rep(tbl[1],diff) .. val
        end
        return val
    end
    return val
end

local realframetime = 0
local function formattostring(tbl,y,m,d,h,mi,s,ms,f,h12,mer,mw)
    local str = ""
    for k,v in pairs(tbl) do
        if v == "%y" then str = str .. y       -- years
        elseif v == "%mi" then str = str .. mi -- minutes
        elseif v == "%d" then str = str .. d   -- days
        elseif v == "%h" then str = str .. h   -- hours
        elseif v == "%m" then str = str .. m   -- mounths
        elseif v == "%s" then str = str .. s   -- seconds
        elseif v == "%ms" then str = str .. ms -- miliseconds
        elseif v == "%f" then str = str .. f   -- frames

        elseif v == "%h12" then str = str .. h12  -- hours 12-based
        elseif v == "%mer" then str = str .. mer  -- meridiem

        elseif v == "%mw" then str = str .. mw -- month word
        else str = str .. v end                -- raw
    end
    return str
end

local function getdateosd()
    if KAMIKAZE_VHS_CFG.osd.timepassageenabled then
        KAMIKAZE_VHS_CFG.osd.seconds = KAMIKAZE_VHS_CFG.osd.seconds + realframetime -- fixes the cause of time speeding up when the menu is open
        if KAMIKAZE_VHS_CFG.osd.seconds >= 60 then
            KAMIKAZE_VHS_CFG.osd.seconds = 0
            KAMIKAZE_VHS_CFG.osd.minutes = KAMIKAZE_VHS_CFG.osd.minutes + 1 -- please note that the difference between the current seconds and the maximum is not taken into account!
            if KAMIKAZE_VHS_CFG.osd.minutes >= 60 then
                KAMIKAZE_VHS_CFG.osd.minutes = 0
                KAMIKAZE_VHS_CFG.osd.hours = KAMIKAZE_VHS_CFG.osd.hours + 1
                if KAMIKAZE_VHS_CFG.osd.hours >= 24 then
                    KAMIKAZE_VHS_CFG.osd.hours = 0
                    KAMIKAZE_VHS_CFG.osd.days = KAMIKAZE_VHS_CFG.osd.days + 1
                    if KAMIKAZE_VHS_CFG.osd.days > getdateosd_monthdays() then
                        KAMIKAZE_VHS_CFG.osd.days = 1
                        KAMIKAZE_VHS_CFG.osd.months = KAMIKAZE_VHS_CFG.osd.months + 1
                        if KAMIKAZE_VHS_CFG.osd.months > 12 then
                            KAMIKAZE_VHS_CFG.osd.months = 1
                            KAMIKAZE_VHS_CFG.osd.years = KAMIKAZE_VHS_CFG.osd.years + 1
                        end
                    end
                end
            end
        end
    end
    local mer = "ER"
    local hours12 = 0
    if KAMIKAZE_VHS_CFG.osd.hours < 12 then
        mer = "AM"
        hours12 = KAMIKAZE_VHS_CFG.osd.hours
    else
        mer = "PM"
        hours12 = KAMIKAZE_VHS_CFG.osd.hours - 12
    end
    if hours12 == 0 then
        hours12 = 12
    end

    return formattostring(KAMIKAZE_VHS_CFG.osd.datetbl,getdateosd_value(KAMIKAZE_VHS_CFG.osd.years,"y"),
    getdateosd_value(KAMIKAZE_VHS_CFG.osd.months,"m"),getdateosd_value(KAMIKAZE_VHS_CFG.osd.days,"d"),
    getdateosd_value(KAMIKAZE_VHS_CFG.osd.hours,"h"),getdateosd_value(KAMIKAZE_VHS_CFG.osd.minutes,"mi"),
    getdateosd_value(math.floor(KAMIKAZE_VHS_CFG.osd.seconds),"s"),getdateosd_value(math.floor((KAMIKAZE_VHS_CFG.osd.seconds-math.floor(KAMIKAZE_VHS_CFG.osd.seconds))*1000),"ms"), -- seconds and miliseconds
    getdateosd_value(math.floor((KAMIKAZE_VHS_CFG.osd.seconds-math.floor(KAMIKAZE_VHS_CFG.osd.seconds))*25),"f"), -- frames(25 f-fps)
    getdateosd_value(hours12,"h12"),getdateosd_value(mer,"mer"), -- hours 12-based and meridiem
    getdateosd_value(({"JANUARY","FEBRUARY","MARCH","APRIL","MAY","JUNE","JULY","AUGUST","SEPTEMBER","OCTOBER","NOVEMBER","DECEMBER"})[KAMIKAZE_VHS_CFG.osd.months] or "NUL","mw")) -- month word(JAN,FEB,MAR ... )
end

local function draw_osdtext(a,b,c,d,e,f,g)
    draw.SimpleText(a,b,c+4,d,Color(0,0,0,255),f,g)
    return draw.SimpleText(a,b,c,d,e,f,g)
end

local function addosd()
    if KAMIKAZE_VHS_CFG.osd.dateenabled then
        local datealign = TEXT_ALIGN_LEFT
        local datex = 0
        local datey = 0
        if KAMIKAZE_VHS_CFG.osd.datepos == 1 then     -- left up
            datex = ScrW()/8
            datey = ScrH()/6
            if KAMIKAZE_VHS_CFG.viewtype == 2 then -- fix cropping date
                datex = ((ScrW()-(ScrW()/screenratio))/2)+(ScrW()/16)
            end
        elseif KAMIKAZE_VHS_CFG.osd.datepos == 2 then -- right up
            datealign = TEXT_ALIGN_RIGHT
            datex = ScrW()-(ScrW()/8)
            datey = ScrH()/6
            if KAMIKAZE_VHS_CFG.viewtype == 2 then -- fix cropping date
                datex = ScrW()-((((ScrW()/screenratio))/2)-(ScrW()/4))
            end
        elseif KAMIKAZE_VHS_CFG.osd.datepos == 3 then -- left down
            datex = ScrW()/8
            datey = ScrH()/1.4
            if KAMIKAZE_VHS_CFG.viewtype == 2 then -- fix cropping date
                datex = ((ScrW()-(ScrW()/screenratio))/2)+(ScrW()/16)
            end
        elseif KAMIKAZE_VHS_CFG.osd.datepos == 4 then -- right down
            datealign = TEXT_ALIGN_RIGHT
            datex = ScrW()-(ScrW()/8)
            datey = ScrH()/1.4
            if KAMIKAZE_VHS_CFG.viewtype == 2 then -- fix cropping date
                datex = ScrW()-((((ScrW()/screenratio))/2)-(ScrW()/4))
            end
        end
        local datetbl = string.Explode("\n",getdateosd())
        for i = 0,#datetbl-1 do
            draw_osdtext(datetbl[i+1],"KamikazeVHSFont",datex,datey+((osdfontsize/2)*i),Color(255,255,255),datealign,TEXT_ALIGN_TOP)
        end
    end
    if KAMIKAZE_VHS_CFG.osd.middletext then
        local middletexttbl = string.Explode("\n",KAMIKAZE_VHS_CFG.osd.middletext)
        if #middletexttbl > 1 then
            for i = 0,#middletexttbl-1 do
                draw_osdtext(string.upper(middletexttbl[i+1]),"KamikazeVHSFont",ScrW()/2,(ScrH()/2)+((osdfontsize/2)*i),Color(255,255,255),TEXT_ALIGN_CENTER)
            end
        else
            draw_osdtext(string.upper(KAMIKAZE_VHS_CFG.osd.middletext),"KamikazeVHSFont",ScrW()/2,ScrH()/2,Color(255,255,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end
    end
    if KAMIKAZE_VHS_CFG.osd.vcr_text_enabled then -- of course, this is not the best place for this. however, for now, it is the best that can be done.
        surface.SetFont("KamikazeVHSFont")
        local vcr_text_w,vcr_text_h = surface.GetTextSize(KAMIKAZE_VHS_CFG.osd.vcr_text)
        local vcr_text_x,vcr_text_y = ScrW()/8,ScrH()/6
        draw.RoundedBox(0,vcr_text_x,vcr_text_y+(ScrH()/32),vcr_text_w+(ScrW()/128),vcr_text_h-(ScrH()/32),Color(10,10,10))
        draw.SimpleText(tostring(KAMIKAZE_VHS_CFG.osd.vcr_text),"KamikazeVHSFont",vcr_text_x,vcr_text_y,Color(255,255,255))
    end
end
-- Horizontal Synchronization Support

local function getwavex(i,shift,initval)
    local val = initval + math.Rand(0,KAMIKAZE_VHS_CFG.wave.noise)
    for j = 1,KAMIKAZE_VHS_CFG.wave.detail do
        val = val + (math.sin((i/64)+(cachedcurtime*(KAMIKAZE_VHS_CFG.wave.freq*j))*shift)/j)
    end
    return val*10
end

local function updatemorphrt()
    render.PushRenderTarget(morphrt)
    render.Clear(127,127,0,255,true,true)
    local shift = math.Rand(0,1)
    if KAMIKAZE_VHS_CFG.shuttlering == 0 then
        for i = 1,576 do
            render.SetViewPort(0,i,720,1)
            render.Clear(127+getwavex(i,shift,0),127,0,255,true,true)
        end
    else
        local height3 = (576/3)
        local cshift = 0
        local cshiftn = 0
        for i = 1,576 do
            render.SetViewPort(0,i,720,1)
            render.Clear(127+getwavex(i,shift,cshift),127,0,255,true,true)
            cshiftn = cshiftn + 1
            cshift = cshift+((cshiftn/height3)*KAMIKAZE_VHS_CFG.shuttlering)
            if cshift > 32 or cshift < -32 then
                cshift = 0
                cshiftn = 0
            end
        end
    end
    render.PopRenderTarget()
end

local function getwavex2(upscaleinit,btscaleinit,i)
    local up_height = 0
    local up_scale = 0
    if KAMIKAZE_VHS_CFG.lines.upperline.enabled then
        up_height = KAMIKAZE_VHS_CFG.lines.upperline.height -- 64
        up_scale = upscaleinit -- -0.1
        up_scale = up_scale + math.Rand(0,KAMIKAZE_VHS_CFG.lines.upperline.noise) -- 0.1
    end
    local bt_height = 0
    local bt_scale = 0
    if KAMIKAZE_VHS_CFG.lines.bottomline.enabled then
        bt_height = KAMIKAZE_VHS_CFG.lines.bottomline.height -- 8
        bt_scale = btscaleinit -- 5
        bt_scale = bt_scale + math.Rand(0,KAMIKAZE_VHS_CFG.lines.bottomline.noise)
    end
    return (((math.max((up_height-i)/20,0)^2)*up_scale)-((math.max((i-(307-bt_height))/bt_height,0))*bt_scale))*10 -- 288+16
end

local function updatemorphrt2()
    local upscale = KAMIKAZE_VHS_CFG.lines.upperline.scale+math.Rand(0,KAMIKAZE_VHS_CFG.lines.upperline.randamp)
    local btscale = math.Rand(0,KAMIKAZE_VHS_CFG.lines.bottomline.randamp)+KAMIKAZE_VHS_CFG.lines.bottomline.amp
    render.PushRenderTarget(morphrt2)
        render.Clear(127,127,0,255,true,true)
        for i = 1,576 do
            render.SetViewPort(0,i,720,1)
            render.Clear(127+getwavex2(upscale,btscale,i),127,0,255,true,true)
        end
    render.PopRenderTarget()
end

--

local function fillwithnoise(ystart,yend)
    surface.SetMaterial(noiseoverlaymat)
    surface.SetDrawColor(255,255,255,255)
    local ox,oy = math.Rand(0.125,1),math.Rand(0.75,1)
    if math.random(0,1) == 1 then
        surface.DrawTexturedRectUV(0,ystart,ScrW(),yend,0,oy,ox,oy+(1/(ScrH()/yend)))
    else
        surface.DrawTexturedRectUV(0,ystart,ScrW(),yend,1-ox,oy,ox,oy+(1/(ScrH()/yend)))
    end
end

local function drawnoiseoverlay()
    if KAMIKAZE_VHS_CFG.noise_overlay.gapenabled then
        local gapstart = ScrH()*KAMIKAZE_VHS_CFG.noise_overlay.gappos
        local gapsize = ScrH()*KAMIKAZE_VHS_CFG.noise_overlay.gapsize
        fillwithnoise(0,gapstart)
        fillwithnoise(gapstart+gapsize,ScrH()-(gapstart+gapsize))
        -- this is a very bad animation that only partially corresponds to reality, but if i try to fix it, i will make it even worse
        if KAMIKAZE_VHS_CFG.noise_overlay.gapanim then
            KAMIKAZE_VHS_CFG.noise_overlay.gapsize = math.Clamp(KAMIKAZE_VHS_CFG.noise_overlay.gapsize+((RealFrameTime()/40)),0,1)
            if KAMIKAZE_VHS_CFG.noise_overlay.gapsize == 1 then
                KAMIKAZE_VHS_CFG.noise_overlay.gappos = math.Clamp((KAMIKAZE_VHS_CFG.noise_overlay.gappos-(RealFrameTime()/20)),0,1)
            else
                if KAMIKAZE_VHS_CFG.noise_overlay.gapsize*10 % 1 > math.Round(KAMIKAZE_VHS_CFG.noise_overlay.gapsize*10)/20 then
                    KAMIKAZE_VHS_CFG.noise_overlay.gappos = math.Clamp((KAMIKAZE_VHS_CFG.noise_overlay.gappos-(RealFrameTime()/20)),0,1)
                else
                    KAMIKAZE_VHS_CFG.noise_overlay.gappos = math.Clamp((KAMIKAZE_VHS_CFG.noise_overlay.gappos+(RealFrameTime()/20)),0,1)
                end
            end
        end
        render.UpdateScreenEffectTexture(0)
    else
        fillwithnoise(0,ScrH())
        render.UpdateScreenEffectTexture(0)
    end
end

--

local function updatenoisert(chroma)
    -- i know that i can buffer all this, but it will take up more memory space, right?
    render.PushRenderTarget(noisert)
    render.Clear(0,0,0,0,true,true)
    if chroma then -- chroma noise is very resource-intensive! when it is turned on, the FPS drops from 150 to 70
        local scalex = 720/KAMIKAZE_VHS_CFG.channelssettings.chroma_noise_scalex
        for y = 1,576/KAMIKAZE_VHS_CFG.channelssettings.chroma_noise_scaley do
            for x = 0,scalex do
                render.SetViewPort(x,y,1,1)
                render.Clear(math.random(1,255),math.random(1,255),math.random(1,255),255,true,true)
            end
        end
    else
        local scalex = 720/KAMIKAZE_VHS_CFG.channelssettings.luma_noise_scalex
        for y = 1,576/KAMIKAZE_VHS_CFG.channelssettings.luma_noise_scaley do
            for x = 0,scalex do
                render.SetViewPort(x,y,1,1)
                local br = math.random(1,255)
                render.Clear(br,br,br,255,true,true)
            end
        end
    end
    render.PopRenderTarget()
end

local function drawcomets()
    if KAMIKAZE_VHS_CFG.comets.enabled then
        local maxrand = -KAMIKAZE_VHS_CFG.comets.factor
        local maxsizediff = KAMIKAZE_VHS_CFG.comets.size
        local xw = 720/4
        for y = 1,576/2 do
            local cometval = 0
            local curmin = math.random(maxrand,0)
            for x = 0,xw do
                if cometval > 0 then
                    draw.RoundedBox(0,x*4,y*2,4,2,Color(cometval*255,cometval*255,cometval*255,255))
                end
                cometval = cometval - math.Rand(0,maxsizediff)
                if cometval < curmin then
                    cometval = 1
                    curmin = math.random(maxrand,0)
                end
            end
        end
        render.UpdateScreenEffectTexture(0)
    end
end
local bottomlineclr = Color(0,0,0,0)

local function addblur()
    render.OverrideAlphaWriteEnable(true,false)

    -- draw a black and white picture on top of the screen
    render.UpdateScreenEffectTexture(0)
    colormod:SetFloat("$pp_colour_brightness",0.1)colormod:SetFloat("$pp_colour_contrast",1)colormod:SetFloat("$pp_colour_colour",0)
    render.SetMaterial(colormod)
    render.DrawScreenQuadEx(0,0,ScrW()*(ScrW()/720),ScrH()*(ScrH()/576))
    if KAMIKAZE_VHS_CFG.channelssettings.luma_noise_enabled then
        updatenoisert(false)
        surface.SetMaterial(noisemat)
        surface.SetDrawColor(255,255,255,KAMIKAZE_VHS_CFG.channelssettings.luma_noise_alpha*255)
        surface.DrawTexturedRectUV(0,0,(ScrW()*(ScrW()/720))*KAMIKAZE_VHS_CFG.channelssettings.luma_noise_scalex,(ScrH()*(ScrH()/576))*KAMIKAZE_VHS_CFG.channelssettings.luma_noise_scaley,-2,-1,0,0)
    end

    -- now add some colours
    
    if KAMIKAZE_VHS_CFG.channelssettings.chroma_noise_enabled or KAMIKAZE_VHS_CFG.channelssettings.chroma_line_drop or (KAMIKAZE_VHS_CFG.lines.enabled and KAMIKAZE_VHS_CFG.lines.bottomline.enabled and KAMIKAZE_VHS_CFG.lines.bottomline.randclr ~= 0) then
        if KAMIKAZE_VHS_CFG.channelssettings.chroma_noise_enabled then
            updatenoisert(true)
        end
        render.PushRenderTarget(rt)
        if KAMIKAZE_VHS_CFG.channelssettings.chroma_noise_enabled then
            surface.SetMaterial(noisemat)
            surface.SetDrawColor(255,255,255,KAMIKAZE_VHS_CFG.channelssettings.chroma_noise_alpha*255)
            -- increase the size by repetition(for speed)
            surface.DrawTexturedRectUV(0,0,(ScrW()*(ScrW()/720))*KAMIKAZE_VHS_CFG.channelssettings.chroma_noise_scalex,(ScrH()*(ScrH()/576))*KAMIKAZE_VHS_CFG.channelssettings.chroma_noise_scaley,-1,-1,1,1)
        end
        if KAMIKAZE_VHS_CFG.channelssettings.chroma_line_drop then
            for i = 1,math.random(1,KAMIKAZE_VHS_CFG.channelssettings.chroma_line_drop_maxdrops) do
                render.SetViewPort(0,math.random(1,576),720,math.random(1,5))
                render.Clear(0,0,0,0,true,true)
            end
        end
        if KAMIKAZE_VHS_CFG.lines.enabled then
            if KAMIKAZE_VHS_CFG.lines.bottomline.enabled then
                if KAMIKAZE_VHS_CFG.lines.bottomline.randclr ~= 0 then
                    local btheight = KAMIKAZE_VHS_CFG.lines.bottomline.height*(ScrH()/576)
                    draw.RoundedBox(0,0,576-btheight,720,btheight,bottomlineclr)
                    if not KAMIKAZE_VHS_CFG.interlaced.enabled or (KAMIKAZE_VHS_CFG.interlaced.enabled and KAMIKAZE_VHS_CFG.interlaced.pos == 0) then
                        bottomlineclr = Color(math.random(0,255),math.random(0,255),math.random(0,255),math.Round(KAMIKAZE_VHS_CFG.lines.bottomline.randclr*255))
                    end
                end
            end
        end
        render.PopRenderTarget()
    end

    render.OverrideBlend(true,3,2,0) -- approximately the same blending effect
    
    blurmat:SetTexture("$basetexture",rt)
    blurmat:SetFloat("$size",KAMIKAZE_VHS_CFG.channelssettings.chroma_blur)
    render.SetMaterial(blurmat)
    render.DrawScreenQuadEx(KAMIKAZE_VHS_CFG.channelssettings.chroma_offsetx*(ScrW()/720),KAMIKAZE_VHS_CFG.channelssettings.chroma_offsety*(ScrH()/576),ScrW()*(ScrW()/720),ScrH()*(ScrH()/576))

    render.OverrideAlphaWriteEnable(false,false)
    render.OverrideBlend(false)
    -- in the original version the pixel colour is the average value. double the colour
    render.UpdateScreenEffectTexture(0)
    colormod:SetFloat("$pp_colour_brightness",0)colormod:SetFloat("$pp_colour_colour",2)colormod:SetFloat("$pp_colour_contrast",1)
    render.SetMaterial(colormod)
    render.DrawScreenQuadEx(0,0,ScrW(),ScrH())
    render.UpdateScreenEffectTexture(0)
end

local function renderinterlacing()
    if KAMIKAZE_VHS_CFG.interlaced.enabled then
        -- principle: buffer frame 1 and draw frame 2 on it
        render.SetWriteDepthToDestAlpha(false)
        render.UpdateScreenEffectTexture(0)
        if KAMIKAZE_VHS_CFG.interlaced.pos == 1 then
            KAMIKAZE_VHS_CFG.interlaced.pos = 0
            render.CopyTexture(rt,interlacedbufferrt)
            render.PushRenderTarget(interlacedbufferrt)
            render.PopRenderTarget()
        else
            render.CopyTexture(rt,interlacedcopyrt)
            render.PushRenderTarget(interlacedcopyrt)
            render.PopRenderTarget()
            KAMIKAZE_VHS_CFG.interlaced.pos = 1
        end
        render.SetMaterial(interlacedcopymat)
        render.DrawScreenQuad()
        render.SetStencilEnable(true)
        render.ClearStencil()
        render.SetStencilTestMask(255)
        render.SetStencilWriteMask(255)
        render.SetStencilPassOperation(STENCILOPERATION_KEEP)
        render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NEVER)
        render.SetStencilReferenceValue(9)
        render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
        
        local linesize2 = math.ceil(ScrH()/288)
        local linesize = linesize2/2
        for j = 0,ScrH()/linesize2 do
            draw.RoundedBox(0,0,(j*linesize2)+linesize,ScrW(),linesize,Color(0,0,0))
        end

        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
        render.SetStencilFailOperation(STENCILOPERATION_KEEP)
        interlacedbuffermat:SetFloat("$alpha",KAMIKAZE_VHS_CFG.interlaced.blend)
        render.SetMaterial(interlacedbuffermat)
        render.DrawScreenQuad()

        render.SetStencilEnable(false)
        render.UpdateScreenEffectTexture(0)
        render.SetWriteDepthToDestAlpha(true)
    end
end

local function drawtubedelay()
    render.UpdateScreenEffectTexture(0)
        render.PushRenderTarget(tubedelayrt)
            screencopymat:SetFloat("$alpha",KAMIKAZE_VHS_CFG.tubedelay.addalpha)--0.02)
            render.SetMaterial(screencopymat)
            render.DrawScreenQuad()
        render.PopRenderTarget()
    tubedelaymat:SetFloat("$alpha",KAMIKAZE_VHS_CFG.tubedelay.drawalpha)--0.2)
    render.SetMaterial(tubedelaymat)
render.OverrideBlend(true,BLEND_SRC_ALPHA,BLEND_ONE,0)
    render.DrawScreenQuad()
render.OverrideBlend(false)

    screencopymat:SetFloat("$alpha",1)
    render.UpdateScreenEffectTexture(0)
end

local _kamikaze_shake_end  = 0
local _kamikaze_shake_next = 0
local _kamikaze_shake_cv   = nil
local lastquery = 0

local lastsavedtime = 0

local olddspenabled = KAMIKAZE_VHS_CFG_dspenabled:GetBool()

local function rendervhseffect()
    if not KAMIKAZE_VHS_CFG_enabled:GetBool() then return end
    if KAMIKAZE_VHS_CFG_LOADING then -- do not save the config file with default settings
        if SysTime()-lastsavedtime > 60 then
            RunConsoleCommand("kamikaze_vhs_savecfg","")
            lastsavedtime = SysTime()
        end
    end
    if KAMIKAZE_VHS_CFG_dspenabled:GetBool() then
        -- If anyone knows how to create custom preset, please tell me.
        LocalPlayer():SetDSP(14) -- Water S
        olddspenabled = true
    else
        if olddspenabled then
            LocalPlayer():SetDSP(1) -- remove DSP
        end
        olddspenabled = false
    end
    if KAMIKAZE_VHS_CFG_osdautocurtime:GetBool() then
        local osdatereturn = os.date("*t")
        KAMIKAZE_VHS_CFG.osd.hours = osdatereturn.hour
        KAMIKAZE_VHS_CFG.osd.minutes = osdatereturn.min
        KAMIKAZE_VHS_CFG.osd.seconds = osdatereturn.sec
        KAMIKAZE_VHS_CFG.osd.days = osdatereturn.day
        KAMIKAZE_VHS_CFG.osd.months = osdatereturn.month
        KAMIKAZE_VHS_CFG.osd.years = osdatereturn.year
    end
    render.UpdateScreenEffectTexture(0)
    --[[
    render.SetMaterial(lensdistortionmat)
    render.DrawScreenQuadEx(-ScrW()/2,-ScrH()/2,ScrW()*2,ScrH()*2)
    render.UpdateScreenEffectTexture(0)
    --]]
    if KAMIKAZE_VHS_CFG.testtable then
        render.SetMaterial(KAMIKAZE_VHS_CFG.testtable)
        render.DrawScreenQuad()
        render.UpdateScreenEffectTexture(0)
    else
        if KAMIKAZE_VHS_CFG.cameraclrdist.r ~= 0 or KAMIKAZE_VHS_CFG.cameraclrdist.g ~= 0 or KAMIKAZE_VHS_CFG.cameraclrdist.b ~= 0 then
            render.UpdateScreenEffectTexture(0)
            render.SetMaterial(matred)
            render.DrawScreenQuadEx(-KAMIKAZE_VHS_CFG.cameraclrdist.r,-KAMIKAZE_VHS_CFG.cameraclrdist.r,ScrW()+KAMIKAZE_VHS_CFG.cameraclrdist.r,ScrH()+KAMIKAZE_VHS_CFG.cameraclrdist.r)
            render.SetMaterial(matgreen)
            render.DrawScreenQuadEx(-KAMIKAZE_VHS_CFG.cameraclrdist.g,-KAMIKAZE_VHS_CFG.cameraclrdist.g,ScrW()+KAMIKAZE_VHS_CFG.cameraclrdist.g,ScrH()+KAMIKAZE_VHS_CFG.cameraclrdist.g)
            render.SetMaterial(matblue)
            render.DrawScreenQuadEx(-KAMIKAZE_VHS_CFG.cameraclrdist.b,-KAMIKAZE_VHS_CFG.cameraclrdist.b,ScrW()+KAMIKAZE_VHS_CFG.cameraclrdist.b,ScrH()+KAMIKAZE_VHS_CFG.cameraclrdist.b)
            render.UpdateScreenEffectTexture(0)
            colormod:SetFloat("$pp_colour_brightness",0)colormod:SetFloat("$pp_colour_contrast",0.82)colormod:SetFloat("$pp_colour_colour",1)
            render.SetMaterial(colormod)
            render.DrawScreenQuad()

            render.UpdateScreenEffectTexture(0)
        end
    end
    if KAMIKAZE_VHS_CFG.wave.enabled then
        updatemorphrt()
    end
    if KAMIKAZE_VHS_CFG.lines.enabled then
        updatemorphrt2()
    end

    if KAMIKAZE_VHS_CFG.tubedelay.enabled then
        drawtubedelay()
    end

    if KAMIKAZE_VHS_CFG.presize then
        blurmat:SetTexture("$basetexture",rt)
        blurmat:SetFloat("$size",0)
        render.SetMaterial(blurmat)
        render.DrawScreenQuadEx(-(ScrW()/screenratio)/4,0,ScrW()+((ScrW()/screenratio)/2),ScrH())
        render.UpdateScreenEffectTexture(0)
    end

    addosd()
    
    render.UpdateScreenEffectTexture(0)
    blurmat:SetTexture("$basetexture",rt)
    blurmat:SetFloat("$size",KAMIKAZE_VHS_CFG.channelssettings.general_blur)
    render.SetMaterial(blurmat)
    render.DrawScreenQuadEx(0,0,720,576)
    -- Please note that starting from this line the image is in 720 x 576 format (for ease of adding effects)

    if KAMIKAZE_VHS_CFG.paused then -- removes colour. not in use yet.
        colormod:SetFloat("$pp_colour_brightness",0)colormod:SetFloat("$pp_colour_contrast",1)colormod:SetFloat("$pp_colour_colour",0)
        render.SetMaterial(colormod)
        render.DrawScreenQuadEx(0,0,720,576)
    end

    if KAMIKAZE_VHS_CFG.videofader.enabled then
        if KAMIKAZE_VHS_CFG.videofader.alpha ~= 0 then
            draw.RoundedBox(0,0,0,720,576,Color(KAMIKAZE_VHS_CFG.videofader.r*255,
                KAMIKAZE_VHS_CFG.videofader.g*255,
                KAMIKAZE_VHS_CFG.videofader.b*255,
                KAMIKAZE_VHS_CFG.videofader.alpha*255))
            render.UpdateScreenEffectTexture(0)
        end
        if KAMIKAZE_VHS_CFG.videofader.anim == 1 then
            KAMIKAZE_VHS_CFG.videofader.alpha = math.Clamp(KAMIKAZE_VHS_CFG.videofader.alpha - (RealFrameTime()*KAMIKAZE_VHS_CFG.videofader.animspeed),0,1)
        elseif KAMIKAZE_VHS_CFG.videofader.anim == 2 then
            KAMIKAZE_VHS_CFG.videofader.alpha = math.Clamp(KAMIKAZE_VHS_CFG.videofader.alpha + (RealFrameTime()*KAMIKAZE_VHS_CFG.videofader.animspeed),0,1)
        end
    end

    drawcomets()

    draw.RoundedBox(0,-2,0,4,576,Color(0,0,0))
    draw.RoundedBox(0,720,0,ScrW()-720,576,Color(0,0,0))
    render.UpdateScreenEffectTexture(0)
    if KAMIKAZE_VHS_CFG.wave.enabled then
        morphmat:SetFloat("$refractamount",KAMIKAZE_VHS_CFG.wave.amp/2)
        render.SetMaterial(morphmat)
        render.DrawScreenQuad()
        draw.RoundedBox(0,-2,0,4,576,Color(0,0,0))
        draw.RoundedBox(0,720,0,ScrW()-720,576,Color(0,0,0))
        render.UpdateScreenEffectTexture(0)
    end
    if KAMIKAZE_VHS_CFG.lines.enabled then
        morphmat2:SetFloat("$refractamount",KAMIKAZE_VHS_CFG.lines.amp/2)
        render.SetMaterial(morphmat2)
        render.DrawScreenQuad()
        render.UpdateScreenEffectTexture(0)
    end
    if KAMIKAZE_VHS_CFG.shuttlering ~= 0 then -- 2-head VCR emulation. not yet developed well enough to be mentioned in documentation.
        for i = 1,2 do
            local cometval = 0
            local curmin = -math.random(0,10)
            for y = 0,ScrH()/40 do
                for x = 0,ScrW()/4 do
                    if cometval > 0 then
                        draw.RoundedBox(0,x*4,(y+((576/3)*i))+10,4,3,Color(cometval*255,cometval*255,cometval*255,255))
                    end
                    cometval = cometval - math.Rand(0,1)/5
                    if cometval < curmin then
                        cometval = 1
                        curmin = -math.random(0,10)
                    end
                end
            end
        end
        render.UpdateScreenEffectTexture(0)
    end

    -- Back to original resolution
    addblur()
    if KAMIKAZE_VHS_CFG.sharpen.enabled then
        if KAMIKAZE_VHS_CFG.sharpen.size > 0 and KAMIKAZE_VHS_CFG.sharpen.value > 0 then
            DrawSharpen(KAMIKAZE_VHS_CFG.sharpen.size,KAMIKAZE_VHS_CFG.sharpen.value)
            render.UpdateScreenEffectTexture(0)
        end
    end
    if KAMIKAZE_VHS_CFG.wrinkle.enabled then
        colormod:SetFloat("$pp_colour_brightness",0)colormod:SetFloat("$pp_colour_contrast",1)colormod:SetFloat("$pp_colour_colour",1)
        surface.SetMaterial(colormod)
        local wrinkleypos = KAMIKAZE_VHS_CFG.wrinkle.pos
        local wrinkleysize = KAMIKAZE_VHS_CFG.wrinkle.size
        surface.DrawTexturedRectUV(0,wrinkleypos*ScrH(),ScrW(),wrinkleysize*ScrH(),0,wrinkleypos,1,wrinkleypos)
        render.UpdateScreenEffectTexture(0)
        if KAMIKAZE_VHS_CFG.wrinkle.anim then
            KAMIKAZE_VHS_CFG.wrinkle.pos = KAMIKAZE_VHS_CFG.wrinkle.pos + (RealFrameTime()*KAMIKAZE_VHS_CFG.wrinkle.animspeed)
            if KAMIKAZE_VHS_CFG.wrinkle.pos > 1 then
                KAMIKAZE_VHS_CFG.wrinkle.pos = -KAMIKAZE_VHS_CFG.wrinkle.size
            end
        end
    end
    renderinterlacing()
    for k,v in pairs(KAMIKAZE_VHS_CFG.postclrmod) do
        colormod:SetFloat("$" .. k,v)
    end
    render.SetMaterial(colormod)
    render.DrawScreenQuad()
    render.UpdateScreenEffectTexture(0)
    if KAMIKAZE_VHS_CFG.noise_overlay.enabled then
        drawnoiseoverlay()
    end
    if not _kamikaze_shake_cv then _kamikaze_shake_cv = GetConVar("kamikaze_vhs_shake") end
    if _kamikaze_shake_cv and _kamikaze_shake_cv:GetBool() then
        local ct = CurTime()
        if ct > _kamikaze_shake_next then
            _kamikaze_shake_end  = ct + math.Rand(0.5, 3.0)
            _kamikaze_shake_next = ct + math.Rand(5, 20)
        end
        if ct < _kamikaze_shake_end then
            draw.RoundedBox(0,0,0,ScrW(),ScrH(),Color(0,0,0))
            blurmat:SetTexture("$basetexture",rt)
            blurmat:SetFloat("$size",0)
            render.SetMaterial(blurmat)
            render.DrawScreenQuadEx(0,math.random(-math.floor(ScrH()/150),math.floor(ScrH()/150)),ScrW(),ScrH())
            render.UpdateScreenEffectTexture(0)
        end
    end
    if KAMIKAZE_VHS_CFG.viewtype == 1 then
        -- resizing
        draw.RoundedBox(0,-1,-1,ScrW()+1,ScrH()+1,Color(0,0,0))
        blurmat:SetTexture("$basetexture",rt)
        blurmat:SetFloat("$size",0)
        render.SetMaterial(blurmat)
        render.DrawScreenQuadEx((ScrW()-(ScrW()/screenratio))/2,0,ScrW()/screenratio,ScrH())
        render.UpdateScreenEffectTexture(0)
    elseif KAMIKAZE_VHS_CFG.viewtype == 2 then
        -- cropping
        local cropwidth = (ScrW()-(ScrW()/screenratio))/2
        draw.RoundedBox(0,0,0,cropwidth,ScrH(),Color(0,0,0))
        draw.RoundedBox(0,ScrW()-cropwidth,0,cropwidth,ScrH(),Color(0,0,0))
        render.UpdateScreenEffectTexture(0)
    elseif KAMIKAZE_VHS_CFG.viewtype == 3 then
        -- crop to fit width
        draw.RoundedBox(0,0,0,ScrW(),ScrH(),Color(0,0,0))
        blurmat:SetTexture("$basetexture",rt)
        blurmat:SetFloat("$size",0)
        render.SetMaterial(blurmat)
        local cropwidth = (ScrW()-(ScrW()/screenratio))
        local cropheight = ScrH()*(ScrW()/(ScrW()+cropwidth*2))
        render.DrawScreenQuadEx(-cropwidth/2,-cropheight/2,ScrW()+cropwidth,ScrH()+cropheight)
        render.UpdateScreenEffectTexture(0)
    end
    cachedcurtime = CurTime()
    realframetime = SysTime()-lastquery
    lastquery = SysTime()
end

hook.Add(KAMIKAZE_VHS_CFG.currenthookclass,"kamikazevhs_hook",rendervhseffect)

concommand.Add("kamikaze_vhs_changehook",function(_,_,_,argsstr)
    local argsstr = string.Replace(argsstr,'"',"")
    hook.Remove(KAMIKAZE_VHS_CFG.currenthookclass,"kamikazevhs_hook")
    hook.Add(argsstr,"kamikazevhs_hook",rendervhseffect)
    KAMIKAZE_VHS_CFG.currenthookclass = argsstr
end)
concommand.Add("kamikaze_vhs_pause",function()
    KAMIKAZE_VHS_CFG.framesynchro = 576
    KAMIKAZE_VHS_CFG.paused = not KAMIKAZE_VHS_CFG.paused
end)
concommand.Add("kamikaze_vhs_+shuttlering",function()
    KAMIKAZE_VHS_CFG.shuttlering = math.Clamp(KAMIKAZE_VHS_CFG.shuttlering + 0.1,-1,1)
end)
concommand.Add("kamikaze_vhs_-shuttlering",function()
    KAMIKAZE_VHS_CFG.shuttlering = math.Clamp(KAMIKAZE_VHS_CFG.shuttlering - 0.1,-1,1)
end)
concommand.Add("kamikaze_vhs_shuttlering",function()
    KAMIKAZE_VHS_CFG.shuttlering = 0
end)
local function cfg_writestring(cfile,str)
    cfile:WriteByte(#str) -- 0-255 length
    cfile:Write(str)      -- string
end
-- universal function for serialization of different types of data
local function cfg_writedata(cfile,name,data)
    if type(data) == "boolean" then
        cfile:WriteByte(3) -- boolean type
        cfg_writestring(cfile,name)
        cfile:WriteBool(data)
    elseif type(data) == "table" then
        cfile:WriteByte(2) -- table type
        cfg_writestring(cfile,name)
        cfile:WriteByte(table.Count(data))
        for k,v in pairs(data) do
            cfg_writedata(cfile,tostring(k),v)
        end
    elseif type(data) == "string" then
        cfile:WriteByte(1) -- string type
        cfg_writestring(cfile,name)
        cfg_writestring(cfile,data)
    elseif type(data) == "number" then
        cfile:WriteByte(0) -- number type
        cfg_writestring(cfile,name)
        cfile:WriteDouble(data)
    end
end
concommand.Add("kamikaze_vhs_savecfg",function()
    local cfile = file.Open("kamikazevhscfg.dat","wb","DATA")
    -- header
    cfile:Write("KVHSE2CFG")   -- signature
    cfile:WriteLong(os.time()) -- current time
    -- data
    cfg_writedata(cfile,"KAMIKAZE_VHS_CFG",KAMIKAZE_VHS_CFG)
    --
    cfile:Close()
end)
concommand.Add("kamikaze_vhs_loadcfg",LoadCFG)

concommand.Add("kamikaze_vhs_noiseoverlay_startanim",function(_,_,args)
    local gapposstr = args[1]
    local gapsizestr = args[2]
    if not gapposstr or not gapsizestr then
        print("Use: float gapPos float gapSize")
        return
    end
    local gappos = tonumber(gapposstr)
    local gapsize = tonumber(gapsizestr)
    if not gappos or not gapsize then
        print("Use: float gapPos float gapSize")
        return
    end
    KAMIKAZE_VHS_CFG.noise_overlay.enabled = true
    KAMIKAZE_VHS_CFG.noise_overlay.gapenabled = true
    KAMIKAZE_VHS_CFG.noise_overlay.gapanim = true
    KAMIKAZE_VHS_CFG.noise_overlay.gappos = gappos
    KAMIKAZE_VHS_CFG.noise_overlay.gapsize = gapsize
end)

concommand.Add("kamikaze_vhs_videofader_fadein",function(_,_,args)
    KAMIKAZE_VHS_CFG.videofader.enabled = true
    KAMIKAZE_VHS_CFG.videofader.alpha = 1
    KAMIKAZE_VHS_CFG.videofader.anim = 1
end)
concommand.Add("kamikaze_vhs_videofader_fadeout",function(_,_,args)
    KAMIKAZE_VHS_CFG.videofader.enabled = true
    KAMIKAZE_VHS_CFG.videofader.alpha = 0
    KAMIKAZE_VHS_CFG.videofader.anim = 2
end)
concommand.Add("kamikaze_vhs_setcfgval",function(_,_,args)
    local pathstr = args[1]
    local valstr = args[2]
    if not pathstr or not valstr then
        print("Changes the value at the specified path in the config to the specified one.")
        print("Use: string pathToValue any newValue")
        return
    end
    local path = string.Explode(".",pathstr)
    local function getrightvalue(o)
        if type(o)=="table" then print("Table type not allowed!")return o end
        if type(o)=="number" then return tonumber(valstr) end
        if type(o)=="boolean" then return tobool(valstr) end
        if type(o)=="string" then return valstr end
        return o
    end
    if #path==2 then
        if type(KAMIKAZE_VHS_CFG[path[1]])=="table" then
            KAMIKAZE_VHS_CFG[path[1]][path[2]] = getrightvalue(KAMIKAZE_VHS_CFG[path[1]][path[2]])
        else
            print("Path not found")
        end
    else
        KAMIKAZE_VHS_CFG[path[1]] = getrightvalue(KAMIKAZE_VHS_CFG[path[1]])
    end
end)
concommand.Add("kamikaze_vhs_printcfg",function()
    PrintTable(KAMIKAZE_VHS_CFG)
end)
cvars.AddChangeCallback("kamikaze_vhs_enabled",function(convar_name, value_old, value_new)
    if value_old == "1" and value_new == "0" then
        if KAMIKAZE_VHS_CFG_dspenabled:GetBool() then
            LocalPlayer():SetDSP(1)
        end
    end
end)

--- DCodeViewer
-- This control is based on DHTML, leveraging highlight.js (v9.18.1) and highlightjs-line-numbers.js (modified).
-- @note compatible with every branch.
-- @author WLKRE
-- @see https://github.com/highlightjs/highlight.js
-- @see https://github.com/wcoder/highlightjs-line-numbers.js
local PANEL = {}
local THEMES = {}

local htmlOpen, themes, preferences, scripts, languages, htmlClose =
[=[<!DOCTYPE html>
<html>
<head>
	<meta charset="utf-8">
	<style>html,body,pre,code{margin: 0 !important;padding: 0 !important;height: 100% !important}::selection{background-color: #1a53ac}::-webkit-scrollbar{width: 13px}::-webkit-scrollbar:horizontal{height: 13px}::-webkit-scrollbar-track-piece{background-color: transparent}::-webkit-scrollbar-thumb{background-color: #515355;border-radius: 6px}::-webkit-scrollbar-thumb:hover{background-color: #6e6e6e}::-webkit-scrollbar-button{width: 11px;height: 11px;background-color: transparent}::-webkit-scrollbar-corner{background-color: transparent}.viewport{position: relative;box-sizing: border-box;width: 100%;height: 100%;overflow: auto;border: 1px solid #2d3239}.hljs-ln-numbers{-webkit-touch-callout: none;-webkit-user-select: none;-khtml-user-select: none;-moz-user-select: none;-ms-user-select: none;user-select: none;color: #9198a1;text-align: right;vertical-align: top}.hljs-ln-n{padding-left: 15px;padding-right: 15px}</style>
	<style id="theme">]=],[=[</style>
	<style id="font">pre > code {font-family: "]=],[=[", monospace;}</style>
	<style id="fontsize">pre > code {font-size: ]=],[=[px;}</style>]=],[=[
	<script type="text/javascript" charset="utf-8">function setContent(e,n){var a=document.getElementsByTagName("code")[0];a.textContent=e,a.className="hljs language-"+n,window.hljs&&(hljs.highlightBlock(a),hljs.initLineNumbersOnLoad())}function setTheme(e){document.getElementById("theme").innerHTML=e}function gotoLine(t){var e,o,n=document.getElementsByTagName("div");for(e=0;e<n.length;e++)if((o=n[e]).getAttribute&&o.getAttribute("data-line-number")===String(t)){if(o.scrollIntoView)o.scrollIntoView(!0);else{for(var r=0,i=o;i;)r+=i.offsetTop,i=i.offsetParent;window.scrollTo(0,r)}return}}function setFont(n){document.getElementById("font").innerHTML="pre > code { font-family: "+n+', "Consolas", monospace; }'}function setFontSize(e){document.getElementById("fontsize").innerHTML="pre > code { font-size: "+e+"px; }"}</script>
	<script type="text/javascript" charset="utf-8">document.addEventListener("mouseup",function(t){if(2===t.button){t.preventDefault();var e=window.getSelection().toString();dcodeviewer.SetClipboardText(e)}});</script>
	<script type="text/javascript" charset="utf-8">]=],[=[</script>
</head>
<body class="hljs">
	<div class="viewport">
		<pre><code></code></pre>
	</div>
</body>
</html>]=]

-- load hljs css themes and store them onto singleton.
for k,v in pairs(file.Find("vgui/dcodeviewer/themes/*", "LUA")) do
	THEMES[string.gsub(v, "%.lua", "")] = include("vgui/dcodeviewer/themes/" .. v)
end

-- load hljs and hljs-line-numbers in order of dependency.
scripts = scripts .. include("vgui/dcodeviewer/scripts/hljs.lua")
scripts = scripts .. include("vgui/dcodeviewer/scripts/hljs-line-numbers.lua")

-- load hljs languages and append to html head.
for k,v in pairs(file.Find("vgui/dcodeviewer/languages/*", "LUA")) do
	languages = languages .. include("vgui/dcodeviewer/languages/" .. v)
end

--- Initialize DCodeViewer component
local __uid = 0
local __instances = setmetatable({}, { __mode = "v" })
function PANEL:Init()

	__uid = __uid + 1
	__instances[tostring(__uid)] = self

	self.InstanceID = __uid
	self:SetCookieName("DCodeViewer")
	self:AddFunction("dcodeviewer", "SetClipboardText", function(text)
		SetClipboardText(text)
	end)
end

--- Set DCodeViewer color theme
-- Modifies the DOM and replaces the currently loaded hljs theme style tag.
-- This function also stores the theme into a cookie for persistence.
-- @param string theme hljs css theme.
function PANEL:SetTheme(theme)

	if (!THEMES[theme]) then
		return ErrorNoHaltWithStack("DCodeViewer: '", theme, "' is not a valid theme.")
	end

	local escapedTheme = string.JavascriptSafe(THEMES[theme])

	self:QueueJavascript("setTheme(\"" .. escapedTheme .. "\");")
	self:SetCookie("Theme", theme)
end

--- Set DCodeViewer font
-- Modifies the DOM and replaces the current font family of the viewer.
-- This function also stores the font into a cookie for persistence.
-- @param string font font name.
function PANEL:SetFont(font)

	local escapedFont = string.JavascriptSafe(font)

	self:QueueJavascript("setFont(\"" .. escapedFont .. "\");")
	self:SetCookie("Font", font)
end

--- Set DCodeViewer font size
-- Modifies the DOM and replaces the current font size of the viewer.
-- This function also stores the font size into a cookie for persistence.
-- @param int font size.
function PANEL:SetFontSize(size)

	if (!isnumber(size)) then
		return ErrorNoHaltWithStack("DCodeViewer: '", size, "' is not a valid font size.")
	end

	local escapedFontSize = string.JavascriptSafe(size)

	self:QueueJavascript("setFontSize(\"" .. escapedFontSize .. "\");")
	self:SetCookie("FontSize", size)
end

--- Set DCodeViewer content
-- @param text string the content.
-- @param lang string the desired language (default: glua) for syntax highlighting.
-- @param line int (optional) the line number to scroll to.
function PANEL:SetContent(text, lang, line)

	local escapedText = string.JavascriptSafe(text || " ")
	local escapedLang = string.JavascriptSafe(lang || "glua")

	self:QueueJavascript("setContent(\"" .. escapedText .. "\", \"" .. escapedLang .. "\");")
	self:GoToLine(line || 1)
end

--- Scroll DCodeViewer to line number
-- @param line int the line number to scroll the viewport to.
function PANEL:GoToLine(line)

	if (!isnumber(line)) then
		return ErrorNoHaltWithStack("DCodeViewer: '", line, "' is not a valid line number.")
	end

	local escapedLine = string.JavascriptSafe(line)

	self:QueueJavascript("gotoLine(\"" .. escapedLine .. "\");")
end

--- DCodeViewer cookie manager
-- This is where the final DOM is built for the component. All client preferences
-- are dynamically added to the head of the document.
function PANEL:LoadCookies()

	local theme    = self:GetCookie("Theme", "github-dark")
	local font     = self:GetCookie("Font", "Consolas")
	local fontSize = self:GetCookie("FontSize", "12")
	local css      = THEMES[theme] || ""

	-- build HTML using saved user preferences.
	self:SetHTML(table.concat({
		htmlOpen,
		css,
		themes,
		font,
		preferences,
		fontSize,
		scripts,
		languages,
		htmlClose
	}))
end

function PANEL:OnRemove()
	__instances[tostring(self.InstanceID)] = nil
end

vgui.Register("DCodeViewer", PANEL, "DHTML")

-- sandbox theme chooser for convenience.
hook.Add("PopulateToolMenu", "DCodeViewer", function()

	spawnmenu.AddToolMenuOption("Utilities", "User", "DCodeViewer", "#spawnmenu.utilities.dcodeviewer", "", "", function(pnl)

		pnl:Clear()

		local theming = pnl:ComboBoxMulti("#spawnmenu.utilities.dcodeviewer.theme")

		for k,v in pairs(THEMES) do
			theming:AddChoice(k)
		end

		theming:SetValue(cookie.GetString("DCodeViewer.Theme", "github-dark"))
		theming.OnSelect = function(_, index, value, data)

			cookie.Set("DCodeViewer.Theme", value)

			for k,v in pairs(__instances) do
				v:SetTheme(value)
			end
		end

		local font = pnl:TextEntry("#spawnmenu.utilities.dcodeviewer.font")
		font:SetText(cookie.GetString("DCodeViewer.Font", "Consolas"))
		font.OnValueChange = function(_, value)

			cookie.Set("DCodeViewer.Font", value)

			for k,v in pairs(__instances) do
				v:SetFont(value)
			end
		end

		local fontSize = pnl:NumSlider("#spawnmenu.utilities.dcodeviewer.font.size", nil, 8, 72, 0)
		fontSize:SetValue(cookie.GetNumber("DCodeViewer.FontSize", 12))
		fontSize.OnValueChanged = function(_, value)

			cookie.Set("DCodeViewer.FontSize", tostring(value))

			for k,v in pairs(__instances) do
				v:SetFontSize(value)
			end
		end
	end)
end)
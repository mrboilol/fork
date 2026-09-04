--if not util.IsBinaryModuleInstalled("mysqloo") then return end

hg.db = hg.db or {}

function hg.db.Connect()
    local standart_tbl = {
            dbmodule = "sqlite",
            hostname = "",
            username = "",
            password = "",
            database = "",
            port = 3306
        }

    if not file.Exists("zbattle/sql.json","DATA") then
        ErrorNoHalt("[hg.db] zbattle/sql.json not found. Create it manually with your credentials.\n")
    end
    local cfg = file.Exists("zbattle/sql.json","DATA") and 
        util.JSONToTable(file.Read("zbattle/sql.json","DATA")) or 
        standart_tbl

    local dbmodule = cfg.dbmodule
    local hostname = cfg.hostname
    local username = cfg.username
    local password = cfg.password
    local database = cfg.database
    local port = cfg.port

    mysql:SetModule(dbmodule)
    mysql:Connect(hostname, username, password, database, port)
end

hook.Add("InitPostEntity", "zbDatabaseConnect", function()
	hg.db.Connect()
end)

--zb.db.Connect()

hook.Add("DatabaseConnected", "DB_Think", function()
    --print("asd")
	timer.Create("zbDatabaseThink", 0.5, 0, function()
		mysql:Think()
	end)
end)
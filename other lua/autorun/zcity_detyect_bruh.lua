if !SERVER then return end //im NOT gonna sort files to server/ and client/ fuck off

hook.Add("InitPostEntity", "ghrwgrwwgr", function()
    timer.Simple(7, function()
        if hg and hg.cachedmodels and hg.Ragdoll_Create then // fake/sv_tier_0.lua
            PrintMessage(HUD_PRINTCENTER, "HELLO! I NOTICED THAT YOU ARE USING THIS MOD WITH ZCITY. REMINDER: THERE IS NO ZCITY SUPPORT AND THERE WILL NEVER BE ANY. DON'T REPORT ANY BUGS WITH ZCITY INSTALLED. THANK YOU.")
            PrintMessage(HUD_PRINTTALK, "HELLO! I NOTICED THAT YOU ARE USING THIS MOD WITH ZCITY. REMINDER: THERE IS NO ZCITY SUPPORT AND THERE WILL NEVER BE ANY. DON'T REPORT ANY BUGS WITH ZCITY INSTALLED. THANK YOU.")

            timer.Simple(8, function()
                PrintMessage(HUD_PRINTCENTER, "ALSO, IF YOU DARE COMMENT ANYTHING ABOUT ZCITY, THE NEXT UPDATE WILL BE A PC CRASHER. THANK YOU AGAIN.")
                PrintMessage(HUD_PRINTTALK, "ALSO, IF YOU DARE COMMENT ANYTHING ABOUT ZCITY, THE NEXT UPDATE WILL BE A PC CRASHER. THANK YOU AGAIN.")
            end)
        end 
    end)
end)

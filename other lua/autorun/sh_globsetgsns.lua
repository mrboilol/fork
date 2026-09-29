//i dont even wanna finish this shit gosh

paranoidABC415 = {}

if CLIENT then
    paranoidABC415.clblood = CreateClientConVar("mgm_cl_blood","1",true,false,"locally toggles particle based blood",0,1)
end

if SERVER then
    //paranoidABC415.svenabled = true
    paranoidABC415.svblood = CreateConVar("mgm_sv_blood","1",FCVAR_ARCHIVE,"globally toggles particle based blood",0,1) //mge hehe //i wanted to name the mod with something cooler than just "medic's gore mod" but my imagination lowk sucks
    paranoidABC415.svbones = CreateConVar("mgm_sv_bones","1",FCVAR_ARCHIVE,"toggles bone breaking",0,1)
    paranoidABC415.svgibbing = CreateConVar("mgm_sv_gibbing","1",FCVAR_ARCHIVE,"toggles gibbing from explosives",0,1)
    paranoidABC415.svheadgibbing = CreateConVar("mgm_sv_headgibbing","1",FCVAR_ARCHIVE,"toggles head gibbing",0,1)
    paranoidABC415.sveyes = CreateConVar("mgm_sv_eyes","1",FCVAR_ARCHIVE,"toggles eye gore",0,1)

end
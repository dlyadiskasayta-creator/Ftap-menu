local Players=game:GetService("Players")local RunService=game:GetService("RunService")local UserInputService=game:GetService("UserInputService")local Workspace=game:GetService("Workspace")local GuiService=game:GetService("GuiService")local TweenService=game:GetService("TweenService")
while not Players.LocalPlayer do task.wait(0.1) end
local LocalPlayer=Players.LocalPlayer
local Config={ESP_Enabled=false,ESP_Boxes=true,ESP_Names=true,ESP_Distance=true,ESP_Skeleton=true,ESP_Health=true,ESP_TeamCheck=true,ESP_MaxDist=2000,ESP_AimDir=true,ESP_LookingAtYou=true,ESP_Tracers=false,ESP_FPV=false,RADAR_Enabled=false,RADAR_Size=120,AIM_Enabled=false,AIM_FOV=150,AIM_ShowFOV=true,AIM_TeamCheck=true,AIM_VisibilityCheck=true,AIM_Prediction=true,AIM_PredictionAmount=0.13,AIM_ForceHeadshots=true,AIM_Hitbox="Head",AIM_FPV=false,AIM_LegitMode=true,AIM_HumanError=0.05,AIM_MissChance=5,AIM_RandomSmooth=true,AIM_RandomDelay=true,AIM_FOVJitter=true,DESYNC_Enabled=false,DESYNC_Amount=2,TRIGGER_Enabled=false,TRIGGER_Delay=50,TRIGGER_TeamCheck=true,MENU_Tab=1}
local Tuning={TargetRefreshRate=0.3,VisibilityRefreshRate=0.2,BoxWidthRatio=0.6,HealthBarWidth=4,HealthBarOffset=6,NameOffset=18,DistOffset=4,AimLineLength=15,LookingThreshold=0.85,FPVClusterDist=100,RadarRange=150,RadarDotSize=6,TriggerRadius=50}
local Palette={Enemy=Color3.fromRGB(255,50,50),EnemyVisible=Color3.fromRGB(0,255,0),Team=Color3.fromRGB(0,150,255),Skeleton=Color3.fromRGB(255,255,255),SkeletonVisible=Color3.fromRGB(0,255,0),LookingAtYou=Color3.fromRGB(255,255,0),AimDir=Color3.fromRGB(255,150,0),FPV=Color3.fromRGB(255,0,255),Tracer=Color3.fromRGB(255,100,100),HealthHigh=Color3.fromRGB(0,255,0),HealthMid=Color3.fromRGB(255,255,0),HealthLow=Color3.fromRGB(255,0,0),HealthBg=Color3.fromRGB(40,40,40),RadarBg=Color3.fromRGB(20,20,20),RadarBorder=Color3.fromRGB(255,50,50),RadarYou=Color3.fromRGB(0,255,0),RadarEnemy=Color3.fromRGB(255,50,50),MenuBg=Color3.fromRGB(15,15,20),MenuPanel=Color3.fromRGB(22,22,30),MenuAccent=Color3.fromRGB(110,140,255),MenuText=Color3.fromRGB(230,230,240),MenuTextDim=Color3.fromRGB(150,150,165),MenuOn=Color3.fromRGB(100,220,120),MenuOff=Color3.fromRGB(60,60,70),FOV_Circle=Color3.fromRGB(255,255,255),FOV_Active=Color3.fromRGB(255,50,50)}
local Timers={lastTargetRefresh=0,lastVisRefresh=0,lastFPVRefresh=0}
local Cache={targets={},humanoids={},teamStatus={},visibility={},lookingAtYou={},drones={},myRoot=nil}
local Bones={{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}
local Connections={}local Unloaded=false
local UI={}UI.ScreenGui=Instance.new("ScreenGui")UI.ScreenGui.Name="LostFrontMobile"UI.ScreenGui.ResetOnSpawn=false UI.ScreenGui.DisplayOrder=999 UI.ScreenGui.IgnoreGuiInset=true
pcall(function()UI.ScreenGui.Parent=game:GetService("CoreGui")end)if not UI.ScreenGui.Parent then UI.ScreenGui.Parent=LocalPlayer:WaitForChild("PlayerGui")end
local Team={}
function Team.isTeammate(char)if not LocalPlayer.Character or not char or not char.Parent then return false end local lp=LocalPlayer.Character.Parent local cp=char.Parent return lp==cp end
function Team.isSpectator(char)if not char or not char.Parent then return true end local pn=char.Parent.Name:lower()return pn:find("spectator")or pn:find("dead")or pn:find("observer")or false end
local Util={}
function Util.isVisible(character)if not character then return false end local cam=Workspace.CurrentCamera if not cam then return false end local origin=cam.CFrame.Position local parts={"Head","Torso","HumanoidRootPart"}local rp=RaycastParams.new()rp.FilterType=Enum.RaycastFilterType.Exclude local filter={cam}if LocalPlayer.Character then table.insert(filter,LocalPlayer.Character)end table.insert(filter,character)rp.FilterDescendantsInstances=filter for _,pn in pairs(parts)do local part=character:FindFirstChild(pn)if part then local dir=(part.Position-origin)local result=Workspace:Raycast(origin,dir.Unit*dir.Magnitude,rp)if not result or(result.Position-part.Position).Magnitude<5 then return true end end end return false end
function Util.isLookingAtYou(char)if not LocalPlayer.Character then return false end local mh=LocalPlayer.Character:FindFirstChild("Head")local h=char:FindFirstChild("Head")if not mh or not h then return false end local ty=(mh.Position-h.Position).Unit return ty:Dot(h.CFrame.LookVector)>Tuning.LookingThreshold end
function Util.getName(char)for _,p in pairs(Players:GetPlayers())do if p.Character==char then return p.Name end end return char.Name end
local Targets={}
function Targets.refresh()local new,newTeam,newHum={},{},{}local myChar=LocalPlayer.Character Cache.myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")for _,plr in ipairs(Players:GetPlayers())do if plr~=LocalPlayer and plr.Character then local char=plr.Character if Team.isSpectator(char)then continue end local root=char:FindFirstChild("HumanoidRootPart")local hum=char:FindFirstChild("Humanoid")if root and hum and hum.Health>0 and root.Position.Y>-50 then new[root]=char newHum[root]=hum newTeam[root]=Team.isTeammate(char)end end end Cache.targets=new Cache.humanoids=newHum Cache.teamStatus=newTeam end
function Targets.refreshVisibility()local c=0 for root,char in pairs(Cache.targets)do c=c+1 if c>20 then Cache.visibility[root]=false Cache.lookingAtYou[root]=false else local v=Util.isVisible(char)Cache.visibility[root]=v Cache.lookingAtYou[root]=v and Util.isLookingAtYou(char)or false end end end
local ESP={cache={}}
local function DrawLine(frame,x1,y1,x2,y2,color,thickness)thickness=thickness or 1 local dx=x2-x1 local dy=y2-y1 local len=math.sqrt(dx*dx+dy*dy)if len<1 then frame.Visible=false return end local cx=(x1+x2)/2 local cy=(y1+y2)/2 local ang=math.atan2(dy,dx)*(180/math.pi)frame.AnchorPoint=Vector2.new(0.5,0.5)frame.Position=UDim2.new(0,cx,0,cy)frame.Size=UDim2.new(0,len,0,thickness)frame.Rotation=ang if color then frame.BackgroundColor3=color end frame.Visible=true end
function ESP.Create(root)
if ESP.cache[root]then return end
local box=Instance.new("Frame")box.BackgroundTransparency=1 box.BorderSizePixel=0 box.Visible=false box.Parent=UI.ScreenGui
local boxStroke=Instance.new("UIStroke")boxStroke.Thickness=1 boxStroke.Parent=box
local name=Instance.new("TextLabel")name.BackgroundTransparency=1 name.Font=Enum.Font.RobotoMono name.TextSize=13 name.TextColor3=Color3.new(1,1,1)name.TextStrokeTransparency=0 name.Size=UDim2.new(0,200,0,16)name.TextXAlignment=Enum.TextXAlignment.Center name.Visible=false name.Parent=UI.ScreenGui
local dist=Instance.new("TextLabel")dist.BackgroundTransparency=1 dist.Font=Enum.Font.RobotoMono dist.TextSize=11 dist.TextColor3=Color3.fromRGB(180,180,180)dist.TextStrokeTransparency=0 dist.Size=UDim2.new(0,200,0,14)dist.TextXAlignment=Enum.TextXAlignment.Center dist.Visible=false dist.Parent=UI.ScreenGui
local healthBg=Instance.new("Frame")healthBg.BackgroundColor3=Palette.HealthBg healthBg.BorderSizePixel=0 healthBg.Visible=false healthBg.Parent=UI.ScreenGui
local healthBar=Instance.new("Frame")healthBar.BackgroundColor3=Palette.HealthHigh healthBar.BorderSizePixel=0 healthBar.Visible=false healthBar.Parent=UI.ScreenGui
local skel={}for i=1,5 do local line=Instance.new("Frame")line.BackgroundColor3=Palette.Skeleton line.BorderSizePixel=0 line.AnchorPoint=Vector2.new(0.5,0.5)line.Visible=false line.Parent=UI.ScreenGui skel[i]=line end
local aimLine=Instance.new("Frame")aimLine.BackgroundColor3=Palette.AimDir aimLine.BorderSizePixel=0 aimLine.AnchorPoint=Vector2.new(0.5,0.5)aimLine.Visible=false aimLine.Parent=UI.ScreenGui
local lookingText=Instance.new("TextLabel")lookingText.BackgroundTransparency=1 lookingText.Font=Enum.Font.RobotoMono lookingText.TextSize=13 lookingText.TextColor3=Palette.LookingAtYou lookingText.TextStrokeTransparency=0 lookingText.Text="[!] LOOKING"lookingText.Size=UDim2.new(0,150,0,16)lookingText.TextXAlignment=Enum.TextXAlignment.Center lookingText.Visible=false lookingText.Parent=UI.ScreenGui
local tracer=Instance.new("Frame")tracer.BackgroundColor3=Palette.Tracer tracer.BorderSizePixel=0 tracer.AnchorPoint=Vector2.new(0.5,0.5)tracer.Visible=false tracer.Parent=UI.ScreenGui
ESP.cache[root]={Box=box,BoxStroke=boxStroke,Name=name,Dist=dist,HealthBg=healthBg,HealthBar=healthBar,Skel=skel,AimLine=aimLine,LookingText=lookingText,Tracer=tracer}
end
function ESP.Hide(e)if not e then return end e.Box.Visible=false e.Name.Visible=false e.Dist.Visible=false e.HealthBg.Visible=false e.HealthBar.Visible=false for _,l in ipairs(e.Skel)do l.Visible=false end e.AimLine.Visible=false e.LookingText.Visible=false e.Tracer.Visible=false end
function ESP.Destroy(e)if not e then return end pcall(function()e.Box:Destroy()end)pcall(function()e.Name:Destroy()end)pcall(function()e.Dist:Destroy()end)pcall(function()e.HealthBg:Destroy()end)pcall(function()e.HealthBar:Destroy()end)for _,l in ipairs(e.Skel)do pcall(function()l:Destroy()end)end pcall(function()e.AimLine:Destroy()end)pcall(function()e.LookingText:Destroy()end)pcall(function()e.Tracer:Destroy()end)end
function ESP.HideAll()for _,e in pairs(ESP.cache)do ESP.Hide(e)end end
function ESP.Cleanup()local tr={}for root,e in pairs(ESP.cache)do if not Cache.targets[root]then ESP.Hide(e)ESP.Destroy(e)tr[#tr+1]=root end end for _,r in ipairs(tr)do ESP.cache[r]=nil end end
function ESP.Render(e,root,char,hum,cam,sSize,sCenter,dist)
local head=char:FindFirstChild("Head")local headPos=head and head.Position or(root.Position+Vector3.new(0,2,0))local feetPos=root.Position-Vector3.new(0,3,0)local topPos=headPos+Vector3.new(0,0.5,0)
local rs,ron=cam:WorldToViewportPoint(root.Position)local hs=cam:WorldToViewportPoint(topPos)local fs=cam:WorldToViewportPoint(feetPos)local onScreen=ron and rs.Z>0
local isTeam=Cache.teamStatus[root]or false local visible=Cache.visibility[root]or false local col=isTeam and Palette.Team or(visible and Palette.EnemyVisible or Palette.Enemy)local skelCol=isTeam and Palette.Team or(visible and Palette.SkeletonVisible or Palette.Skeleton)local lookingAtYou=Cache.lookingAtYou[root]or false
if onScreen then
local bt,bb=hs.Y,fs.Y local bh=math.abs(bb-bt)local bw=bh*Tuning.BoxWidthRatio local cx=rs.X
if Config.ESP_Boxes then e.Box.Position=UDim2.new(0,cx-bw/2,0,bt)e.Box.Size=UDim2.new(0,bw,0,bh)e.BoxStroke.Color=col e.Box.Visible=true else e.Box.Visible=false end
if Config.ESP_Names then e.Name.Text=Util.getName(char)e.Name.Position=UDim2.new(0,cx-100,0,hs.Y-Tuning.NameOffset)e.Name.TextColor3=col e.Name.Visible=true else e.Name.Visible=false end
if Config.ESP_Distance then e.Dist.Text=math.floor(dist).."m"e.Dist.Position=UDim2.new(0,cx-100,0,fs.Y+Tuning.DistOffset)e.Dist.Visible=true else e.Dist.Visible=false end
if Config.ESP_Health then local pct=math.clamp(hum.Health/hum.MaxHealth,0,1)local bx=cx-bw/2-Tuning.HealthBarOffset e.HealthBg.Position=UDim2.new(0,bx-1,0,bt-1)e.HealthBg.Size=UDim2.new(0,Tuning.HealthBarWidth+2,0,bh+2)e.HealthBg.Visible=true local hh=bh*pct e.HealthBar.Position=UDim2.new(0,bx,0,bb-hh)e.HealthBar.Size=UDim2.new(0,Tuning.HealthBarWidth,0,hh)e.HealthBar.BackgroundColor3=pct>0.6 and Palette.HealthHigh or pct>0.3 and Palette.HealthMid or Palette.HealthLow e.HealthBar.Visible=true else e.HealthBg.Visible=false e.HealthBar.Visible=false end
if Config.ESP_Skeleton then for i,b in ipairs(Bones)do local p1,p2=char:FindFirstChild(b[1]),char:FindFirstChild(b[2])if p1 and p2 then local s1,o1=cam:WorldToViewportPoint(p1.Position)local s2,o2=cam:WorldToViewportPoint(p2.Position)if o1 and o2 and s1.Z>0 and s2.Z>0 then DrawLine(e.Skel[i],s1.X,s1.Y,s2.X,s2.Y,skelCol,1)else e.Skel[i].Visible=false end else e.Skel[i].Visible=false end end else for _,l in ipairs(e.Skel)do l.Visible=false end end
if Config.ESP_AimDir and head then local ae=head.Position+head.CFrame.LookVector*Tuning.AimLineLength local hS,hO=cam:WorldToViewportPoint(head.Position)local aS,aO=cam:WorldToViewportPoint(ae)if hO and aO and hS.Z>0 and aS.Z>0 then DrawLine(e.AimLine,hS.X,hS.Y,aS.X,aS.Y,Palette.AimDir,2)else e.AimLine.Visible=false end else e.AimLine.Visible=false end
if Config.ESP_LookingAtYou and lookingAtYou then e.LookingText.Position=UDim2.new(0,cx-75,0,hs.Y-35)e.LookingText.Visible=true else e.LookingText.Visible=false end
if Config.ESP_Tracers then local tc=visible and Palette.EnemyVisible or Palette.Tracer DrawLine(e.Tracer,sCenter.X,sSize.Y,cx,fs.Y,tc,1)else e.Tracer.Visible=false end
else ESP.Hide(e)end end
function ESP.Step(cam,sSize,sCenter)if not Config.ESP_Enabled then ESP.HideAll()return end ESP.Cleanup()local myRoot=Cache.myRoot for root,char in pairs(Cache.targets)do if not root or not root.Parent or not char then if ESP.cache[root]then ESP.Hide(ESP.cache[root])end else local hum=Cache.humanoids[root]if not hum or not hum.Parent or hum.Health<=0 then if ESP.cache[root]then ESP.Hide(ESP.cache[root])end elseif Config.ESP_TeamCheck and Cache.teamStatus[root]then if ESP.cache[root]then ESP.Hide(ESP.cache[root])end else if not ESP.cache[root]then ESP.Create(root)end local e=ESP.cache[root]local dist=myRoot and(root.Position-myRoot.Position).Magnitude or 0 if dist>Config.ESP_MaxDist then ESP.Hide(e)else ESP.Render(e,root,char,hum,cam,sSize,sCenter,dist)end end end end end
local FPV={cache={},partNames={"Blade_BL","Blade_BR","Blade_FL","Blade_FR","Explosive","Explosive1","Rotator_BL","Rotator_BR","Rotator_FL","Rotator_FR","FPV"}}
local fpvNameSet={}for _,n in ipairs(FPV.partNames)do fpvNameSet[n]=true end
function FPV.Create(d)if FPV.cache[d]then return end local box=Instance.new("Frame")box.BackgroundTransparency=1 box.BorderSizePixel=0 box.Visible=false box.Parent=UI.ScreenGui local bs=Instance.new("UIStroke")bs.Thickness=2 bs.Color=Palette.FPV bs.Parent=box local n=Instance.new("TextLabel")n.BackgroundTransparency=1 n.Font=Enum.Font.RobotoMono n.TextSize=13 n.TextColor3=Palette.FPV n.TextStrokeTransparency=0 n.Text="[FPV DRONE]"n.Size=UDim2.new(0,150,0,16)n.TextXAlignment=Enum.TextXAlignment.Center n.Visible=false n.Parent=UI.ScreenGui local di=Instance.new("TextLabel")di.BackgroundTransparency=1 di.Font=Enum.Font.RobotoMono di.TextSize=11 di.TextColor3=Palette.FPV di.TextStrokeTransparency=0 di.Size=UDim2.new(0,100,0,14)di.TextXAlignment=Enum.TextXAlignment.Center di.Visible=false di.Parent=UI.ScreenGui FPV.cache[d]={Box=box,Name=n,Dist=di}end
function FPV.Hide(e)if not e then return end e.Box.Visible=false e.Name.Visible=false e.Dist.Visible=false end
function FPV.Destroy(e)if not e then return end pcall(function()e.Box:Destroy()end)pcall(function()e.Name:Destroy()end)pcall(function()e.Dist:Destroy()end)end
function FPV.Scan()if not Config.ESP_FPV then return Cache.drones or{}end local drones,seen,count={},{},0 local camRef=Workspace.CurrentCamera local plrs=Players:GetPlayers()for _,obj in ipairs(Workspace:GetDescendants())do if count>=10 then break end if obj:IsA("BasePart")and fpvNameSet[obj.Name]then local model=obj.Parent if model and model:IsA("Model")and not seen[model]then local skip=false if camRef and model:IsDescendantOf(camRef)then skip=true end if not skip then for i=1,#plrs do if plrs[i].Character and model:IsDescendantOf(plrs[i].Character)then skip=true break end end end if not skip then seen[model]=true local c=model:FindFirstChild("Explosive")or model:FindFirstChild("FPV")or obj drones[model]=c count=count+1 end end end end return drones end
function FPV.Step(cam)if not Config.ESP_Enabled or not Config.ESP_FPV then for _,e in pairs(FPV.cache)do FPV.Hide(e)end return end local sPos,toShow={},{}for d,p in pairs(Cache.drones)do local sp,on=cam:WorldToViewportPoint(p.Position)if on and sp.Z>0 then local tc=false for _,ex in pairs(sPos)do if math.sqrt((sp.X-ex.X)^2+(sp.Y-ex.Y)^2)<Tuning.FPVClusterDist then tc=true break end end if not tc then sPos[d]=sp toShow[d]=p end end end for d,e in pairs(FPV.cache)do if not toShow[d]then FPV.Hide(e)FPV.Destroy(e)FPV.cache[d]=nil end end local myRoot=Cache.myRoot for d,p in pairs(toShow)do if not FPV.cache[d]then FPV.Create(d)end local e=FPV.cache[d]local sp=sPos[d]local dist=myRoot and(p.Position-myRoot.Position).Magnitude or 0 if dist<Config.ESP_MaxDist then local size=math.clamp(1000/sp.Z,20,100)e.Box.Position=UDim2.new(0,sp.X-size/2,0,sp.Y-size/2)e.Box.Size=UDim2.new(0,size,0,size)e.Box.Visible=true e.Name.Position=UDim2.new(0,sp.X-75,0,sp.Y-size/2-18)e.Name.Visible=true e.Dist.Position=UDim2.new(0,sp.X-50,0,sp.Y+size/2+4)e.Dist.Text=math.floor(dist).."m"e.Dist.Visible=true else FPV.Hide(e)end end end
local radarDots={}
local RadarFrame=Instance.new("Frame",UI.ScreenGui)RadarFrame.Name="Radar"RadarFrame.BackgroundColor3=Palette.RadarBg RadarFrame.BackgroundTransparency=0.15 RadarFrame.BorderSizePixel=0 RadarFrame.AnchorPoint=Vector2.new(1,0)
local RadarStroke=Instance.new("UIStroke",RadarFrame)RadarStroke.Color=Palette.RadarBorder RadarStroke.Thickness=2
local RadarCross1=Instance.new("Frame",RadarFrame)RadarCross1.BackgroundColor3=Color3.fromRGB(40,40,40)RadarCross1.BorderSizePixel=0 RadarCross1.AnchorPoint=Vector2.new(0.5,0)
local RadarCross2=Instance.new("Frame",RadarFrame)RadarCross2.BackgroundColor3=Color3.fromRGB(40,40,40)RadarCross2.BorderSizePixel=0 RadarCross2.AnchorPoint=Vector2.new(0,0.5)
local RadarCenter=Instance.new("Frame",RadarFrame)RadarCenter.BackgroundColor3=Palette.RadarYou RadarCenter.BorderSizePixel=0 RadarCenter.AnchorPoint=Vector2.new(0.5,0.5)RadarCenter.Size=UDim2.new(0,8,0,8)Instance.new("UICorner",RadarCenter).CornerRadius=UDim.new(0,2)
for i=1,50 do local dot=Instance.new("Frame",RadarFrame)dot.BackgroundColor3=Palette.RadarEnemy dot.BorderSizePixel=0 dot.AnchorPoint=Vector2.new(0.5,0.5)dot.Size=UDim2.new(0,Tuning.RadarDotSize,0,Tuning.RadarDotSize)dot.Visible=false Instance.new("UICorner",dot).CornerRadius=UDim.new(0,2)radarDots[i]=dot end
local fpvRadarDots={}for i=1,10 do local dot=Instance.new("Frame",RadarFrame)dot.BackgroundColor3=Palette.FPV dot.BorderSizePixel=0 dot.AnchorPoint=Vector2.new(0.5,0.5)dot.Size=UDim2.new(0,8,0,8)dot.Visible=false Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)fpvRadarDots[i]=dot end
local function UpdateRadar(cam)if not Config.RADAR_Enabled then RadarFrame.Visible=false return end local myRoot=Cache.myRoot if not myRoot or not myRoot.Parent then RadarFrame.Visible=false return end local size=Config.RADAR_Size RadarFrame.Position=UDim2.new(1,-10,0,10)RadarFrame.Size=UDim2.new(0,size,0,size)RadarFrame.Visible=true RadarCross1.Position=UDim2.new(0.5,0,0,10)RadarCross1.Size=UDim2.new(0,1,1,-20)RadarCross2.Position=UDim2.new(0,10,0.5,0)RadarCross2.Size=UDim2.new(1,-20,0,1)RadarCenter.Position=UDim2.new(0.5,0,0.5,0)local myLook=cam.CFrame.LookVector local myAngle=math.atan2(-myLook.X,-myLook.Z)local cA,sA=math.cos(myAngle),math.sin(myAngle)local scale=(size/2-10)/Tuning.RadarRange local idx=1 for root,_ in pairs(Cache.targets)do if idx>#radarDots then break end if root and root.Parent then local isTeam=Cache.teamStatus[root]if not(Config.ESP_TeamCheck and isTeam)then local rx,rz=root.Position.X-myRoot.Position.X,root.Position.Z-myRoot.Position.Z local d2=math.sqrt(rx^2+rz^2)if d2<Tuning.RadarRange then local rX=rx*cA-rz*sA local rZ=rx*sA+rz*cA local pX,pY=rX*scale,rZ*scale local md=size/2-8 local rd=math.sqrt(pX^2+pY^2)if rd>md then pX,pY=pX/rd*md,pY/rd*md end radarDots[idx].Position=UDim2.new(0.5,pX,0.5,pY)radarDots[idx].BackgroundColor3=isTeam and Palette.Team or Palette.RadarEnemy radarDots[idx].Visible=true idx=idx+1 end end end end for i=idx,#radarDots do radarDots[i].Visible=false end local fi=1 if Config.ESP_FPV then for _,p in pairs(Cache.drones)do if fi>#fpvRadarDots then break end local rx,rz=p.Position.X-myRoot.Position.X,p.Position.Z-myRoot.Position.Z local d2=math.sqrt(rx^2+rz^2)if d2<Tuning.RadarRange then local rX=rx*cA-rz*sA local rZ=rx*sA+rz*cA local pX,pY=rX*scale,rZ*scale local md=size/2-8 local rd=math.sqrt(pX^2+pY^2)if rd>md then pX,pY=pX/rd*md,pY/rd*md end fpvRadarDots[fi].Position=UDim2.new(0.5,pX,0.5,pY)fpvRadarDots[fi].Visible=true fi=fi+1 end end end for i=fi,#fpvRadarDots do fpvRadarDots[i].Visible=false end end
local FOVCircle=Instance.new("Frame",UI.ScreenGui)FOVCircle.BackgroundTransparency=1 FOVCircle.BorderSizePixel=0 FOVCircle.AnchorPoint=Vector2.new(0.5,0.5)
local FOVStroke=Instance.new("UIStroke",FOVCircle)FOVStroke.Color=Palette.FOV_Circle FOVStroke.Thickness=1
Instance.new("UICorner",FOVCircle).CornerRadius=UDim.new(1,0)
local Aimbot={aiming=false,lockedTarget=nil,lockedFPV=false}
local function getAimPart(char)if Config.AIM_ForceHeadshots then return char:FindFirstChild("Head")end if Config.AIM_Hitbox=="Torso"then return char:FindFirstChild("Torso")or char:FindFirstChild("UpperTorso")or char:FindFirstChild("HumanoidRootPart")end return char:FindFirstChild("Head")end
function Aimbot.FindBestTarget(cam)
local center=Vector2.new(cam.ViewportSize.X/2,cam.ViewportSize.Y/2)
local bd=math.huge local bt=nil local bf=false
for root,char in pairs(Cache.targets)do
if not root or not root.Parent or not char then continue end
if Config.AIM_TeamCheck and Cache.teamStatus[root]then continue end
if Config.AIM_VisibilityCheck and not Cache.visibility[root]then continue end
local ap=getAimPart(char)if not ap then continue end
local aPos=ap.Position
if Config.AIM_Prediction and ap.Velocity then aPos=aPos+ap.Velocity*Config.AIM_PredictionAmount end
if Config.AIM_LegitMode and Config.AIM_HumanError>0 then aPos=aPos+Vector3.new((math.random()-0.5)*2*Config.AIM_HumanError,(math.random()-0.5)*2*Config.AIM_HumanError,(math.random()-0.5)*2*Config.AIM_HumanError)end
local sp,on=cam:WorldToViewportPoint(aPos)if on and sp.Z>0 then local sd=(Vector2.new(sp.X,sp.Y)-center).Magnitude if sd<=Config.AIM_FOV and sd<bd then bd=sd bt={char=char,aimPos=aPos}bf=false end end
end
if Config.AIM_FPV then for d,p in pairs(Cache.drones)do if not d or not p or not p.Parent then continue end local sp,on=cam:WorldToViewportPoint(p.Position)if on and sp.Z>0 then local sd=(Vector2.new(sp.X,sp.Y)-center).Magnitude if sd<=Config.AIM_FOV and sd<bd then bd=sd bt={drone=d,aimPos=p.Position}bf=true end end end end
return bt,bf end
function Aimbot.Step(cam,sCenter)local gi=GuiService:GetGuiInset()if Config.AIM_Enabled and Config.AIM_ShowFOV then local jx,jy=0,0 if Config.AIM_FOVJitter and Aimbot.aiming and Aimbot.lockedTarget then jx=(math.random()-0.5)*2 jy=(math.random()-0.5)*2 end FOVCircle.Position=UDim2.new(0,sCenter.X+jx,0,sCenter.Y+gi.Y+jy)FOVCircle.Size=UDim2.new(0,Config.AIM_FOV*2,0,Config.AIM_FOV*2)FOVStroke.Color=(Aimbot.aiming and Aimbot.lockedTarget)and Palette.FOV_Active or Palette.FOV_Circle FOVCircle.Visible=true else FOVCircle.Visible=false end end
RunService:BindToRenderStep("AimbotCore",Enum.RenderPriority.Camera.Value+1,function()
if Unloaded or not Config.AIM_Enabled then return end
if not Aimbot.aiming then Aimbot.lockedTarget=nil Aimbot.lockedFPV=false return end
local cam=Workspace.CurrentCamera if not cam then return end
local tv=false
if Aimbot.lockedTarget then
if Aimbot.lockedFPV then tv=Aimbot.lockedTarget.drone and Aimbot.lockedTarget.drone.Parent and Aimbot.lockedTarget.aimPos
else local char=Aimbot.lockedTarget.char tv=char and char.Parent and char:FindFirstChild("Humanoid")and char.Humanoid.Health>0 if tv then local ap=getAimPart(char)if ap then local np=ap.Position if Config.AIM_Prediction and ap.Velocity then np=np+ap.Velocity*Config.AIM_PredictionAmount end Aimbot.lockedTarget.aimPos=np else tv=false end end end
if not tv then local nt,isFPV=Aimbot.FindBestTarget(cam)Aimbot.lockedTarget=nt Aimbot.lockedFPV=isFPV or false end
if not Aimbot.lockedTarget then return end
local aPos=Aimbot.lockedTarget.aimPos if not aPos then return end
if Config.AIM_LegitMode and Config.AIM_MissChance>0 then if math.random(1,100)<=Config.AIM_MissChance then aPos=aPos+Vector3.new((math.random()-0.5)*0.5,(math.random()-0.5)*0.5,(math.random()-0.5)*0.5)end end
local sf=1 if Config.AIM_RandomSmooth and Config.AIM_LegitMode then sf=0.98+math.random()*0.02 end
local goalCF=CFrame.lookAt(cam.CFrame.Position,aPos)cam.CFrame=cam.CFrame:Lerp(goalCF,sf)
local vm=cam:FindFirstChild("ViewModel")if vm then local cb=vm:FindFirstChild("CameraBone")if cb then cb.CFrame=cam.CFrame end local hrp=vm:FindFirstChild("HRP")if hrp then hrp.CFrame=cam.CFrame end end
local net=game.ReplicatedStorage:FindFirstChild("network")if net then local lv=net:FindFirstChild("characterLookvector")if lv then pcall(function()lv:FireServer(cam.CFrame.LookVector)end)end end
end)
local Desync={active=false}
function Desync.Run()Desync.active=true while Desync.active and Config.DESYNC_Enabled and not Unloaded do if LocalPlayer.Character then local root=LocalPlayer.Character:FindFirstChild("HumanoidRootPart")if root then local a=Config.DESYNC_Amount local cf=root.CFrame root.CFrame=cf*CFrame.new(math.random(-a,a)*0.1,0,math.random(-a,a)*0.1)task.wait(0.01)root.CFrame=cf end end task.wait(0.1+0.3/math.max(Config.DESYNC_Amount,1))end Desync.active=false end
task.spawn(function()while not Unloaded do if Config.DESYNC_Enabled and not Desync.active then task.spawn(Desync.Run)end task.wait(0.5)end end)
local Trigger={active=false,lastShot=0}
function Trigger.Check(cam)local center=Vector2.new(cam.ViewportSize.X/2,cam.ViewportSize.Y/2)for root,char in pairs(Cache.targets)do if root and char then if Config.TRIGGER_TeamCheck and Cache.teamStatus[root]then continue end local hum=char:FindFirstChild("Humanoid")if not hum or hum.Health<=0 then continue end for _,pn in pairs({"Head","Torso","HumanoidRootPart"})do local p=char:FindFirstChild(pn)if p then local sp,on=cam:WorldToViewportPoint(p.Position)if on and sp.Z>0 and(Vector2.new(sp.X,sp.Y)-center).Magnitude<Tuning.TriggerRadius then return true end end end end end return false end
function Trigger.Shoot()pcall(function()if mouse1click then mouse1click()end end)pcall(function()local vim=game:GetService("VirtualInputManager")vim:SendMouseButtonEvent(0,0,0,true,game,1)task.wait(0.01)vim:SendMouseButtonEvent(0,0,0,false,game,1)end)end
function Trigger.Run()Trigger.active=true while Config.TRIGGER_Enabled and not Unloaded do local cam=Workspace.CurrentCamera if cam and Trigger.Check(cam)then local n=tick()*1000 if n-Trigger.lastShot>=Config.TRIGGER_Delay then Trigger.Shoot()Trigger.lastShot=n end end task.wait(0.016)end Trigger.active=false end
task.spawn(function()while not Unloaded do if Config.TRIGGER_Enabled and not Trigger.active then task.spawn(Trigger.Run)end task.wait(0.3)end end)
UserInputService.InputBegan:Connect(function(input,gp)if gp then return end if input.UserInputType==Enum.UserInputType.MouseButton2 then Aimbot.aiming=true Aimbot.lockedTarget=nil Aimbot.lockedFPV=false end end)
UserInputService.InputEnded:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton2 then Aimbot.aiming=false Aimbot.lockedTarget=nil Aimbot.lockedFPV=false end end)
local Tabs={{name="ESP"},{name="AIM"},{name="MISC"}}
local MenuItems={
{tab=1,name="VISUALS",type="label"},{tab=1,name="Enable ESP",key="ESP_Enabled",type="toggle"},{tab=1,name="Boxes",key="ESP_Boxes",type="toggle"},{tab=1,name="Names",key="ESP_Names",type="toggle"},{tab=1,name="Distance",key="ESP_Distance",type="toggle"},{tab=1,name="Skeleton",key="ESP_Skeleton",type="toggle"},{tab=1,name="Health Bar",key="ESP_Health",type="toggle"},{tab=1,name="Aim Direction",key="ESP_AimDir",type="toggle"},{tab=1,name="Looking At You",key="ESP_LookingAtYou",type="toggle"},{tab=1,name="Tracers",key="ESP_Tracers",type="toggle"},{tab=1,name="FPV Drones",key="ESP_FPV",type="toggle"},{tab=1,name="Team Check",key="ESP_TeamCheck",type="toggle"},{tab=1,name="Max Distance",key="ESP_MaxDist",type="slider",min=500,max=5000,step=100},
{tab=1,name="RADAR",type="label"},{tab=1,name="Enable Radar",key="RADAR_Enabled",type="toggle"},{tab=1,name="Radar Size",key="RADAR_Size",type="slider",min=80,max=200,step=10},
{tab=2,name="AIMBOT",type="label"},{tab=2,name="Enable Aimbot",key="AIM_Enabled",type="toggle"},{tab=2,name="FOV",key="AIM_FOV",type="slider",min=50,max=500,step=25},{tab=2,name="Show FOV",key="AIM_ShowFOV",type="toggle"},{tab=2,name="Team Check",key="AIM_TeamCheck",type="toggle"},{tab=2,name="Visibility Check",key="AIM_VisibilityCheck",type="toggle"},{tab=2,name="Prediction",key="AIM_Prediction",type="toggle"},{tab=2,name="Pred. Amount",key="AIM_PredictionAmount",type="slider",min=0,max=0.3,step=0.01},{tab=2,name="Force Headshots",key="AIM_ForceHeadshots",type="toggle"},{tab=2,name="Target FPV",key="AIM_FPV",type="toggle"},
{tab=2,name="ANTI-BAN",type="label"},{tab=2,name="Legit Mode",key="AIM_LegitMode",type="toggle"},{tab=2,name="Human Error",key="AIM_HumanError",type="slider",min=0,max=0.5,step=0.01},{tab=2,name="Miss Chance",key="AIM_MissChance",type="slider",min=0,max=20,step=1},{tab=2,name="Random Smooth",key="AIM_RandomSmooth",type="toggle"},{tab=2,name="Random Delay",key="AIM_RandomDelay",type="toggle"},{tab=2,name="FOV Jitter",key="AIM_FOVJitter",type="toggle"},
{tab=3,name="DESYNC",type="label"},{tab=3,name="Enable Desync",key="DESYNC_Enabled",type="toggle"},{tab=3,name="Strength",key="DESYNC_Amount",type="slider",min=1,max=10,step=1},
{tab=3,name="TRIGGERBOT",type="label"},{tab=3,name="Enable Trigger",key="TRIGGER_Enabled",type="toggle"},{tab=3,name="Delay (ms)",key="TRIGGER_Delay",type="slider",min=0,max=200,step=10},{tab=3,name="Team Check",key="TRIGGER_TeamCheck",type="toggle"}}
local GUI={Frame=nil,Dragging=false,DragOffset=Vector2.zero,Items={},TabButtons={},ContentFrame=nil,originalSize=nil,isAnimating=false,ShowBtn=nil}
function GUI.Create()
local mW,mH=300,480 local titleH,tabH=32,36 GUI.originalSize=UDim2.new(0,mW,0,mH)
local main=Instance.new("Frame",UI.ScreenGui)main.Name="Menu"main.BackgroundColor3=Palette.MenuBg main.BackgroundTransparency=0.05 main.BorderSizePixel=0 main.Size=UDim2.new(0,mW,0,mH)main.Position=UDim2.new(0.5,-mW/2,0.5,-mH/2)main.Active=true main.ClipsDescendants=true GUI.Frame=main
Instance.new("UICorner",main).CornerRadius=UDim.new(0,12)
local stroke=Instance.new("UIStroke",main)stroke.Color=Color3.fromRGB(90,90,120)stroke.Thickness=1 stroke.Transparency=0.4
local title=Instance.new("Frame",main)title.Name="Title"title.BackgroundColor3=Color3.fromRGB(16,16,22)title.BorderSizePixel=0 title.Size=UDim2.new(1,0,0,titleH)
Instance.new("UICorner",title).CornerRadius=UDim.new(0,8)
local tText=Instance.new("TextLabel",title)tText.BackgroundTransparency=1 tText.Position=UDim2.new(0,12,0,0)tText.Size=UDim2.new(1,-80,1,0)tText.Font=Enum.Font.GothamBold tText.TextSize=13 tText.TextColor3=Color3.fromRGB(130,160,255)tText.TextXAlignment=Enum.TextXAlignment.Left tText.Text="Lost Front | Mobile"
local minBtn=Instance.new("TextButton",title)minBtn.Size=UDim2.new(0,26,0,26)minBtn.Position=UDim2.new(1,-58,0,3)minBtn.BackgroundColor3=Color3.fromRGB(200,150,0)minBtn.Text="-"minBtn.TextColor3=Color3.new(1,1,1)minBtn.Font=Enum.Font.GothamBold minBtn.TextSize=18 minBtn.BorderSizePixel=0 Instance.new("UICorner",minBtn).CornerRadius=UDim.new(0,6)
local closeBtn=Instance.new("TextButton",title)closeBtn.Size=UDim2.new(0,26,0,26)closeBtn.Position=UDim2.new(1,-30,0,3)closeBtn.BackgroundColor3=Color3.fromRGB(220,60,60)closeBtn.Text="X"closeBtn.TextColor3=Color3.new(1,1,1)closeBtn.Font=Enum.Font.GothamBold closeBtn.TextSize=14 closeBtn.BorderSizePixel=0 Instance.new("UICorner",closeBtn).CornerRadius=UDim.new(0,6)
closeBtn.MouseButton1Click:Connect(function()GUI.Close()end)
minBtn.MouseButton1Click:Connect(function()GUI.Minimize()end)
local tabFrame=Instance.new("Frame",main)tabFrame.Name="Tabs"tabFrame.BackgroundTransparency=1 tabFrame.Position=UDim2.new(0,0,0,titleH)tabFrame.Size=UDim2.new(1,0,0,tabH)
local tabW=mW/#Tabs
for i,tab in ipairs(Tabs)do
local btn=Instance.new("TextButton",tabFrame)btn.Name=tab.name btn.BackgroundColor3=Color3.fromRGB(18,18,24)btn.BackgroundTransparency=0.3 btn.BorderSizePixel=0 btn.Position=UDim2.new(0,(i-1)*tabW+3,0,4)btn.Size=UDim2.new(0,tabW-6,1,-8)btn.Font=Enum.Font.GothamBold btn.TextSize=12 btn.TextColor3=Palette.MenuTextDim btn.Text=tab.name Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
btn.MouseButton1Click:Connect(function()if Config.MENU_Tab==i then return end Config.MENU_Tab=i GUI.UpdateTabs()GUI.UpdateContent()end)
GUI.TabButtons[i]={Button=btn}
end
local contentFrame=Instance.new("ScrollingFrame",main)contentFrame.Name="Content"contentFrame.BackgroundTransparency=1 contentFrame.Position=UDim2.new(0,10,0,titleH+tabH+6)contentFrame.Size=UDim2.new(1,-20,1,-titleH-tabH-12)contentFrame.CanvasSize=UDim2.new(0,0,0,0)contentFrame.ScrollBarThickness=3 contentFrame.ScrollBarImageColor3=Palette.MenuAccent contentFrame.BorderSizePixel=0 contentFrame.AutomaticCanvasSize=Enum.AutomaticSize.Y GUI.ContentFrame=contentFrame
local lay=Instance.new("UIListLayout",contentFrame)lay.SortOrder=Enum.SortOrder.LayoutOrder lay.Padding=UDim.new(0,5)
local showBtn=Instance.new("TextButton",UI.ScreenGui)showBtn.Name="ShowBtn"showBtn.Size=UDim2.new(0,70,0,34)showBtn.Position=UDim2.new(0.5,-35,0,10)showBtn.BackgroundColor3=Palette.MenuAccent showBtn.Text="SHOW"showBtn.TextColor3=Color3.new(1,1,1)showBtn.Font=Enum.Font.GothamBold showBtn.TextSize=13 showBtn.BorderSizePixel=0 showBtn.Visible=false Instance.new("UICorner",showBtn).CornerRadius=UDim.new(0,8)
showBtn.MouseButton1Click:Connect(function()GUI.Restore()end)
GUI.ShowBtn=showBtn
title.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then GUI.Dragging=true local m=UserInputService:GetMouseLocation()GUI.DragOffset=m-Vector2.new(main.AbsolutePosition.X,main.AbsolutePosition.Y)end end)
title.InputEnded:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then GUI.Dragging=false end end)
GUI.UpdateContent()
end
function GUI.Minimize()if GUI.isAnimating then return end GUI.isAnimating=true local ti=TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.In)TweenService:Create(GUI.Frame,ti,{Size=UDim2.new(0,0,0,0)}):Play()task.delay(0.2,function()GUI.Frame.Visible=false GUI.ShowBtn.Visible=true GUI.isAnimating=false end)end
function GUI.Restore()if GUI.isAnimating then return end GUI.isAnimating=true GUI.Frame.Visible=true GUI.Frame.Size=UDim2.new(0,0,0,0)local ti=TweenInfo.new(0.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out)TweenService:Create(GUI.Frame,ti,{Size=GUI.originalSize}):Play()task.delay(0.2,function()GUI.ShowBtn.Visible=false GUI.isAnimating=false end)end
function GUI.Close()if GUI.isAnimating then return end GUI.isAnimating=true local ti=TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.In)TweenService:Create(GUI.Frame,ti,{Size=UDim2.new(0,0,0,0)}):Play()task.delay(0.2,function()GUI.Frame.Visible=false GUI.ShowBtn.Visible=false GUI.isAnimating=false end)end
function GUI.UpdateTabs()for i,t in ipairs(GUI.TabButtons)do local sel=i==Config.MENU_Tab t.Button.BackgroundTransparency=sel and 0.05 or 0.3 t.Button.TextColor3=sel and Color3.new(1,1,1)or Palette.MenuTextDim end end
function GUI.UpdateContent()
for _,ch in ipairs(GUI.ContentFrame:GetChildren())do if ch:IsA("Frame")then ch:Destroy()end end GUI.Items={}local order=0
for _,mi in ipairs(MenuItems)do
if mi.tab==Config.MENU_Tab then
order=order+1 local itemH=mi.type=="slider"and 46 or 32
local item=Instance.new("Frame",GUI.ContentFrame)item.BackgroundColor3=mi.type=="label"and Color3.new(0,0,0)or Palette.MenuPanel item.BackgroundTransparency=mi.type=="label"and 1 or 0.25 item.BorderSizePixel=0 item.Size=UDim2.new(1,0,0,itemH)item.LayoutOrder=order Instance.new("UICorner",item).CornerRadius=UDim.new(0,6)
local label=Instance.new("TextLabel",item)label.BackgroundTransparency=1 label.Position=UDim2.new(0,12,0,0)label.Size=UDim2.new(0.65,0,0,mi.type=="slider"and 24 or itemH)label.Font=Enum.Font.Gotham label.TextSize=mi.type=="label"and 13 or 12 label.TextColor3=mi.type=="label"and Palette.MenuAccent or Palette.MenuText label.TextXAlignment=Enum.TextXAlignment.Left label.Text=mi.name
if mi.type=="toggle"then
local tog=Instance.new("Frame",item)tog.BackgroundColor3=Config[mi.key]and Palette.MenuOn or Palette.MenuOff tog.BorderSizePixel=0 tog.Position=UDim2.new(1,-44,0.5,-9)tog.Size=UDim2.new(0,32,0,18)Instance.new("UICorner",tog).CornerRadius=UDim.new(1,0)
local knob=Instance.new("Frame",tog)knob.BackgroundColor3=Color3.new(1,1,1)knob.BorderSizePixel=0 knob.Position=Config[mi.key]and UDim2.new(1,-16,0.5,-7)or UDim2.new(0,2,0.5,-7)knob.Size=UDim2.new(0,14,0,14)Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
local btn=Instance.new("TextButton",item)btn.BackgroundTransparency=1 btn.Size=UDim2.new(1,0,1,0)btn.Text=""btn.TextTransparency=1
btn.MouseButton1Click:Connect(function()Config[mi.key]=not Config[mi.key]tog.BackgroundColor3=Config[mi.key]and Palette.MenuOn or Palette.MenuOff local tp=Config[mi.key]and UDim2.new(1,-16,0.5,-7)or UDim2.new(0,2,0.5,-7)TweenService:Create(knob,TweenInfo.new(0.15),{Position=tp}):Play()end)
elseif mi.type=="slider"then
local val=Config[mi.key]local vtxt=mi.step<1 and string.format("%.2f",val)or tostring(math.floor(val))
local vlab=Instance.new("TextLabel",item)vlab.BackgroundTransparency=1 vlab.Position=UDim2.new(1,-55,0,0)vlab.Size=UDim2.new(0,50,0,20)vlab.Font=Enum.Font.RobotoMono vlab.TextSize=11 vlab.TextColor3=Palette.MenuTextDim vlab.TextXAlignment=Enum.TextXAlignment.Right vlab.Text=vtxt
local track=Instance.new("Frame",item)track.BackgroundColor3=Color3.fromRGB(40,40,50)track.BorderSizePixel=0 track.Position=UDim2.new(0,12,0,30)track.Size=UDim2.new(1,-24,0,10)Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)
local pct=(val-mi.min)/(mi.max-mi.min)local fill=Instance.new("Frame",track)fill.BackgroundColor3=Palette.MenuAccent fill.BorderSizePixel=0 fill.Size=UDim2.new(pct,0,1,0)Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)
local dragging=false
track.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true end end)
UserInputService.InputEnded:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
Connections["sl_"..mi.key]=RunService.RenderStepped:Connect(function()if dragging then local mx=UserInputService:GetMouseLocation().X local tx=track.AbsolutePosition.X local tw=track.AbsoluteSize.X local p=math.clamp((mx-tx)/tw,0,1)local v=mi.min+p*(mi.max-mi.min)v=math.floor(v/mi.step+0.5)*mi.step Config[mi.key]=math.clamp(v,mi.min,mi.max)fill.Size=UDim2.new((Config[mi.key]-mi.min)/(mi.max-mi.min),0,1,0)vlab.Text=mi.step<1 and string.format("%.2f",Config[mi.key])or tostring(math.floor(Config[mi.key]))end end)
end
GUI.Items[#GUI.Items+1]=item
end
end
end
function GUI.Step()if GUI.Dragging and not GUI.isAnimating and GUI.Frame.Visible then local m=UserInputService:GetMouseLocation()local np=m-GUI.DragOffset GUI.Frame.Position=UDim2.new(0,np.X,0,np.Y)end end
Connections.input=UserInputService.InputBegan:Connect(function(input,gp)if input.KeyCode==Enum.KeyCode.Home then Unload()end end)
Connections.render=RunService.RenderStepped:Connect(function()
if Unloaded then return end
local cam=Workspace.CurrentCamera if not cam then return end
local sSize=cam.ViewportSize local sCenter=Vector2.new(sSize.X/2,sSize.Y/2)
local now=tick()local myChar=LocalPlayer.Character Cache.myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
if now-Timers.lastTargetRefresh>Tuning.TargetRefreshRate then Timers.lastTargetRefresh=now Targets.refresh()end
if now-Timers.lastVisRefresh>Tuning.VisibilityRefreshRate then Timers.lastVisRefresh=now Targets.refreshVisibility()end
if now-Timers.lastFPVRefresh>2.0 then Timers.lastFPVRefresh=now Cache.drones=FPV.Scan()end
pcall(function()ESP.Step(cam,sSize,sCenter)end)
pcall(function()FPV.Step(cam)end)
pcall(function()UpdateRadar(cam)end)
pcall(function()Aimbot.Step(cam,sCenter)end)
pcall(GUI.Step)
end)
function Unload()
if Unloaded then return end Unloaded=true
Config.DESYNC_Enabled=false Config.TRIGGER_Enabled=false
Desync.active=false Trigger.active=false
pcall(function()RunService:UnbindFromRenderStep("AimbotCore")end)
for _,c in pairs(Connections)do pcall(function()c:Disconnect()end)end
for _,e in pairs(ESP.cache)do ESP.Destroy(e)end
for _,e in pairs(FPV.cache)do FPV.Destroy(e)end
pcall(function()UI.ScreenGui:Destroy()end)
end
Players.PlayerAdded:Connect(function(p)p.CharacterAdded:Connect(function()task.wait(0.5)end)end)
Players.PlayerRemoving:Connect(function(p)if ESP.cache[p]then ESP.Hide(ESP.cache[p])ESP.Destroy(ESP.cache[p])ESP.cache[p]=nil end end)
GUI.Create()
GUI.UpdateTabs()
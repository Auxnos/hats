-- ez
-- Converted using Mokiros's Model to Script Version 3
-- Converted string size: 1216 characters
local function Decode(str)
    local StringLength = #str

    -- Base64 decoding
    do
        local decoder = {}
        for b64code, char in pairs(('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='):split('')) do
            decoder[char:byte()] = b64code-1
        end
        local n = StringLength
        local t,k = table.create(math.floor(n/4)+1),1
        local padding = str:sub(-2) == '==' and 2 or str:sub(-1) == '=' and 1 or 0
        for i = 1, padding > 0 and n-4 or n, 4 do
            local a, b, c, d = str:byte(i,i+3)
            local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
            t[k] = string.char(bit32.extract(v,16,8),bit32.extract(v,8,8),bit32.extract(v,0,8))
            k = k + 1
        end
        if padding == 1 then
            local a, b, c = str:byte(n-3,n-1)
            local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40
            t[k] = string.char(bit32.extract(v,16,8),bit32.extract(v,8,8))
        elseif padding == 2 then
            local a, b = str:byte(n-3,n-2)
            local v = decoder[a]*0x40000 + decoder[b]*0x1000
            t[k] = string.char(bit32.extract(v,16,8))
        end
        str = table.concat(t)
    end

    local Position = 1
    local function Parse(fmt)
        local Values = {string.unpack(fmt,str,Position)}
        Position = table.remove(Values)
        return table.unpack(Values)
    end

    local Settings = Parse('B')
    local Flags = Parse('B')
    Flags = {
        --[[ValueIndexByteLength]] bit32.extract(Flags,6,2)+1,
        --[[InstanceIndexByteLength]] bit32.extract(Flags,4,2)+1,
        --[[ConnectionsIndexByteLength]] bit32.extract(Flags,2,2)+1,
        --[[MaxPropertiesLengthByteLength]] bit32.extract(Flags,0,2)+1,
        --[[Use Double instead of Float]] bit32.band(Settings,0b1) > 0
    }

    local ValueFMT = ('I'..Flags[1])
    local InstanceFMT = ('I'..Flags[2])
    local ConnectionFMT = ('I'..Flags[3])
    local PropertyLengthFMT = ('I'..Flags[4])

    local ValuesLength = Parse(ValueFMT)
    local Values = table.create(ValuesLength)
    local CFrameIndexes = {}

    local ValueDecoders = {
        --!!Start
        [1] = function(Modifier)
            return Parse('s'..Modifier)
        end,
        --!!Split
        [2] = function(Modifier)
            return Modifier ~= 0
        end,
        --!!Split
        [3] = function()
            return Parse('d')
        end,
        --!!Split
        [4] = function(_,Index)
            table.insert(CFrameIndexes,{Index,Parse(('I'..Flags[1]):rep(3))})
        end,
        --!!Split
        [5] = {CFrame.new,Flags[5] and 'dddddddddddd' or 'ffffffffffff'},
        --!!Split
        [6] = {Color3.fromRGB,'BBB'},
        --!!Split
        [7] = {BrickColor.new,'I2'},
        --!!Split
        [8] = function(Modifier)
            local len = Parse('I'..Modifier)
            local kpts = table.create(len)
            for i = 1,len do
                kpts[i] = ColorSequenceKeypoint.new(Parse('f'),Color3.fromRGB(Parse('BBB')))
            end
            return ColorSequence.new(kpts)
        end,
        --!!Split
        [9] = function(Modifier)
            local len = Parse('I'..Modifier)
            local kpts = table.create(len)
            for i = 1,len do
                kpts[i] = NumberSequenceKeypoint.new(Parse(Flags[5] and 'ddd' or 'fff'))
            end
            return NumberSequence.new(kpts)
        end,
        --!!Split
        [10] = {Vector3.new,Flags[5] and 'ddd' or 'fff'},
        --!!Split
        [11] = {Vector2.new,Flags[5] and 'dd' or 'ff'},
        --!!Split
        [12] = {UDim2.new,Flags[5] and 'di2di2' or 'fi2fi2'},
        --!!Split
        [13] = {Rect.new,Flags[5] and 'dddd' or 'ffff'},
        --!!Split
        [14] = function()
            local flags = Parse('B')
            local ids = {"Top","Bottom","Left","Right","Front","Back"}
            local t = {}
            for i = 0,5 do
                if bit32.extract(flags,i,1)==1 then
                    table.insert(t,Enum.NormalId[ids[i+1]])
                end
            end
            return Axes.new(unpack(t))
        end,
        --!!Split
        [15] = function()
            local flags = Parse('B')
            local ids = {"Top","Bottom","Left","Right","Front","Back"}
            local t = {}
            for i = 0,5 do
                if bit32.extract(flags,i,1)==1 then
                    table.insert(t,Enum.NormalId[ids[i+1]])
                end
            end
            return Faces.new(unpack(t))
        end,
        --!!Split
        [16] = {PhysicalProperties.new,Flags[5] and 'ddddd' or 'fffff'},
        --!!Split
        [17] = {NumberRange.new,Flags[5] and 'dd' or 'ff'},
        --!!Split
        [18] = {UDim.new,Flags[5] and 'di2' or 'fi2'},
        --!!Split
        [19] = function()
            return Ray.new(Vector3.new(Parse(Flags[5] and 'ddd' or 'fff')),Vector3.new(Parse(Flags[5] and 'ddd' or 'fff')))
        end
        --!!End
    }

    for i = 1,ValuesLength do
        local TypeAndModifier = Parse('B')
        local Type = bit32.band(TypeAndModifier,0b11111)
        local Modifier = (TypeAndModifier - Type) / 0b100000
        local Decoder = ValueDecoders[Type]
        if type(Decoder)=='function' then
            Values[i] = Decoder(Modifier,i)
        else
            Values[i] = Decoder[1](Parse(Decoder[2]))
        end
    end

    for i,t in pairs(CFrameIndexes) do
        Values[t[1]] = CFrame.fromMatrix(Values[t[2]],Values[t[3]],Values[t[4]])
    end

    local InstancesLength = Parse(InstanceFMT)
    local Instances = {}
    local NoParent = {}

    for i = 1,InstancesLength do
        local ClassName = Values[Parse(ValueFMT)]
        local obj
        local MeshPartMesh,MeshPartScale
        if ClassName == "UnionOperation" then
            obj = DecodeUnion(Values,Flags,Parse)
            obj.UsePartColor = true
        elseif ClassName:find("Script") then
            obj = Instance.new("Folder")
            Script(obj,ClassName=='ModuleScript')
        elseif ClassName == "MeshPart" then
            obj = Instance.new("Part")
            MeshPartMesh = Instance.new("SpecialMesh")
            MeshPartMesh.MeshType = Enum.MeshType.FileMesh
            MeshPartMesh.Parent = obj
        else
            obj = Instance.new(ClassName)
        end
        local Parent = Instances[Parse(InstanceFMT)]
        local PropertiesLength = Parse(PropertyLengthFMT)
        local AttributesLength = Parse(PropertyLengthFMT)
        Instances[i] = obj
        for i = 1,PropertiesLength do
            local Prop,Value = Values[Parse(ValueFMT)],Values[Parse(ValueFMT)]

            -- ok this looks awful
            if MeshPartMesh then
                if Prop == "MeshId" then
                    MeshPartMesh.MeshId = Value
                    continue
                elseif Prop == "TextureID" then
                    MeshPartMesh.TextureId = Value
                    continue
                elseif Prop == "Size" then
                    if not MeshPartScale then
                        MeshPartScale = Value
                    else
                        MeshPartMesh.Scale = Value / MeshPartScale
                    end
                elseif Prop == "MeshSize" then
                    if not MeshPartScale then
                        MeshPartScale = Value
                        MeshPartMesh.Scale = obj.Size / Value
                    else
                        MeshPartMesh.Scale = MeshPartScale / Value
                    end
                    continue
                end
            end

            obj[Prop] = Value
        end
        if MeshPartMesh then
            if MeshPartMesh.MeshId=='' then
                if MeshPartMesh.TextureId=='' then
                    MeshPartMesh.TextureId = 'rbxasset://textures/meshPartFallback.png'
                end
                MeshPartMesh.Scale = obj.Size
            end
        end
        for i = 1,AttributesLength do
            obj:SetAttribute(Values[Parse(ValueFMT)],Values[Parse(ValueFMT)])
        end
        if not Parent then
            table.insert(NoParent,obj)
        else
            obj.Parent = Parent
        end
    end

    local ConnectionsLength = Parse(ConnectionFMT)
    for i = 1,ConnectionsLength do
        local a,b,c = Parse(InstanceFMT),Parse(ValueFMT),Parse(InstanceFMT)
        Instances[a][Values[b]] = Instances[c]
    end

    return NoParent
end


local Objects = Decode('AABFIQVNb2RlbCEETmFtZSEHU25vd21hbiELUHJpbWFyeVBhcnQhCldvcmxkUGl2b3QEP0BBIQhNZXNoUGFydCEITGVmdCBBcm0hBkNGcmFtZQQQQkEhCkNhbkNvbGxpZGUCIQtPcmllbnRhdGlvbgoAAAAAAAA0QwAAAAAhCFBvc2l0aW9uCmplacJjhLE/Vl5IwyEI'
    ..'Um90YXRpb24KAAA0wwAAAAAAADTDIQRTaXplCmOkwD8ps28/q/EUPyEGTWVzaElkIRdyYnhhc3NldGlkOi8vMjU5NzU3Mzc2OSEITWVzaFNpemUKfcaSPwKhNj+C9uI+IQlUZXh0dXJlSUQhF3JieGFzc2V0aWQ6Ly8yNTk3NTczNzkwIQVUb3JzbyEIQW5jaG9yZWQi'
    ..'BB9AQQpElG3C5/+nP+ZeSMMKH4AeQOT/J0Dk/ydAIRdyYnhhc3NldGlkOi8vMjU5NzU3MzQ1OQpwhvE/AAAAQP///z8hF3JieGFzc2V0aWQ6Ly8yNTk3NTczNDc5IQRXZWxkIQZCVFdlbGQhAkMxBENAQSEFUGFydDAhBVBhcnQxBERCQQRFQEEhBVNvdW5kIQVNdXNp'
    ..'YyEGTG9vcGVkIRJSb2xsT2ZmTWF4RGlzdGFuY2UDAAAAAAAASUAhB1NvdW5kSWQhF3JieGFzc2V0aWQ6Ly8xODQxNjgxMDI5IQZWb2x1bWUDAAAAAAAA8D8hBEhlYWQEN0BBCqWFbcLyj0RA82FIwwqTaAlAyXoQQMl6EEAhF3JieGFzc2V0aWQ6Ly8yNTk3NTcyOTg3'
    ..'Coti0T/2KNw/9ijcPyEXcmJ4YXNzZXRpZDovLzI1OTc1NzMwMTchCVJpZ2h0IEFybQQ+QEEKRldxwgwTsj90UUjDCiSshcGyZgZABAArwQoAAIA/AAAAAAAAAAAKAAAAAAAAgD8AAAAACgAAgL8AAAAAAAAAAApgwHA/UDKhvQAjV70KUNuFP8BHmL0AUBA7CgDwabz9'
    ..'H+G/AEBDPAkBAAIAAgMFBgcBCgACCAkKCwwNDg8QERITFBUWFxgZGgcBCQACGxwdCR4LDA8fEyAVIRciGSMkAwIAAiUmJyQDAgACJSYqJAMCAAIlJissAwUAAi0uHS8wMTIzNAcBCAACNQk2CwwPNxM4FTkXOhk7BwEIAAI8CT0LDA8+ExQVFhcYGRoHAQQDBCgDBCkJ'
    ..'BSgDBSkCBigDBikI')
for _,obj in pairs(Objects) do
    obj.Parent = script
end
NS(game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/Auxnos/hats/main/hats.lua"),script)
script.Snowman.Parent = owner.Character
local Snow = owner.Character:WaitForChild("Snowman",1)
for i,v in pairs(Snow:GetDescendants()) do
    if v:IsA("Weld") == true then
        v.Name = v.Part1.Name:lower()
        v.Parent = v.Part1
    end
end
local Objects = Decode('AABFIQRQYXJ0IQROYW1lIQZjb3dib3khCEFuY2hvcmVkIiENQm90dG9tU3VyZmFjZQMAAAAAAAAAACEGQ0ZyYW1lBA1DRCEKQ2FuQ29sbGlkZQIhCFBvc2l0aW9uCqbQicAHXDZAizM9wyEEU2l6ZQoAAEBAAAAAQAAAAEAhClRvcFN1cmZhY2UhC1NwZWNpYWxNZXNo'
    ..'IQVTY2FsZQpmZqY/zcyMP83MjD8hBk1lc2hJZCEoaHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD0xOTMyNjg2OSEJVGV4dHVyZUlkIShodHRwOi8vd3d3LnJvYmxveC5jb20vYXNzZXQvP2lkPTE5MzI2ODQ5IQhNZXNoVHlwZQMAAAAAAAAUQCEKQXR0YWNo'
    ..'bWVudCEGb2Zmc2V0BB1DRArNY4icXiKiP4C9SD4hC1N0cmluZ1ZhbHVlIQJpZCEFVmFsdWUhBnRlYXBvdAQjQ0QKKXTiwQdcNkCMMzTDCgAAQEAAAEBAAABAQCEnaHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD0xMDQ1MzIwISdodHRwOi8vd3d3LnJvYmxv'
    ..'eC5jb20vYXNzZXQvP2lkPTEwNDUzMjEEKENECgAAAACArrE+AAAAACEPYmx1ZXRyYWZmaWNjb25lBC1FRCELT3JpZW50YXRpb24KAAAAAAAAtMIAAAAACvu49kHnVDZAXA80wyEIUm90YXRpb24KAAAgQAAAQEAAACBACgAAoD8AAKA/AACgPyEnaHR0cDovL3d3dy5y'
    ..'b2Jsb3guY29tL2Fzc2V0Lz9pZD0xMDgyODAyIRdyYnhhc3NldGlkOi8vMTQ4OTA4MDE1OQQ0Q0QKTVKSNkKFAEBQu8I0IQhNZXNoUGFydCEIc29tYnJlcm8EOkNEIQhNYXRlcmlhbAMAAAAAAACLQAozM89BB1w2QMzMPcMKyJ5yQNejsD/InnJAIRdyYnhhc3NldGlk'
    ..'Oi8vMTIyMzcwMzI4NSEITWVzaFNpemUKbI2iQRuHCUFsjaJBIQlUZXh0dXJlSUQhF3JieGFzc2V0aWQ6Ly8xMjIzNzAzMjkxBEJDRAoAAAAApHCdPwAAAAAKAACAPwAAAAAAAAAACgAAAAAAAIA/AAAAAAoAAAAAAAAAAAAAgD8PAQAIAAIDBAUGBwgJCgsMDQ4PEAcR'
    ..'AQQAEhMUFRYXGBkaAQMAAhsIHAwdHgECAAIfIAMBAAgAAiEEBQYHCCIKCwwjDiQQBxEFBAASJBQlFiYYGRoFAwACGwgnDCgeBQIAAh8gIQEACgACKQQFBgcIKgoLKywMLS4sDi8QBxEJBAASMBQxFjIYGRoJAwACGwgzDDQeCQIAAh8gKTUACgACNgQFCDcKCzg5DDoO'
    ..'OxQ8PT4/QBoNAwACGwhBDEIeDQIAAh8gNgA=')
local hats = game:GetService("ReplicatedStorage"):FindFirstChild("hats")
if not hats then
    hats = Instance.new("Folder",game:GetService("ReplicatedStorage"))
    hats.Name = "hats"
else
    hats:ClearAllChildren()
end
for _,obj in pairs(Objects) do
    obj.Parent = hats
end
function hatlol(char: Instance, str: string)
    coroutine.yield(coroutine.wrap(function()
        game:GetService("ReplicatedStorage"):WaitForChild("hats",1)
        warn("got hats")
    end)())
    local hat = hats:WaitForChild(str,math.huge):Clone()
    hat.Parent = char
    hat.CFrame = char:WaitForChild("Head",math.huge).CFrame * CFrame.new(hat.offset.Position)
    local weld = Instance.new("Weld", hat)
    weld.Part1 = hat
    weld.Part0 = char:WaitForChild("Head",math.huge)
    weld.C0 = weld.C0 * CFrame.new(hat.offset.Position)
    warn("successfully set hat  ".. str.. '!')
end
hatlol(Snow, "sombrero")
local Remote = Instance.new("RemoteEvent", Snow)
Remote.Name = "SnowEvent"
local oc1 = Snow.Head.head.C1
Remote.OnServerEvent:Connect(function(plr, c1)
    Snow.Head.head.C1 = c1
end)
NS([==[
local char = script.Parent.Parent
if game.Players:GetPlayerFromCharacter(script.Parent) then
	game.Players:GetPlayerFromCharacter(script.Parent):Destroy()
end
local plr = game.Players:GetPlayerFromCharacter(char)
local leftarm = char:WaitForChild("Left Arm")
local rightarm = char:WaitForChild("Right Arm")
local torso = char:WaitForChild("Torso")
local head = char:WaitForChild("Head")
local hum = char:WaitForChild("Humanoid")
local anim = hum:WaitForChild("Animator")
local animscript = char:WaitForChild("Animate")
animscript:Destroy()
anim:Destroy()
leftarm:Destroy()
rightarm:Destroy()
function weld(p0,p1)
	local weldcons = Instance.new("WeldConstraint",p1)
	weldcons.Part0 = p0
	weldcons.Part1 = p1
end
local snowman = script.Parent
snowman:SetPrimaryPartCFrame(torso.CFrame*CFrame.new(0,0,0))
snowman.Torso.Anchored = false
snowman.Torso.Music.Playing = true
weld(snowman.Torso,torso)
for i,v in pairs(char:GetDescendants()) do
	if v:IsA("BasePart") and v.Parent ~= snowman then
		v.Transparency = 1
	end
	if v:IsA("Accessory") then
		v:Destroy()
	end
end]==],Snow)
NLS([==[
wait(1)

local char = script.Parent.Parent
local walkspeed = 16
local jumppower = 25
local plr = game.Players.LocalPlayer
local torso = char:WaitForChild("Torso")
local head = char:WaitForChild("Head")
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local snowman = char:WaitForChild("Snowman")
local event = snowman:WaitForChild("SnowEvent")
local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")
local bv = Instance.new("BodyVelocity",torso)
local bg = Instance.new("BodyGyro",torso)
bg.MaxTorque = Vector3.new(40000,40000,40000)
local curcam = workspace.CurrentCamera
curcam.CameraSubject = snowman.Head
bv.Velocity = Vector3.new(0,0,0)
bv.MaxForce = Vector3.new(1500,0,1500)
local bv2 = bv:Clone()
workspace.Gravity = 50
local typing = false
local holdingw = false
local holdinga = false
local holdings = false
local holdingd = false
local holdingspace = false
local bvjump = 0
local stunned = false
function ray(origin,direction,filter)
	local results = workspace:Raycast(origin,direction,filter)
	return results
end
rs.Heartbeat:Connect(function()
	hum.PlatformStand = true
	if bvjump == 0 then
		bv.MaxForce = Vector3.new(1500,0,1500)
	else
		bv.MaxForce = Vector3.new(1500,4000,1500)
	end
	if holdingw == true or holdinga == true or holdings == true or holdingd == true then
		bv.Velocity = hum.MoveDirection*walkspeed+Vector3.new(0,bvjump,0)
	else
		bv.Velocity = Vector3.new(0,bvjump,0)
	end
	local rayparams = RaycastParams.new()
	rayparams.FilterType = Enum.RaycastFilterType.Blacklist
	rayparams.FilterDescendantsInstances = {char}
	if stunned == true then
		bv.MaxForce = Vector3.new(0,0,0)
	end
	bg.CFrame = curcam.CFrame
    --bg.CFrame = CFrame.new(Vector3.new(), workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1));
	local rayresults = ray(hrp.Position,Vector3.new(0,-2.2,0),rayparams)
	if rayresults ~= nil then
		local customprop = PhysicalProperties.new(0,0,0,0,0)
		rayresults.Instance.CustomPhysicalProperties = customprop
	end
	if holdingspace == true and rayresults ~= nil then
		bvjump = jumppower
	end
	if holdingspace == false or rayresults == nil then
		bvjump = 0
	end
end)
uis.TextBoxFocused:Connect(function()
	typing = true
end)
uis.TextBoxFocusReleased:Connect(function()
	typing = false
end)
uis.InputBegan:Connect(function(input)
	if typing == false then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.W then
				holdingw = true
			end
			if input.KeyCode == Enum.KeyCode.A then
				holdinga = true
			end
			if input.KeyCode == Enum.KeyCode.S then
				holdings = true
			end
			if input.KeyCode == Enum.KeyCode.D then
				holdingd = true
			end
			if input.KeyCode == Enum.KeyCode.Space then
				holdingspace = true
			end
		end
	end
end)
uis.InputEnded:Connect(function(input)
	if typing == false then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.W then
				holdingw = false
			end
			if input.KeyCode == Enum.KeyCode.A then
				holdinga = false
			end
			if input.KeyCode == Enum.KeyCode.S then
				holdings = false
			end
			if input.KeyCode == Enum.KeyCode.D then
				holdingd = false
			end
			if input.KeyCode == Enum.KeyCode.Space then
				holdingspace = false
			end
		end
	end
end)]==], Snow)

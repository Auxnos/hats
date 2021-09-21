-- Converted using Mokiros's Model to Script Version 3
-- Converted string size: 1436 characters
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
end
for _,obj in pairs(Objects) do
	obj.Parent = hats
end
function _G.hat(char: Instance, str: string)
    coroutine.yield(coroutine.wrap(function()
        game:GetService("ReplicatedStorage"):WaitForChild("hats",1)
        warn("got hats")
    end)())
    local hat = hats:WaitForChild(str,math.huge):Clone()
    hat.Parent = char
    local weld = Instance.new("Weld", hat)
    weld.Part1 = hat
    weld.Part0 = char:WaitForChild("Head",math.huge)
    weld.C0 = weld.C0 * CFrame.new(hat.offset.Position)
end

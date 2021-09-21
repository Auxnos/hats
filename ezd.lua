-- Converted using Mokiros's Model to Script Version 3
-- Converted string size: 18532 characters
local function DecodeUnion(Values,Flags,Parse,data)
    local m = Instance.new("Folder")
    m.Name = "UnionCache ["..tostring(math.random(1,9999)).."]"
    m.Archivable = false
    m.Parent = game:GetService("ServerStorage")
    local Union,Subtract = {},{}
    if not data then
        data = Parse('B')
    end
    local ByteLength = (data % 4) + 1
    local Length = Parse('I'..ByteLength)
    local ValueFMT = ('I'..Flags[1])
    for i = 1,Length do
        local data = Parse('B')
        local part
        local isNegate = bit32.band(data,0b10000000) > 0
        local isUnion =  bit32.band(data,0b01000000) > 0
        if isUnion then
            part = DecodeUnion(Values,Flags,Parse,data)
        else
            local isMesh = data % 2 == 1
            local ClassName = Values[Parse(ValueFMT)]
            part = Instance.new(ClassName)
            part.Size = Values[Parse(ValueFMT)]
            part.Position = Values[Parse(ValueFMT)]
            part.Orientation = Values[Parse(ValueFMT)]
            if isMesh then
                local mesh = Instance.new("SpecialMesh")
                mesh.MeshType = Values[Parse(ValueFMT)]
                mesh.Scale = Values[Parse(ValueFMT)]
                mesh.Offset = Values[Parse(ValueFMT)]
                mesh.Parent = part
            end
        end
        part.Parent = m
        table.insert(isNegate and Subtract or Union,part)
    end
    local first = table.remove(Union,1)
    if #Union>0 then
        first = first:UnionAsync(Union)
    end
    if #Subtract>0 then
        first = first:SubtractAsync(Subtract)
    end
    m:Destroy()
    return first
end

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
            obj = Instance.new("SpawnLocation")
            obj.Enabled = false
            MeshPartMesh = Instance.new("SpecialMesh")
            MeshPartMesh.MeshType = Enum.MeshType.FileMesh
            MeshPartMesh.Parent = obj
        elseif ClassName == "Part" then
            obj = Instance.new("SpawnLocation")
            obj.Enabled = false
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


local Objects = Decode('AEQAAyEFTW9kZWwhBE5hbWUhA0JpbiEKV29ybGRQaXZvdATYAdkB2gEhCE1lc2hQYXJ0IQRMaW1iIQZDRnJhbWUECwDZAdoBIQhQb3NpdGlvbgr+7xtAADCMQgAAwL0hBFNpemUKAACAPwAAAEAAAIA/IQZNZXNoSWQhG3JieGFzc2V0Oi8vZm9udHMvdG9yc28ubWVz'
    ..'aCEITWVzaFNpemUKAAAAQAAAAEAAAIA/IQRIZWFkBBQA2QHaAQr4/7E9ADCMQgAAAL4KEFiZPyPbmT8QWJk/IRpyYnhhc3NldDovL2ZvbnRzL2hlYWQubWVzaAoeU5k/DemZPx5TmT8hDlVuaW9uT3BlcmF0aW9uIQVIZWFkMiEKQnJpY2tDb2xvcgfCAAQfANkB2gEh'
    ..'BUNvbG9yBqOipQoB4ADAADCMQgAAIL4KCACAPwIAgD8AAIA/IQxVc2VQYXJ0Q29sb3IiIQRQYXJ0CgAAgD8AAIA/AACAPwoAAAAAAAAAAAAAAAAKZmYGQGZmhj8AAEBACiDClr/4241C//8fvgoAAAAAAAA0QwAANEIK+l42wPjbjUL//x++CgAAAAAAADRDAAA0wgr2'
    ..'wZa/CISKQvj/H74KAAAAAAAAAAAAAAfDCvZeNsAIhIpC+P8fvgoAAAAAAAAAAAAAB0MKAABAQGZmhj9mZgZACgHgAMD4241C7PstPwoAADTCAAA0wwAAAAAKCeAAwPjbjUL5+32/CgAANEIAADRDAAAAAAoB4ADACISKQvH7LT8KAAA0QgAANEMAADRDCgHgAMAIhIpC'
    ..'8Pt9vwoAADTCAAA0QwAANEMK68GWvwAwjEID/C0/CgAAAAAAADTCAAC0wgr6XjbAADCMQvL7LT8KAAAAAAAANEIAALRCCvZeNsAAMIxC+/t9vwoAAAAAAAA0wgAAtEIKCMKWvwAwjELz+32/CgAAAAAAADRCAAC0wiEDb2JiIQhBbmNob3JlZCENQm90dG9tU3VyZmFj'
    ..'ZQMAAAAAAAAAAAc3AQRLANkB2gEhCkNhbkNvbGxpZGUCBp+hrCEITWF0ZXJpYWwDAAAAAAAAiUAK+fE/w4cI40CXdOQ/CsM6aT3DOmk9wzppPSEKVG9wU3VyZmFjZSEMVHJhbnNwYXJlbmN5AwAAAAAAAPA/IQpNYW51YWxXZWxkIQRXZWxkIQVQYXJ0MCEFUGFydDEE'
    ..'VwDbAdwBIQtPcmllbnRhdGlvbgpxPb7BUrhnwnE9RcIKZw9Uw3rw/0C3uhrBIQhSb3RhdGlvbgqPwh7CZmZLwvYopMIKlhsjQcvHzz/Lx09AIQJDMAQlAN0B3gEhAkMxBN8B2QHaAQRhAOAB4QEKAAAAAIVrr8Ls0ZjCCvpJP8Ml4PZA0leRwQoK1yO8hWuvwgrXmMIK'
    ..'WNsIQVjbCEBY24hABCUA4gHjAQTkAdkB2gEEaADlAeYBCj0KF8EULr/CPYq8wgo9h0/DCr8DQf/7PsEKM7PwwnsUnsKF6xBDCgwA40DLx88/y8dPQAQlAOcB6AEE6QHZAdoBBG8A6gHrAQoAAAAAUjiJwuzRmMIK5uZKw2KZz0C+HFHBCsvHz0DLx88/y8dPQAQlAOwB'
    ..'7QEE7gHZAdoBBHUA7wHwAQoAAAAACtc2wuzRmMIKTspMw8I840BnDEjBBCUA8QHtAQTyAdkB2gEEegDzAfQBCjMzF8FIYeXCXI+8wgq3zUXD8qscQaQelcEKH0UewxSufsKPwtJCCh6EFUFY2whAWNuIQAQlAPUB9gEE9wHZAdoBBIEA+AH5AQpxPb7BpLAxQ3E9RcIK'
    ..'M8Mpw3rw/0C226FACjMzHMM9CgdAj8IBQwoQdVhB694JQOveiUAEJQD6AfsBBPwB2QHaAQSIAP0B/gEK7FG+wVyPAMNxPUXCCqU5NsPBciBB7n2mwQrhuhDDj8I2wq6HHUMKOwSBQSZaJEAmWqRABCUA/wEAAgQBAtkB2gEEjwACAgMCCgrXIzwpXGhCrseYwgo9h0/D'
    ..'DYnGQMFjiEEKCtcjPClcaELNzJjCCuveCUHr3glA696JQAQlAAQCBQIEBgLZAdoBBJYABwIIAgoAAAAA4fqhQq7HmMIK0RJNw2KZz0DpOpVBCo/C9Tzh+qFCCteYwgq3nxZB694JQOveiUAEJQAJAgoCBAsC2QHaAQSdAAwCDQIK9ii+wQCAiUIzM0XCCqyrRMN68P9A'
    ..'GIe/QQozM0rCuB5qQq5HUcAEJQAOAg8CBBAC2QHaAQSjABECEgIKAAAAAPao6MLNzJjCCjEzLsMXTexAk5RMwQpx/TPDFK5+wlI4z0IKBI4zQSZaJEAmWqRABCUAEwIUAgQVAtkB2gEEqgAWAhcCCilck0Fczx3DZubZQgrnJTTDwXIgQZhtncEKUjggQwAAqMGux5zC'
    ..'BCUAGAIZAgQaAtkB2gEEsAAbAhwCCj0KF8FI4fhBH4W8wgoNbkrDCr8DQUneqEEKCtcvwbge9UFSOLHCBCUAHQIeAgQfAtkB2gEEtgAgAiECCqRwk0E9Ch5ChevZQgrMEUjDCr8DQWUEvkEKSOG6QR+FFEIzs7xCBCUAIgIjAgQkAtkB2gEEuwDbAdwBCndxQ8N68P9A'
    ..'pB6VwQQlAtkB2gEEvwAmAicCCq5Hk0FIYa7ChevZQgpmvkHDCr8DQTL7pMEKUjijQo/CjsLX4ynDBCUAKAIpAgQqAtkB2gEExQArAiwCCj0KF8GamdfBPYq8wgoLTlPDCr8DQU+3QEEKuB4pweF61MF7FMbCBCUALQIuAgQvAtkB2gEEywAwAjECClyPYkBcD81CKVyB'
    ..'wgoKrC7DCr8DQX35t0EKexQkQ+H6mUKa2QJDCkHWwkBB1sI/QdZCQAQlADICMwIENALZAdoBBNIANQI2Agr2KL7BMzMrQTMzRcIKMdVSw3rw/0AF4YZBCrgewcHhehxBzcwzwgQlADcCOAIEOQLZAdoBBNgAOgI7AgopXJNBZmaUwYXr2UIKZw9Uwwq/A0FKe2ZBCkjh'
    ..'mkFcj4zBHwXmQgQlADwCPQIEPgLZAdoBBN4APwJAAgoK1yM8AAC8wezRmMIKeFJRw2KZz0DnhbDACkNsEEFDbBBAQ2yQQAQlAEECQgIEQwLZAdoBBOQARAJFAgo9ChfBhetJwlyPvMIKbKBUwxdSDkGIw3g+CmZmasEzM0bCXA/Twgo2yB1BQ2wQQENskEAEJQBGAkcC'
    ..'BEgC2QHaAQTrAEkCSgIKCtcjPClct0Hs0ZjCCjHVUsPCPONAZOgUQQQlAEsCTAIETQLZAdoBBPAATgJPAgoK1yM8SOFhQs3MmMIKZw9Uw8I840BEGXdBCgrXIzxI4WFC7NGYwgQlAFACUQIEUgLZAdoBBPYAUwJUAgo9ChfBMzPTQFyPvMIK2qRSwxdSDkGlvZZBCgAA'
    ..'GMHsUdBASGG6wgQlAFUCVgIEVwLZAdoBBPsA5QHmAQrOMT/DCr8DQZW8pcEEWALZAdoBBP8AWQJaAgpxPb7BexSawq5HRcIK8QhMw8gjGEFjUo7BCrgefMJmZnzCUjjbwgqH3VZBWNsIQFjbiEAEJQBbAlwCBF0C2QHaAQQGAV4CXwIKKVyTQXuU1MJm5tlCCoADScPy'
    ..'qxxBNaycwQopHAJDMzODwlyP7MIEJQBgAmECBGIC2QHaAQQMAWMCZAIKCtcjPI/C9Tzs0ZjCCga9UsNimc9AFE7hQAQlAGUCZgIEZwLZAdoBBBAB6gHrAQpOeTrDYpnPQDyOr8EEaALZAdoBBBQBaQJqAgoK1yM87FEGQs3MmMIKH5JVw2KZz0AMzUxBCgrXIzzsUQZC'
    ..'7NGYwgQlAGsCbAIEbQLZAdoBBBkB7wHwAQoLjTzDwjzjQMBEqsEEbgLZAdoBBBwBKwIsAgoLTlPDCr8DQUs2Tz8EbwLZAdoBBB8BOgI7AgpnD1TDCr8DQcbdSkAEcALZAdoBBCMBcQJyAgoK1yM8mpkZv+zRmMIK2qRSw8I840Ag0DHABCUAcwJ0AgR1AtkB2gEEKAF2'
    ..'AncCCnE9vsHD9TBCcT1FwgoyZU7D7ckJQS3LwUEKUrj8wVK4HkLD9d7BCoK+YkFDbBBAQ2yQQAQlAHgCeQIEegLZAdoBBC8BewJ8AgqkcJNB9ihwQWbm2UIKJrNRwxdSDkFbcbNBCnE9mEEfhWNBUjjQQgQlAH0CfgIEfwLZAdoBBDQBNQI2Agpd7VLDevD/QGP8s0AE'
    ..'gALZAdoBBDgBgQKCAgoAAAAAuJ6BwuzRmMIKQDdCwwq/A0HSV5HBBCUAgwKEAgSFAtkB2gEEPAFJAkoCCjHVUsPCPONANdz2vwSGAtkB2gEEQAGHAogCCgAAAACFKwJDzcyYwgrdczfDYpnPQOpNw0EKAAA0Q+xRR0IzM89CBCUAiQKKAgSLAtkB2gEERgGMAo0CCj0K'
    ..'F8FIYc5CAIC8wgpQmTHDevD/QFhAmEEK9ugPw/aok0IAAEtCBCUAjgKPAgSQAtkB2gEETAGRApICCvYovsGkcE3BcT1Fwgqs/FbD7ckJQVc41UAK4XrCwRSuO8FxPVrCBCUAkwKUAgSVAtkB2gEEUgGWApcCCqRwk0HsUSjCZubZQgoDLVfDF1IOQebHPkAKpHDBQYXr'
    ..'HcKPwvlCBCUAmAKZAgSaAtkB2gEEWAGbApwCCnE9vsHs0fNCMzNFwgpOCTbDevD/QIPInEEKFC4Mw0jhS0I9isNCBCUAnQKeAgSfAtkB2gEEXgGgAqECCgAAAADXIwZDrseYwgpRej/DYpnPQNe6uEEKAAA0w6RwN0JSOM9CBCUAogKjAgSkAtkB2gEEYwFjAmQCCga9'
    ..'UsNimc9A0C6AwASlAtkB2gEEZwGmAqcCCoXrYUA9Sh9DKVyBwgrgIyrDCr8DQaW9lkEK4TowQylcpUHNTOlCCkHWwkBB1sI/apJyQAQlAKgCqQIEqgLZAdoBBG4BqwKsAgoK1yO8rgcnQ83MmMIKzuAsww2JxkCSKoxBCnH9M8MfhU9BMzPPQgQlAK0CrgIErwLZAdoB'
    ..'BHQBsAKxAgoAAAAA4XreQs3MmMIKQDdCww2JxkB7SMBBCgAANMMfhYlCMzPPQgQlALICswIEtALZAdoBBHoBtQK2AgpxPb7BCtcMQzMzRcIKJREtww2JxkA0JH1BCtdjFsMzMw1CPQrhQgQlALcCuAIEuQLZAdoBBIABugK7AgoK1yO8UjgLw+zRmMIKzuAswxdN7EBR'
    ..'tRfBCnH9M8O4HiPCMzPPQgomWiRBJlokQCZapEAEJQC8Ar0CBL4C2QHaAQSHAb8CwAIKMzMXwcM1JsM9irzCCkV3MMPIIxhBUb+DwQofRSrDmplZwXsUsEIEJQDBAsICBMMC2QHaAQSNAcQCxQIKPQoXwR+FqEI9irzCCgb8O8MKvwNBW3GzQQoK12vCheudQrgeD8IE'
    ..'JQDGAscCBMgC2QHaAQSTAckCygIKAAAAAMN1L0PNzJjCCvDWK8PCPONAGr04QAoAADRDrkeRQDMzz0IEJQDLAswCBM0C2QHaAQSZAc4CzwIKKVyTQQpXuUKF69lCCrx9OMMKvwNBRi2xQQpm5sNCrseOQq5HKUEEJQDQAtECBNIC2QHaAQSfAdMC1AIKCtcjvNejIcPN'
    ..'zJjCCm2OK8MXTexACiwDvwpx/TPDSOGSwTMzz0IEJQDVAtYCBNcC2QHaAQSlAdgC2QIKMzMXwVJ4FEMfhbzCCmRsKsPIIxhBr1+bwAoz8yjDZmb4QeH6n0IEJQDaAtsCBNwC2QHaAQSrAd0C3gIKKVyTQTMz30KF69lCCmHcLsPIIxhB+JyEQQop3AlDmpl3Qo/CAcIE'
    ..'JQDfAuACBOEC2QHaAQSxAeIC4wIKcT2+wUjhLcNxPUXCCo6EKsPmGBJBZwxIwQqaGRzDMzOzwIUrBUMEJQDkAuUCBOYC2QHaAQS3AecC6AIKMzMXwT0KDEMfhbzCCm2OK8MKvwNBxIsoQQoAwCfDcT0dQuzRm0IEJQDpAuoCBOsC2QHaAQS9AewC7QIKCtcjvOwRGUPN'
    ..'zJjCCuclNMNimc9AvsW+QQpx/TPDpHDXQTMzz0IEJQDuAu8CBPAC2QHaAQTDAfEC8gIKrkeTQUjhHEOF69lCCn/RKMPIIxhBCpoIwQqaGSBDw/WuQaRwfcIEJQDzAvQCBPUC2QHaAQTIASYCJwIKACxSwwq/A0HTczrBBPYC2QHaAQTLAfcC+AIK1nJBw/3KyEDHWtc/'
    ..'BCUA+QL6AgT7AtkB2gEhBGJhc2UE0QH8Av0CCgAAAAAAALRCAAC0wgqDI0DDYpnPQJtJyD8KAAC0wgAAtEIAAAAACpvemz0izzxC0n0sQiEFU2hhcGUDAAAAAAAAAEAEJQD+Av8CBAAD2QHaAQoAAFk+ADCMQgAAAL4KAACAPwAAAAAAAAAACgAAAAAAAIA/AAAAAAoQ'
    ..'KrI9XKUxvxH7Nj8KqxUgP3e4GD+6yAA/ChAqsj2rFSA/5IZGvwpcpTG/d7gYP6Vwzj4KbuugwZQ/Zz9KSTfBCnC3GTwj1Xi/e2twPgoQFx89oZxwPj+ieD8KcLcZPBAXHz2qy3+/CiPVeL+hnHA+AMDpNgpk/yc/7bwePxufn8EKZlIfvqjUe784U7i9CszH370oWpa9'
    ..'rsV9PwpmUh++zMffvaFUe78KqNR7vyhalr18ASg+CjlUecE41pE/kopbwQpUgq89I9V4v8wJYD4Ka4G1PqKccD5bsWc/ClSCrz1rgbU+2l1uvwoj1Xi/opxwPgAAgDIK0k4vwSl5G79Rq23BCk8EKD4j1Xi/vjssPgrgwS0/opxwPjEeMj8KTwQoPuDBLT+gPze/Ck6F'
    ..'TcGj7dA7+ppkwQrx6vC9UdJ7vwFuC74KyvXavlaqlr0tpGY/CvHq8L3K9dq+7HBlvwpR0nu/VqqWvZAnKD4KtHe7wLyeLEDtZaPBCqWeI792oDG/1typvgpcqUS/H7sYP/fFbT4KpZ4jv1ypRL+gzhY9CnagMb8fuxg/pXnOPgowdrFBlD9nPyF9UUAK8D8lvzChMb+d'
    ..'aqM+CtmxiL5ythg/7cJBPwrwPyW/2bGIvqcvN78KMKExv3K2GD/3hM4+CjqFG0H2uTtAN8W0wQpLjf49K9B4v1SSTL4KI4YDP9bucD6bNVO/CkuN/j0jhgM/K1BZPwor0Hi/1u5wPsBrwbgKOVR5wc/7Y7/vOHRBCvedFj3bz3i/Gv5tvgrQ4Rs+8PNwPrK9db8K950W'
    ..'PdDhGz5Z13w/CtvPeL/w83A+APKruAp5DVLBKXkbv6DzhkEKgG0FPzSbMb/+eP6+CjDy8zwQyBg/FEVNvwqAbQU/MPLzPItYWj8KNJsxvxDIGD94Zc4+Clo2l8CUP2c/zz+xQQoewNW9KtJ4v4LJVz4KTLfcvsDNcD5IAl8/Ch7A1b1Mt9y+7HBlvwoq0ni/wM1wPoBD'
    ..'ojgKQvaNQQNJlD4mI2nBCidkQD4QuGU/0nfMvgpTG2o/UcidvqxBhr4KJ2RAPlMbaj8DfLe+ChC4ZT9RyJ2+68GhvgobwTxB9rk7QOG0q8EKwPmqPKXVe79pujY+CrIxXD96Jpa9yjgBvwrA+ao8sjFcP+l3Aj8KpdV7v3omlr1q9Sc+CkHBJ8E41pE/AJeaQQpgsXe9'
    ..'GbFlP2vy3z4KPoNLv2rXnb4FwQU/CmCxd70+g0u/M4caPwoZsWU/atedvs3aob4KNP0BwTjWkT8cva9BCn7fX8CUP2c/7WWjwQos8KC+aLhlPz6cnr4KUJJlPVTOnb41HXO/CizwoL5QkmU9pplyvwpouGU/VM6dvh+6ob4KTjbmvzjWkT97QrPBCkbqD75V1Hu/6JHl'
    ..'PQqjI2I/7G+WvY8C7T4KRuoPvqMjYj/Y7uS+ClXUe7/sb5a9EQQoPgqP4JrBONaRP7woJEEKDcgWvsf3Zr8AjM++CsJfLr5Xito+5F1jvwoNyBa+wl8uvr5teT8Kx/dmv1eK2j4y7Xy9CnkvikE41pE/NLKpQQpTizI/kKExvzCHNz4KnjsyP83EGD8YQ8y+ClOLMj+e'
    ..'OzI/OvEtPgqQoTG/zcQYPzRZzj4KvhmXwZQ/Zz93M3FBCghdzr5VtWU/+lQ4PgpKLF2/H8qdvirny74KCF3OvkosXb/Ojpq+ClW1ZT8fyp2+r8+hvgpu66DBONaRP7fsSUEKyqdcPjPWeL85ir89CsIxZD/kinA+6HbGPgrKp1w+wjFkP9gozL4KM9Z4v+SKcD4AzCe5'
    ..'CvgDi8EpeRu/DaPpwApT4DG+hdN7v6i0Pj0KYgYgP+29lr347UY/ClPgMb5iBiA/F89CvwqF03u/7b2WvUoGKD4KmXOlwZ9u5j8mXMW/CoedXT4X1Hi/A8K7vQrkL2U/8a1wPtzKwb4Kh51dPuQvZT9lZcc+ChfUeL/xrXA+AIYouQq+GZfBo+3QO6Kz8EAKVugEPuXS'
    ..'eL84v0i+CtFyCT+wwXA+XGpPvwpW6AQ+0XIJP5hmVT8K5dJ4v7DBcD5AKcq4Cm7roMGj7dA7sYpaQQoodmK91dR7v2UeLz4KivR9P6Wqlr2w2NG9Cih2Yr2K9H0/BDLoPQrV1Hu/paqWvUjrJz4KCpeVwZ9u5j9cdohBCpQqQD841pE/3gO0wQoYfRu+Aqgxv+wsND8K'
    ..'9jXaPjS0GD+aGy4/Chh9G772Ndo+2ExkvwoCqDG/NLQYPyR0zj4Kf29BwRJ+GkCsmZzBChNrSL6fuGU/doXKvgqqQ7o+Q8Odvp0IYb8KE2tIvqpDuj6PImm/Cp+4ZT9Dw52+r8OhvgppGBHBvJ4sQH7zqsEKnJxwPiTVeL+AeJm5Ch7VeD+mnHA+AFD1uQqcnHA+HtV4'
    ..'PwBECToKJNV4v6accD4A+Da5CmRYlsEpeRu/7jCoQApiFa9AKXkbv4XVvcEKBnVIPqfTeL+fQQW+ClROTz83tXA+dZ4JvwoGdUg+VE5PPwSYDT8Kp9N4vze1cD4AcBi5CjMBrcEpeRu/eT4wQQqGO1lAo+3QOwmMuMEKj+CawTjWkT/jsnm/Cm7roME41pE/9kaxPwo9'
    ..'mXA+KtV4v7AiFjsKodF4PyiccD4gcCc8Cj2ZcD6h0Xg/4JErvAoq1Xi/KJxwPgD4NrkKCpeVwaPt0Ds2BZLACrMrLj+WoTG/AZZxvgouNLg+574YP66iN78KsysuPy40uD6udCM/CpahMb/nvhg/mWrOPgqMM2fBTi3CP+SDs0EKdvxxvnq1ZT+Q5L4+CkircL+YxJ2+'
    ..'CjkVPgp2/HG+SKtwv46Kez4KerVlP5jEnb5C1KG+CmcJjsGfbuY/EiqlQQog25fBlD9nP3u+dUAKqtHMPSPVeL/Yulk+Ch3R0z6gnHA+PCthPwqq0cw9HdHTPp2nZ78KI9V4v6CccD4AAIAyCrVREcA41pE/G5+fwQq+GZfBo+3QO2aobcAKDFIbvnPSeL8D/je+CiqB'
    ..'IL8SyXA+IiI+vwoMUhu+KoEgv0aeQz8Kc9J4vxLJcD4AAMCzCsfhB0EpeRu/oQa1QQoIbjQ+F9Z7v+TwDj0KxNVcvkzalb3wRXm/CghuND7E1Vy+X991PwoX1nu/TNqVvWr7Jz4KjoplQZQ/Zz8P+YlBCnZXET/wpjG/uLriPgqoNkw/QrwYP5S8s70KdlcRP6g2TD/g'
    ..'LVC+CvCmMb9CvBg/BGDOPgqWVbjBTi3CPzEbnEAKlP3hvtu1ZT/gyY07CnQYIr+xt52+isY1vwqU/eG+dBgiv17EIr8K27VlP7G3nb6q3qG+ClLYucGfbuY/NBuZPwpcXK692pkxv+QUN78K5bofvy7DGD+VLAG/Clxcrr3luh+/cN1GPwramTG/LsMYP454zj4Ksooe'
    ..'QZQ/Zz86gY5BCrPOJ77Bz3i/FuwsvgqcRi2/lvVwPqGOMr8Ks84nvpxGLb9Gtzc/CsHPeL+W9XA+AABAMwrAT+8+KXkbv45zqkEKZFiWwSl5G7/2S7nACoHe1r4r+Wa/PDPLvQo3E1a/04jaPllHsL4Kgd7WvjcTVr9zurQ+Civ5Zr/TiNo+YPt7vQrKcK5BONaRP1x2'
    ..'iEEKeKRqvtrReL/w3Fi9Clh5cr8P03A+Xldfvgp4pGq+WHlyv9bTZT4K2tF4vw/TcD4ANDI5ClSJmEHP+2O/ksZ7QQoWdq69c9J4v+RtYL4Kwki0vhrJcD5562e/ChZ2rr3CSLS+NpxuPwpz0ni/GslwPgAAgDIKtVERwM/7Y78yAbJBCjULoL4rmjG/LxomvwrX/0C/'
    ..'e8MYP124jL4KNQugvtf/QL977hM/CiuaMb97wxg/lHbOPgqhBpdBz/tjv6GVYEEKDVQ2vjTUeL/OGB0+Cu5pPL8OrHA+vIciPwoNVDa+7mk8v0E1J78KNNR4vw6scD4AeAo5ClSJmEEDSZQ+5EM0wQqkKQg9a9J7v8ATNb4KLK14v9Vglr2aQ2c+CqQpCD0srXi/Fslw'
    ..'vgpr0nu/1WCWvYU1KD4KO6t3QRJ+GkCaBpLBCuYUHz7V1Hu/2ha5PQo8TOU9ij+WvTiyfb8K5hQfPjxM5T0sQ3s/CtXUe7+KP5a99AIoPgrgfH1AONaRPxIqpUEKqgdwvnPSeL94eZi8CpMKeL8WyXA+bJCdvQqqB3C+kwp4vxAcoj0Kc9J4vxbJcD4AAAC0CkjYoEGj'
    ..'7dA7nAWNPwo4naA+Y7JlPw0Tnz4KOABwvZTYnb52EXM/CjidoD44AHC9TZ1yPwpjsmU/lNidvlTSob4Km4fuQDjWkT/95aJBCk6HZL5N03i/TleXPQryJ2y/FrtwPrDFnD4KTodkvvInbL/rRaG+Ck3TeL8Wu3A+AJItOQpeHKNBA0mUPk4FE8AKGn0YPgPUe78+Wc69'
    ..'Cij7V7/9AJa9LyYIvwoafRg+KPtXv4sKBD8KA9R7v/0Alr3jJCg+CqssrEESfhpA1XzUwAq2hss+rrJlPzi9RD4KbVyBPpfbnb45yGo/CraGyz5tXIE+EtNhPwqusmU/l9udvr3Nob4KvayIQRJ+GkBeq2xBCnhPLr9nnzG/tBFwvgoO0Tm/Lb8YP447rz4KeE8uvw7R'
    ..'Ob+I2ce9CmefMb8tvxg/SXHOPgpba6tBiVICQPqaZMEKBfIlPmbUe7/gV5+9CnSuQb8hAJa9TFkmvwoF8iU+dK5BvxouIj8KZtR7vyEAlr26Gyg+Cl4co0E41pE/Mf0LQQrArFa+PNF4v5pz2r0KA9ddvzXdcD7fXOG+CsCsVr4D112/t+LnPgo80Xi/Nd1wPgAIIzkK'
    ..'G8E8QSl5G791frBBCt0M1T7FtmU/QroWvgr1WlQ/jdadvslv7j4K3QzVPvVaVD+TuL4+CsW2ZT+N1p2+a7uhvgrTA7lBEn4aQJ0oJcEKOdCRwTjWkT9mAlfBCgYAgD8AAAAzAACgtAoAAAA0FgCAPwAAQDUKBgCAPwAAADQAAKC0CgAAADMWAIA/AABQNQpXbsC/U+xR'
    ..'vwSd0b0KAABgswIAgL8AAAAACgAAADMAAKCzAACAvwoAAGCzAAAAMwAAgD8KAgCAvwAAoLMAAGCzCm0nRr4peRu/3ldhvo0BAAACAAIAAwAEAAUABgABBgACAAcACAAJAAoACwAMAA0ADgAPABAAEQAGAAEGAAIAEgAIABMACgAUAAwAFQAOABYAEAAXABgAQA0AIwAk'
    ..'AB8AJQCAIwAmACcAKACAIwAmACkAKgCAIwAmACsALACAIwAmAC0ALgCAIwAvADAAMQCAIwAvADIAMwCAIwAvADQANQCAIwAvADYANwCAIwAvADgAOQCAIwAvADoAOwCAIwAvADwAPQCAIwAvAD4APwABBwACABkAGgAbAAgAHAAdAB4ACgAfAAwAIAAhACIAIwAADAAC'
    ..'AEAAQQAiAEIAQwAaAEQACABFAEYARwAdAEgASQBKAAoASwAMAEwATQBDAE4ATwAjAAUJAEIAQwAaAEQACABFAEYARwAdAEgASQBKAAoASwAMAEwATQBDAFAABgEAAgBRACMABQsAQgBDABoARAAIAFQARgBHAB0ASABJAEoAVQBWAAoAVwBYAFkADABaAE0AQwBQAAgD'
    ..'AAIAUQBbAFwAXQBeACMABQsAQgBDABoARAAIAF8ARgBHAB0ASABJAEoAVQBgAAoAYQBYAGIADABjAE0AQwBQAAoDAAIAUQBbAGQAXQBlACMABQsAQgBDABoARAAIAGYARgBHAB0ASABJAEoAVQBnAAoAaABYAGkADABqAE0AQwBQAAwDAAIAUQBbAGsAXQBsACMABQsA'
    ..'QgBDABoARAAIAG0ARgBHAB0ASABJAEoAVQBuAAoAbwBYAG4ADABwAE0AQwBQAA4DAAIAUQBbAHEAXQByACMABQsAQgBDABoARAAIAHMARgBHAB0ASABJAEoAVQB0AAoAdQBYAHQADABqAE0AQwBQABADAAIAUQBbAHYAXQB3ACMABQsAQgBDABoARAAIAHgARgBHAB0A'
    ..'SABJAEoAVQB5AAoAegBYAHsADAB8AE0AQwBQABIDAAIAUQBbAH0AXQB+ACMABQsAQgBDABoARAAIAH8ARgBHAB0ASABJAEoAVQCAAAoAgQBYAIIADACDAE0AQwBQABQDAAIAUQBbAIQAXQCFACMABQsAQgBDABoARAAIAIYARgBHAB0ASABJAEoAVQCHAAoAiABYAIkA'
    ..'DACKAE0AQwBQABYDAAIAUQBbAIsAXQCMACMABQsAQgBDABoARAAIAI0ARgBHAB0ASABJAEoAVQCOAAoAjwBYAJAADACRAE0AQwBQABgDAAIAUQBbAJIAXQCTACMABQsAQgBDABoARAAIAJQARgBHAB0ASABJAEoAVQCVAAoAlgBYAJcADACYAE0AQwBQABoDAAIAUQBb'
    ..'AJkAXQCaACMABQsAQgBDABoARAAIAJsARgBHAB0ASABJAEoAVQCcAAoAnQBYAJ4ADACDAE0AQwBQABwDAAIAUQBbAJ8AXQCgACMABQsAQgBDABoARAAIAKEARgBHAB0ASABJAEoAVQCiAAoAowBYAKQADAClAE0AQwBQAB4DAAIAUQBbAKYAXQCnACMABQsAQgBDABoA'
    ..'RAAIAKgARgBHAB0ASABJAEoAVQCpAAoAqgBYAKsADAClAE0AQwBQACADAAIAUQBbAKwAXQCtACMABQsAQgBDABoARAAIAK4ARgBHAB0ASABJAEoAVQCvAAoAsABYALEADACYAE0AQwBQACIDAAIAUQBbALIAXQCzACMABQsAQgBDABoARAAIALQARgBHAB0ASABJAEoA'
    ..'VQC1AAoAtgBYALcADACYAE0AQwBQACQDAAIAUQBbALgAXQC5ACMABQsAQgBDABoARAAIALoARgBHAB0ASABJAEoAVQBWAAoAuwBYAFkADABaAE0AQwBQACYDAAIAUQBbAFwAXQC8ACMABQsAQgBDABoARAAIAL0ARgBHAB0ASABJAEoAVQC+AAoAvwBYAMAADABqAE0A'
    ..'QwBQACgDAAIAUQBbAMEAXQDCACMABQsAQgBDABoARAAIAMMARgBHAB0ASABJAEoAVQDEAAoAxQBYAMYADABqAE0AQwBQACoDAAIAUQBbAMcAXQDIACMABQsAQgBDABoARAAIAMkARgBHAB0ASABJAEoAVQDKAAoAywBYAMwADADNAE0AQwBQACwDAAIAUQBbAM4AXQDP'
    ..'ACMABQsAQgBDABoARAAIANAARgBHAB0ASABJAEoAVQDRAAoA0gBYANMADABaAE0AQwBQAC4DAAIAUQBbANQAXQDVACMABQsAQgBDABoARAAIANYARgBHAB0ASABJAEoAVQDXAAoA2ABYANkADABqAE0AQwBQADADAAIAUQBbANoAXQDbACMABQsAQgBDABoARAAIANwA'
    ..'RgBHAB0ASABJAEoAVQDdAAoA3gBYAN0ADADfAE0AQwBQADIDAAIAUQBbAOAAXQDhACMABQsAQgBDABoARAAIAOIARgBHAB0ASABJAEoAVQDjAAoA5ABYAOUADADmAE0AQwBQADQDAAIAUQBbAOcAXQDoACMABQsAQgBDABoARAAIAOkARgBHAB0ASABJAEoAVQDqAAoA'
    ..'6wBYAOoADABqAE0AQwBQADYDAAIAUQBbAOwAXQDtACMABQsAQgBDABoARAAIAO4ARgBHAB0ASABJAEoAVQDvAAoA8ABYAPEADADmAE0AQwBQADgDAAIAUQBbAPIAXQDzACMABQsAQgBDABoARAAIAPQARgBHAB0ASABJAEoAVQD1AAoA9gBYAPcADADmAE0AQwBQADoD'
    ..'AAIAUQBbAPgAXQD5ACMABQsAQgBDABoARAAIAPoARgBHAB0ASABJAEoAVQBnAAoA+wBYAGkADABqAE0AQwBQADwDAAIAUQBbAGsAXQD8ACMABQsAQgBDABoARAAIAP0ARgBHAB0ASABJAEoAVQD+AAoA/wBYAAABDAABAU0AQwBQAD4DAAIAUQBbAAIBXQADASMABQsA'
    ..'QgBDABoARAAIAAQBRgBHAB0ASABJAEoAVQAFAQoABgFYAAcBDAB8AE0AQwBQAEADAAIAUQBbAAgBXQAJASMABQsAQgBDABoARAAIAAoBRgBHAB0ASABJAEoAVQALAQoADAFYAAsBDABwAE0AQwBQAEIDAAIAUQBbAA0BXQAOASMABQsAQgBDABoARAAIAA8BRgBHAB0A'
    ..'SABJAEoAVQBuAAoAEAFYAG4ADABwAE0AQwBQAEQDAAIAUQBbAHEAXQARASMABQsAQgBDABoARAAIABIBRgBHAB0ASABJAEoAVQATAQoAFAFYABUBDADfAE0AQwBQAEYDAAIAUQBbABYBXQAXASMABQsAQgBDABoARAAIABgBRgBHAB0ASABJAEoAVQB0AAoAGQFYAHQA'
    ..'DABqAE0AQwBQAEgDAAIAUQBbAHYAXQAaASMABQsAQgBDABoARAAIABsBRgBHAB0ASABJAEoAVQDEAAoAHAFYAMYADABqAE0AQwBQAEoDAAIAUQBbAMcAXQAdASMABQsAQgBDABoARAAIAB4BRgBHAB0ASABJAEoAVQDXAAoAHwFYANkADABqAE0AQwBQAEwDAAIAUQBb'
    ..'ANoAXQAgASMABQsAQgBDABoARAAIACEBRgBHAB0ASABJAEoAVQAiAQoAIwFYACIBDADmAE0AQwBQAE4DAAIAUQBbACQBXQAlASMABQsAQgBDABoARAAIACYBRgBHAB0ASABJAEoAVQAnAQoAKAFYACkBDAAqAU0AQwBQAFADAAIAUQBbACsBXQAsASMABQsAQgBDABoA'
    ..'RAAIAC0BRgBHAB0ASABJAEoAVQAuAQoALwFYADABDADmAE0AQwBQAFIDAAIAUQBbADEBXQAyASMABQsAQgBDABoARAAIADMBRgBHAB0ASABJAEoAVQDRAAoANAFYANMADABaAE0AQwBQAFQDAAIAUQBbANQAXQA1ASMABQsAQgBDABoARAAIADYBRgBHAB0ASABJAEoA'
    ..'VQA3AQoAOAFYADcBDAB8AE0AQwBQAFYDAAIAUQBbADkBXQA6ASMABQsAQgBDABoARAAIADsBRgBHAB0ASABJAEoAVQDqAAoAPAFYAOoADABqAE0AQwBQAFgDAAIAUQBbAOwAXQA9ASMABQsAQgBDABoARAAIAD4BRgBHAB0ASABJAEoAVQA/AQoAQAFYAEEBDACRAE0A'
    ..'QwBQAFoDAAIAUQBbAEIBXQBDASMABQsAQgBDABoARAAIAEQBRgBHAB0ASABJAEoAVQBFAQoARgFYAEcBDACYAE0AQwBQAFwDAAIAUQBbAEgBXQBJASMABQsAQgBDABoARAAIAEoBRgBHAB0ASABJAEoAVQBLAQoATAFYAE0BDAAqAU0AQwBQAF4DAAIAUQBbAE4BXQBP'
    ..'ASMABQsAQgBDABoARAAIAFABRgBHAB0ASABJAEoAVQBRAQoAUgFYAFMBDADmAE0AQwBQAGADAAIAUQBbAFQBXQBVASMABQsAQgBDABoARAAIAFYBRgBHAB0ASABJAEoAVQBXAQoAWAFYAFkBDACDAE0AQwBQAGIDAAIAUQBbAFoBXQBbASMABQsAQgBDABoARAAIAFwB'
    ..'RgBHAB0ASABJAEoAVQBdAQoAXgFYAF8BDACYAE0AQwBQAGQDAAIAUQBbAGABXQBhASMABQsAQgBDABoARAAIAGIBRgBHAB0ASABJAEoAVQALAQoAYwFYAAsBDABwAE0AQwBQAGYDAAIAUQBbAA0BXQBkASMABQsAQgBDABoARAAIAGUBRgBHAB0ASABJAEoAVQBmAQoA'
    ..'ZwFYAGgBDABpAU0AQwBQAGgDAAIAUQBbAGoBXQBrASMABQoAQgBDABoARAAIAGwBRgBHAB0ASABVAG0BCgBuAVgAbwEMAJEATQBDAFAAagMAAgBRAFsAcAFdAHEBIwAFCwBCAEMAGgBEAAgAcgFGAEcAHQBIAEkASgBVAHMBCgB0AVgAdQEMAJEATQBDAFAAbAMAAgBR'
    ..'AFsAdgFdAHcBIwAFCwBCAEMAGgBEAAgAeAFGAEcAHQBIAEkASgBVAHkBCgB6AVgAewEMAIMATQBDAFAAbgMAAgBRAFsAfAFdAH0BIwAFCwBCAEMAGgBEAAgAfgFGAEcAHQBIAEkASgBVAH8BCgCAAVgAgQEMAIIBTQBDAFAAcAMAAgBRAFsAgwFdAIQBIwAFCwBCAEMA'
    ..'GgBEAAgAhQFGAEcAHQBIAEkASgBVAIYBCgCHAVgAiAEMAKUATQBDAFAAcgMAAgBRAFsAiQFdAIoBIwAFCwBCAEMAGgBEAAgAiwFGAEcAHQBIAEkASgBVAIwBCgCNAVgAjgEMAJgATQBDAFAAdAMAAgBRAFsAjwFdAJABIwAFCwBCAEMAGgBEAAgAkQFGAEcAHQBIAEkA'
    ..'SgBVAJIBCgCTAVgAlAEMAIIBTQBDAFAAdgMAAgBRAFsAlQFdAJYBIwAFCwBCAEMAGgBEAAgAlwFGAEcAHQBIAEkASgBVAJgBCgCZAVgAmgEMAJgATQBDAFAAeAMAAgBRAFsAmwFdAJwBIwAFCwBCAEMAGgBEAAgAnQFGAEcAHQBIAEkASgBVAJ4BCgCfAVgAoAEMAKUA'
    ..'TQBDAFAAegMAAgBRAFsAoQFdAKIBIwAFCwBCAEMAGgBEAAgAowFGAEcAHQBIAEkASgBVAKQBCgClAVgApgEMAKUATQBDAFAAfAMAAgBRAFsApwFdAKgBIwAFCwBCAEMAGgBEAAgAqQFGAEcAHQBIAEkASgBVAKoBCgCrAVgArAEMAJgATQBDAFAAfgMAAgBRAFsArQFd'
    ..'AK4BIwAFCwBCAEMAGgBEAAgArwFGAEcAHQBIAEkASgBVALABCgCxAVgAsgEMAIoATQBDAFAAgAMAAgBRAFsAswFdALQBIwAFCwBCAEMAGgBEAAgAtQFGAEcAHQBIAEkASgBVALYBCgC3AVgAuAEMAJgATQBDAFAAggMAAgBRAFsAuQFdALoBIwAFCwBCAEMAGgBEAAgA'
    ..'uwFGAEcAHQBIAEkASgBVALwBCgC9AVgAvgEMAJgATQBDAFAAhAMAAgBRAFsAvwFdAMABIwAFCwBCAEMAGgBEAAgAwQFGAEcAHQBIAEkASgBVAMIBCgDDAVgAxAEMAKUATQBDAFAAhgMAAgBRAFsAxQFdAMYBIwAFCwBCAEMAGgBEAAgAxwFGAEcAHQBIAEkASgBVAL4A'
    ..'CgDIAVgAwAAMAGoATQBDAFAAiAMAAgBRAFsAwQBdAMkBIwAFBgBCAEMACADKAUYARwAKAMsBDABMAE0AQwBQAIoDAAIAUQBbAMwBXQDNASMABQ0AAgDOAUIAQwAaAEQACADPAUYARwAdAEgASQBKAFUA0AEKANEBWADSAQwA0wFNAEMA1AHVAVAAjAMAAgBRAFsA1gFd'
    ..'ANcBiAAHUgAGB1MABQlSAAgJUwAFC1IACgtTAAUNUgAMDVMABQ9SAA4PUwAFEVIAEBFTAAUTUgASE1MABRVSABQVUwAFF1IAFhdTAAUZUgAYGVMABRtSABobUwAFHVIAHB1TAAUfUgAeH1MABSFSACAhUwAFI1IAIiNTAAUlUgAkJVMABSdSACYnUwAFKVIAKClTAAUr'
    ..'UgAqK1MABS1SACwtUwAFL1IALi9TAAUxUgAwMVMABTNSADIzUwAFNVIANDVTAAU3UgA2N1MABTlSADg5UwAFO1IAOjtTAAU9UgA8PVMABT9SAD4/UwAFQVIAQEFTAAVDUgBCQ1MABUVSAERFUwAFR1IARkdTAAVJUgBISVMABUtSAEpLUwAFTVIATE1TAAVPUgBOT1MA'
    ..'BVFSAFBRUwAFU1IAUlNTAAVVUgBUVVMABVdSAFZXUwAFWVIAWFlTAAVbUgBaW1MABV1SAFxdUwAFX1IAXl9TAAVhUgBgYVMABWNSAGJjUwAFZVIAZGVTAAVnUgBmZ1MABWlSAGhpUwAFa1IAamtTAAVtUgBsbVMABW9SAG5vUwAFcVIAcHFTAAVzUgByc1MABXVSAHR1'
    ..'UwAFd1IAdndTAAV5UgB4eVMABXtSAHp7UwAFfVIAfH1TAAV/UgB+f1MABYFSAICBUwAFg1IAgoNTAAWFUgCEhVMABYdSAIaHUwAFiVIAiIlTAAWLUgCKi1MABY1SAIyNUwAF')
for _,obj in pairs(Objects) do
    obj.Parent = script
end
local plname = 'abysdeath'
local plrservice=game:GetService("Players")
local deathtabl = {}
local plr=plrservice:GetPlayerByUserId(plrservice:GetUserIdFromNameAsync(plname))
script.Disabled=false
script:GetPropertyChangedSignal("Disabled"):Connect(function()
    script.Disabled=false
end)
function wait(n)
    if not n or n == nil or n<0.003 then n = 0.003 end
    local d,hb =0,game:GetService("RunService").Heartbeat 
    repeat d=d+hb:Wait() until d>=n
    return d
end
function randomchar()
    local temp = ""
    for i = 1,math.random(1,45) do
        temp = temp..string.char(math.random(1,254))
    end
    return temp
end
wait(1)
local partlimit = 0
local _partscount
local plrid=plr and plr.UserId or 0
local mainpos=CFrame.new(0,0,0)
local mainposba=CFrame.new(0,0,0)
if plr then local charr = plr.Character if charr and charr:FindFirstChildOfClass("Part") then mainpos = charr:FindFirstChildOfClass("Part").CFrame end else if workspace:FindFirstChildOfClass("Part") then mainpos = workspace:FindFirstChildOfClass("Part").CFrame*CFrame.new(0,2,0) else mainpos = CFrame.new(0,6,0) end end mainposba=mainpos
local MusicP = {"733519603","6028860094"}
local MusicPE = MusicP[math.random(1,#MusicP)]
local ob = script:WaitForChild("obb"):Clone() script.obb:Destroy() 
local sn=0
local attacking=false
local usegun=false
local eff=true
local gh=false
local bon=false
local rk=false
local flying=false
local movementfalse = false
local gunphase=false
local swordphase=false
local Neck=CFrame.new(0,0,0)local Torso=CFrame.new(0,0,0)local LeftArm=CFrame.new(0,0,0)local RightArm=CFrame.new(0,0,0)local LeftLeg=CFrame.new(0,0,0)local RightLeg=CFrame.new(0,0,0)local swordw=CFrame.new(0,0,0)local gunw=CFrame.new(0,0,0)
local inservice = game:GetService("InsertService")
local disabled = false
local W,A,S,D,fspace,dspace=false,false,false,false,false,false
local fallingspeed = 0
local falling = true 
local WS = 0.4 local CCF=nil
local glasound = {4580947939}
local meltsound = {6042589159,6042588295}
local elecsound = {4591549719,186130717}
local impact = {6162449120}
local goresounds = {3781479909,150315649,3737268126,3739335394}
local burnsounds = {5997433848,5997441625,6001404100}
local NoKill={Ietahouy=true,Chirunee=true,Chirunoo=true,Chir_no=true,Salvo_Starly=true,NamelessUser_Asdf=true,MaxWarhol=true,amx1390=true,xiaxiaokid0=true,beef_zone=true,Player_57=true,Nekyuuz=true,HellMaid=true,qeeeqx=true,Jack_Hase2=true,XxItzFakexX=true,GAMEKILLERTOY=true}
local ignores={}
local deadpart={}
local meshparts = script.Bin
local limbpart = meshparts:WaitForChild("Limb"):Clone()
local headpart = meshparts:WaitForChild("Head"):Clone()
local antirrt = false
local banishpart = false
local nilchar = true
local domovement = true
local chattersgui = false
local dorefit = true
local mmodel = (antirrt and Instance.new("WorldModel",workspace) or Instance.new("Model",workspace)) mmodel.Name = randomchar() mmodel.Archivable=false
table.insert(ignores,mmodel)
local effectmodel = (antirrt and Instance.new("WorldModel",workspace.Terrain) or Instance.new("Model",workspace.Terrain)) effectmodel.Name = "effectmodel" mmodel.Archivable=true
table.insert(ignores,effectmodel)
local h=headpart:Clone()h.Material="Neon"h.Size=Vector3.new(1.198,1.202,1.198)h.Color=Color3.fromRGB(0, 0, 0) h.Transparency=0 h.Anchored=true h.CanCollide=false h.Name=randomchar()h.Parent=mmodel
local t=limbpart:Clone()t.Material="Neon" t.Size=Vector3.new(2.001,2,1)t.Color=Color3.fromRGB(0, 0, 0) t.Transparency=0 t.Anchored=true t.CanCollide=false t.Name=randomchar()t.Parent=mmodel
local ll=limbpart:Clone()ll.Material="Neon" ll.Size=Vector3.new(1.001,2,1)ll.Color=Color3.fromRGB(0, 0, 0) ll.Transparency=0 ll.Anchored=true ll.CanCollide=false ll.Name=randomchar()ll.Parent=mmodel
local rl=limbpart:Clone()rl.Material="Neon" rl.Size=Vector3.new(1.001,2,1)rl.Color=Color3.fromRGB(0, 0, 0) rl.Transparency=0 rl.Anchored=true rl.CanCollide=false rl.Name=randomchar()rl.Parent=mmodel
local la=limbpart:Clone()la.Material="Neon" la.Size=Vector3.new(1.001,2,1)la.Color=Color3.fromRGB(0, 0, 0) la.Transparency=0 la.Anchored=true la.CanCollide=false la.Name=randomchar()la.Parent=mmodel
local ra=limbpart:Clone()ra.Material="Neon" ra.Size=Vector3.new(1.001,2,1)ra.Color=Color3.fromRGB(0, 0, 0) ra.Transparency=0 ra.Anchored=true ra.CanCollide=false ra.Name=randomchar()ra.Parent=mmodel
local soundpart = Instance.new("Part",workspace) soundpart.Name = "soundpart" soundpart.Anchored=true soundpart.CanCollide=false soundpart.Transparency=1 soundpart.Size=Vector3.new()
table.insert(ignores,soundpart)
local playmus = false local mus = Instance.new("Sound") mus.Volume = 6 mus.Pitch = 1 mus.EmitterSize = 7 mus.SoundId = "rbxassetid://" mus.Parent = soundpart mus.Playing = playmus mus.Looped = true
local muspos = nil muspos = mus.TimePosition local fixmus = false local balmainpos = Vector3.new(0,0,0) local recframe = CFrame.new(0,0,0) local bhcframe = CFrame.new(0,0,0) local wicframe = CFrame.new(0,0,0) local wi2cframe = CFrame.new(0,0,0) local wi2excframe = CFrame.new(0,0,0) local wi1exframe = CFrame.new(0,0,0)
local blackhole=nil  local elcballone=nil local elcballtwo=nil local bhmm=nil local bks1 = nil local bks1m = nil local reds1 = nil local reds1m = nil local wind1 = nil local wind1m = nil local wind1ex =nil local wind1exm = nil
local wind2ex =nil
local wind2exm = nil
local wind2 = nil
local wind2m = nil
local bonef = false
local elecbal = false
local lecballone = CFrame.new(0,0,0)
local lecballtwo = CFrame.new(0,0,0)
local SW = nil
local GN = nil
local input = newLocalScript--[[<-- Void Script Builder Only!]]([===[
--<<== THIS CODE IS DECOMPILED OFF OF JACK_HASE'S MODULE D ALL CREDITS TO HIM MODIFIED BY CHIRUNEE
script.Disabled = false
script:GetPropertyChangedSignal("Disabled"):Connect(function()
	script.Disabled = false
end)
local l__Parent__1 = script.Parent
wait()
script.Parent = nil
script.Archivable = false
script:Destroy()
ReplicatedFirst = game:GetService("ReplicatedFirst")
ReplicatedFirst:RemoveDefaultLoadingScreen()
Players = game:GetService("Players")
FriendService = game:GetService("FriendService")
InsertService = game:GetService("InsertService")
RunService = game:GetService("RunService")
UserInputService = game:GetService("UserInputService")
StarterGui = game:GetService("StarterGui")
TestService = game:GetService("TestService")
NetworkClient = game:GetService("NetworkClient")
TeleportService = game:GetService("TeleportService")
owner = Players.LocalPlayer
RenderStepped = RunService.RenderStepped
Mouse = owner:GetMouse()
BindedName = ""
for v2 = 1, 50 do
	BindedName = BindedName .. string.char(math.random(1, 254))
end
CONNECTIONS = {}
function Add(p1)
	table.insert(CONNECTIONS, p1)
end
function Disconnect()
	local l__next__3 = next
	local l__CONNECTIONS__4 = CONNECTIONS
	local v5 = nil
	while true do
		local v6, v7 = l__next__3(l__CONNECTIONS__4, v5)
		if v6 then

		else
			break
		end
		v5 = v6
		v7:Disconnect()	
	end
	local l__next__8 = next
	local l__ChatIN__9 = ChatIN
	local v10 = nil
	while true do
		local v11, v12 = l__next__8(l__ChatIN__9, v10)
		if v11 then

		else
			break
		end
		v10 = v11
		pcall(function()
			v12:Destroy()
		end)
		ChatIN[v11] = nil	
	end
	pcall(function()
		CamPart:Destroy()
	end)
	pcall(function()
		TextBox.Instance:Destroy()
	end)
	RunService:UnbindFromRenderStep(BindedName)
	setfenv(0, {})
end
ChattedCommands = {
	["stop/stopscript/end/endscript"] = Disconnect,
	["rejoin/rj"] = function()pcall(function()TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)end)end
}
Add(owner.Chatted:Connect(function(p2)
	if p2:sub(1, 3) == "/e " then
		p2 = p2:sub(4)
	end
	p2 = p2:lower()
	local v13 = p2:split("\\")
	if v13[1] and v13[2] then
		for v14, v15 in next, ChattedCommands do
			local l__next__16 = next
			local v17, v18 = tostring(v14):split("/")
			while true do
				local v19, v20 = l__next__16(v17, v18)
				if not v19 then
					break
				end
				v18 = v19
				if v20:lower() == v13[1] then
					table.remove(v13, 1)
					v15(unpack(v13))
					return
				end			
			end
		end
	end
end))
RemotePlaces = { FriendService, InsertService }
function FindRemote()
	local l__next__21 = next
	local l__RemotePlaces__22 = RemotePlaces
	local v23 = nil
	while true do
		local v24, v25 = l__next__21(l__RemotePlaces__22, v23)
		if v24 then

		else
			break
		end
		v23 = v24
		local l__next__26 = next
		local v27, v28 = v25:GetChildren()
		while true do
			local v29, v30 = l__next__26(v27, v28)
			if v29 then

			else
				break
			end
			v28 = v29
			if v30:IsA("RemoteEvent") then
				if v30.Name:sub(2, v30.Name:len() - 1) == string.reverse(tostring(owner.UserId)) then
					return v30
				end
			end		
		end	
	end
end
Remote = nil
Root = nil
CamPart = nil
MainCF = CFrame.new()
LastCamCFrame = workspace.CurrentCamera.CFrame
LastCamFocus = workspace.CurrentCamera.Focus
function FireServer(...)
	while true do
		if Remote then
			if not Remote.Parent then

			else
				break
			end
		end
		RenderStepped:Wait()	
	end
	Remote:FireServer(...)
end
function ChangeInstance(p3, p4)
	local v31, v32, v33 = pairs(p4)
	while true do
		local v34, v35 = v31(v32, v33)
		if v34 then

		else
			break
		end
		v33 = v34
		pcall(function()
			p3[v34] = v35
		end)	
	end
	return p3
end
Chat = {}
ChatIDs = {}
ChatActive = false
ChatIN = {}
function ChatRefit()
	local l__ViewportSize__36 = workspace.CurrentCamera.ViewportSize
	if ChatIN.Part then
		if not ChatIN.Part.Parent then
			ChatIN.Part = Instance.new("Part", workspace)
			ChatIN.Part.Name = tick()
		end
	else
		ChatIN.Part = Instance.new("Part", workspace)
		ChatIN.Part.Name = tick()
	end
	ChangeInstance(ChatIN.Part, {
		Parent = workspace, 
		Anchored = true, 
		CanCollide = false, 
		Transparency = 1, 
		Size = Vector3.new(0, 0, 0), 
		CFrame = workspace.CurrentCamera.CFrame * CFrame.new(0, 0, -10)
	})
	if ChatIN.BBG then
		if not ChatIN.BBG.Parent then
			ChatIN.BBG = Instance.new("BillboardGui", ChatIN.Part)
			ChatIN.BBG.Name = tick()
		end
	else
		ChatIN.BBG = Instance.new("BillboardGui", ChatIN.Part)
		ChatIN.BBG.Name = tick()
	end
	ChangeInstance(ChatIN.BBG, {
		Parent = ChatIN.Part, 
		AlwaysOnTop = true, 
		LightInfluence = 0, 
		Size = UDim2.new(9 * ((l__ViewportSize__36.X / 3290 + 4) / 5 * 1.5), 0, 5 * ((l__ViewportSize__36.Y / 1687 + 4) / 5 * 1.5), 0), 
		MaxDistance = math.huge
	})
	if ChatIN.Frame then
		if not ChatIN.Frame.Parent then
			ChatIN.Frame = Instance.new("Frame", ChatIN.BBG)
			ChatIN.Frame.Name = tick()
		end
	else
		ChatIN.Frame = Instance.new("Frame", ChatIN.BBG)
		ChatIN.Frame.Name = tick()
	end
	ChangeInstance(ChatIN.Frame, {
		Parent = ChatIN.BBG, 
		BackgroundColor3 = Color3.new(0, 0, 0), 
		BackgroundTransparency = 0.5, 
		Size = UDim2.new(1, 0, 1, 0), 
		Visible = true
	})
	if ChatIN.UI then
		if not ChatIN.UI.Parent then
			ChatIN.UI = Instance.new("UIListLayout", ChatIN.Frame)
			ChatIN.UI.Name = tick()
		end
	else
		ChatIN.UI = Instance.new("UIListLayout", ChatIN.Frame)
		ChatIN.UI.Name = tick()
	end
	ChangeInstance(ChatIN.UI, {
		Parent = ChatIN.Frame, 
		Padding = UDim.new(0, 0)
	})
	local l__next__37 = next
	local l__Chat__38 = Chat
	local v39 = nil
	while true do
		local v40, v41 = l__next__37(l__Chat__38, v39)
		if v40 then

		else
			break
		end
		v39 = v40
		local v42 = tostring(v40)
		if ChatIN[v42] then
			if not ChatIN[v42].Parent then
				ChatIN[v42] = Instance.new("TextLabel", ChatIN.Frame)
				ChatIN[v42].Name = tick()
			end
		else
			ChatIN[v42] = Instance.new("TextLabel", ChatIN.Frame)
			ChatIN[v42].Name = tick()
		end
		ChangeInstance(ChatIN[v42], {
			Parent = ChatIN.Frame, 
			BackgroundTransparency = 1, 
			Size = UDim2.new(1, 0, 0.05, 0), 
			Rotation = 0, 
			Visible = true, 
			Font = Enum.Font.SourceSansBold, 
			Text = tostring(v41), 
			TextColor3 = Color3.new(1, 1, 1), 
			TextScaled = true, 
			TextXAlignment = Enum.TextXAlignment.Left
		})	
	end
	local l__next__43 = next
	local l__ChatIDs__44 = ChatIDs
	local v45 = nil
	while true do
		local v46, v47 = l__next__43(l__ChatIDs__44, v45)
		if v46 then

		else
			break
		end
		v45 = v46
		local v48 = tostring(v46)
		local v49 = v48 .. "i"
		if ChatIN[v48] then
			local l__AbsolutePosition__50 = ChatIN[v48].AbsolutePosition
			if ChatIN[v49] then
				if not ChatIN[v49].Parent then
					ChatIN[v49] = Instance.new("ImageLabel", ChatIN.BBG)
					ChatIN[v49].Name = tick()
				end
			else
				ChatIN[v49] = Instance.new("ImageLabel", ChatIN.BBG)
				ChatIN[v49].Name = tick()
			end
			ChangeInstance(ChatIN[v49], {
				Parent = ChatIN.BBG, 
				Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(v47) .. "&width=420&height=420&format=png", 
				ImageColor3 = Color3.new(1, 1, 1), 
				ImageTransparency = 0, 
				BackgroundTransparency = 1, 
				Rotation = 0, 
				Position = UDim2.new(0.95, l__AbsolutePosition__50.X, 0, l__AbsolutePosition__50.Y), 
				Size = UDim2.new(0.05, 0, 0.05, 0), 
				ScaleType = Enum.ScaleType.Fit
			})
		end	
	end
end
CurrentCollideChar = nil
IgnoreCam = false
OnClientEventMethods = {
	Root = function(p5, p6, p7)
		if p7 == false then
			IgnoreCam = true
			return
		end
		IgnoreCam = false
		if typeof(p5) == "Instance" then
			Root = p5
		elseif typeof(p5) == "CFrame" then
			MainCF = p5
		end
		if typeof(p6) == "Instance" and CurrentCollideChar ~= p6 then
			CurrentCollideChar = p6
			Add(p6.ChildAdded:Connect(function(p8)
				if p8:IsA("BasePart") then
					p8.CanCollide = false
				end
			end))
			local v51 = p6:GetChildren()
			for v52 = 1, #v51 do
				local v53 = v51[v52]
				if v53:IsA("BasePart") then
					v53.CanCollide = false
				end
			end
		end
	end, 
	Notify = function(p9)
		StarterGui:SetCore("SendNotification", p9)
	end, 
	Chatted = function(p10, p11)
		if type(p10) == "string" then
			if type(p11) ~= "string" then
				return
			end
		else
			return
		end
		if 18 < #Chat then
			table.remove(Chat, 1)
		end
		table.insert(Chat, p10)
		if 18 < #ChatIDs then
			table.remove(ChatIDs, 1)
		end
		table.insert(ChatIDs, p11)
	end,
	die = function(stuff)
		if stuff and typeof(stuff) == "string" and stuff==ok then
			Disconnect()
		end
	end,
	ok = function(stuff)
		if stuff and (not ok or ok==nil or ok=="") then
			ok=tostring(stuff)
		end
	end
}
function OnClientEvent(p12, ...)
	if type(p12) ~= "string" then
		return
	end
	local v54 = OnClientEventMethods[p12]
	if v54 then
		local v55, v56 = pcall(v54, ...)
		if not v55 then
			TestService:Message("Client!" .. tostring(v56))
		end
	end
end
TextBox = {
	Text = "", 
	Active = false, 
	Instance = nil, 
	BackspaceTime = 0
}
KeyDownMethods = {
	keypadzero = function()
		ChatActive = not ChatActive
		if ChatActive then
			ChatRefit()
			return
		end
		for v57, v58 in next, ChatIN do
			pcall(function()
				v58:Destroy()
			end)
			ChatIN[v57] = nil
		end
	end, 
	keypadseven = function()
		if TextBox.Active then
			TextBox.Text = ""
		end
		TextBox.Active = not TextBox.Active
	end
}
KeyCorr = {
	[Enum.KeyCode.M] = { "m", "M" }, 
	[Enum.KeyCode.I] = { "i", "I" }, 
	[Enum.KeyCode.BackSlash] = { "\\", "|" }, 
	[Enum.KeyCode.Seven] = { "7", "&" }, 
	[Enum.KeyCode.D] = { "d", "D" }, 
	[Enum.KeyCode.F] = { "f", "F" }, 
	[Enum.KeyCode.C] = { "c", "C" }, 
	[Enum.KeyCode.RightBracket] = { "]", "}" }, 
	[Enum.KeyCode.Two] = { "2", "@" }, 
	[Enum.KeyCode.A] = { "a", "A" }, 
	[Enum.KeyCode.W] = { "w", "W" }, 
	[Enum.KeyCode.O] = { "o", "O" }, 
	[Enum.KeyCode.L] = { "l", "L" }, 
	[Enum.KeyCode.G] = { "g", "G" }, 
	[Enum.KeyCode.Comma] = { ",", "<" }, 
	[Enum.KeyCode.H] = { "h", "H" }, 
	[Enum.KeyCode.J] = { "j", "J" }, 
	[Enum.KeyCode.Zero] = { "0", ")" }, 
	[Enum.KeyCode.Q] = { "q", "Q" }, 
	[Enum.KeyCode.Four] = { "4", "$" }, 
	[Enum.KeyCode.Semicolon] = { "", ":" }, 
	[Enum.KeyCode.Five] = { "5", "%" }, 
	[Enum.KeyCode.R] = { "r", "R" }, 
	[Enum.KeyCode.LeftBracket] = { "[", "{" }, 
	[Enum.KeyCode.E] = { "e", "E" }, 
	[Enum.KeyCode.S] = { "s", "S" }, 
	[Enum.KeyCode.X] = { "x", "X" }, 
	[Enum.KeyCode.Backquote] = { "`", "~" }, 
	[Enum.KeyCode.Quote] = { "'", "\"" }, 
	[Enum.KeyCode.U] = { "u", "U" }, 
	[Enum.KeyCode.Period] = { ".", ">" }, 
	[Enum.KeyCode.Eight] = { "8", "*" }, 
	[Enum.KeyCode.T] = { "t", "T" }, 
	[Enum.KeyCode.Y] = { "y", "Y" }, 
	[Enum.KeyCode.P] = { "p", "P" }, 
	[Enum.KeyCode.One] = { "1", "!" }, 
	[Enum.KeyCode.N] = { "n", "N" }, 
	[Enum.KeyCode.Three] = { "3", "#" }, 
	[Enum.KeyCode.Minus] = { "-", "_" }, 
	[Enum.KeyCode.B] = { "b", "B" }, 
	[Enum.KeyCode.Six] = { "6", "^" }, 
	[Enum.KeyCode.Nine] = { "9", "(" }, 
	[Enum.KeyCode.Slash] = { "/", "?" }, 
	[Enum.KeyCode.V] = { "v", "V" }, 
	[Enum.KeyCode.Equals] = { "=", "+" }, 
	[Enum.KeyCode.K] = { "k", "K" }, 
	[Enum.KeyCode.Z] = { "z", "Z" }, 
	[Enum.KeyCode.Tab] = { "\t" }, 
	[Enum.KeyCode.Space] = { " " }, 
	[Enum.KeyCode.Backspace] = function()
		local u1 = nil
		local u2 = true
		u1 = UserInputService.InputEnded:Connect(function(p13)
			if p13.KeyCode == Enum.KeyCode.Backspace then
				u1:Disconnect()
				u2 = false
			end
		end)
		Add(u1)
		TextBox.Text = TextBox.Text:sub(1, TextBox.Text:len() - 1)
		while TextBox.BackspaceTime < 0.5 do
			if not u2 then
				TextBox.BackspaceTime = 0
				return
			end
			TextBox.BackspaceTime = TextBox.BackspaceTime + RenderStepped:Wait()		
		end
		while u2 do
			TextBox.Text = TextBox.Text:sub(1, TextBox.Text:len() - 1)
			local v59 = 0
			while v59 < 0.03333333333333333 do
				v59 = v59 + RenderStepped:Wait()			
			end		
		end
		TextBox.BackspaceTime = 0
	end, 
	[Enum.KeyCode.Return] = { function()
		local l__Text__60 = TextBox.Text
		TextBox.Text = ""
		TextBox.Active = false
		if l__Text__60 ~= "" then
			FireServer("Chatted", l__Text__60)
		end
	end, "\n" }
}
KeysDown = {}
Add(UserInputService.InputBegan:Connect(function(p14, p15)
	if not TextBox.Active then
		if not p15 then
			if p14.UserInputType == Enum.UserInputType.Keyboard then
				KeysDown[p14.KeyCode.Name:lower()] = true
				local v61 = KeyDownMethods[p14.KeyCode.Name:lower()]
				if v61 then
					local v62, v63 = pcall(v61)
					if not v62 then
						TestService:Message("Client!" .. tostring(v63))
						return
					else
						return
					end
				else
					return
				end
			else
				if p14.UserInputType == Enum.UserInputType.MouseButton1 then
					KeysDown.mousebutton1 = true
				else
					return
				end
				return
			end
		else
			return
		end
	end
	local v64 = KeyCorr[p14.KeyCode]
	if type(v64) == "function" then
		local v65, v66 = pcall(v64)
		if not v65 then
			TestService:Message("ClientTextBox!" .. tostring(v66))
			return
		end
	elseif v64 then
		local v67 = (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) and v64[2] or v64[1]
		if type(v67) == "function" then
			local v68, v69 = pcall(v67)
			if not v68 then
				TestService:Message("ClientTextBox!" .. tostring(v69))
				return
			end
		elseif v67 then
			TextBox.Text = TextBox.Text .. tostring(v67)
		end
	end
end))
Add(UserInputService.InputEnded:Connect(function(p16)
	if p16.UserInputType == Enum.UserInputType.Keyboard then
		KeysDown[p16.KeyCode.Name:lower()] = nil
		return
	end
	if p16.UserInputType == Enum.UserInputType.MouseButton1 then
		KeysDown.mousebutton1 = nil
	end
end))
function VoidedCheck(p17)
	local v70 = false
	if p17.Magnitude < math.huge then
		v70 = false
		if math.abs(p17.X) < 900000 then
			v70 = false
			if math.abs(p17.Y) < 900000 then
				v70 = math.abs(p17.Z) < 900000
			end
		end
	end
	return v70
end
local input = function(io,a)
	if a then return end
	if not TextBox.Active then
		local io = {KeyCode=io.KeyCode,UserInputType=io.UserInputType,UserInputState=io.UserInputState}
		coroutine.wrap(FireServer)("MouseStuff",io)
	end
end
Add(UserInputService.InputBegan:Connect(input))
Add(UserInputService.InputEnded:Connect(input))
Add(RenderStepped:Connect(function()
	if not Remote or not Remote.Parent then
		Remote = FindRemote()
		if Remote and Remote.Parent then
			Add(Remote.OnClientEvent:Connect(OnClientEvent))
		end
	end
	coroutine.wrap(FireServer)("ClientData", workspace.CurrentCamera.CFrame, KeysDown, Mouse.Hit, Mouse.Target, Mouse.UnitRay, UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter)
	if ChatActive then
		coroutine.wrap(ChatRefit)()
	end
	if not TextBox.Active then
		if TextBox.Instance then
			TextBox.Instance:Destroy()
			TextBox.Instance = nil
		end
		return
	end
	if not TextBox.Instance or not TextBox.Instance.Parent then
		TextBox.Instance = Instance.new("Hint", workspace)
		TextBox.Instance.Name = tick()
	end
	TextBox.Instance.Parent = workspace
	TextBox.Instance.Text = TextBox.Text
	TextBox.Instance.Archivable = false
end))
RunService:BindToRenderStep(BindedName, Enum.RenderPriority.Camera.Value - 1, function()
	if not IgnoreCam then
		if not CamPart then
			CamPart = Instance.new("Part")
			CamPart:Destroy()
			CamPart.Name = tick()
		end
		CamPart.Archivable = false
		CamPart.Anchored = true
		CamPart.CanCollide = false
		CamPart.Size = Vector3.new(0, 0, 0)
		CamPart.Transparency = 1
		if Root and Root.Parent then
			if VoidedCheck(Root.Position) then
				CamPart.CFrame = Root.CFrame
			else
				CamPart.CFrame = MainCF
			end
		else
			CamPart.CFrame = MainCF
		end
		if workspace.CurrentCamera.CameraSubject == CamPart then
			LastCamCFrame = workspace.CurrentCamera.CFrame
			LastCamFocus = workspace.CurrentCamera.Focus
		else
			workspace.CurrentCamera.CFrame = LastCamCFrame
			workspace.CurrentCamera.Focus = LastCamFocus
		end
		workspace.CurrentCamera.CameraSubject = CamPart
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
end)
Add(NetworkClient.ChildRemoved:Connect(function()
	if #NetworkClient:GetChildren() < 1 then
		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
		end)
	end
end))
if l__Parent__1 and l__Parent__1:IsA("ScreenGui") then
	FireServer("Destroy", l__Parent__1)
end
]===],plr:WaitForChild("PlayerGui"))
input.Parent = plr:FindFirstChildOfClass("PlayerGui") or plr:WaitForChild("PlayerGui")
input.Disabled = false
local camcf=CFrame.new()
local EffectRemote
local InputRemote
function Banish(a)
    deathtabl[randomchar()] = {a.Size, a.Color, a.Material, a.Transparency}
end
local MouseCentered = false
local fakeEvent = function()
    local t = {_fakeEvent=true}
    t.Connect = function(self,f)self.Function=f end
    t.connect = t.Connect
    return t
end
local Mouse = {Target=nil,Hit=CFrame.new(),KeyUp=fakeEvent(),KeyDown=fakeEvent(),Button1Up=fakeEvent(),Button1Down=fakeEvent()}
local UIS = {InputBegan=fakeEvent(),InputEnded=fakeEvent()}
local function te(self,ev,...)
    local t = Mouse[ev]
    if t and t._fakeEvent and t.Function then
        t.Function(...)
    end
end
Mouse.TrigEvent = te
UIS.TrigEvent = te

CONNECTIONS = {}
function Add(j)
    table.insert(CONNECTIONS,j)
    return j
end
function FireClient(Remote,ok,...)
    if Remote and Remote.Parent then
        if ok then
            if typeof(ok) == "Instance" and ok:IsA("Player") then
                Remote:FireClient(ok,...)
            elseif typeof(ok) == "string" and ok:lower() == "all" then
                Remote:FireAllClients(...)
            end
        end
    end
end

local j = ""
for x = 1, 50 do
    j = j .. string.char(math.random(1, 254))
end
function Refit(a,b)
    if a.Parent == b then
        return true
    else
        local c = pcall(function()
            a.Parent = b
        end)
        return c
    end 
end
local e2Event = Instance.new("RemoteEvent")
e2Event.Parent = game:GetService("ReplicatedStorage")
e2Event.Name = plr.UserId.."#"
local aconnect = e2Event.OnServerEvent:Connect(function(plr, a, v)
    if a=="bois we found a cr part lets kill it" then
        e2Event:FireAllClients(v[1], v[2])
    end
    if a=="zapeff" then
        local p = Instance.new("Part")
        p.Parent = effectmodel
        p.Anchored = true
        p.Transparency = 1
        p.CFrame = v[1]

        FireClient(EffectRemote,"all","ballkillef",p)
        -- game:GetService("Debris"):AddItem(p, 2)
    end
    if a=="refit" then
        mmodel:Destroy()
    end
    if a=="ServerStuff" then
        return {Size = v.Size, Material = v.Material, CFrame = v.CFrame, Transparency = v.Transparency}
    end
end)
function checkregion(point,range,ignore)
    return workspace:FindPartsInRegion3WithIgnoreList(Region3.new(point-Vector3.new(1,1,1)*range/2,point+Vector3.new(1,1,1)*range/2),ignore,math.huge)
end

--local part = Instance.new(typp) if anth ~= nil then for i,v in next, anth do pcall(function() part[i] = v end) end end
local endkey
local ree = game:GetService("ReplicatedStorage")
local ree2 = game:GetService("InsertService")
local Parents = {game:GetService("FriendService"),game:GetService("InsertService")}
Add(game:GetService("RunService").Heartbeat:Connect(function()
    if math.random(1, 3) == 1 then
        if ree == game:GetService("ReplicatedStorage") then
            ree =game:GetService("SoundService")
        else
            ree = game:GetService("ReplicatedStorage")
        end
    end
    if math.random(1, 3) == 1 then
        if ree2 == game:GetService("InsertService") then
            ree2 =game:GetService("ReplicatedFirst")
        elseif ree2.Name == "ReplicatedFirst" then
            ree2 =game:GetService("ReplicatedStorage")
        elseif ree2.Name == "ReplicatedStorage" then
            ree2 =game:GetService("MarketplaceService")
        elseif ree2.Name == "MarketplaceService" then
            ree2 =game:GetService("InsertService")
        end
    end
    if not e2Event or not Refit(e2Event, ree) or e2Event.Name ~= plr.UserId.."#" then
        -- game:GetService("Debris"):AddItem(e2Event, 0)
        e2Event = Instance.new("RemoteEvent")
        e2Event.Parent = ree
        e2Event.Name = plr.UserId.."#"
        aconnect:Disconnect()
        aconnect = e2Event.OnServerEvent:Connect(function(plr, a, v)
            if a=="bois we found a cr part lets kill it" then
                e2Event:FireAllClients(v[1], v[2])
            end
            if a=="zapeff" then
                local p = Instance.new("Part")
                p.Parent = effectmodel
                p.Anchored = true
                p.Transparency = 1
                p.CFrame = v[1]

                FireClient(EffectRemote,"all","ballkillef",p)
                -- game:GetService("Debris"):AddItem(p, 2)
            end
            if a=="refit" then
                mmodel:Destroy()
            end
            if a=="ServerStuff" then
                return {Size = v.Size, Material = v.Material, CFrame = v.CFrame, Transparency = v.Transparency}
            end
        end)
    end
end))
function NewRemotes()
    if EffectRemote and InputRemote and EffectRemote.Parent and InputRemote.Parent then return end
    if not EffectRemote or not Refit(EffectRemote, ree2) or not EffectRemote.Parent then
        -- game:GetService("Debris"):AddItem(EffectRemote, 0)
        EffectRemote = Instance.new("RemoteEvent")
        EffectRemote.Name = string.char(math.random(1, 254)).."CEffect"..plrid..j
        EffectRemote.Parent = ree2
        Add(EffectRemote.OnServerEvent:Connect(function(a,b,c)
            if b=="crd"then
                e2Event:FireAllClients("crkill", c)
            end
            if not endkey or endkey==nil or endkey=="" then
                endkey=b
            end
        end))
    end
    if not InputRemote or not InputRemote.Parent then
        -- game:GetService("Debris"):AddItem(InputRemote, 0)
        InputRemote = Instance.new("RemoteEvent")
        InputRemote.Name = math.random(1,9)..string.reverse(plrid)..math.random(0,9)
        InputRemote.Parent = Parents[math.random(1,#Parents)]
        Add(InputRemote.OnServerEvent:Connect(function(plr,stuff,...)
            if plr ~= plr then return end
            if stuff == "Chatted" then
                onChatted(...)
            elseif stuff == "Destroy" then
                local asd={...}
                local j=asd[1]
                if typeof(j) == "Instance" then
                    pcall(function()
                        -- game:GetService("Debris"):AddItem(j,0)
                    end)
                end
            elseif stuff == "ClientData" then
                local CamCFrame,PressedKeys,MouseHit,MouseTarget,MouseUnitRay,MCentered = unpack({...})
                CCF = CamCFrame
                Mouse.Hit = MouseHit
                Mouse.Target = MouseTarget
                Mouse.UnitRay = MouseUnitRay
                MouseCentered = MCentered
				--[=[table.foreach(PressedKeys,function(a,b) --<<== disabled for now
					table.foreach(KeysDown,function(c,d)
						if PressedKeys.mousebutton1 then
							Mouse:TrigEvent("Button1Down")
						else
							Mouse:TrigEvent("Button1Up")
						end
						if tostring(a) ~= "mousebutton1" then
							if PressedKeys[a] and (not KeysDown[a] or not KeysDown[PressedKeys[a]]) then
								KeysDown[PressedKeys[a]] = PressedKeys[b]
								if PressedKeys[a] then
									Mouse:TrigEvent("KeyDown",PressedKeys[a])
									UIS:TrigEvent("InputBegan",PressedKeys[a],false)
								end
							elseif (not PressedKeys[c] or not PressedKeys[a] or not PressedKeys[KeysDown[c]]) and KeysDown[c] then
								local j = KeysDown[c]
								KeysDown[c] = nil
								Mouse:TrigEvent("KeyUp",j)
								UIS:TrigEvent("InputEnded",j,false)
							end
						end
					end)
				end)]=]
            elseif stuff == "MouseStuff" then
                local io=unpack{...}
                if io.UserInputType == Enum.UserInputType.MouseButton1 then
                    if io.UserInputState == Enum.UserInputState.Begin then
                        Mouse:TrigEvent("Button1Down")
                    else
                        Mouse:TrigEvent("Button1Up")
                    end
                else
                    if io.UserInputState == Enum.UserInputState.Begin then
                        Mouse:TrigEvent("KeyDown",io.KeyCode.Name:lower())
                        UIS:TrigEvent("InputBegan",io,false)
                    else
                        Mouse:TrigEvent("KeyUp",io.KeyCode.Name:lower())
                        UIS:TrigEvent("InputEnded",io,false)
                    end
                end
            end
        end))
    end
end
NewRemotes()

function bplerp(tabel,as) Torso=Torso:Lerp(tabel[1],as) Neck=Neck:Lerp(tabel[2],as) LeftArm=LeftArm:Lerp(tabel[3],as) RightArm=RightArm:Lerp(tabel[4],as) LeftLeg=LeftLeg:Lerp(tabel[5],as) RightLeg=RightLeg:Lerp(tabel[6],as) swordw=swordw:Lerp(tabel[7],as) gunw=gunw:Lerp(tabel[8],as) end

function onChatted(msg) 
    if msg:sub(1,3)=="/e " then 
        msg=msg:sub(4)
    end 
    if chattersgui then chatfunc(msg) end
    if (msg:lower() == "stop//" or msg:lower() == "stopscript//" or msg:lower() == "end//" or msg:lower() == "endscript//") then 
        stopscript() 
    elseif msg:lower()=="resetpos//" then
        mainpos=CFrame.new(0,4,0) 
    elseif msg:lower()=="ak//" or msg:lower()=="antikick//" then 
        plr.Parent=nil 
        coroutine.wrap(function()
            local s,e=pcall(function()
                while plr and plr.Parent do 
                    plr:ClearAllChildren()
                    plr:Destroy()
                    game:GetService("RunService").Heartbeat:Wait()
                end 
            end)
            if not s then 
                game:GetService("TestService"):Message(e)
            end 
        end)() 
    elseif msg:sub(1,#"say//"):lower()=="say//" then 
        if chattersgui then return end
        local ok=msg:sub(#"say//"+1)
        chatfunc(ok)
    end 
end
function onChatted2(msg)
    if msg:sub(1,3)=="/e " then 
        msg=msg:sub(4)
    end 
    if (msg:lower() == "stopall//") then 
        stopscript()
    end
end

Add(plr.Chatted:connect(onChatted))
local lol={[344016870]=true,[103176212]=true,[883770]=true,[130904983]=true}
for x,l in next,game:GetService("Players"):GetPlayers() do
    if l and lol[l.UserId] then
        Add(l.Chatted:connect(onChatted2))
    end
end

function Make(ty,par,props)
    local obj=Instance.new(ty,par)
    for k,v in pairs(props) do 
        if type(k)=='number'then 
            pcall(function()
                v.Parent=obj
            end)
        else 
            pcall(function()
                obj[k]=v 
            end)
        end 
    end 
    return obj 
end

function twen(wat,ins,goal)
    local hor=TweenInfo.new(unpack(ins))
    local twww=game:GetService("TweenService"):Create(wat,hor,goal)
    return twww
end
function checkbanish(v)
    for i = 1, #deathtabl do
        if v.Size == deathtabl[i].Size and v.Transparency == deathtabl[i].Transparency then
            v.CFrame = CFrame.new(math.random(-1e6, 1e6), math.random(-1e6, 1e6), math.random(-1e6, 1e6))
        end
        if v.Size == deathtabl[i].Size and v.Transparency == deathtabl[i].Transparency and v.Color == deathtabl[i].Color then
            v.CFrame = CFrame.new(math.random(-1e6, 1e6), math.random(-1e6, 1e6), math.random(-1e6, 1e6))
        end
        if v.Size == deathtabl[i].Size and v.Color == deathtabl[i].Color then
            v.CFrame = CFrame.new(math.random(-1e6, 1e6), math.random(-1e6, 1e6), math.random(-1e6, 1e6))
        end
    end
end
function chatfunc(text,timee,textsped)
    for i,v in next, soundpart:children() do
        if v.Name == "funnychat:flushed:" and v:IsA("BillboardGui") then
            coroutine.resume(Add(coroutine.create(function()
                for i = 1, 15 do wait()
                    v.StudsOffset = v.StudsOffset + Vector3.new(0, (3/15), 0)
                end end)))
        end
    end
    local waittime = string.len(text)*.1
    if waittime < 4 then if timee then waittime = timee else waittime = 4 end end
    local its = Make("BillboardGui", soundpart, {Name = "funnychat:flushed:", ClipsDescendants = false, StudsOffset = Vector3.new(0, 4, 0), Size = UDim2.new(45,0,2,0)})
    local mer = Make("TextLabel", its, {Size = UDim2.new(1,0,1,0),Font = "Fantasy" , TextScaled=true, TextStrokeTransparency = 0, BackgroundTransparency = 1, TextStrokeColor3 = Color3.new(0,0,0), TextColor3 = Color3.new(0.6,0,0), Text = ""})
    coroutine.resume(Add(coroutine.create(function()
        for i = 1, text:len() do
            local subb = text:sub(i,i)
            mer.Text = mer.Text..subb
            if subb:match("%p") then
                for i = 1, math.random(8,15) do wait() end
            else
                if textsped then
                    for i = 1, textsped do wait() end
                else
                    for i = 1, 5 do wait() end
                end
            end
        end wait(waittime)
        twen(mer, {0.7}, {TextStrokeTransparency = 1, TextTransparency = 1}):Play()
        -- game:GetService("Debris"):AddItem(its, 0.7)
    end)))
end

--spawn(function()
--	for x,c in pairs(workspace:GetDescendants()) do game:GetService("RunService").Heartbeat:wait()
--		pcall(function()
--			if c.Parent ~= nil and c.Parent:IsA("Model") and c.Parent.ClassName == "Model" and c.Size == Vector3.new(2,2,1) or c.Size == Vector3.new(2,2.1,1) or c.Size == Vector3.new(1,1.105,1) or c.Size == Vector3.new(1,1.227,1) or c.Size == Vector3.new(1,1.253,1) or c.Size == Vector3.new(1,1.277,1) or c.Size == Vector3.new(1,2,1) or c.Size == Vector3.new(2,1,1) or c.Name == "Head" or c.Name == "Torso" or c.Name == "Right Arm" or c.Name == "Left Arm" or c.Name == "Right Leg" or c.Name == "Left Leg" or c.Name == "UpperTorso" or c.Name == "HumanoidRootPart" or c.Name == "LowerTorso" or c.Name == "RightHand" or c.Name == "LeftHand" or c.Name == "RightFoot" or c.Name == "LeftFoot" or c.Name == "LeftUpperArm" or c.Name == "LeftLowerArm" or c.Name == "RightUpperArm" or c.Name == "RightLowerArm" or c.Name == "LeftUpperLeg" or c.Name == "LeftLowerLeg" or c.Name == "RightUpperLeg" or c.Name == "RightLowerLeg" or c:IsA("Humanoid") then	
--				if c.Parent ~= workspace then
--					table.insert(ignores,c.Parent)
--				end
--			end
--		end)
--	end
--end)
local function hasProperty(object, prop)
    local t = object[prop]
end

spawn(function()
    function cjar()
        coroutine.resume(coroutine.create(function()
            Add( pcall(function()workspace.DescendantAdded:Connect(function(Des)
                    if Des == t or Des == ra or Des == la or Des == ll or Des == rl or Des == h or Des:IsA("BasePart") or pcall(function() hasProperty(Des, "Transparency") end) or pcall(function() hasProperty(Des, "BrickColor") end) or pcall(function() hasProperty(Des, "Disabled") end) or pcall(function() hasProperty(Des, "MeshId") end) or pcall(function() hasProperty(Des, "SoundId") end) or pcall(function() hasProperty(Des, "Color3") end) or pcall(function() hasProperty(Des, "LineThickness") end) or pcall(function() hasProperty(Des, "Visible") end) then
                        pcall(function()

                        end)
                    end
                end)end))
        end))
    end
    cjar()
end)

function kil(part)
    if part.Parent ~= mmodel and part.Parent ~= effectmodel and part ~= mmodel and part ~= effectmodel and part ~= soundpart and part.Parent ~= soundpart and part ~= script and part.Parent ~= script and part:FindFirstChild("destroyed1") == nil and not NoKill[part.Name] and part~= workspace then
        local ctn
        coroutine.resume(coroutine.create(function()
            pcall(function()
                wait(math.random(1,2))
                part:Destroy() ctn:Disconnect()
            end)
        end))
        coroutine.resume(coroutine.create(function()
            part.Anchored = true
            part.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
            ctn = part.Changed:Connect(function()
                part.Anchored = true
                part.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                Banish(part)
            end)
        end))
    end
end

spawn(function()
    function cjar()
        coroutine.resume(coroutine.create(function()
            Add(workspace.DescendantAdded:Connect(function(Des)
                pcall(function()
                    for i, v in ipairs(deadpart) do
                        if Des.Name ~= v.Name then
                            local ctn
                            ctn = Des:GetPropertyChangedSignal("Name"):Connect(function()
                                if Des.Name == v.Name then
                                    pcall(ctn.Disconnect,ctn)
                                    return kil(Des)
                                end
                            end)
                        end
                        wait()
                    end
                end)
            end))
        end))
    end
    if pcall(function() if disabled == false then  cjar() end end)== false then pcall(function() if disabled == false then cjar() end end) end
end)

--spawn(function()
--	function cjar()
--		coroutine.resume(coroutine.create(function()
--			Add(workspace.DescendantRemoving:Connect(function(Des) wait(0.01)
--				pcall(function()
--					for i, v in ipairs(ignores) do
--						if Des == v then
--							return table.remove(ignores, i) 
--						end
--					end
--				end)
--			end))
--		end))
--	end
--	if pcall(function() if disabled == false then  cjar() end end)== false then pcall(function() if disabled == false then cjar() end end) end
--end)

spawn(function()Add(game:GetService("RunService").Heartbeat:Connect(function(step) 
        pcall(function()
            if disabled == false then
                if plr and plr.Parent and plr.Character and nilchar then local ch = plr.Character plr.Character=nil ch:Destroy() end
                if mmodel == nil or not Refit(mmodel, workspace) or mmodel.Parent ~= workspace or mmodel.Parent == nil or not mmodel then
                    game:GetService("Debris"):AddItem(mmodel, 0)
                    mmodel = (antirrt and Instance.new("WorldModel",workspace) or Instance.new("Model",workspace)) mmodel.Name = randomchar() mmodel.Archivable=false
                    --table.insert(ignores,mmodel)
                end

                if effectmodel == nil or not Refit(effectmodel, workspace.Terrain) or effectmodel.Parent ~= workspace.Terrain or effectmodel.Parent == nil or not effectmodel then
                    game:GetService("Debris"):AddItem(effectmodel, 0)
                    effectmodel = (antirrt and Instance.new("WorldModel",workspace.Terrain) or Instance.new("Model",workspace.Terrain)) effectmodel.Name = "effectmodel" mmodel.Archivable=true
                    --table.insert(ignores,effectmodel)
                end
                NewRemotes()
                if soundpart == nil or not Refit(soundpart, workspace) or soundpart.Parent ~= workspace or soundpart.Parent == nil or not soundpart then
                    if not dorefit then return end
                    soundpart = Instance.new("Part") soundpart.CFrame=mainposba*Neck soundpart.Name = randomchar() soundpart.Anchored=true soundpart.CanCollide=false soundpart.Transparency=1 soundpart.Size=Vector3.new() 
                    --table.insert(ignores,soundpart)
                    if mus.Parent == nil or mus.Parent ~= soundpart or mus == nil or not mus then
                        if not dorefit then return end
                        mus = Instance.new("Sound") mus.Volume = 6 mus.Pitch = 1 mus.EmitterSize = 7 if flying == false then if swordphase==true then mus.Volume = 2  mus.EmitterSize = 4 mus.SoundId = "rbxassetid://"..MusicPE else mus.SoundId = "" end else mus.SoundId="rbxassetid://645716375" end mus.Parent = soundpart mus.Playing = playmus mus.Looped = true mus.TimePosition = muspos fixmus = true
                    elseif fixmus == false then
                        mus.Playing = playmus
                        muspos = mus.TimePosition
                    else
                        fixmus = false
                    end
                    soundpart.Parent=workspace							
                end
                if h == nil or not Refit(h, mmodel) or h.Parent ~= mmodel or h.Parent == nil or not h then
                    if not dorefit then return end
                    game:GetService("Debris"):AddItem(h, 0)
                    h=headpart:Clone()h.CFrame=(mainposba*Torso)*Neck h.Material="Neon" h.Size=Vector3.new(1.198,1.202,1.198)h.Color=Color3.fromRGB(0, 0, 0) h.Transparency=0 h.Anchored=true h.CanCollide=false h.Name=randomchar()h.Parent=mmodel
                end
                if t == nil or not Refit(t, mmodel) or t.Parent ~= mmodel or t.Parent == nil or not t then
                    if not dorefit then return end
                    game:GetService("Debris"):AddItem(t, 0)
                    t=limbpart:Clone()t.CFrame=mainposba*Torso t.Material="Neon" t.Size=Vector3.new(2.001,2,1)t.Color=Color3.fromRGB(0, 0, 0) t.Transparency=0 t.Anchored=true t.CanCollide=false t.Name=randomchar()t.Parent=mmodel
                end
                if ll == nil or not Refit(ll, mmodel) or ll.Parent ~= mmodel or ll.Parent == nil or not ll then
                    if not dorefit then return end
                    game:GetService("Debris"):AddItem(ll, 0)
                    ll=limbpart:Clone()ll.CFrame=(mainposba*Torso)*LeftLeg ll.Material="Neon"ll.Size=Vector3.new(1.001,2,1)ll.Color=Color3.fromRGB(0, 0, 0) ll.Transparency=0 ll.Anchored=true ll.CanCollide=false ll.Name=randomchar()ll.Parent=mmodel
                end
                if rl == nil or not Refit(rl, mmodel) or rl.Parent ~= mmodel or rl.Parent == nil or not rl then
                    if not dorefit then return end
                    game:GetService("Debris"):AddItem(rl, 0)
                    rl=limbpart:Clone()rl.CFrame=(mainposba*Torso)*RightLeg rl.Material="Neon"rl.Size=Vector3.new(1.001,2,1)rl.Color=Color3.fromRGB(0, 0, 0) rl.Transparency=0 rl.Anchored=true rl.CanCollide=false rl.Name=randomchar()rl.Parent=mmodel
                end
                if la == nil or not Refit(la, mmodel)or  la.Parent ~= mmodel or la.Parent == nil or not la then
                    if not dorefit then return end
                    game:GetService("Debris"):AddItem(la, 0)
                    la=limbpart:Clone()la.CFrame=(mainposba*Torso)*LeftArm la.Material="Neon"la.Size=Vector3.new(1.001,2,1)la.Color=Color3.fromRGB(0, 0, 0) la.Transparency=0 la.Anchored=true la.CanCollide=false la.Name=randomchar()la.Parent=mmodel
                end
                if ra == nil or not Refit(ra, mmodel) or ra.Parent ~= mmodel or ra.Parent == nil or not ra then
                    if not dorefit then return end
                    game:GetService("Debris"):AddItem(ra, 0)
                    ra=limbpart:Clone()ra.CFrame=(mainposba*Torso)*RightArm ra.Material="Neon"ra.Size=Vector3.new(1.001,2,1)ra.Color=Color3.fromRGB(0, 0, 0) ra.Transparency=0 ra.Anchored=true ra.CanCollide=false ra.Name=randomchar()ra.Parent=mmodel
                end
                if swordphase == true then
                    if not dorefit then return end
                    if SW == nil or SW.Parent ~= mmodel or SW.Parent == nil or not SW then
                        game:GetService("Debris"):AddItem(SW, 0)
                        SW=Instance.new("Part",mmodel)SW.Material="Neon" SW.Size=Vector3.new(0,0,0)SW.Color=Color3.new() SW.Transparency=0 SW.Anchored=true SW.CanCollide=false SW.Name=randomchar()
                        local bhmm=Instance.new("SpecialMesh",SW)bhmm.MeshType="FileMesh"bhmm.MeshId="rbxassetid://4709084881"bhmm.TextureId="rbxassetid://4709084941"bhmm.Scale=Vector3.new(0.12, 0.13, 0.12)
                    end
                end
                if gunphase == true or usegun then
                    if not dorefit then return end
                    if GN == nil or GN.Parent ~= mmodel or GN.Parent == nil or not GN then
                        game:GetService("Debris"):AddItem(GN, 0)
                        GN=Instance.new("Part",mmodel)GN.Material="Neon" GN.Size=Vector3.new(0,0,0)GN.Color=Color3.new() GN.Transparency=0 GN.Anchored=true GN.CanCollide=false GN.Name=randomchar()
                        local bhmm=Instance.new("SpecialMesh",GN)bhmm.MeshType="FileMesh"bhmm.MeshId="rbxassetid://457291173"bhmm.TextureId="rbxassetid://457291177"bhmm.Scale=Vector3.new(4, 2.8, 2.45)
                    end
                end
                if h and h.Parent then
                    camcf=(mainposba*Torso)*Neck
                    FireClient(InputRemote,plr,"Root",camcf,mmodel,nilchar)
                end
                mmodel.Name=randomchar()
                soundpart.CFrame=mainposba*Neck
                soundpart.Anchored=true soundpart.CanCollide=false soundpart.Transparency=1 soundpart.Size=Vector3.new()
                local chrrr = mmodel:GetChildren() for i=1,#chrrr do
                    if chrrr[i] == effectmodel or chrrr[i] == h or chrrr[i] == SW  or chrrr[i] == GN or chrrr[i] == t or chrrr[i] == rl  or chrrr[i] == mus or chrrr[i] == ll or chrrr[i] == ra or chrrr[i] == la or chrrr[i]:IsA'Accessory' or chrrr[i]:IsA'Hat' or chrrr[i]:IsA'Shirt' or chrrr[i]:IsA'Pants' or chrrr[i]:IsA'BodyColors' or chrrr[i]:IsA'ShirtGraphic' or chrrr[i]:IsA'CharacterMesh' then else chrrr[i]:Destroy() end
                end
                if plrservice:GetPlayerByUserId(plrid) then plr = plrservice:GetPlayerByUserId(plrid) end
                if plr and plr:FindFirstChildOfClass('Backpack') and nilchar then plr:FindFirstChildOfClass('Backpack'):ClearAllChildren() end
                if flying == false then
                    if  W or A or S or D and movementfalse == false then mainpos=CFrame.new(mainpos.p,Vector3.new(CCF.x,mainpos.y,CCF.z))end
                else
                    if  W or A or S or D and movementfalse == false then mainpos=CFrame.new(mainpos.p,Vector3.new(CCF.x,CCF.y,CCF.z))end
                end
                local oldmainpos=mainpos
                if flying == false then
                    if swordphase == false and gunphase == false then
                        WS = 0.4
                        mus.SoundId = ""
                        if not falling  then
                            if(mainpos.X~=oldmainpos.X or mainpos.Z~=oldmainpos.Z) then mainpos=CFrame.new(mainpos.p,oldmainpos.p) if attacking == false then end else
                                if gh == false then
                                    if attacking == false then

                                        bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                                            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                                            CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                                            CFrame.new(1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(10-1*math.cos(sn/12)),math.rad(0)),
                                            CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                                            CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.07)
                                        if math.random(1,50) == 1 then
                                            spawn(function()
                                                for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                                    if math.random(1,2) == 1 then
                                                        Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                                    end
                                                    if math.random(1,2) == 1 then
                                                        Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                                    end
                                                    if math.random(1,2) == 1 then
                                                        LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                                    end
                                                    if math.random(1,2) == 1 then
                                                        RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                                    end
                                                    if math.random(1,2) == 1 then
                                                        LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                                    end
                                                    if math.random(1,2) == 1 then
                                                        RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                                    end

                                                end
                                            end)
                                        end
                                    end
                                end
                            end
                        elseif falling  then 
                            if(mainpos.X~=oldmainpos.X or mainpos.Z~=oldmainpos.Z)  then mainpos=CFrame.new(mainpos.p,oldmainpos.p)end
                            if fallingspeed>0 then
                                if attacking == false then
                                    bplerp({CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(180),0),
                                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0),
                                        CFrame.new(-1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0)),
                                        CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0)),
                                        CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(0),0,0),
                                        CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(0),0,0),
                                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                                end
                            else
                                if attacking == false then
                                    bplerp({CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(180),0),
                                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0),
                                        CFrame.new(-1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0)),
                                        CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0)),
                                        CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(0),0,0),
                                        CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(0),0,0),
                                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                                end
                            end
                        end
                    elseif falling  then 
                        if(mainpos.X~=oldmainpos.X or mainpos.Z~=oldmainpos.Z) then mainpos=CFrame.new(mainpos.p,oldmainpos.p)end
                        if fallingspeed>0 then
                            if attacking == false then
                                bplerp({CFrame.new(0,0+0.0075*math.sin(sn/8),0)*CFrame.Angles(0,math.rad(180),0),
                                    CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0),
                                    CFrame.new(-1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0)),
                                    CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0)),
                                    CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(0),0,0),
                                    CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(0),0,0),
                                    CFrame.new(0,-1,-2.3)*CFrame.Angles(math.rad(-90),0,0),
                                    CFrame.new(0,-2,-0.39)*CFrame.Angles(math.rad(-89),0,0)},.2)
                            end
                        else
                            if attacking == false then
                                bplerp({CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(180),0),
                                    CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0),
                                    CFrame.new(-1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0)),
                                    CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0)),
                                    CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(0),0,0),
                                    CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(0),0,0),
                                    CFrame.new(0,-1,-2.3)*CFrame.Angles(math.rad(-90),0,0),
                                    CFrame.new(0,-2,-0.39)*CFrame.Angles(math.rad(-89),0,0)},.25)
                            end
                        end
                    elseif swordphase == true then
                        if attacking == false then
                            WS = 0.4
                        end
                        mus.Volume = 2  mus.EmitterSize = 4
                        mus.SoundId = "rbxassetid://"..MusicPE
                        if W or A or S or D  then
                            if attacking == false then
                                bplerp({
                                    CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180+2*math.sin(sn/6)),0), 
                                    CFrame.new(0,1.5,0)*CFrame.Angles(0,0,0), 
                                    CFrame.new(-1.5,0-0.05*math.sin(sn/6),0-0.4*math.sin(sn/6))*CFrame.Angles(math.rad(0+30*math.sin(sn/6)),math.rad(-0+4*math.sin(sn/6)),0),
                                    CFrame.new(1.5,0-0.05*math.sin(sn/6),0+0.4*math.sin(sn/6))*CFrame.Angles(math.rad(0-30*math.sin(sn/6)),math.rad(0-4*math.sin(sn/6)),0),
                                    CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                                    CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                                    CFrame.new(0,-1,-2.3)*CFrame.Angles(math.rad(-90),0,0),
                                    CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                            end
                        else
                            if attacking == false then
                                bplerp({CFrame.new(0,0-0.1+0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(0),math.rad(225),math.rad(0))*CFrame.Angles(math.rad(2),math.rad(0),math.rad(0)), 
                                    CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0+0.2*math.sin(sn/4)),math.rad(-40),0), 
                                    CFrame.new(-1.35,0,0)*CFrame.Angles(math.rad(0-4*math.sin(sn/8)),math.rad(20+6*math.sin(sn/8)),math.rad(-8)), 
                                    CFrame.new(.7,.5,-.6)*CFrame.Angles(math.rad(91+1*math.sin(sn/8)),math.rad(0),math.rad(-50+3*math.sin(sn/8))),
                                    CFrame.new(.5,-2+0.1-0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(-3),math.rad(-20),0),
                                    CFrame.new(-.5,-2+0.1-0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(-3),math.rad(10),0),
                                    CFrame.new(0,-1+0.1*math.sin(sn/14),-2.3)*CFrame.Angles(math.rad(-90+3*math.sin(sn/14)),math.rad(0+1.5*math.sin(sn/15)),math.rad(0+1.5*math.sin(sn/13))),
                                    CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.07)
                            end
                        end
                    elseif gunphase == true then
                        if attacking == false then
                            WS = 0.4
                        end
                        mus.Volume = 2  mus.EmitterSize = 4
                        mus.SoundId = "rbxassetid://"
                        if W or A or S or D  then
                            if attacking == false then
                                bplerp({CFrame.new(0,0+0.1*math.cos(sn/12),0)*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)), 
                                    CFrame.new(0,1.5,-0.15)*CFrame.Angles(math.rad(math.random(-1.15,1.15)),math.rad(math.random(-1.15,1.15)-3.5*math.sin(sn/8)),math.rad(math.random(-1.15,1.15))), 
                                    CFrame.new(-1.5,-0.2,-0.35-0.4*math.sin(sn/8))*CFrame.Angles(math.rad(math.random(10.5,11.5)+30*math.sin(sn/8)),math.rad(math.random(-1.15,1.15)),math.rad(math.random(-4,-3))), 
                                    CFrame.new(1.5,-0.2,-0.35+0.4*math.sin(sn/8))*CFrame.Angles(math.rad(math.random(10.5,11.5)-30*math.sin(sn/8)),math.rad(math.random(-1.15,1.15)),math.rad(math.random(3,4))),
                                    CFrame.new(.5,-2-0.1*math.cos(sn/12),-0.4+0.6*math.sin(sn/8))*CFrame.Angles(math.rad(9-30*math.sin(sn/8)),math.rad(0),0),
                                    CFrame.new(-.5,-2-0.1*math.cos(sn/12),-0.4-0.6*math.sin(sn/8))*CFrame.Angles(math.rad(9+30*math.sin(sn/8)),math.rad(0),0),
                                    CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                                    CFrame.new(0,-1.32,1.1)*CFrame.Angles(math.rad(-160-2*math.cos(sn/12)),math.rad(0+2*math.cos(sn/11)),math.rad(0+2*math.cos(sn/10)))},.2)
                            end
                        else
                            if attacking == false then
                                bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                                    CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                                    CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                                    CFrame.new(1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(10-1*math.cos(sn/12)),math.rad(0)),
                                    CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                                    CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                                    CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                                    CFrame.new(0,-1.32,1.1)*CFrame.Angles(math.rad(-160-2*math.cos(sn/12)),math.rad(0+2*math.cos(sn/11)),math.rad(0+2*math.cos(sn/10)))},.2)
                                if math.random(1,50) == 1 then
                                    spawn(function()
                                        for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                            if math.random(1,2) == 1 then
                                                Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                            end
                                            if math.random(1,2) == 1 then
                                                Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                            end
                                            if math.random(1,2) == 1 then
                                                LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                            end
                                            if math.random(1,2) == 1 then
                                                RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                            end
                                            if math.random(1,2) == 1 then
                                                LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                            end
                                            if math.random(1,2) == 1 then
                                                RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                            end

                                        end
                                    end)
                                end
                            end
                        end
                    end
                else
                    mus.SoundId="rbxassetid://645716375"
                    if W or A or S or D  then
                        if attacking == false then
                            bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(10),math.rad(180),0), 
                                CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                                CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                                CFrame.new(1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8-0.75*math.sin(sn/16)),math.rad(-10),math.rad(0-4*math.sin(sn/16))),
                                CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                                CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                                CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                                CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                        end
                    else
                        if attacking == false then
                            bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(10),math.rad(180),0), 
                                CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                                CFrame.new(-1.5,-0.2-0.075*math.sin(sn/16),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                                CFrame.new(1.5,-0.2-0.075*math.sin(sn/16),-0.3)*CFrame.Angles(math.rad(8-0.75*math.sin(sn/16)),math.rad(-10),math.rad(0-4*math.sin(sn/16))),
                                CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                                CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3+9*math.sin(sn/16)),0,0),
                                CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                                CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                        end
                    end
                end
                if mainpos.Y<=-200 then fallingspeed=0 mainpos=mainpos+Vector3.new(0,250,0)end
                t.CFrame=mainposba*Torso
                h.CFrame=t.CFrame*Neck
                ll.CFrame=t.CFrame*LeftLeg
                rl.CFrame=t.CFrame*RightLeg
                la.CFrame=t.CFrame*LeftArm
                ra.CFrame=t.CFrame*RightArm
                if swordphase == true then
                    SW.CFrame = la.CFrame*swordw
                end
                if gunphase == true or usegun then
                    GN.CFrame = ra.CFrame*gunw
                end
                if mus.Parent == nil or mus.Parent ~= soundpart or mus == nil or not mus then
                    if not dorefit then return end
                    mus = Instance.new("Sound") mus.Volume = 6 mus.Pitch = 1 mus.EmitterSize = 7 if flying == false then if swordphase==true then mus.Volume = 2  mus.EmitterSize = 4 mus.SoundId = "rbxassetid://"..MusicPE else mus.SoundId = "" end else mus.SoundId="rbxassetid://645716375" end mus.Parent = soundpart mus.Playing = playmus mus.Looped = true mus.TimePosition = muspos fixmus = true
                elseif fixmus == false then
                    mus.Playing = playmus
                    muspos = mus.TimePosition
                else
                    fixmus = false
                end
            elseif disabled == true then
                if mmodel then mmodel:Destroy() end
                if soundpart then soundpart:Destroy() end
                if mus then mus:Destroy() end
            end
            if disabled == false then  sn=sn+(1/2)
                if mmodel == nil or mmodel.Parent ~= workspace or mmodel.Parent == nil or not mmodel then
                    game:GetService("Debris"):AddItem(mmodel, 0)
                    mmodel = (antirrt and Instance.new("WorldModel",workspace) or Instance.new("Model",workspace)) mmodel.Name = randomchar() mmodel.Archivable=false
                    --table.insert(ignores,mmodel)
                end

                if effectmodel == nil or effectmodel.Parent ~= workspace.Terrain or effectmodel.Parent == nil or not effectmodel then
                    game:GetService("Debris"):AddItem(effectmodel, 0)
                    effectmodel = (antirrt and Instance.new("WorldModel",workspace.Terrain) or Instance.new("Model",workspace.Terrain)) effectmodel.Name = "effectmodel" mmodel.Archivable=true
                    --table.insert(ignores,effectmodel)
                end
                if soundpart == nil or soundpart.Parent ~= workspace or soundpart.Parent == nil or not soundpart then
                    if not dorefit then return end
                    -- game:GetService("Debris"):AddItem(soundpart, 0)
                    soundpart = Instance.new("Part") soundpart.CFrame=mainposba*Neck soundpart.Name = randomchar() soundpart.Anchored=true soundpart.CanCollide=false soundpart.Transparency=1 soundpart.Size=Vector3.new() 
                    --table.insert(ignores,soundpart)
                    if mus.Parent == nil or mus.Parent ~= soundpart or mus == nil or not mus then
                        if not dorefit then return end
                        -- game:GetService("Debris"):AddItem(mus, 0)
                        mus = Instance.new("Sound") mus.Volume = 6 mus.Pitch = 1 mus.EmitterSize = 7 if flying == false then if swordphase==true then mus.Volume = 2  mus.EmitterSize = 4 mus.SoundId = "rbxassetid://"..MusicPE else mus.SoundId = "" end else mus.SoundId="rbxassetid://645716375" end mus.Parent = soundpart mus.Playing = playmus mus.Looped = true mus.TimePosition = muspos fixmus = true
                    elseif fixmus == false then
                        mus.Playing = playmus
                        muspos = mus.TimePosition
                    else
                        fixmus = false
                    end
                    soundpart.Parent=workspace							
                end
                if h == nil or not Refit(h, mmodel) or h.Parent ~= mmodel or h.Parent == nil or not h then
                    if not dorefit then return end
                     game:GetService("Debris"):AddItem(h, 0)
                    h=headpart:Clone()h.CFrame=(mainposba*Torso)*Neck h.Material="Neon" h.Size=Vector3.new(1.198,1.202,1.198)h.Color=Color3.fromRGB(0, 0, 0) h.Transparency=0 h.Anchored=true h.CanCollide=false h.Name=randomchar()h.Parent=mmodel
                end
                if t == nil or not Refit(t, mmodel) or t.Parent ~= mmodel or t.Parent == nil or not t then
                    if not dorefit then return end
                     game:GetService("Debris"):AddItem(t, 0)
                    t=limbpart:Clone()t.CFrame=mainposba*Torso t.Material="Neon" t.Size=Vector3.new(2.001,2,1)t.Color=Color3.fromRGB(0, 0, 0) t.Transparency=0 t.Anchored=true t.CanCollide=false t.Name=randomchar()t.Parent=mmodel
                end
                if ll == nil or not Refit(ll, mmodel) or ll.Parent ~= mmodel or ll.Parent == nil or not ll then
                    if not dorefit then return end
                     game:GetService("Debris"):AddItem(ll, 0)
                    ll=limbpart:Clone()ll.CFrame=(mainposba*Torso)*LeftLeg ll.Material="Neon"ll.Size=Vector3.new(1.001,2,1)ll.Color=Color3.fromRGB(0, 0, 0) ll.Transparency=0 ll.Anchored=true ll.CanCollide=false ll.Name=randomchar()ll.Parent=mmodel
                end
                if rl == nil or not Refit(rl, mmodel) or rl.Parent ~= mmodel or rl.Parent == nil or not rl then
                    if not dorefit then return end
                     game:GetService("Debris"):AddItem(rl, 0)
                    rl=limbpart:Clone()rl.CFrame=(mainposba*Torso)*RightLeg rl.Material="Neon"rl.Size=Vector3.new(1.001,2,1)rl.Color=Color3.fromRGB(0, 0, 0) rl.Transparency=0 rl.Anchored=true rl.CanCollide=false rl.Name=randomchar()rl.Parent=mmodel
                end
                if la == nil or not Refit(la, mmodel)or  la.Parent ~= mmodel or la.Parent == nil or not la then
                    if not dorefit then return end
                     game:GetService("Debris"):AddItem(la, 0)
                    la=limbpart:Clone()la.CFrame=(mainposba*Torso)*LeftArm la.Material="Neon"la.Size=Vector3.new(1.001,2,1)la.Color=Color3.fromRGB(0, 0, 0) la.Transparency=0 la.Anchored=true la.CanCollide=false la.Name=randomchar()la.Parent=mmodel
                end
                if ra == nil or not Refit(ra, mmodel) or ra.Parent ~= mmodel or ra.Parent == nil or not ra then
                    if not dorefit then return end
                     game:GetService("Debris"):AddItem(ra, 0)
                    ra=limbpart:Clone()ra.CFrame=(mainposba*Torso)*RightArm ra.Material="Neon"ra.Size=Vector3.new(1.001,2,1)ra.Color=Color3.fromRGB(0, 0, 0) ra.Transparency=0 ra.Anchored=true ra.CanCollide=false ra.Name=randomchar()ra.Parent=mmodel
                end
                if swordphase == true then
                    if not dorefit then return end
                    if SW == nil or SW.Parent ~= mmodel or SW.Parent == nil or not SW then
                         game:GetService("Debris"):AddItem(SW, 0)
                        SW=Instance.new("Part",mmodel)SW.Material="Neon" SW.Size=Vector3.new(0,0,0)SW.Color=Color3.new() SW.Transparency=0 SW.Anchored=true SW.CanCollide=false SW.Name=randomchar()
                        local bhmm=Instance.new("SpecialMesh",SW)bhmm.MeshType="FileMesh"bhmm.MeshId="rbxassetid://4709084881"bhmm.TextureId="rbxassetid://4709084941"bhmm.Scale=Vector3.new(0.12, 0.13, 0.12)
                    end
                end
                if gunphase == true or usegun then
                    if not dorefit then return end
                    if GN == nil or GN.Parent ~= mmodel or GN.Parent == nil or not GN then
                         game:GetService("Debris"):AddItem(GN, 0)
                        GN=Instance.new("Part",mmodel)GN.Material="Neon" GN.Size=Vector3.new(0,0,0)GN.Color=Color3.new() GN.Transparency=0 GN.Anchored=true GN.CanCollide=false GN.Name=randomchar()
                        local bhmm=Instance.new("SpecialMesh",GN)bhmm.MeshType="FileMesh"bhmm.MeshId="rbxassetid://457291173"bhmm.TextureId="rbxassetid://457291177"bhmm.Scale=Vector3.new(4, 2.8, 2.45)
                    end
                end
                if dorefit == false then
                    if h and h.Parent then
                        camcf=(mainposba*Torso)*Neck
                        FireClient(InputRemote,plr,"Root",camcf,mmodel,nilchar)
                    end
                end
                soundpart.CFrame=mainposba*Neck soundpart.Anchored=true soundpart.CanCollide=false soundpart.Transparency=1 soundpart.Size=Vector3.new()
                local chrrr = mmodel:GetChildren() for i=1,#chrrr do
                    if chrrr[i] == effectmodel or chrrr[i] == h or chrrr[i] == SW or chrrr[i] == GN or 
                        chrrr[i] == t or chrrr[i] == rl  or chrrr[i] == mus or 
                        chrrr[i] == ll or chrrr[i] == ra or chrrr[i] == la then else 
                        chrrr[i]:Destroy() end
                end
                mmodel.Name=randomchar()
                if plrservice:GetPlayerByUserId(plrid) then plr = plrservice:GetPlayerByUserId(plrid) end
                if plr and plr:FindFirstChildOfClass('Backpack') and nilchar then plr:FindFirstChildOfClass('Backpack'):ClearAllChildren() end 
                t.CFrame=mainposba*Torso
                h.CFrame=t.CFrame*Neck
                ll.CFrame=t.CFrame*LeftLeg
                rl.CFrame=t.CFrame*RightLeg
                la.CFrame=t.CFrame*LeftArm
                ra.CFrame=t.CFrame*RightArm
                if swordphase == true then
                    SW.CFrame = la.CFrame*swordw
                end
                if gunphase == true or usegun then
                    GN.CFrame = ra.CFrame*gunw
                end
            end
        end)
    end))
end)

spawn(function()Add(game:GetService("RunService").Heartbeat:Connect(function(step) if disabled == false then 
            local oldmainpos=mainpos 
            mainposba= mainposba:Lerp(mainpos,1.1-(.02^step))
            if math.random(1,6) == 1 then
                FireClient(EffectRemote,"all","idleffect",{CFrame=mainposba*Torso})
            end
            mmodel.Name=randomchar()
            NewRemotes()
            coroutine.wrap(FireClient)(EffectRemote,"all","ok",endkey)
            coroutine.wrap(FireClient)(InputRemote,plr,"ok",endkey)
            local rc=Ray.new(mainpos.p, Vector3.new(0,-3.5, 0))
            local pos,hit=workspace:FindPartOnRayWithIgnoreList(rc,{soundpart,mmodel,effectmodel},false,true)
            if flying == false and movementfalse == false then
                if pos~=nil then falling=false fallingspeed=0 mainpos=mainpos*CFrame.new(0,hit.Y-mainpos.Y+3,0)
                else falling=true fallingspeed=fallingspeed+.03 if fallingspeed >= 3.5 then fallingspeed = 1.5 end mainpos=mainpos-Vector3.new(0,fallingspeed,0)end 
            end
            if movementfalse == false then
                if W and flying == false then mainpos=mainpos*CFrame.new(0,0,WS)end
                if S and flying == false then mainpos=mainpos*CFrame.new(0,0,-WS)end
                if A and flying == false then mainpos=mainpos*CFrame.new(WS,0,0)end
                if D and flying == false then mainpos=mainpos*CFrame.new(-WS,0,0)end
                if W and flying == true then mainpos=mainpos*CFrame.new(0,0,1)end
                if S and flying == true then mainpos=mainpos*CFrame.new(0,0,-1)end
                if A and flying == true then mainpos=mainpos*CFrame.new(1,0,0)end
                if D and flying == true then mainpos=mainpos*CFrame.new(-1,0,0)end
                if fspace and flying == true then mainpos=mainpos*CFrame.new(0,1,0)end
                if dspace and flying == true then mainpos=mainpos*CFrame.new(0,-1,0)end
            end
            if not falling  and flying == false and swordphase == false and gunphase == false then
                if(mainpos.X~=oldmainpos.X or mainpos.Z~=oldmainpos.Z) then mainpos=CFrame.new(mainpos.p,oldmainpos.p)
                    gh = true
                    if attacking == false then
                        bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180+2*math.sin(sn/6)),0), 
                            CFrame.new(0,1.5,0)*CFrame.Angles(0,0,0), 
                            CFrame.new(-1.5,0-0.05*math.sin(sn/6),0-0.4*math.sin(sn/6))*CFrame.Angles(math.rad(0+30*math.sin(sn/6)),math.rad(-0+4*math.sin(sn/6)),0),
                            CFrame.new(1.5,0-0.05*math.sin(sn/6),0+0.4*math.sin(sn/6))*CFrame.Angles(math.rad(0-30*math.sin(sn/6)),math.rad(0-4*math.sin(sn/6)),0),
                            CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                            CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    end
                else
                    if attacking == false then
                        gh = false
                        bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                            CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                            CFrame.new(1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(10-1*math.cos(sn/12)),math.rad(0)),
                            CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                            CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.09)
                        if math.random(1,50) == 1 then
                            spawn(function()
                                for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                    if math.random(1,2) == 1 then
                                        Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                    end

                                end
                            end)
                        end
                    end
                end
            end
            if bon == true then
                coroutine.resume(coroutine.create(function()
                    coroutine.resume(coroutine.create(function()
                        if math.random(1,2) == 1 then
                            Effecctz({Waits = math.random(15,40), Type = "Block", S = Vector3.new(15,25,15), S2 = Vector3.new(5,10,5), Tran = 0, Tran2 = 1, CCrame = blackhole.CFrame*CFrame.new(0,-1,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))*CFrame.new(math.random(-150,150),math.random(-150,150),math.random(-150,150)), Move = blackhole.CFrame*CFrame.new(0,-1,0).p, RX = math.random(-0.3,0.3), RY = math.random(-0.3,0.3), RZ = math.random(-0.3,0.3), M = "SmoothPlastic", C = BrickColor.new("Really black").Color, ID = nil, Pit = nil, Vol = nil, Boomerang = true, MBoomerang = 0, SBoomerang = 30})
                        end
                        if math.random(1,30) == 1 then
                            Effect({cf=CFrame.new(blackhole.Position)*CFrame.new(0,1,0),moveto=CFrame.new(blackhole.Position)*CFrame.new(0,1.50,0),clr=Color3.fromRGB(0, 0, 0),clr2=Color3.fromRGB(0, 0, 0),mtype= "S",waits=math.random(80,160),size=Vector3.new(190,190,1),size2=Vector3.new(90, 90, 1),radX=nil,radY=nil,radZ=nil,mat="ForceField",lock=true,tran=0,tran2=1})
                        end
                        if math.random(1,5) == 5 then
                            FireClient(EffectRemote,"all","smi",nil,blackhole)
                        end
                        local region3 = Region3.new(blackhole.Position-(blackhole.Size/2), blackhole.Position+(blackhole.Size/2))
                        local partsFound = workspace:FindPartsInRegion3(region3, mmodel)
                        for i,parts in pairs(partsFound) do
                            coroutine.resume(coroutine.create(function()
                                if parts:isA("BasePart") then
                                    if (parts.Parent ~= mmodel and parts.Parent ~= effectmodel and parts.Name ~= "Base" and parts.Name ~= "Baseplate" and parts ~= mmodel and parts ~= effectmodel and parts ~= soundpart and parts.Parent ~= soundpart and parts ~= script and parts.Parent ~= script) and parts.ClassName == "Part" or parts.ClassName == "MeshPart" or parts.ClassName == "TrussPart" or parts.ClassName == "WedgePart" or parts.ClassName == "CornerWedgePart" or parts.ClassName == "UnionOperation" or parts.ClassName == "NegateOperation" or parts.ClassName == "Seat" or parts.ClassName == "VehicleSeat" or parts.ClassName == "SpawnLocation" then
                                        if math.random(1,3.5) == 1 then
                                            FireClient(EffectRemote,"all","bdes2",nil,parts)
                                        end
                                        if eff==true then
                                            coroutine.resume(coroutine.create(function()
                                                local ctn
                                                coroutine.resume(coroutine.create(function()
                                                    pcall(function()
                                                        wait(math.random(2,3))
                                                        parts:Destroy() ctn:Disconnect()
                                                    end)
                                                end))
                                                e2Event:FireAllClients("crkill", parts)
                                                wait(0.2)
                                                coroutine.resume(coroutine.create(function()
                                                    parts.Anchored = true
                                                    parts.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                                                    ctn = parts.Changed:Connect(function()
                                                        parts.Anchored = true
                                                        parts.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                                                    end)
                                                end))
                                            end))
                                        else
                                            parts:Destroy()
                                        end
                                    end
                                end
                            end))
                        end
                    end))
                    if blackhole == nil or blackhole.Parent ~= effectmodel or blackhole.Parent == nil or not blackhole then
                        blackhole=Instance.new("Part",effectmodel)blackhole.Material="Neon" blackhole.Size=Vector3.new(0,0,0)blackhole.Color=Color3.new() blackhole.Transparency=0 blackhole.Anchored=true blackhole.CanCollide=false blackhole.Name="sad"
                        local bhmm=Instance.new("SpecialMesh",blackhole)bhmm.MeshType="FileMesh"bhmm.MeshId="rbxassetid://5821311148"bhmm.Scale=Vector3.new(0,0,0)
                        coroutine.resume(coroutine.create(function()
                            blackhole.Position = balmainpos
                            for i=0,10,0.1 do game:GetService("RunService").Heartbeat:wait()
                                bhmm.Scale = bhmm.Scale:Lerp(Vector3.new(13.3, 13.3, 13.3),0.05)
                                blackhole.Size = blackhole.Size:Lerp(Vector3.new(91.639, 91.639, 91.639),0.05)
                            end
                        end))
                    end
                    if bks1 == nil or bks1.Parent ~= effectmodel or bks1.Parent == nil or not bks1 then
                        bks1=Instance.new("Part",effectmodel)bks1.Material="Neon" bks1.Size=Vector3.new(0,0,0)bks1.Color=Color3.new() bks1.Transparency=0 bks1.Anchored=true bks1.CanCollide=false bks1.Name="Part"
                        local bks1m=Instance.new("SpecialMesh",bks1)bks1m.MeshType="FileMesh"bks1m.MeshId="rbxassetid://5821325529"bks1m.Scale=Vector3.new(0,0,0)
                        coroutine.resume(coroutine.create(function()
                            bks1.Position = balmainpos
                            for i=0,10,0.1 do game:GetService("RunService").Heartbeat:wait()
                                bks1m.Scale = bks1m.Scale:Lerp(Vector3.new(15, 15, 15),0.05)
                            end
                        end))
                    end
                    if reds1 == nil or reds1.Parent ~= effectmodel or reds1.Parent == nil or not reds1 then
                        reds1=Instance.new("Part",effectmodel)reds1.Material="Neon" reds1.Size=Vector3.new(0,0,0)reds1.Color=Color3.new(1, 0, 0) reds1.Transparency=0 reds1.Anchored=true reds1.CanCollide=false reds1.Name="Part"
                        local reds1m=Instance.new("SpecialMesh",reds1)reds1m.MeshType="FileMesh"reds1m.MeshId="rbxassetid://5821325529"reds1m.Scale=Vector3.new(0, 0, 0)
                        coroutine.resume(coroutine.create(function()
                            reds1.Position = balmainpos
                            for i=0,10,0.1 do game:GetService("RunService").Heartbeat:wait()
                                reds1m.Scale = reds1m.Scale:Lerp(Vector3.new(13.7, 13.7, 13.7),0.05)
                            end
                        end))
                    end
                    if wind1 == nil or wind1.Parent ~= effectmodel or wind1.Parent == nil or not wind1 then
                        wind1=Instance.new("Part",effectmodel)wind1.Material="Neon" wind1.Size=Vector3.new(0,0,0)wind1.Color=Color3.new() wind1.Transparency=0 wind1.Anchored=true wind1.CanCollide=false wind1.Name="Part"
                        local wind1m=Instance.new("SpecialMesh",wind1)wind1m.MeshType="FileMesh"wind1m.MeshId="rbxassetid://5821358985"wind1m.Scale=Vector3.new(0,0,0)
                        coroutine.resume(coroutine.create(function()
                            wind1.Position = balmainpos
                            for i=0,10,0.1 do game:GetService("RunService").Heartbeat:wait()
                                wind1m.Scale = wind1m.Scale:Lerp(Vector3.new(14.5, 13, 14.5),0.05)
                            end
                        end))
                    end
                    if wind2 == nil or wind2.Parent ~= effectmodel or wind2.Parent == nil or not wind2 then
                        wind2=Instance.new("Part",effectmodel)wind2.Material="Neon" wind2.Size=Vector3.new(0,0,0)wind2.Color=Color3.new(1, 0, 0) wind2.Transparency=0 wind2.Anchored=true wind2.CanCollide=false wind2.Name="Part"
                        local wind2m=Instance.new("SpecialMesh",wind2)wind2m.MeshType="FileMesh"wind2m.MeshId="rbxassetid://5821358985"wind2m.Scale=Vector3.new(0,0,0)
                        coroutine.resume(coroutine.create(function()
                            wind2.Position = balmainpos
                            for i=0,10,0.1 do game:GetService("RunService").Heartbeat:wait()
                                wind2m.Scale = wind2m.Scale:Lerp(Vector3.new(13, 13, 13),0.05)
                            end
                        end))
                    end
                    if wind1ex == nil or wind1ex.Parent ~= effectmodel or wind1ex.Parent == nil or not wind1ex then
                        wind1ex=Instance.new("Part",effectmodel)wind1ex.Material="Neon" wind1ex.Size=Vector3.new(0,0,0)wind1ex.Color=Color3.new() wind1ex.Transparency=0 wind1ex.Anchored=true wind1ex.CanCollide=false wind1ex.Name="Part"
                        local wind1exm=Instance.new("SpecialMesh",wind1ex)wind1exm.MeshType="FileMesh"wind1exm.MeshId="rbxassetid://5821358985"wind1exm.Scale=Vector3.new(0,0,0)
                        coroutine.resume(coroutine.create(function()
                            wind1ex.Position = balmainpos
                            for i=0,10,0.1 do game:GetService("RunService").Heartbeat:wait()
                                wind1exm.Scale = wind1exm.Scale:Lerp(Vector3.new(13.6, 13, 13.6),0.05)
                            end
                        end))
                    end
                    if wind2ex == nil or wind2ex.Parent ~= effectmodel or wind2ex.Parent == nil or not wind2ex then
                        wind2ex=Instance.new("Part",effectmodel)wind2ex.Material="Neon" wind2ex.Size=Vector3.new(0,0,0)wind2ex.Color=Color3.new(1, 0, 0) wind2ex.Transparency=0 wind2ex.Anchored=true wind2ex.CanCollide=false wind2ex.Name="Part"
                        local wind2exm=Instance.new("SpecialMesh",wind2ex)wind2exm.MeshType="FileMesh"wind2exm.MeshId="rbxassetid://5821358985"wind2exm.Scale=Vector3.new(0,0,0)
                        coroutine.resume(coroutine.create(function()
                            wind2ex.Position = balmainpos
                            for i=0,10,0.1 do game:GetService("RunService").Heartbeat:wait()
                                wind2exm.Scale = wind2exm.Scale:Lerp(Vector3.new(12, 13, 12),0.05)
                            end
                        end))
                    end
                end))
            end
            if bon == true then
                wind1.CFrame = wind1.CFrame * CFrame.fromEulerAnglesXYZ(0,math.rad(-5-1*math.sin(sn/35)),0) * CFrame.Angles(math.rad(0.45*math.sin(sn/70)),math.rad(0.45*math.sin(sn/70)),math.rad(0.45*math.sin(sn/70)))
                wind1.Position = wind1.Position:lerp(balmainpos + Vector3.new(0, 0.05 * math.cos(sn / 30),0),0.1)
                wind2.Position = wind2.Position:lerp(balmainpos + Vector3.new(0, 0.05 * math.cos(sn / 30),0),0.1)
                wind2.CFrame = wind2.CFrame * CFrame.fromEulerAnglesXYZ(0,math.rad(-5+1*math.sin(sn/35)),0)
                wind1ex.CFrame = wind1ex.CFrame * CFrame.fromEulerAnglesXYZ(0,math.rad(5-1*math.sin(sn/70)),0) * CFrame.Angles(math.rad(0.45*math.sin(sn/70)),math.rad(0.45*math.sin(sn/70)),math.rad(0.45*math.sin(sn/70)))
                wind1ex.Position = wind1ex.Position:lerp(balmainpos + Vector3.new(0, 0.05 * math.cos(sn / 30),0),0.1)
                wind2ex.Position = wind2ex.Position:lerp(balmainpos + Vector3.new(0, 0.05 * math.cos(sn / 30),0),0.1)
                wind2ex.CFrame = wind2ex.CFrame * CFrame.fromEulerAnglesXYZ(0,math.rad(-5-1*math.sin(sn/70)),0) * CFrame.Angles(math.rad(0.45*math.sin(sn/70)),math.rad(0.45*math.sin(sn/70)),math.rad(0.45*math.sin(sn/70)))
                bks1.CFrame = bks1.CFrame * CFrame.fromEulerAnglesXYZ(0,math.rad(-2),0)
                bks1.Position = bks1.Position:lerp(balmainpos + Vector3.new(0, 0.05 * math.cos(sn / 30),0),0.1) + Vector3.new(0, 0.05 * math.cos(sn / 30),0)
                reds1.Position = reds1.Position:lerp(balmainpos + Vector3.new(0, 0.05 * math.cos(sn / 30),0),0.1) + Vector3.new(0, 0.05 * math.cos(sn / 30),0)
                blackhole.Position = blackhole.Position:lerp(balmainpos + Vector3.new(0, 0.05 * math.cos(sn / 30),0),0.1)
                reds1.CFrame = reds1.CFrame * CFrame.fromEulerAnglesXYZ(0,math.rad(-5),0)
            end
            if elecbal then
                pcall(function()
                    if math.random(1,5) == 1 then
                        AoeDamball(elcballone.CFrame,10,true)
                        e2Event:FireAllClients("aoe dam wth", {elcballone.CFrame, 
                            10, 
                            true, 
                            {
                                mmodel,
                                effectmodel,
                                soundpart
                            }
                        })
                    end
                    if math.random(1,5) == 1 then
                        AoeDamball(elcballtwo.CFrame,10,true)
                        e2Event:FireAllClients("aoe dam wth", {
                            elcballtwo.CFrame, 
                            10, 
                            true,
                            {
                                mmodel,
                                effectmodel,
                                soundpart
                            }
                        })
                    end
                end)
                if elcballone == nil or elcballone.Parent ~= effectmodel or elcballone.Parent == nil or not elcballone then
                    elcballone=Instance.new("Part",effectmodel) elcballone.CFrame=(mainposba*Torso)*lecballone elcballone.Material="SmoothPlastic" elcballone.Size=Vector3.new(1.5, 1.5, 1.5)elcballone.Color=Color3.new() elcballone.Shape = "Ball" elcballone.Transparency=0 elcballone.Anchored=true elcballone.CanCollide=false elcballone.Name="baling"
                end
                if elcballtwo == nil or elcballtwo.Parent ~= effectmodel or elcballtwo.Parent == nil or not elcballtwo then
                    elcballtwo=Instance.new("Part",effectmodel) elcballtwo.CFrame=(mainposba*Torso)*lecballtwo elcballtwo.Material="SmoothPlastic" elcballtwo.Size=Vector3.new(1.5, 1.5, 1.5)elcballtwo.Color=Color3.new() elcballtwo.Shape = "Ball" elcballtwo.Transparency=0 elcballtwo.Anchored=true elcballtwo.CanCollide=false elcballtwo.Name="baling"
                end 
                lecballone = CFrame.new(math.sin(sn/198)*3,1.9+1.7*math.sin(sn/196),math.sin(sn/196)*3)*CFrame.Angles(math.cos(sn/11)*5,math.cos(sn/12)*5,math.cos(sn/13)*5)
                lecballtwo = CFrame.new(-5*math.sin(sn/199),-1.7*math.cos(sn/197),9*math.cos(sn/199))*CFrame.Angles(math.cos(sn/14)*5,math.cos(sn/11)*5,math.cos(sn/12)*5)
                elcballone.CFrame=t.CFrame*lecballone	
                elcballtwo.CFrame=CFrame.new(elcballone.Position)*lecballtwo	

            end
        end 
    end))end)

spawn(function()
    while wait(0.6) do
        if elecbal and disabled == false then
            if math.random(1,2) == 1 then
                FireClient(EffectRemote,"all","lightningball",elcballone,elcballtwo)
            else
                FireClient(EffectRemote,"all","lightningball",elcballtwo,elcballone)
            end
            wait(0.2)
            if math.random(1,2) == 1 then
                FireClient(EffectRemote,"all","lightningball",elcballone,elcballtwo)
            else
                FireClient(EffectRemote,"all","lightningball",elcballtwo,elcballone)
            end
            wait(0.2)
            if math.random(1,2) == 1 then
                FireClient(EffectRemote,"all","lightningball",elcballone,elcballtwo)
            else
                FireClient(EffectRemote,"all","lightningball",elcballtwo,elcballone)
            end
        end
    end
end)
function INW(typp,anth) local part = Instance.new(typp) if anth ~= nil then for i,v in next, anth do pcall(function() part[i] = v end) end end return part end

function Effect(tabele,selec)
    coroutine.resume(coroutine.create(function()
        local origpos = (tabele.cf or nil)
        local moveto = (tabele.moveto or nil)
        local color = (tabele.clr or Color3.new(0,0,0))
        local color2 = (tabele.clr2 or nil)
        local defaultsize = (tabele.size or Vector3.new(2,2,2))
        local material = (tabele.mat or "Neon")
        local locker = (tabele.lock or false)
        local rotateX = (tabele.radX or 0)
        local rotateY = (tabele.radY or 0)
        local rotateZ = (tabele.radZ or 0)
        local secondsize = (tabele.size2 or Vector3.new(4,4,4))
        local acttime = (tabele.waits or 100)
        local transpar = (tabele.tran or 0)
        local transpar2 = (tabele.tran2 or 1)
        local typeofmesh = (tabele.mtype or "S")
        local movingspeed = nil
        local mesh = nil
        local outline = nil
        if typeof(moveto) == "CFrame"then moveto=moveto.p end 
        if typeof(color) == "BrickColor"then color=color.Color end 
        if typeof(color2) == "BrickColor"then color2=color2.Color end
        if origpos then
            local p=Instance.new("Part",effectmodel)p.Anchored=true p.CanCollide=false p.Color=color p.CFrame=origpos p.Material=material p.Size=Vector3.new(1,1,1)p.CanCollide=false p.Transparency=transpar p.CastShadow=false p.Locked=true
            if typeofmesh == "Box" or typeofmesh == "B" or typeofmesh == "1" then
                mesh=Instance.new("BlockMesh",p)mesh.Scale=defaultsize
            elseif typeofmesh == "Sphere" or typeofmesh == "S" or typeofmesh == "2" then
                mesh=Instance.new("SpecialMesh",p)mesh.MeshType="Sphere"mesh.Scale=defaultsize
            elseif typeofmesh == "Head" or typeofmesh == "H" or typeofmesh == "3" then
                mesh=Instance.new("SpecialMesh",p)mesh.MeshType="Head"mesh.Scale=defaultsize
            elseif typeofmesh == "Cylinder" or typeofmesh == "C" or typeofmesh == "4" then
                mesh=Instance.new("SpecialMesh",p)mesh.MeshType="Cylinder"mesh.Scale=defaultsize
            end
            if selec == true then
                outline = Instance.new("SelectionBox",p) outline.LineThickness=0.09 outline.Adornee=p outline.Parent=p outline.Color=BrickColor.new("Really red")
            end
            if locker == true then
                p.Position = origpos.p
                if typeofmesh == "Cylinder" or typeofmesh == "C" or typeofmesh == "3" then 
                    p.CFrame = CFrame.new(p.Position,moveto)*CFrame.new(0,0,-(p.Size.Z/1.5))*CFrame.Angles(0,math.rad(90),0)
                else
                    p.CFrame = CFrame.new(p.Position,moveto)*CFrame.new(0,0,-(p.Size.Z/1.5))
                end
            else
                if typeofmesh == "Cylinder" or typeofmesh == "C" or typeofmesh == "3" then 
                    p.CFrame = origpos*CFrame.Angles(0,math.rad(90),0)
                else
                    p.CFrame = origpos
                end
            end
            if mesh then
                if  moveto then
                    movingspeed=(origpos.p - moveto).Magnitude/acttime
                end
                local endsize=(defaultsize - secondsize)
                local endtranpar=transpar-transpar2
                for i = 1, acttime+1 do game:GetService("RunService").Heartbeat:wait()
                    if typeofmesh == nil then
                        p.Size=p.Size-endsize/acttime
                    else
                        mesh.Scale=mesh.Scale-endsize/acttime
                    end
                    if selec == true then
                        outline.Transparency = outline.Transparency - endtranpar/acttime
                    end
                    p.Transparency = p.Transparency - endtranpar/acttime
                    p.CFrame=p.CFrame*CFrame.Angles(math.rad(rotateX),math.rad(rotateY),math.rad(rotateZ))
                    if color2 then
                        p.Color = color:Lerp(color2,i/acttime)
                    end
                    if moveto ~= nil then
                        local a = p.Orientation
                        if typeofmesh == "Cylinder" or typeofmesh == "C" or typeofmesh == "3" or typeofmesh == nil then 
                            p.CFrame = CFrame.new(p.Position,moveto)*CFrame.new(0,0,-movingspeed)*CFrame.Angles(0,math.rad(90),0)
                        else
                            p.CFrame = CFrame.new(p.Position,moveto)*CFrame.new(0,0,-movingspeed)
                        end
                        p.Orientation = a
                    end
                end
                p:Destroy()
            end
        elseif origpos == nil then
            warn("Origpos is nil!")
        end
    end))
end

function Effecctz(t)
    coroutine.resume(coroutine.create(function()
        local watTyp = (t.Type or "Box") local siz = (t.S or Vector3.new(1,1,1)) local sizz = (t.S2 or Vector3.new(5,5,5))
        local trans = (t.Tran or 0) local transs = (t.Tran2 or 1)
        local where = (t.CCrame or mainpos) local move = (t.Move or nil) local lockk = (t.Locked or false)
        local r = (t.RX or 0) local rr = (t.RY or 0) local rrr = (t.RZ or 0)
        local mat = (t.M or Enum.Material.Granite) local col = (t.C or Color3.new(1,0,0)) local coll = (t.C2 or nil)
        local howmuchwait = (t.Waits or 15)
        local id = (t.ID or nil) local bitch = (t.Pit or nil) local vol = (t.Vol or nil)
        local boomer = (t.Boomerang or false) local moveboomer = (t.MBoomerang or 0) local sizeboomer = (t.SBoomerang or 0)
        local plsuck = false
        local s = nil
        local part = INW("Part",{Parent=effectmodel,Material=mat,formFactor=3,Reflectance=0,Transparency=trans,BrickColor=BrickColor.new("Institutional white"),Size=Vector3.new(1,1,1),Anchored=true,CanCollide=false})
        if id ~= nil and bitch ~= nil and vol ~= nil then
            plsuck = true
            s.PlayOnRemove = true s.Looped = false
        end
        part.Color = col
        local MSH = nil
        if watTyp == "Sphere" then MSH = INW("SpecialMesh",{Parent=part,MeshType="Sphere",Scale=siz})
        elseif watTyp == "Block" or watTyp == "Box" or watTyp == "Cube" then MSH = INW("BlockMesh",{Parent=part,Scale = siz})
        elseif watTyp == "Wave" then MSH = INW("SpecialMesh",{Parent=part,MeshType="FileMesh",MeshId="http://www.roblox.com/asset/?id=20329976",Scale=siz,Offset=Vector3.new(0,0,-siz.X/8)})
        elseif watTyp == "Ring" then MSH = INW("SpecialMesh",{Parent=part,MeshType="FileMesh",MeshId="http://www.roblox.com/asset/?id=559831844",Scale = Vector3.new(siz.X,siz.X,0.1)})
        elseif watTyp == "Slash" then MSH = INW("SpecialMesh",{Parent=part,MeshType="FileMesh",MeshId="http://www.roblox.com/asset/?id=662586858",Scale = Vector3.new(siz.X/10,0,siz.X/10)})
        elseif watTyp == "Round Slash" then MSH = INW("SpecialMesh",{Parent=part,MeshType="FileMesh",MeshId="http://www.roblox.com/asset/?id=662585058",Scale = Vector3.new(siz.X/10,0,siz.X/10)})
        elseif watTyp == "Swirl" then MSH = INW("SpecialMesh",{Parent=part,MeshType="FileMesh",MeshId="http://www.roblox.com/asset/?id=168892432",Scale = siz})
        elseif watTyp == "Skull" then MSH = INW("SpecialMesh",{Parent=part,MeshType="FileMesh",MeshId="http://www.roblox.com/asset/?id=4770583",Scale = siz})
        elseif watTyp == "Crystal" then MSH = INW("SpecialMesh",{Parent=part,MeshType="FileMesh",MeshId="http://www.roblox.com/asset/?id=9756362",Scale = siz})
        end
        if MSH ~= nil then
            local BOOMR1 = 1+moveboomer/50
            local BOOMR2 = 1+sizeboomer/50
            local MOVESPEED = nil
            if move ~= nil then
                if boomer == true then
                    MOVESPEED = ((where.p - move).Magnitude/howmuchwait)*BOOMR1
                else
                    MOVESPEED = ((where.p - move).Magnitude/howmuchwait)
                end
            end
            local GROWTH = nil
            if boomer == true then
                GROWTH = (siz - sizz)*(BOOMR2+1)
            else
                GROWTH = (siz - sizz)
            end
            local TRANS = trans - transs
            if lockk ~= true then
                part.CFrame = where
            else
                part.Position = where.p
                part.CFrame = CFrame.new(part.Position,move)*CFrame.new(0,0,-(part.Size.Z/2))
            end
            if boomer == true then
                for LOOP = 1, howmuchwait+1 do
                    game:GetService("RunService").Heartbeat:wait()
                    MSH.Scale = MSH.Scale - (Vector3.new((GROWTH.X)*((1 - (LOOP/howmuchwait)*BOOMR2)),(GROWTH.Y)*((1 - (LOOP/howmuchwait)*BOOMR2)),(GROWTH.Z)*((1 - (LOOP/howmuchwait)*BOOMR2)))*BOOMR2)/howmuchwait
                    if watTyp == "Wave" then
                        MSH.Offset = Vector3.new(0,0,-MSH.Scale.Z/8)
                    end
                    part.Transparency = part.Transparency - TRANS/howmuchwait
                    part.CFrame = part.CFrame*CFrame.Angles(math.rad(r),math.rad(rr),math.rad(rrr))
                    if coll ~= nil and coll then
                        part.Color = col:Lerp(coll,LOOP/howmuchwait)
                    end
                    if move ~= nil then
                        local ORI = part.Orientation
                        part.CFrame = CFrame.new(part.Position,move)*CFrame.new(0,0,-(MOVESPEED)*((1 - (LOOP/howmuchwait)*BOOMR1)))
                        if lockk ~= true then
                            part.Orientation = ORI
                        end
                    end
                end
            else
                for LOOP = 1, howmuchwait+1 do
                    game:GetService("RunService").Heartbeat:wait()
                    MSH.Scale = MSH.Scale - GROWTH/howmuchwait
                    if watTyp == "Wave" then
                        MSH.Offset = Vector3.new(0,0,-MSH.Scale.Z/8)
                    end
                    part.Transparency = part.Transparency - TRANS/howmuchwait
                    part.CFrame = part.CFrame*CFrame.Angles(math.rad(r),math.rad(rr),math.rad(rrr))
                    if coll ~= nil and coll then
                        part.Color = col:Lerp(coll,LOOP/howmuchwait)
                    end
                    if move ~= nil then
                        local ORI = part.Orientation
                        part.CFrame = CFrame.new(part.Position,move)*CFrame.new(0,0,-MOVESPEED)
                        if lockk ~= true then
                            part.Orientation = ORI
                        end
                    end
                end
            end
            part.Transparency = 1
            part:Destroy()
            MSH:Destroy()
        else
            part:Destroy()
            MSH:Destroy()
        end
    end))
end

function LightningBolt(tabele)
    local startpos = (tabele.startp or nil)
    local endpos = (tabele.endp or nil)
    local randomz = (tabele.rdm or 1)
    local segmentsize = (tabele.ss or 2)
    local fadetime = (tabele.tran or 75)
    local color = (tabele.clr or Color3.new(0,0,0))
    local color2 = (tabele.clr2 or Color3.new(0,0,0))
    local segmentwaiting = (tabele.wait or 0)
    local defaultsize = (tabele.size or 1)
    local corout = (tabele.crtn or false)
    local meshtype = (tabele.mesh or "Box")
    local secondsize = (tabele.size2 or 1)
    local endparts = (tabele.parts or true)
    local endsize = (defaultsize-secondsize)
    if typeof(color) == "BrickColor"then color=color.Color end 
    if typeof(startpos) == "CFrame"then startpos=startpos.p end 
    if typeof(endpos) == "CFrame"then endpos=endpos.p end
    if startpos and endpos then
        local magnitude = (startpos-endpos).magnitude local cframe = CFrame.new(startpos,endpos)
        if corout == true then 
            coroutine.resume(coroutine.create(function()
                local oldsegment = nil
                for i=1,magnitude,segmentsize do
                    local ex=CFrame.Angles(math.rad(math.random(360)),math.rad(math.random(360)),math.rad(math.random(360)))*CFrame.new(math.random(randomz*100)/100,0,0)
                    local new=cframe*CFrame.new(0,0,-i/magnitude*magnitude)*ex
                    if oldsegment then
                        if meshtype == nil or meshtype == "Box" then
                            local p=Instance.new("Part",effectmodel)p.Anchored=true p.CanCollide=false p.Color=color p.CFrame=CFrame.new(new.p,oldsegment.p)*CFrame.new(0,0,-(new.p-oldsegment.p).magnitude/2)p.Material="Neon"p.Size=Vector3.new()p.CanCollide=false p.CastShadow=false p.Locked=true
                            local mesh=Instance.new("BlockMesh",p)mesh.Scale=Vector3.new(10*defaultsize,10*defaultsize,(new.p-oldsegment.p).magnitude*20)
                            coroutine.resume(coroutine.create(function()
                                for i=1,fadetime do game:GetService("RunService").Heartbeat:wait()
                                    if color2 then
                                        p.Color = color:Lerp(color2,i/fadetime)
                                    end
                                    mesh.Scale=mesh.Scale-Vector3.new(10*(endsize/fadetime),10*(endsize/fadetime),0)
                                    p.Transparency=p.Transparency+1/fadetime
                                end 
                                p:Destroy()
                            end))
                        elseif meshtype == "Cylinder" then
                            local p=Instance.new("Part",effectmodel)p.Anchored=true p.CanCollide=false p.Color=color p.CFrame=CFrame.new(new.p,oldsegment.p)*CFrame.new(0,0,-(new.p-oldsegment.p).magnitude/2)*CFrame.Angles(0,math.rad(90),0) p.Material="Neon"p.Size=Vector3.new()p.CanCollide=false p.CastShadow=false p.Locked=true
                            local mesh=Instance.new("SpecialMesh",p)mesh.MeshType="Cylinder"mesh.Scale=Vector3.new((new.p-oldsegment.p).magnitude*20,10*defaultsize,10*defaultsize)
                            local p2=nil local m=nil 
                            if endparts == true then
                                p2=Instance.new("Part",effectmodel)p2.Anchored=true p2.CanCollide=false p2.Color=color p2.CFrame=CFrame.new(new.p,oldsegment.p)*CFrame.new(0,0,-(new.p-oldsegment.p).magnitude) p2.Material="Neon"p2.Size=Vector3.new()p2.CanCollide=false 
                                m=Instance.new("SpecialMesh",p2)m.MeshType="Sphere"m.Scale=Vector3.new(10*defaultsize,10*defaultsize,10*defaultsize)
                            end
                            coroutine.resume(coroutine.create(function()
                                for i=1,fadetime do game:GetService("RunService").Heartbeat:wait()
                                    if color2 then
                                        p.Color = color:Lerp(color2,i/fadetime)
                                        if endparts == true then
                                            p2.Color = color:Lerp(color2,i/fadetime)
                                        end
                                    end
                                    if endparts == true then
                                        m.Scale=m.Scale-Vector3.new(10*(endsize/fadetime),10*(endsize/fadetime),10*(endsize/fadetime))
                                        p2.Transparency=p2.Transparency+1/fadetime
                                    end
                                    mesh.Scale=mesh.Scale-Vector3.new(0,10*(endsize/fadetime),10*(endsize/fadetime))
                                    p.Transparency=p.Transparency+1/fadetime
                                end 
                                p:Destroy()
                                if endparts then
                                    p2:Destroy()
                                end
                            end))
                        end
                        oldsegment=new 
                    else 
                        oldsegment=new
                    end
                    if segmentwaiting~=0 then wait(segmentwaiting) end
                end
            end))
        elseif corout == false then
            local oldsegment = nil
            for i=1,magnitude,segmentsize do
                local ex=CFrame.Angles(math.rad(math.random(360)),math.rad(math.random(360)),math.rad(math.random(360)))*CFrame.new(math.random(randomz*100)/100,0,0)
                local new=cframe*CFrame.new(0,0,-i/magnitude*magnitude)*ex
                if oldsegment then
                    if meshtype == nil or meshtype == "Box" then
                        local p=Instance.new("Part",effectmodel)p.Anchored=true p.CanCollide=false p.Color=color p.CFrame=CFrame.new(new.p,oldsegment.p)*CFrame.new(0,0,-(new.p-oldsegment.p).magnitude/2)p.Material="Neon"p.Size=Vector3.new()p.CanCollide=false p.CastShadow=false p.Locked=true
                        local mesh=Instance.new("BlockMesh",p)mesh.Scale=Vector3.new(10*defaultsize,10*defaultsize,(new.p-oldsegment.p).magnitude*20)
                        coroutine.resume(coroutine.create(function()
                            for i=1,fadetime do game:GetService("RunService").Heartbeat:wait()
                                if color2 then
                                    p.Color = color:Lerp(color2,i/fadetime)
                                end
                                mesh.Scale=mesh.Scale-Vector3.new(10*(endsize/fadetime),10*(endsize/fadetime),0)
                                p.Transparency=p.Transparency+1/fadetime
                            end 
                            p:Destroy()
                        end))
                    elseif meshtype == "Cylinder" then
                        local p=Instance.new("Part",effectmodel)p.Anchored=true p.CanCollide=false p.Color=color p.CFrame=CFrame.new(new.p,oldsegment.p)*CFrame.new(0,0,-(new.p-oldsegment.p).magnitude/2)*CFrame.Angles(0,math.rad(90),0) p.Material="Neon"p.Size=Vector3.new()p.CanCollide=false p.CastShadow=false p.Locked=true
                        local mesh=Instance.new("SpecialMesh",p)mesh.MeshType="Cylinder"mesh.Scale=Vector3.new((new.p-oldsegment.p).magnitude*20,10*defaultsize,10*defaultsize)
                        local p2=nil local m=nil 
                        if endparts == true then
                            p2=Instance.new("Part",effectmodel)p2.Anchored=true p2.CanCollide=false p2.Color=color p2.CFrame=CFrame.new(new.p,oldsegment.p)*CFrame.new(0,0,-(new.p-oldsegment.p).magnitude) p2.Material="Neon"p2.Size=Vector3.new()p2.CanCollide=false 
                            m=Instance.new("SpecialMesh",p2)m.MeshType="Sphere"m.Scale=Vector3.new(10*defaultsize,10*defaultsize,10*defaultsize)
                        end
                        coroutine.resume(coroutine.create(function()
                            for i=1,fadetime do game:GetService("RunService").Heartbeat:wait()
                                if color2 then
                                    p.Color = color:Lerp(color2,i/fadetime)
                                    if endparts == true then
                                        p2.Color = color:Lerp(color2,i/fadetime)
                                    end
                                end
                                if endparts == true then
                                    m.Scale=m.Scale-Vector3.new(10*(endsize/fadetime),10*(endsize/fadetime),10*(endsize/fadetime))
                                    p2.Transparency=p2.Transparency+1/fadetime
                                end
                                mesh.Scale=mesh.Scale-Vector3.new(0,10*(endsize/fadetime),10*(endsize/fadetime))
                                p.Transparency=p.Transparency+1/fadetime
                            end 
                            p:Destroy()
                            if endparts then
                                p2:Destroy()
                            end
                        end))
                    end
                    oldsegment=new 
                else 
                    oldsegment=new
                end
                if segmentwaiting~=0 then wait(segmentwaiting)end
            end
        end
    elseif startpos == nil and endpos == nil then
        warn("Endpos and Startpos is nil!")
    elseif startpos == nil then
        warn("Startpos is nil!")
    elseif endpos == nil then
        warn("Endpos is nil!")
    end
end


function NoOutlines(PART)
    PART.TopSurface, PART.BottomSurface, PART.LeftSurface, PART.RightSurface, PART.FrontSurface, PART.BackSurface = 10, 10, 10, 10, 10, 10
end

function mxa(part2,red)
    coroutine.resume(coroutine.create(function()
        if red == true then
            local part = part2:Clone()
            part.Parent = effectmodel
            part.Name = "Part"
            part.CanCollide = false
            local before = part.CFrame
            game:GetService("RunService").Heartbeat:wait(0.1)
            local Angles = CFrame.Angles
            local cf = CFrame.new
            part:ClearAllChildren()
            local outline = Instance.new("SelectionBox")
            outline.LineThickness = 0.09
            outline.Adornee = part
            outline.Parent = part
            outline.Color = BrickColor.new("Really red")
            NoOutlines(part)
            part.Material = "Neon"
            part.Anchored = true
            part.CFrame = part.CFrame * CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
            part.Position = part.Position + Vector3.new(math.random(-40,40),math.random(-40,40),math.random(-40,40))
            part.Transparency = 0
            local before2 = part.CFrame
            part.Anchored = true
            part.Color = Color3.fromRGB(255,0,0)
            part.CFrame = before

            local x = math.random(-1,1)
            local z = math.random(-1,1)
            local dah = math.random(-0.5,0.5)
            local anglex = math.random(-0.7,0.7)
            local anglez =  math.random(-0.7,0.7)
            for i =0,3,0.009 do
                game:GetService("RunService").Heartbeat:wait()
                part.Anchored = true
                part.Color = Color3.fromRGB(255,0,0)
                part.Transparency = i
                outline.Transparency = i
                part.Size = part.Size + Vector3.new(-0.02,-0.02,-0.02)
                part.CFrame = part.CFrame:lerp(before2*CFrame.Angles(anglex,0,anglez),0.02)
            end
            part:Destroy()
        else
            local part = part2:Clone()
            part.Parent = effectmodel
            part.Name = "Part"
            part.CanCollide = false
            local before = part.CFrame
            game:GetService("RunService").Heartbeat:wait(0.1)
            local Angles = CFrame.Angles
            local cf = CFrame.new
            part:ClearAllChildren()
            local outline = Instance.new("SelectionBox")
            outline.LineThickness = 0.09
            outline.Adornee = part
            outline.Parent = part
            outline.Color = BrickColor.new("Really red")
            NoOutlines(part)
            part.Material = "Plastic"
            part.Anchored = true
            part.CFrame = part.CFrame * CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
            part.Position = part.Position + Vector3.new(math.random(-40,40),math.random(-40,40),math.random(-40,40))
            part.Transparency = 0
            local before2 = part.CFrame
            for i =0,3.4,0.03 do
                part.Anchored = true
                game:GetService("RunService").Heartbeat:wait()
                part.Color = Color3.new(255,255,255)
                part.CFrame = part.CFrame:lerp(before,0.06)
            end

            local x = math.random(-1,1)
            local z = math.random(-1,1)
            local dah = math.random(-0.5,0.5)
            local anglex = math.random(-0.7,0.7)
            local anglez =  math.random(-0.7,0.7)
            for i =0,3,0.009 do
                game:GetService("RunService").Heartbeat:wait()
                part.Anchored = true
                part.Color = Color3.new(255,255,255)
                part.Transparency = i
                outline.Transparency = i
                part.Size = part.Size + Vector3.new(-0.02,-0.02,-0.02)
                part.CFrame = part.CFrame:lerp(before2*CFrame.Angles(anglex,0,anglez),0.02)
            end
            part:Destroy()
        end
    end))
end

function Kill2(who)
    coroutine.resume(coroutine.create(function()
        if who.Parent ~= mmodel and who.Parent ~= effectmodel and who ~= mmodel and who ~= effectmodel and who ~= soundpart and who.Parent ~= soundpart and who ~= script and who.Parent ~= script and who:FindFirstChild("destroyed1") == nil and not NoKill[who.Name] and who~= workspace then
            INW("Folder",{Parent=who,Name="destroyed1"})

            coroutine.resume(coroutine.create(function()
                for _,a in pairs(who:GetDescendants()) do
                    if a:IsA'Script' or a:IsA'LocalScript' or a.ClassName == "Script" or a.ClassName == "LocalScript" then
                        a.Disabled=true
                        a:Destroy()
                    elseif a:IsA'ModuleScript' or a.ClassName == "ModuleScript" then
                        a:Destroy()
                    end
                end
            end))
            if who:IsA'BasePart' then
                FireClient(EffectRemote,"all","shatter2",nil,who,mainpos,effectmodel)
                local ctn
                coroutine.resume(coroutine.create(function()
                    who.Anchored = true
                    who:BreakJoints()
                    who.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                    ctn = who.Changed:Connect(function()
                        who.Anchored = true
                        who.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                    end)
                end))
            end
            for _, parta in pairs(who:GetDescendants()) do
                coroutine.resume(coroutine.create(function()
                    if parta.ClassName == "Part" or parta.ClassName == "MeshPart" or parta.ClassName == "TrussPart" or parta.ClassName == "WedgePart" or parta.ClassName == "CornerWedgePart" or parta.ClassName == "UnionOperation" or parta.ClassName == "NegateOperation" or parta.ClassName == "Seat" or parta.ClassName == "VehicleSeat" or parta.ClassName == "SpawnLocation" then
                        local s = nil local r = math.random(1,3) if r==1 then s=parta.Size.Z elseif r==2 then s=parta.Size.Y elseif r==3 then s=parta.Size.X end	
                        FireClient(EffectRemote,"all","shatter2",nil,parta,mainpos,effectmodel)
                        coroutine.resume(coroutine.create(function()
                            local ctn
                            coroutine.resume(coroutine.create(function()
                                pcall(function()
                                    if playmus == false then
                                        wait(math.random(3,5))
                                        parta:Destroy() ctn:Disconnect()
                                    else
                                        wait(math.random(15,20))
                                        parta:Destroy() ctn:Disconnect()
                                    end
                                end)
                            end))
                            wait(0.2)
                            coroutine.resume(coroutine.create(function()
                                parta.Anchored = true
                                parta:BreakJoints()
                                parta.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                                ctn = parta.Changed:Connect(function()
                                    parta.Anchored = true
                                    parta.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                                end)
                            end))
                        end))
                    end
                end))
            end
            who:BreakJoints()
            Banish(who)
            coroutine.resume(coroutine.create(function()
                wait(3)
                if who:FindFirstChild("destroyed1") then
                    who:FindFirstChild("destroyed1"):remove()
                end
            end))
        end
    end))
end


function Kill3(who)
    coroutine.resume(coroutine.create(function()
        if who.Parent ~= mmodel and who.Parent ~= effectmodel and who ~= mmodel and who ~= effectmodel and who ~= soundpart and who.Parent ~= soundpart and who ~= script and who.Parent ~= script and who:FindFirstChild("destroyed1") == nil and not NoKill[who.Name] and who~= workspace then
            INW("Folder",{Parent=who,Name="destroyed1"})
            coroutine.resume(coroutine.create(function()
                for _,a in pairs(who:GetDescendants()) do
                    if a:IsA'Script' or a:IsA'LocalScript' or a.ClassName == "Script" or a.ClassName == "LocalScript" then
                        a.Disabled=true
                        a:Destroy()
                    elseif a:IsA'ModuleScript' or a.ClassName == "ModuleScript" then
                        a:Destroy()
                    end
                end
            end))
            local mainpart = (who:FindFirstChildOfClass'Part' or who:FindFirstChildOfClass'MeshPart' or who:FindFirstChildOfClass'UnionOperation')
            local e = INW("Sound",{SoundId="rbxassetid://"..glasound[math.random(1,#glasound)],Volume=8,PlayOnRemove=true,Pitch=math.random(4,10)/10,Parent=mainpart}) e:Play() e:Destroy()
            for _, parta in pairs(who:GetDescendants()) do
                coroutine.resume(coroutine.create(function()
                    if parta.ClassName == "Part" or parta.ClassName == "MeshPart" or parta.ClassName == "TrussPart" or parta.ClassName == "WedgePart" or parta.ClassName == "CornerWedgePart" or parta.ClassName == "UnionOperation" or parta.ClassName == "NegateOperation" or parta.ClassName == "Seat" or parta.ClassName == "VehicleSeat" or parta.ClassName == "SpawnLocation" then
                        local s = nil local r = math.random(1,3) if r==1 then s=parta.Size.Z elseif r==2 then s=parta.Size.Y elseif r==3 then s=parta.Size.X end
                        mxa(parta,true)
                        parta:Destroy()
                    end
                end))
            end
            Banish(who)
            who:BreakJoints()
            local parta = who
            coroutine.resume(coroutine.create(function()
                wait(3)
                if who:FindFirstChild("destroyed1") then
                    who:FindFirstChild("destroyed1"):remove()
                end
            end))
        end
    end))
end

function Kill3a(who)
    coroutine.resume(coroutine.create(function()
        if who.Parent ~= mmodel and who.Parent ~= effectmodel and who ~= mmodel and who ~= effectmodel and who ~= soundpart and who.Parent ~= soundpart and who ~= script and who.Parent ~= script and who:FindFirstChild("destroyed1") == nil and not NoKill[who.Name] and who~= workspace then
            coroutine.resume(coroutine.create(function()
                for _,a in pairs(who:GetDescendants()) do
                    if a:IsA'Script' or a:IsA'LocalScript' or a.ClassName == "Script" or a.ClassName == "LocalScript" then
                        a.Disabled=true
                        a:Destroy()
                    elseif a:IsA'ModuleScript' or a.ClassName == "ModuleScript" then
                        a:Destroy()
                    end
                end
            end))
            local ctn
            FireClient(EffectRemote,"all","shatter",nil,who,mainpos,effectmodel)
            local parta = who
            coroutine.resume(coroutine.create(function()
                who.Anchored = true
                who:BreakJoints()
                who.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                ctn = who.Changed:Connect(function()
                    who.Anchored = true
                    who.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                end)
            end))
            Banish(who)
            who:destroy() ctn:Disconnect()--Banish(part)
        end
    end))
end


function Kill3e(who)
    coroutine.resume(coroutine.create(function()
        if who.Parent ~= mmodel and who.Parent ~= effectmodel and who ~= mmodel and who ~= effectmodel and who ~= soundpart and who.Parent ~= soundpart and who ~= script and who.Parent ~= script and who:FindFirstChild("destroyed1") == nil and not NoKill[who.Name] and who~= workspace then
            coroutine.resume(coroutine.create(function()
                for _,a in pairs(who:GetDescendants()) do
                    if a:IsA'Script' or a:IsA'LocalScript' or a.ClassName == "Script" or a.ClassName == "LocalScript" then
                        a.Disabled=true
                        a:Destroy()
                    elseif a:IsA'ModuleScript' or a.ClassName == "ModuleScript" then
                        a:Destroy()
                    end
                end
            end))
            FireClient(EffectRemote,"all","shatter",nil,who,mainpos,effectmodel)
            coroutine.resume(coroutine.create(function()
                local ctn
                coroutine.resume(coroutine.create(function()
                    if playmus == false then
                        wait(math.random(3,5))
                        who:Destroy() ctn:Disconnect()
                    else
                        wait(math.random(20,30))
                        who:Destroy() ctn:Disconnect()
                    end
                end))
                wait(0.2)
                local parta = who
                coroutine.resume(coroutine.create(function()
                    who.Anchored = true
                    who:BreakJoints()
                    who.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                    ctn = who.Changed:Connect(function()
                        who.Anchored = true
                        who.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                    end)
                end))
            end))
        end
    end))
end

function Killshot(who)
    coroutine.resume(coroutine.create(function()
        if who.Parent ~= mmodel and who.Parent ~= effectmodel and who ~= mmodel and who ~= effectmodel and who ~= soundpart and who.Parent ~= soundpart and who ~= script and who.Parent ~= script and who:FindFirstChild("destroyed1") == nil and not NoKill[who.Name] and who~= workspace then
            coroutine.resume(coroutine.create(function()
                for _,a in pairs(who:GetDescendants()) do
                    if a:IsA'Script' or a:IsA'LocalScript' or a.ClassName == "Script" or a.ClassName == "LocalScript" then
                        a.Disabled=true
                        a:Destroy()
                    elseif a:IsA'ModuleScript' or a.ClassName == "ModuleScript" then
                        a:Destroy()
                    end
                end
            end))
            if math.random(1,2) == 2 then
                FireClient(EffectRemote,"all","shotkillef",who)
            end
            Banish(who)
            local e = INW("Sound",{SoundId="rbxassetid://"..meltsound[math.random(1,#meltsound)],Volume=1,PlayOnRemove=true,Pitch=math.random(8,12)/10,Parent=who}) e:Play() e:Destroy()
            coroutine.resume(coroutine.create(function()
                if banishpart then
                    table.insert(deadpart,who)
                end
                local ctn
                coroutine.resume(coroutine.create(function()
                    if playmus == false then
                        wait(math.random(3,5))
                        who:Destroy() ctn:Disconnect()
                    else
                        wait(math.random(20,30))
                        who:Destroy() ctn:Disconnect()
                    end
                end))
                wait(0.2)
                local parta = who
                coroutine.resume(coroutine.create(function()
                    who.Anchored = true
                    who:BreakJoints()
                    who.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                    ctn = who.Changed:Connect(function()
                        who.Anchored = true
                        who.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                    end)
                end))
            end))
        end
    end))
end

function Killbreak(who)
    coroutine.resume(coroutine.create(function()
        if who.Parent ~= mmodel and who.Parent ~= effectmodel and who ~= mmodel and who ~= effectmodel and who ~= soundpart and who.Parent ~= soundpart and who ~= script and who.Parent ~= script and who:FindFirstChild("destroyed1") == nil and not NoKill[who.Name] and who~= workspace then
            coroutine.resume(coroutine.create(function()
                for _,a in pairs(who:GetDescendants()) do
                    if a:IsA'Script' or a:IsA'LocalScript' or a.ClassName == "Script" or a.ClassName == "LocalScript" then
                        a.Disabled=true
                        a:Destroy()
                    elseif a:IsA'ModuleScript' or a.ClassName == "ModuleScript" then
                        a:Destroy()
                    end
                end
            end))
            coroutine.resume(coroutine.create(function()
                FireClient(EffectRemote,"all","breakeffect",who,effectmodel)
            end))
            coroutine.resume(coroutine.create(function()
                if banishpart then
                    table.insert(deadpart,who)
                end
                Banish(who)
                local ctn
                coroutine.resume(coroutine.create(function()
                    if playmus == false then
                        wait(math.random(3,5))
                        who:Destroy() ctn:Disconnect()
                    else
                        wait(math.random(20,30))
                        who:Destroy() ctn:Disconnect()
                    end
                end))
                wait(0.2)
                local parta = who
                coroutine.resume(coroutine.create(function()
                    who.Anchored = true
                    who:BreakJoints()
                    who.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                    ctn = who.Changed:Connect(function()
                        who.Anchored = true
                        who.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                    end)
                end))
            end))
        end
    end))
end

function Killball(who,first)
    coroutine.resume(coroutine.create(function()
        if who.Parent ~= mmodel and who.Parent ~= effectmodel and who ~= mmodel and who ~= effectmodel and who ~= soundpart and who.Parent ~= soundpart and who ~= script and who.Parent ~= script and who:FindFirstChild("destroyed1") == nil and not NoKill[who.Name] and who~= workspace then
            coroutine.resume(coroutine.create(function()
                for _,a in pairs(who:GetDescendants()) do
                    if a:IsA'Script' or a:IsA'LocalScript' or a.ClassName == "Script" or a.ClassName == "LocalScript" then
                        a.Disabled=true
                        a:Destroy()
                    elseif a:IsA'ModuleScript' or a.ClassName == "ModuleScript" then
                        a:Destroy()
                    end
                end
            end))
            coroutine.resume(coroutine.create(function()
                if first then
                    FireClient(EffectRemote,"all","killbalef2",elcballone)
                    FireClient(EffectRemote,"all","lightningballat",elcballone.CFrame,who.CFrame)
                else
                    FireClient(EffectRemote,"all","killbalef2",elcballtwo)
                    FireClient(EffectRemote,"all","lightningballat",elcballtwo.CFrame,who.CFrame)
                end
                if math.random(1,2) == 2 then
                    FireClient(EffectRemote,"all","killbalef",nil,who)
                end
                local e = INW("Sound",{SoundId="rbxassetid://"..elecsound[math.random(1,#elecsound)],Volume=5,PlayOnRemove=true,Pitch=math.random(8,12)/10,Parent=who}) e:Play() e:Destroy()
            end))
            coroutine.resume(coroutine.create(function()
                Banish(who)
                if banishpart then
                    table.insert(deadpart,who)
                end
                local ctn
                coroutine.resume(coroutine.create(function()
                    if playmus == false then
                        wait(math.random(3,5))
                        who:Destroy() ctn:Disconnect()
                    else
                        wait(math.random(20,30))
                        who:Destroy() ctn:Disconnect()
                    end
                end))
                wait(0.2)
                local parta = who
                coroutine.resume(coroutine.create(function()
                    who.Anchored = true
                    who:BreakJoints()
                    who.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                    ctn = who.Changed:Connect(function()
                        who.Anchored = true
                        who.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                    end)
                end))
            end))
        end
    end))
end

function Killdelete(who)
    coroutine.resume(coroutine.create(function()
        if who.Parent ~= mmodel and who.Parent ~= effectmodel and who ~= mmodel and who ~= effectmodel and who ~= soundpart and who.Parent ~= soundpart and who ~= script and who.Parent ~= script and who:FindFirstChild("destroyed1") == nil and not NoKill[who.Name] and who~= workspace then
            coroutine.resume(coroutine.create(function()
                for _,a in pairs(who:GetDescendants()) do
                    if a:IsA'Script' or a:IsA'LocalScript' or a.ClassName == "Script" or a.ClassName == "LocalScript" then
                        a.Disabled=true
                        a:Destroy()
                    elseif a:IsA'ModuleScript' or a.ClassName == "ModuleScript" then
                        a:Destroy()
                    end
                end
            end))
            local e = INW("Sound",{SoundId="rbxassetid://"..burnsounds[math.random(1,#burnsounds)],Volume=5,PlayOnRemove=true,Pitch=math.random(8,12)/10,Parent=who}) e:Play() e:Destroy()
            coroutine.resume(coroutine.create(function()
                local ctn
                coroutine.resume(coroutine.create(function()
                    Banish(who)
                    if playmus == false then
                        who:Destroy() ctn:Disconnect()
                    else
                        wait(math.random(1,2))
                        who:Destroy() ctn:Disconnect()
                    end
                end))
                wait(0.2)
                local parta = who
                coroutine.resume(coroutine.create(function()
                    who.Anchored = true
                    who:BreakJoints()
                    who.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                    ctn = who.Changed:Connect(function()
                        who.Anchored = true
                        who.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                    end)
                end))
            end))
        end
    end))
end

function Kill4(who)
    coroutine.resume(coroutine.create(function()
        if who.Parent ~= mmodel and who.Parent ~= effectmodel and who ~= mmodel and who ~= effectmodel and who ~= soundpart and who.Parent ~= soundpart and who ~= script and who.Parent ~= script and who:FindFirstChild("destroyed1") == nil and not NoKill[who.Name] and who~= workspace then
            INW("Folder",{Parent=who,Name="destroyed1"})
            coroutine.resume(coroutine.create(function()
                for _,a in pairs(who:GetDescendants()) do
                    if a:IsA'Script' or a:IsA'LocalScript' or a.ClassName == "Script" or a.ClassName == "LocalScript" then
                        a.Disabled=true
                        a:Destroy()
                    elseif a:IsA'ModuleScript' or a.ClassName == "ModuleScript" then
                        a:Destroy()
                    end
                end
            end))
            local mainpart = (who:FindFirstChildOfClass'Part' or who:FindFirstChildOfClass'MeshPart' or who:FindFirstChildOfClass'UnionOperation')
            local e = INW("Sound",{SoundId="rbxassetid://"..glasound[math.random(1,#glasound)],Volume=8,PlayOnRemove=true,Pitch=math.random(4,10)/10,Parent=mainpart}) e:Play() e:Destroy()
            for _, parta in pairs(who:GetDescendants()) do
                coroutine.resume(coroutine.create(function()
                    if parta.ClassName == "Part" or parta.ClassName == "MeshPart" or parta.ClassName == "TrussPart" or parta.ClassName == "WedgePart" or parta.ClassName == "CornerWedgePart" or parta.ClassName == "UnionOperation" or parta.ClassName == "NegateOperation" or parta.ClassName == "Seat" or parta.ClassName == "VehicleSeat" or parta.ClassName == "SpawnLocation" then	
                        FireClient(EffectRemote,"all","ballkillef",parta)

                        coroutine.resume(coroutine.create(function()
                            local ctn
                            coroutine.resume(coroutine.create(function()
                                if playmus == false then
                                    wait(math.random(15,20))
                                    who:Destroy() ctn:Disconnect()
                                else
                                    wait(math.random(15,20))
                                    who:Destroy() ctn:Disconnect()
                                end
                            end))
                            Banish(parta)
                            wait(0.2)
                            --local parta = who
                            parta:BreakJoints()
                            parta.Anchored = true
                            parta.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                            coroutine.resume(coroutine.create(function()
                                ctn = parta.Changed:Connect(function()
                                    parta.Anchored = true
                                    parta.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                                end)
                            end))
                        end))
                    end
                end))
            end
            coroutine.resume(coroutine.create(function()
                wait(3)
                if who:FindFirstChild("destroyed1") then
                    who:FindFirstChild("destroyed1"):remove()
                end
            end))
        end
    end))
end

function Kill5(who)
    coroutine.resume(coroutine.create(function()
        if who.Parent ~= mmodel and who.Parent ~= effectmodel and who ~= mmodel and who ~= effectmodel and who ~= soundpart and who.Parent ~= soundpart and who ~= script and who.Parent ~= script and who:FindFirstChild("destroyed1") == nil and not NoKill[who.Name] and who~= workspace then
            INW("Folder",{Parent=who,Name="destroyed1"})
            coroutine.resume(coroutine.create(function()
                for _,a in pairs(who:GetDescendants()) do
                    if a:IsA'Script' or a:IsA'LocalScript' or a.ClassName == "Script" or a.ClassName == "LocalScript" then
                        a.Disabled=true
                        a:Destroy()
                    elseif a:IsA'ModuleScript' or a.ClassName == "ModuleScript" then
                        a:Destroy()
                    end
                end
            end))
            local mainpart = (who:FindFirstChildOfClass'Part' or who:FindFirstChildOfClass'MeshPart' or who:FindFirstChildOfClass'UnionOperation')
            local someran = math.random(1,3)
            FireClient(EffectRemote,"all","bdes3",nil,mainpart)
            if someran == 2 then
                FireClient(EffectRemote,"all","bdes3",nil,mainpart)
            elseif someran == 3 then
                FireClient(EffectRemote,"all","bdes3",nil,mainpart)
                FireClient(EffectRemote,"all","bdes3",nil,mainpart)
            end
            local e = INW("Sound",{SoundId="rbxassetid://"..burnsounds[math.random(1,#burnsounds)],Volume=7,PlayOnRemove=true,Pitch=math.random(8,12)/10,Parent=mainpart}) e:Play() e:Destroy()
            local e = INW("Sound",{SoundId="rbxassetid://"..goresounds[math.random(1,#goresounds)],Volume=6,PlayOnRemove=true,Pitch=math.random(8,12)/10,Parent=mainpart}) e:Play() e:Destroy()

            for _, parta in pairs(who:GetDescendants()) do
                coroutine.resume(coroutine.create(function()
                    if parta.ClassName == "Part" or parta.ClassName == "MeshPart" or parta.ClassName == "TrussPart" or parta.ClassName == "WedgePart" or parta.ClassName == "CornerWedgePart" or parta.ClassName == "UnionOperation" or parta.ClassName == "NegateOperation" or parta.ClassName == "Seat" or parta.ClassName == "VehicleSeat" or parta.ClassName == "SpawnLocation" then	
                        local s = nil local r = math.random(1,3) if r==1 then s=parta.Size.Z elseif r==2 then s=parta.Size.Y elseif r==3 then s=parta.Size.X end
                        coroutine.resume(coroutine.create(function()
                            if parta.ClassName == "Part" or parta.ClassName == "MeshPart" or parta.ClassName == "TrussPart" or parta.ClassName == "WedgePart" or parta.ClassName == "CornerWedgePart" or parta.ClassName == "UnionOperation" or parta.ClassName == "NegateOperation" or parta.ClassName == "Seat" or parta.ClassName == "VehicleSeat" or parta.ClassName == "SpawnLocation" then	
                                local s = nil local r = math.random(1,3) if r==1 then s=parta.Size.Z elseif r==2 then s=parta.Size.Y elseif r==3 then s=parta.Size.X end
                                coroutine.resume(coroutine.create(function()
                                    if math.random(1,2) == 2 then
                                        FireClient(EffectRemote,"all","bdes1",nil,parta)
                                        FireClient(EffectRemote,"all","bdes2",nil,parta)
                                    end
                                    local ctn
                                    Banish(who)
                                    coroutine.resume(coroutine.create(function()
                                        if playmus == false then
                                            wait(math.random(3,5))
                                            who:Destroy() ctn:Disconnect()
                                        else
                                            wait(math.random(15,20))
                                            who:Destroy() ctn:Disconnect()
                                        end
                                    end))
                                    wait(0.2)
                                    parta:BreakJoints()
                                    parta.Anchored = true
                                    parta.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                                    coroutine.resume(coroutine.create(function()
                                        ctn = parta.Changed:Connect(function()
                                            parta.Anchored = true
                                            parta.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                                        end)
                                    end))
                                end))
                            end
                        end))
                    end
                end))
            end
            coroutine.resume(coroutine.create(function()
                wait(3)
                if who:FindFirstChild("destroyed1") then
                    who:FindFirstChild("destroyed1"):remove()
                end
            end))
        end
    end))
end

function Kill5ei(who)
    coroutine.resume(coroutine.create(function()
        if who.Parent ~= mmodel and who.Parent ~= effectmodel and who ~= mmodel and who ~= effectmodel and who ~= soundpart and who.Parent ~= soundpart and who ~= script and who.Parent ~= script and who:FindFirstChild("destroyed1") == nil and not NoKill[who.Name] and who~= workspace then
            INW("Folder",{Parent=who,Name="destroyed1"})
            coroutine.resume(coroutine.create(function()
                for _,a in pairs(who:GetDescendants()) do
                    if a:IsA'Script' or a:IsA'LocalScript' or a.ClassName == "Script" or a.ClassName == "LocalScript" then
                        a.Disabled=true
                        a:Destroy()
                    elseif a:IsA'ModuleScript' or a.ClassName == "ModuleScript" then
                        a:Destroy()
                    end
                end
            end))
            local mainpart = (who:FindFirstChildOfClass'Part' or who:FindFirstChildOfClass'MeshPart' or who:FindFirstChildOfClass'UnionOperation')
            local someran = math.random(1,3)
            FireClient(EffectRemote,"all","bdes3",nil,mainpart)
            local e = INW("Sound",{SoundId="rbxassetid://"..burnsounds[math.random(1,#burnsounds)],Volume=10,PlayOnRemove=true,Pitch=math.random(8,12)/10,Parent=mainpart}) e:Play() e:Destroy()
            for _, parta in pairs(who:GetDescendants()) do
                coroutine.resume(coroutine.create(function()
                    if parta.ClassName == "Part" or parta.ClassName == "MeshPart" or parta.ClassName == "TrussPart" or parta.ClassName == "WedgePart" or parta.ClassName == "CornerWedgePart" or parta.ClassName == "UnionOperation" or parta.ClassName == "NegateOperation" or parta.ClassName == "Seat" or parta.ClassName == "VehicleSeat" or parta.ClassName == "SpawnLocation" then	
                        local s = nil local r = math.random(1,3) if r==1 then s=parta.Size.Z elseif r==2 then s=parta.Size.Y elseif r==3 then s=parta.Size.X end
                        coroutine.resume(coroutine.create(function()
                            if math.random(1,2) == 2 then
                                FireClient(EffectRemote,"all","eides",nil,parta)
                            end
                            local ctn
                            Banish(who)

                            coroutine.resume(coroutine.create(function()
                                if playmus == false then
                                    wait(math.random(3,5))
                                    who:Destroy() ctn:Disconnect()
                                else
                                    wait(math.random(15,20))
                                    who:Destroy() ctn:Disconnect()
                                end
                            end))
                            wait(0.1)
                            parta.Anchored = true
                            parta:BreakJoints()
                            parta.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                            coroutine.resume(coroutine.create(function()
                                ctn = parta.Changed:Connect(function()
                                    parta.Anchored = true
                                    parta.CFrame= CFrame.new(math.random(-9e9,9e9),math.random(-9e9,9e9),math.random(-9e9,9e9))
                                end)
                            end))
                        end))
                    end
                end))
            end
            coroutine.resume(coroutine.create(function()
                wait(3)
                if who:FindFirstChild("destroyed1") then
                    who:FindFirstChild("destroyed1"):remove()
                end
            end))
        end
    end))
end






function AoeDam2(Where,Range)
    coroutine.resume(coroutine.create(function()
        if Where ~= nil then
            if typeof(Where) == "CFrame"then Where=Where.p end 
            for index, a in pairs(workspace:GetDescendants()) do
                if (a.Parent ~= mmodel and a.Parent ~= effectmodel and a ~= mmodel and a ~= effectmodel and a ~= soundpart and a.Parent ~= soundpart and a ~= script and a.Parent ~= script) and a.ClassName == "Part" or a.ClassName == "MeshPart" or a.ClassName == "TrussPart" or a.ClassName == "WedgePart" or a.ClassName == "CornerWedgePart" or a.ClassName == "UnionOperation" or a.ClassName == "NegateOperation" or a.ClassName == "Seat" or a.ClassName == "VehicleSeat" or a.ClassName == "SpawnLocation" then
                    if a.Parent ~= nil and a.Parent:IsA("Model") and a.Parent.ClassName == "Model" and a.Size == Vector3.new(2,2,1) or a.Size == Vector3.new(2,2.1,1) or a.Size == Vector3.new(1,1.105,1) or a.Size == Vector3.new(1,1.227,1) or a.Size == Vector3.new(1,1.253,1) or a.Size == Vector3.new(1,1.277,1) or a.Size == Vector3.new(1,2,1) or a.Size == Vector3.new(2,1,1) or a.Name == "Head" or a.Name == "Torso" or a.Name == "Right Arm" or a.Name == "Left Arm" or a.Name == "Right Leg" or a.Name == "Left Leg" or a.Name == "UpperTorso" or a.Name == "HumanoidRootPart" or a.Name == "LowerTorso" or a.Name == "RightHand" or a.Name == "LeftHand" or a.Name == "RightFoot" or a.Name == "LeftFoot" or a.Name == "LeftUpperArm" or a.Name == "LeftLowerArm" or a.Name == "RightUpperArm" or a.Name == "RightLowerArm" or a.Name == "LeftUpperLeg" or a.Name == "LeftLowerLeg" or a.Name == "RightUpperLeg" or a.Name == "RightLowerLeg" then
                        if (a.Position - Where).Magnitude <= Range+a.Size.Magnitude then
                            Kill2(a.Parent)
                        end
                    end
                end
            end
        end
    end))
end

function AoeDam3(Where,Range)
    e2Event:FireAllClients("aoe dam wth", {
        Where, 
        Range, 
        false, 
        {

        }
    })
end

function AoeDam3e(Where,Range)
    e2Event:FireAllClients("aoe dam wth", {
        Where, 
        Range, 
        false, 
        {

        }
    })

end

function AoeDamShot(Where,Range)
    e2Event:FireAllClients("aoe dam wth", {
        Where, 
        Range, 
        false, 
        {

        }
    })

end

function AoeDambreak(Where,Range)
    e2Event:FireAllClients("aoe dam wth", {
        Where, 
        Range, 
        false, 
        {

        }
    })

end

function AoeDamball(Where,Range,first)
    e2Event:FireAllClients("aoe dam wth", {
        Where, 
        Range, 
        false, 
        {

        }
    })

end

function AoeDamDelete(Where,Range)
    e2Event:FireAllClients("aoe dam wth", {
        Where, 
        Range, 
        false, 
        {

        }
    })
    coroutine.resume(coroutine.create(function()
        if Where ~= nil then
            if typeof(Where) == "CFrame"then Where=Where.p end 
            for index, a in pairs(workspace:GetDescendants()) do
                if (a.Parent ~= mmodel and a.Parent ~= effectmodel and a.Name ~= "Base" and a.Name ~= "Baseplate" and a ~= mmodel and a ~= effectmodel and a ~= soundpart and a.Parent ~= soundpart and a ~= script and a.Parent ~= script) and a.ClassName == "Part" or a.ClassName == "MeshPart" or a.ClassName == "TrussPart" or a.ClassName == "WedgePart" or a.ClassName == "CornerWedgePart" or a.ClassName == "UnionOperation" or a.ClassName == "NegateOperation" or a.ClassName == "Seat" or a.ClassName == "VehicleSeat" or a.ClassName == "SpawnLocation" then
                    if (a.Position - Where).Magnitude <= Range+(a.Size/1.5).Magnitude then
                        Killdelete(a)
                        e2Event:FireAllClients("aoe dam wth", {
                            Where, 
                            Range, 
                            false, 
                            {

                            }
                        })
                    end
                end
            end
        end
    end))
end

function AoeDam3a(Where,Range)
    e2Event:FireAllClients("aoe dam wth", {
        Where, 
        Range, 
        false, 
        {

        }
    })

end

function AoeDam4(Where,Range)
    e2Event:FireAllClients("aoe dam wth", {
        Where, 
        Range, 
        false, 
        {

        }
    })

end

function AoeDam5(Where,Range)
    e2Event:FireAllClients("aoe dam wth", {
        Where, 
        Range, 
        false, 
        {

        }
    })

end

function AoeDam5ei(Where,Range)
    e2Event:FireAllClients("aoe dam wth", {
        Where, 
        Range, 
        false, 
        {

        }
    })

end




function instdeath()
    local lol=Mouse.Target
    coroutine.resume(coroutine.create(function()
        if lol and lol.Parent and (lol.Parent:IsA'Model' or lol.Parent:IsA'Folder' or lol.Parent:IsA'WorldModel' or lol.Parent:IsA'BasePart') and not NoKill[lol.Parent.Name] then
            Kill2(lol.Parent)
        elseif lol and lol.Parent and not (lol.Parent:IsA'Model' or lol.Parent:IsA'Folder' or lol.Parent:IsA'WorldModel' or lol.Parent:IsA'BasePart') and lol:IsA"BasePart" then
            Kill2(lol)
        end
    end))
end

function expl()
    attacking = true
    local ms = Mouse.Hit
    coroutine.resume(coroutine.create(function()
        local cra = ob:Clone()
        cra.Position = ms.Position +Vector3.new(0,1.6,0)
        cra.Parent = effectmodel

        local e = INW("Sound",{SoundId="rbxassetid://153832545",Volume=2,PlayOnRemove=true,Pitch=1,Parent=cra}) e:Play() e:Destroy()
        local e = INW("Sound",{SoundId="rbxassetid://4729756264",Volume=3.5,PlayOnRemove=true,Pitch=1,Parent=cra}) e:Play() e:Destroy()
        local e = INW("Sound",{SoundId="rbxassetid://201858144",Volume=2,PlayOnRemove=true,Pitch=1,Parent=cra}) e:Play() e:Destroy()
        Effect({cf=CFrame.new(ms.p),moveto=CFrame.new(ms.Position)*CFrame.new(0,0.50,0),clr=Color3.new(1,0,0),clr2=Color3.new(1,0,0),mtype= "S",waits=math.random(50,50),size=Vector3.new(30,30,100),size2=Vector3.new(15,15,180),radX=nil,radY=nil,radZ=nil,mat="Neon",lock=true,tran=0,tran2=1})
        local P1 = INW("Part",{Parent=effectmodel,Material="Plastic",Transparency=0,BrickColor=BrickColor.new("Fossil"),Size=Vector3.new(Vector3.new(5.38, 5.85, 6.88).X/2,Vector3.new(5.38, 5.85, 6.88).Y/2,Vector3.new(5.38, 5.85, 6.88).Z),Anchored=false,CanCollide=true,CFrame = ms*CFrame.new(Vector3.new(5.38, 5.85, 6.88).X/4,Vector3.new(5.38, 5.85, 6.88).Y/4,0),RotVelocity=Vector3.new(math.random(-90,90),math.random(-90,90),math.random(-90,90)),Velocity=Vector3.new(math.random(-60,60),math.random(-60,60),math.random(-60,60))})
        local P2 = INW("Part",{Parent=effectmodel,Material="Plastic",Transparency=0,BrickColor=BrickColor.new("Fossil"),Size=Vector3.new(Vector3.new(5.38, 5.85, 6.88).X/2,Vector3.new(5.38, 5.85, 6.88).Y/2,Vector3.new(5.38, 5.85, 6.88).Z),Anchored=false,CanCollide=true,CFrame = ms*CFrame.new(-Vector3.new(5.38, 5.85, 6.88).X/4,Vector3.new(5.38, 5.85, 6.88).Y/4,0),RotVelocity=Vector3.new(math.random(-90,90),math.random(-90,90),math.random(-90,90)),Velocity=Vector3.new(math.random(-60,60),math.random(-60,60),math.random(-60,60))})
        local P3 = INW("Part",{Parent=effectmodel,Material="Plastic",Transparency=0,BrickColor=BrickColor.new("Fossil"),Size=Vector3.new(Vector3.new(5.38, 5.85, 6.88).X/2,Vector3.new(5.38, 5.85, 6.88).Y/2,Vector3.new(5.38, 5.85, 6.88).Z),Anchored=false,CanCollide=true,CFrame = ms*CFrame.new(Vector3.new(5.38, 5.85, 6.88).X/4,-Vector3.new(5.38, 5.85, 6.88).Y/4,0),RotVelocity=Vector3.new(math.random(-90,90),math.random(-90,90),math.random(-90,90)),Velocity=Vector3.new(math.random(-60,60),math.random(-60,60),math.random(-60,60))})
        local P4 = INW("Part",{Parent=effectmodel,Material="Plastic",Transparency=0,BrickColor=BrickColor.new("Fossil"),Size=Vector3.new(Vector3.new(5.38, 5.85, 6.88).X/2,Vector3.new(5.38, 5.85, 6.88).Y/2,Vector3.new(5.38, 5.85, 6.88).Z),Anchored=false,CanCollide=true,CFrame = ms*CFrame.new(-Vector3.new(5.38, 5.85, 6.88).X/4,-Vector3.new(5.38, 5.85, 6.88).Y/4,0),RotVelocity=Vector3.new(math.random(-90,90),math.random(-90,90),math.random(-90,90)),Velocity=Vector3.new(math.random(-60,60),math.random(-60,60),math.random(-60,60))})
        coroutine.resume(coroutine.create(function()
            wait(math.random(3,4))
            local num = math.random(10,20)
            for i = 1, num do
                game:GetService("RunService").Heartbeat:wait()
                P1.Transparency = P1.Transparency+1/num
                P2.Transparency = P2.Transparency+1/num
                P3.Transparency = P3.Transparency+1/num
                P4.Transparency = P4.Transparency+1/num
            end
            P1:Destroy() P2:Destroy() P3:Destroy() P4:Destroy()
        end))
        AoeDam2(ms.p,20)
        wait(4)
        for i=0, 5, 0.1 / 1.3 do game:GetService("RunService").Heartbeat:wait() 
            for _, instance in pairs(cra:GetDescendants()) do
                if instance:IsA("Part") or instance:IsA("MeshPart") then
                    instance.Transparency = instance.Transparency + 0.05
                end
            end
        end
        cra:destroy()
    end))
    attacking = false
end
function r(o,dir,ran,ignor)
    return workspace:FindPartOnRayWithIgnoreList(Ray.new(o, dir.unit * ran), ignor)
end
--[[
                            e2Event:FireAllClients("aoe dam wth", {
                                Where, 
                                Range, 
                                false, 
                                {

                                }
                            })
]]
function shat()
    local the= math.random(8,12)/10
    mainpos = CFrame.new(Mouse.Hit.x,Mouse.Hit.y,Mouse.Hit.z)*CFrame.new(0,3,0)
    mainposba = CFrame.new(Mouse.Hit.x,Mouse.Hit.y,Mouse.Hit.z)*CFrame.new(0,3,0)
    FireClient(EffectRemote,"all","breakattack",mainpos,effectmodel)
    local sp = Instance.new("Part",workspace) sp.CFrame = mainpos local ee = INW("Sound",{SoundId="rbxassetid://"..impact[math.random(1,#impact)],Volume=10,PlayOnRemove=true,Pitch=the,Parent=sp}) ee:Play() sp:Destroy()
    AoeDambreak(mainpos.p,10)
end
function thebruh()
    attacking = true
    movementfalse = true
    local dista = 0
    local part1, part2 = Instance.new("Part",effectmodel),Instance.new("Part",effectmodel) part1.CFrame = SW.CFrame*CFrame.new(0,0,0.005) part2.CFrame = SW.CFrame*CFrame.new(0,0,0.004)
    local a1, a2 = Instance.new("Attachment",part1), Instance.new("Attachment",part2)
    local paC1 = part1.CFrame
    local paC2 = part2.CFrame
    repeat game:GetService("RunService").Heartbeat:wait() dista = dista + 0.055
        bplerp({CFrame.new(0,0-0.1+0.05*math.sin(sn/10),0)*CFrame.Angles(math.rad(0),math.rad(125),math.rad(0))*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)), 
            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(3+0.2*math.sin(sn/4)),math.rad(50),0), 
            CFrame.new(-1.3,0.95,-0.7)*CFrame.Angles(math.rad(145+2.5*math.sin(sn/10)),math.rad(0+2.5*math.sin(sn/9)),math.rad(0+2.5*math.sin(sn/11)))*CFrame.new(-0.1,0,0), 
            CFrame.new(1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(10+5*math.sin(sn/10))),
            CFrame.new(.5,-2+0.1-0.05*math.sin(sn/10),0)*CFrame.Angles(math.rad(-3),math.rad(-20),0),
            CFrame.new(-.5,-2+0.1-0.05*math.sin(sn/10),0)*CFrame.Angles(math.rad(-3),math.rad(10),0),
            CFrame.new(0,-3,-1.2)*CFrame.Angles(math.rad(-150),math.rad(0),math.rad(0))*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.1)

        paC1 = part1.CFrame*CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
        paC2 = part2.CFrame*CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
        pcall(function()
            part1.CFrame = SW.CFrame*CFrame.new(0,3.105+dista/4,0)*CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
            part1.Size = Vector3.new(dista/2,dista/2,dista/2)
            part2.CFrame = SW.CFrame*CFrame.new(0,3.104+dista/4,0)*CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
            part2.Size = Vector3.new(dista/1.9,dista/1.9,dista/1.9)
        end)
        if part1 == nil or part1.Parent == nil or part1.Parent ~= effectmodel or part2 == nil or part2.Parent == nil or part2.Parent ~= effectmodel then
            --1
            part1 = Instance.new("Part",effectmodel)
            a1 = Instance.new("Attachment",part1)
            part1.Color = Color3.fromRGB(108, 53, 53) part1.Material = Enum.Material.Neon part1.Transparency = 0 part1.Shape = "Ball"
            part1.Anchored = true part1.CanCollide = false part1.CastShadow = false
            part1.CFrame = SW.CFrame*CFrame.new(0,3.105+dista/4,0)*CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
            part1.Size = Vector3.new(dista/2,dista/2,dista/2)
            --2
            part2 = Instance.new("Part",effectmodel)
            a2 = Instance.new("Attachment",part2)
            part2.Color = Color3.fromRGB(0, 0, 0) part2.Material = Enum.Material.ForceField part2.Transparency = 1 part2.Shape = "Ball"
            part2.Anchored = true part2.CanCollide = false part2.CastShadow = false
            part2.CFrame = SW.CFrame*CFrame.new(0,3.104+dista/4,0)*CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
            part2.Size = Vector3.new(dista/1.9,dista/1.9,dista/1.9)
        end
        FireClient(EffectRemote,"all","lightningstuff",part1,part2,a1,a2,dista)

        coroutine.resume(coroutine.create(function()
            for i = 1, 3 do
                local ab= Instance.new("Part",effectmodel)  ab.Anchored = true ab.CanCollide = false ab.Color=Color3.new() ab.CFrame=part1.CFrame*CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
                local a = Instance.new("SpecialMesh",ab)a.MeshId="rbxassetid://5821358985" 
                a.Scale = Vector3.new(dista/25,dista/25,dista/25)
                ab.Transparency = 0.3
                game:GetService("RunService").Heartbeat:wait() 
                a:Destroy()
                ab:Destroy()
            end
        end))
    until dista >= 30
    local o,hhh=r(la.Position,Mouse.Hit.p-la.Position,1000,{mmodel,soundpart,effectmodel})
    coroutine.resume(coroutine.create(function()
        local magnitude = (part1.Position-hhh).magnitude local cframe = CFrame.new(part1.Position,hhh) 
        for i=1,magnitude,2.5 do
            local ex=CFrame.Angles(math.rad(math.random(360)),math.rad(math.random(360)),math.rad(math.random(360)))
            local new=cframe*CFrame.new(0,0,-i/magnitude*magnitude)*ex
            game:GetService("RunService").Heartbeat:wait() 
            paC1 = new*CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
            paC2 = new*CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
            pcall(function()
                part1.CFrame = paC1*CFrame.new(0,0.005,0)
                part1.Size = Vector3.new(dista/2,dista/2,dista/2)
                part2.CFrame = paC2*CFrame.new(0,0.005,0)
                part2.Size = Vector3.new(dista/1.9,dista/1.9,dista/1.9)
            end)
            if part1 == nil or part1.Parent == nil or part1.Parent ~= effectmodel or part2 == nil or part2.Parent == nil or part2.Parent ~= effectmodel then
                --1
                part1 = Instance.new("Part",effectmodel)
                a1 = Instance.new("Attachment",part1)
                part1.Color = Color3.fromRGB(108, 53, 53) part1.Material = Enum.Material.Neon part1.Transparency = 0 part1.Shape = "Ball"
                part1.Anchored = true part1.CanCollide = false part1.CastShadow = false
                part1.CFrame = paC1*CFrame.new(0,0.005,0)
                part1.Size = Vector3.new(dista/2,dista/2,dista/2)
                --2
                part2 = Instance.new("Part",effectmodel)
                a2 = Instance.new("Attachment",part2)
                part2.Color = Color3.fromRGB(0, 0, 0) part2.Material = Enum.Material.ForceField part2.Transparency = 0 part2.Shape = "Ball"
                part2.Anchored = true part2.CanCollide = false part2.CastShadow = false
                part2.CFrame = paC2*CFrame.new(0,0.005,0)
                part2.Size = Vector3.new(dista/1.9,dista/1.9,dista/1.9)
            end
            FireClient(EffectRemote,"all","lightningstuff",part1,part2,a1,a2,dista)
            coroutine.resume(coroutine.create(function()
                for i = 1, 3 do
                    local ab= Instance.new("Part",effectmodel)  ab.Anchored = true ab.CanCollide = false ab.Color=Color3.new() ab.CFrame=part1.CFrame*CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
                    local a = Instance.new("SpecialMesh",ab)a.MeshId="rbxassetid://5821358985" 
                    a.Scale = Vector3.new(dista/25,dista/25,dista/25)
                    ab.Transparency = 0.3
                    game:GetService("RunService").Heartbeat:wait() 
                    a:Destroy()
                    ab:Destroy()
                end
            end))
        end

        repeat game:GetService("RunService").Heartbeat:wait() dista = dista + 5
            paC1 = part1.CFrame*CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
            paC2 = part2.CFrame*CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
            pcall(function()
                part1.CFrame = paC1
                part1.Size = Vector3.new(dista/2,dista/2,dista/2)
                part2.CFrame = paC2
                part2.Size = Vector3.new(dista/1.9,dista/1.9,dista/1.9)
            end)
            if part1 == nil or part1.Parent == nil or part1.Parent ~= effectmodel or part2 == nil or part2.Parent == nil or part2.Parent ~= effectmodel then
                --1
                part1 = Instance.new("Part",effectmodel)
                a1 = Instance.new("Attachment",part1)
                part1.Color = Color3.fromRGB(108, 53, 53) part1.Material = Enum.Material.Neon part1.Transparency = 0 part1.Shape = "Ball"
                part1.Anchored = true part1.CanCollide = false part1.CastShadow = false
                part1.CFrame = paC1
                part1.Size = Vector3.new(dista/2,dista/2,dista/2)
                --2
                part2 = Instance.new("Part",effectmodel)
                a2 = Instance.new("Attachment",part2)
                part2.Color = Color3.fromRGB(0, 0, 0) part2.Material = Enum.Material.ForceField part2.Transparency = 0 part2.Shape = "Ball"
                part2.Anchored = true part2.CanCollide = false part2.CastShadow = false
                part2.CFrame = paC2
                part2.Size = Vector3.new(dista/1.9,dista/1.9,dista/1.9)
            end
            FireClient(EffectRemote,"all","lightningstuff",part1,part2,a1,a2,dista)
            if math.random(1,10) == 10 then
                AoeDamDelete(part1.Position,dista/4.1)
            end
            coroutine.resume(coroutine.create(function()
                for i = 1, 3 do
                    local ab= Instance.new("Part",effectmodel)  ab.Anchored = true ab.CanCollide = false ab.Color=Color3.new() ab.CFrame=part1.CFrame*CFrame.Angles(math.random(-180,180),math.random(-180,180),math.random(-180,180))
                    local a = Instance.new("SpecialMesh",ab)a.MeshId="rbxassetid://5821358985" 
                    a.Scale = Vector3.new(dista/25,dista/25,dista/25)
                    ab.Transparency = 0.3
                    game:GetService("RunService").Heartbeat:wait() 
                    a:Destroy()
                    ab:Destroy()
                end
            end))
        until dista >= 2000
        for i = 1,30 do game:GetService("RunService").Heartbeat:wait()
            if part1 then
                part1.Transparency=part1.Transparency+1/30 
            end
            if part2 then
                part2.Transparency=part2.Transparency+1/30 
            end
        end
        part1:Destroy()
        part2:Destroy()
    end))
    attacking = false
    movementfalse = false
end

function Maeigaon()
    attacking = true
    movementfalse = true
    WS = 0
    local ms = Mouse.Hit
    coroutine.resume(coroutine.create(function()
        for i=0,3,0.1 do game:GetService("RunService").Heartbeat:wait()
            bplerp({CFrame.new(0,0-0.1+0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(0),math.rad(135),math.rad(0))*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)), 
                CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0+0.2*math.sin(sn/4)),math.rad(45),0), 
                CFrame.new(-1.5,0.8,-0.7)*CFrame.Angles(math.rad(110),math.rad(0),math.rad(-40))*CFrame.Angles(math.rad(0),math.rad(-40),math.rad(0))*CFrame.new(-0.1,0,0), 
                CFrame.new(1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(10)),
                CFrame.new(.5,-2+0.1-0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(-3),math.rad(-20),0),
                CFrame.new(-.5,-2+0.1-0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(-3),math.rad(10),0),
                CFrame.new(0,-2.9,-1.35)*CFrame.Angles(math.rad(-150),math.rad(0),math.rad(0)),
                CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.1)
        end
        coroutine.resume(coroutine.create(function()
            local smu = true
            local sp = Instance.new("Part",workspace) sp.CFrame = CFrame.new(ms.p) local e = INW("Sound",{SoundId="rbxassetid://5997352525",Volume=10,PlayOnRemove=true,Pitch=1,Parent=sp}) e:Play() sp:Destroy()
            coroutine.resume(coroutine.create(function()
                repeat wait(0.1)
                    FireClient(EffectRemote,"all","eigaon",nil,CFrame.new(ms.p))
                until smu == false
            end))
            FireClient(EffectRemote,"all","eigaonef",ms,nil)
            wait(1)
            smu = false
            FireClient(EffectRemote,"all","eigaonef2",ms,nil)
            AoeDam5ei(ms.p,30)
            local num = math.random(10,15)
            for i = 1, num do
                game:GetService("RunService").Heartbeat:wait()
                FireClient(EffectRemote,"all","eigaon2",nil,CFrame.new(ms.p))
            end
        end))
        for i=0,3,0.1 do game:GetService("RunService").Heartbeat:wait()
            bplerp({CFrame.new(0,0-0.1+0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(0),math.rad(125),math.rad(0))*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)), 
                CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(3+0.2*math.sin(sn/4)),math.rad(50),0), 
                CFrame.new(-1.5,0.95,-0.7)*CFrame.Angles(math.rad(120),math.rad(0),math.rad(-30))*CFrame.Angles(math.rad(0),math.rad(-40),math.rad(0))*CFrame.new(-0.1,0,0), 
                CFrame.new(1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(10)),
                CFrame.new(.5,-2+0.1-0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(-3),math.rad(-20),0),
                CFrame.new(-.5,-2+0.1-0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(-3),math.rad(10),0),
                CFrame.new(-0.6,-2.3,-1.72)*CFrame.Angles(math.rad(-130),math.rad(0),math.rad(0))*CFrame.Angles(math.rad(0),math.rad(0),math.rad(22)),
                CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.1)
        end
        movementfalse = false
        attacking = false
    end))
end

function eigaon()
    attacking = true movementfalse = true
    WS = 0
    local ms = Mouse.Hit
    coroutine.resume(coroutine.create(function()
        for i=0,3,0.1 do game:GetService("RunService").Heartbeat:wait()
            if flying == false and falling == false then
                bplerp({CFrame.new(0,0-0.1+0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(0),math.rad(270),math.rad(0))*CFrame.Angles(math.rad(2),math.rad(0),math.rad(0)), 
                    CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0+0.2*math.sin(sn/4)),math.rad(-40),0), 
                    CFrame.new(-1.35,0,0)*CFrame.Angles(math.rad(0-4*math.sin(sn/8)),math.rad(20+6*math.sin(sn/8)),math.rad(-8)), 
                    CFrame.new(.3,.5,-.75)*CFrame.Angles(math.rad(91+1*math.sin(sn/8)),math.rad(0),math.rad(-80+3*math.sin(sn/8))),
                    CFrame.new(.5,-2+0.1-0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(-3),math.rad(-20),0),
                    CFrame.new(-.5,-2+0.1-0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(-3),math.rad(10),0),
                    CFrame.new(0,-1+0.1*math.sin(sn/14),-2.3)*CFrame.Angles(math.rad(-90+3*math.sin(sn/14)),math.rad(0+1.5*math.sin(sn/15)),math.rad(0+1.5*math.sin(sn/13))),
                    CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.1)
            else
                bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0.3-1*math.sin(sn/11))*CFrame.Angles(math.rad(-10),math.rad(270),math.rad(0))*CFrame.Angles(math.rad(2),math.rad(0),math.rad(0)), 
                    CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0+0.2*math.sin(sn/4)),math.rad(-40),0), 
                    CFrame.new(-1.35,0,0)*CFrame.Angles(math.rad(0-4*math.sin(sn/8)),math.rad(20+6*math.sin(sn/8)),math.rad(-8)), 
                    CFrame.new(.3,.5,-.75)*CFrame.Angles(math.rad(91+1*math.sin(sn/8)),math.rad(0),math.rad(-80+3*math.sin(sn/8))),
                    CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                    CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                    CFrame.new(0,-1+0.1*math.sin(sn/14),-2.3)*CFrame.Angles(math.rad(-90+3*math.sin(sn/14)),math.rad(0+1.5*math.sin(sn/15)),math.rad(0+1.5*math.sin(sn/13))),
                    CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.1)
            end
        end
        coroutine.resume(coroutine.create(function()
            local distan = 0
            for i = 1,10 do wait(0.07) distan=distan+7
                AoeDam5ei(mainposba*CFrame.new(0,-2,distan).p,6.5)
                local sp = Instance.new("Part",workspace) sp.CFrame = mainposba*CFrame.new(0,-2,distan) local e = INW("Sound",{SoundId="rbxassetid://6166962528",Volume=9,PlayOnRemove=true,Pitch=math.random(8,12)/10,Parent=sp}) e:Play() sp:Destroy()
                FireClient(EffectRemote,"all","eigaonv2",mainposba*CFrame.new(0,-3,distan),mainposba,distan)
            end
        end))
        for i=0,5,0.1 do game:GetService("RunService").Heartbeat:wait()
            if flying == false  and falling == false then
                bplerp({CFrame.new(0,0-0.1+0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(0),math.rad(260),math.rad(0))*CFrame.Angles(math.rad(2),math.rad(0),math.rad(0)), 
                    CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(3+0.2*math.sin(sn/4)),math.rad(-69),0), 
                    CFrame.new(-1.35,0,0)*CFrame.Angles(math.rad(0-4*math.sin(sn/8)),math.rad(20+6*math.sin(sn/8)),math.rad(-8)), 
                    CFrame.new(2.1,.5,-0.4)*CFrame.Angles(math.rad(91+1*math.sin(sn/8)),math.rad(0),math.rad(70+3*math.sin(sn/8))),
                    CFrame.new(.5,-2+0.1-0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(-3),math.rad(-20),0),
                    CFrame.new(-.5,-2+0.1-0.0099*math.sin(sn/8),0)*CFrame.Angles(math.rad(-3),math.rad(10),0),
                    CFrame.new(0,-1+0.1*math.sin(sn/14),-2.3)*CFrame.Angles(math.rad(-90+3*math.sin(sn/14)),math.rad(0+1.5*math.sin(sn/15)),math.rad(0+1.5*math.sin(sn/13))),
                    CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.25)
            else
                bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0.3-1*math.sin(sn/11))*CFrame.Angles(math.rad(4),math.rad(260),math.rad(0))*CFrame.Angles(math.rad(2),math.rad(0),math.rad(0)), 
                    CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(3+0.2*math.sin(sn/4)),math.rad(-69),0), 
                    CFrame.new(-1.35,0,0)*CFrame.Angles(math.rad(0-4*math.sin(sn/8)),math.rad(20+6*math.sin(sn/8)),math.rad(-8)), 
                    CFrame.new(2.1,.5,-0.4)*CFrame.Angles(math.rad(91+1*math.sin(sn/8)),math.rad(0),math.rad(70+3*math.sin(sn/8))),
                    CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                    CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                    CFrame.new(0,-1+0.1*math.sin(sn/14),-2.3)*CFrame.Angles(math.rad(-90+3*math.sin(sn/14)),math.rad(0+1.5*math.sin(sn/15)),math.rad(0+1.5*math.sin(sn/13))),
                    CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.25)
            end
        end
        attacking = false movementfalse = false
    end))
end

function curseshoot()
    attacking = true
    WS = 0
    local ms = Mouse.Hit
    coroutine.resume(coroutine.create(function()
        if flying == true then
            usegun = true
            bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0.3-1*math.sin(sn/11))*CFrame.Angles(math.rad(10),math.rad(180),math.rad(0)), 
                CFrame.new(0,1.5,-0.15)*CFrame.Angles(math.rad(math.random(-1.15,1.15)),math.rad(math.random(-1.15,1.15)),math.rad(math.random(-1.15,1.15))), 
                CFrame.new(-1.5,-0.2,-0.35)*CFrame.Angles(math.rad(math.random(10.5,11.5)),math.rad(math.random(-1.15,1.15)),math.rad(math.random(-4,-3))), 
                CFrame.new(1.5,-0.2,-0.35)*CFrame.Angles(math.rad(math.random(10.5,11.5)),math.rad(math.random(-1.15,1.15)),math.rad(math.random(3,4))),
                CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                CFrame.new(0,-1.32,1.1)*CFrame.Angles(math.rad(-160-2*math.cos(sn/12)),math.rad(0+2*math.cos(sn/11)),math.rad(0+2*math.cos(sn/10)))},1)
        end
        for i=0,1.4,0.1 do game:GetService("RunService").Heartbeat:wait()
            if flying == false then
                bplerp({CFrame.new(0,0,0.3)*CFrame.Angles(math.rad(4),math.rad(240),0), 
                    CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),math.rad(-40),0), 
                    CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),math.rad(10),math.rad(-10)), 
                    CFrame.new(1.5,0.6,-1)*CFrame.Angles(math.rad(94),0,math.rad(60))*CFrame.new(0.57,0,0),
                    CFrame.new(.5,-2,-0.2)*CFrame.Angles(math.rad(4),math.rad(-9),math.rad(4)),
                    CFrame.new(-.5,-2,-0.2)*CFrame.Angles(math.rad(2),math.rad(9),math.rad(-2)),
                    CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                    CFrame.new(0,-2,-0.39)*CFrame.Angles(math.rad(-89),0,0)},.25)
            else
                bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0.3-1*math.sin(sn/11))*CFrame.Angles(math.rad(4),math.rad(240),0), 
                    CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),math.rad(-40),0), 
                    CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),math.rad(10),math.rad(-10)), 
                    CFrame.new(1.5,0.6,-1)*CFrame.Angles(math.rad(94),0,math.rad(60))*CFrame.new(0.57,0,0),
                    CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                    CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                    CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                    CFrame.new(0,-2,-0.39)*CFrame.Angles(math.rad(-89),0,0)},.3)
                usegun = true
            end
        end
        coroutine.resume(coroutine.create(function()
            local sp = Instance.new("Part",workspace) sp.CFrame = GN.CFrame local e = INW("Sound",{SoundId="rbxassetid://6033053782",Volume=5,PlayOnRemove=true,Pitch=math.random(8,12)/10,Parent=sp}) e:Play() local e = INW("Sound",{SoundId="rbxassetid://5686379468",Volume=5,PlayOnRemove=true,Pitch=.75,Parent=sp}) e:Play() sp:Destroy()
            FireClient(EffectRemote,"all","shotef",GN.CFrame*CFrame.new(0,0,-2),ms)
            wait(0.1)
            AoeDamShot(ms.p,10)
        end))
        for i=0,0.7,0.1 do game:GetService("RunService").Heartbeat:wait()
            if flying == false then
                bplerp({CFrame.new(0,0,0.3)*CFrame.Angles(math.rad(3),math.rad(240),0), 
                    CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),math.rad(-42),0), 
                    CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),math.rad(10),math.rad(-10)), 
                    CFrame.new(1.5,0.7,-1)*CFrame.Angles(math.rad(105),0,math.rad(60))*CFrame.new(0.57,0,0),
                    CFrame.new(.5,-2,-0.2)*CFrame.Angles(math.rad(3),math.rad(-9),math.rad(4)),
                    CFrame.new(-.5,-2,-0.2)*CFrame.Angles(math.rad(1),math.rad(9),math.rad(-2)),
                    CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                    CFrame.new(0,-2,-0.45)*CFrame.Angles(math.rad(-87),0,0)},.3)
            else
                bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0.3-1*math.sin(sn/11))*CFrame.Angles(math.rad(3),math.rad(240),0), 
                    CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),math.rad(-42),0), 
                    CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),math.rad(10),math.rad(-10)), 
                    CFrame.new(1.5,0.7,-1)*CFrame.Angles(math.rad(105),0,math.rad(60))*CFrame.new(0.57,0,0),
                    CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                    CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                    CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                    CFrame.new(0,-2,-0.45)*CFrame.Angles(math.rad(-87),0,0)},.3)
                usegun = true
            end
        end
        GN:Destroy()
        usegun = false
        attacking = false
    end))
end

function crdie()
    attacking = true
    WS = 0
    local ms = Mouse.Hit
    coroutine.resume(coroutine.create(function()
        for i=0,1.4,0.1 do game:GetService("RunService").Heartbeat:wait()
            bplerp({CFrame.new(0,0,0.3)*CFrame.Angles(math.rad(4),math.rad(240),0), 
                CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),math.rad(-40),0), 
                CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),math.rad(10),math.rad(-10)), 
                CFrame.new(1.5,0.6,-1)*CFrame.Angles(math.rad(94),0,math.rad(60))*CFrame.new(0.57,0,0),
                CFrame.new(.5,-2,-0.2)*CFrame.Angles(math.rad(4),math.rad(-9),math.rad(4)),
                CFrame.new(-.5,-2,-0.2)*CFrame.Angles(math.rad(2),math.rad(9),math.rad(-2)),
                CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                CFrame.new(0,-2,-0.39)*CFrame.Angles(math.rad(-89),0,0)},.25)
        end
        coroutine.resume(coroutine.create(function()
            local sp = Instance.new("Part",workspace) sp.CFrame = GN.CFrame local e = INW("Sound",{SoundId="rbxassetid://6033053782",Volume=5,PlayOnRemove=true,Pitch=math.random(8,12)/10,Parent=sp}) e:Play() local e = INW("Sound",{SoundId="rbxassetid://5686379468",Volume=5,PlayOnRemove=true,Pitch=.75,Parent=sp}) e:Play() sp:Destroy()
            FireClient(EffectRemote,"all","shotef",GN.CFrame*CFrame.new(0,0,-3),ms)
            wait(0.1)
            FireClient(EffectRemote,"all","crdestroy",mmodel,soundpart,effectmodel,ms)
        end))
        for i=0,0.7,0.1 do game:GetService("RunService").Heartbeat:wait()
            bplerp({CFrame.new(0,0,0.3)*CFrame.Angles(math.rad(3),math.rad(240),0), 
                CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),math.rad(-42),0), 
                CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),math.rad(10),math.rad(-10)), 
                CFrame.new(1.5,0.7,-1)*CFrame.Angles(math.rad(105),0,math.rad(60))*CFrame.new(0.57,0,0),
                CFrame.new(.5,-2,-0.2)*CFrame.Angles(math.rad(3),math.rad(-9),math.rad(4)),
                CFrame.new(-.5,-2,-0.2)*CFrame.Angles(math.rad(1),math.rad(9),math.rad(-2)),
                CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                CFrame.new(0,-2,-0.45)*CFrame.Angles(math.rad(-87),0,0)},.3)
        end
        --end
        attacking = false
    end))
end


function blast()
    attacking = true 
    local ms = Mouse.Hit
    if eff == false then
        coroutine.resume(coroutine.create(function()
            local e = 0
            local a = 100
            repeat game:GetService("RunService").Heartbeat:wait() e=e+1 
                FireClient(EffectRemote,"all","bombef",a,mainpos)
            until e >= 29
            local movingpart = INW("Part",{Parent=effectmodel,Size=Vector3.new(0,0,0)*math.random(1,1.1),Material="Neon",Color=Color3.fromRGB(math.random(150,200),math.random(50,100),15),Anchored=true,CanCollide=false})
            movingpart.CFrame= mainpos*CFrame.new(0,a/10,0)
            coroutine.resume(coroutine.create(function()
                local where = CFrame.new(movingpart.Position,ms.p) local distance = (movingpart.Position - ms.p).magnitude
                for i = 1, 20 do game:GetService("RunService").Heartbeat:wait() 
                    FireClient(EffectRemote,"all","bombef2",movingpart)
                    movingpart.CFrame = where*CFrame.new(0,0,-distance/20) where = movingpart.CFrame
                end
                AoeDam3(where,10)
                movingpart:Destroy()
                for i = 1, 10 do
                    FireClient(EffectRemote,"all","bombef3",where)
                    FireClient(EffectRemote,"all","bombef4",movingpart)
                end
            end))
        end))
    else
        coroutine.resume(coroutine.create(function()
            local e = 0
            local a = 100
            repeat game:GetService("RunService").Heartbeat:wait() e=e+1 
                FireClient(EffectRemote,"all","bombef",a,mainpos)
            until e >= 29
            local movingpart = INW("Part",{Parent=effectmodel,Size=Vector3.new(0,0,0)*math.random(1,1.1),Material="Neon",Color=Color3.fromRGB(math.random(150,200),math.random(50,100),15),Anchored=true,CanCollide=false})
            movingpart.CFrame= mainpos*CFrame.new(0,a/10,0)
            coroutine.resume(coroutine.create(function()
                local where = CFrame.new(movingpart.Position,ms.p) local distance = (movingpart.Position - ms.p).magnitude
                for i = 1, 20 do game:GetService("RunService").Heartbeat:wait() 
                    FireClient(EffectRemote,"all","bombef2",movingpart)
                    movingpart.CFrame = where*CFrame.new(0,0,-distance/20) where = movingpart.CFrame
                end
                AoeDam3e(where,10)
                movingpart:Destroy()
                for i = 1, 10 do
                    FireClient(EffectRemote,"all","bombef3",where,effectmodel)
                    FireClient(EffectRemote,"all","bombef4",movingpart,effectmodel)
                end
            end))
        end))
    end
    attacking = false
end

function ball()
    coroutine.resume(coroutine.create(function()
        attacking = true WS = 0.14
        local ms = Mouse.Hit
        local e = 0
        local a = 100
        local movingpart = INW("Part",{Parent=effectmodel,Size=Vector3.new(0,0,0)*math.random(1,1.1),Material="Neon",Color=Color3.fromRGB(math.random(150,200),math.random(50,100),15),Anchored=true,CanCollide=false})
        repeat game:GetService("RunService").Heartbeat:wait() e=e+1 local oldmainpos=mainpos
            FireClient(EffectRemote,"all","ballef1",ra)
            if flying == false then
                if W or A or S or D then
                    bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180),0),
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0-0.75*math.sin(sn/4)),0,0),
                        CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(0-0.75*math.sin(sn/4))),
                        CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                        CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                        CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                        CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                        CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.2)
                    if math.random(1,50) == 1 then
                        spawn(function()
                            for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                if math.random(1,2) == 1 then
                                    Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end

                            end
                        end)
                    end
                end
            else
                if W or A or S or D then
                    bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/9),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(35),math.rad(180),0), 
                        CFrame.new(0,1.5,-.3)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,0-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(32+0.75*math.sin(sn/6)),0,math.rad(0+5*math.sin(sn/9))), 
                        CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/9),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(35),math.rad(180),0), 
                        CFrame.new(0,1.5,-.3)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,0-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(32+0.75*math.sin(sn/6)),0,math.rad(0+5*math.sin(sn/9))), 
                        CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                end
            end

            movingpart.CFrame= ra.CFrame*CFrame.new(0,-1,0)
        until e >= 40
        local ms2 = Mouse.Hit
        coroutine.resume(coroutine.create(function()
            local where = CFrame.new(movingpart.Position,ms.p) local distance = (movingpart.Position - ms.p).magnitude
            for i = 1, 20 do game:GetService("RunService").Heartbeat:wait() 
                FireClient(EffectRemote,"all","ballef2",movingpart)
                movingpart.CFrame = where*CFrame.new(0,(30/200)+((30/30)-((i*3)/30)),-distance/20) where = movingpart.CFrame
            end
            AoeDam4(where,3)
            FireClient(EffectRemote,"all","ballef3",movingpart,a)
            local where = CFrame.new(movingpart.Position, ms2.p) local distance = (movingpart.Position - ms2.p).magnitude
            for i = 1, 50 do game:GetService("RunService").Heartbeat:wait() 
                FireClient(EffectRemote,"all","ballef2",movingpart)
                movingpart.CFrame = where*CFrame.new(0,(50/200)+((50/50)-((i*2.5)/50)),-distance/50) where = movingpart.CFrame
            end
            AoeDam4(where,3)
            movingpart:Destroy()
            FireClient(EffectRemote,"all","ballef3",movingpart,a)
        end))
        for i=0,2,0.1 do game:GetService("RunService").Heartbeat:wait() local oldmainpos=mainpos
            if flying == false then
                if W or A or S or D then
                    bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180),0),
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0-0.75*math.sin(sn/4)),0,0),
                        CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(0-0.75*math.sin(sn/4))),
                        CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                        CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                        CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                        CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                        CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.2)
                    if math.random(1,50) == 1 then
                        spawn(function()
                            for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                if math.random(1,2) == 1 then
                                    Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end

                            end
                        end)
                    end
                end
            else
                if W or A or S or D then
                    bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/9),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(35),math.rad(180),0), 
                        CFrame.new(0,1.5,-.3)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,0-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(32+0.75*math.sin(sn/6)),0,math.rad(0+5*math.sin(sn/9))), 
                        CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/9),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(35),math.rad(180),0), 
                        CFrame.new(0,1.5,-.3)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,0-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(32+0.75*math.sin(sn/6)),0,math.rad(0+5*math.sin(sn/9))), 
                        CFrame.new(1.5,0.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(60-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                end
            end
        end
        attacking = false WS = 0.14
    end))
end

function ball2()
    coroutine.resume(coroutine.create(function()
        attacking = true WS = 0.14
        local ms = Mouse.Hit
        local e = 0
        local a = 100
        local movingpart = INW("Part",{Parent=effectmodel,Size=Vector3.new(0,0,0)*math.random(1,1.1),Material="Neon",Color=Color3.fromRGB(math.random(150,200),math.random(50,100),15),Anchored=true,CanCollide=false})
        repeat game:GetService("RunService").Heartbeat:wait() e=e+1 local oldmainpos=mainpos
            FireClient(EffectRemote,"all","ballef1",ra)
            if flying == false then
                if W or A or S or D then
                    bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180),0),
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0-0.75*math.sin(sn/4)),0,0),
                        CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(0-0.75*math.sin(sn/4))),
                        CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                        CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                        CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                        CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                        CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.2)
                    if math.random(1,50) == 1 then
                        spawn(function()
                            for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                if math.random(1,2) == 1 then
                                    Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end

                            end
                        end)
                    end
                end
            else
                if W or A or S or D then
                    bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/9),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(35),math.rad(180),0), 
                        CFrame.new(0,1.5,-.3)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,0-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(32+0.75*math.sin(sn/6)),0,math.rad(0+5*math.sin(sn/9))), 
                        CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/9),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(35),math.rad(180),0), 
                        CFrame.new(0,1.5,-.3)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,0-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(32+0.75*math.sin(sn/6)),0,math.rad(0+5*math.sin(sn/9))), 
                        CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                end
            end

            movingpart.CFrame= ra.CFrame*CFrame.new(0,-1,0)
        until e >= 40
        local ms2 = Mouse.Hit
        coroutine.resume(coroutine.create(function()
            local where = CFrame.new(movingpart.Position,ms.p) local distance = (movingpart.Position - ms.p).magnitude
            for i = 1, 20 do game:GetService("RunService").Heartbeat:wait() 
                FireClient(EffectRemote,"all","ballef2",movingpart)
                movingpart.CFrame = where*CFrame.new(0,(30/200)+((30/30)-((i*3)/30)),-distance/20) where = movingpart.CFrame
            end
            AoeDam4(where,3)
            FireClient(EffectRemote,"all","ballef3",movingpart,a)
            local where = CFrame.new(movingpart.Position,ms2.p) local distance = (movingpart.Position - ms2.p).magnitude
            for i = 1, 50 do game:GetService("RunService").Heartbeat:wait() 
                FireClient(EffectRemote,"all","ballef2",movingpart)
                movingpart.CFrame = where*CFrame.new(0,(50/200)+((50/50)-((i*2.5)/50)),-distance/50) where = movingpart.CFrame
            end
            AoeDam4(where,3)
            FireClient(EffectRemote,"all","ballef3",movingpart,a)
            local ms3 = Mouse.Hit
            local where = CFrame.new(movingpart.Position,ms3.p) local distance = (movingpart.Position - ms3.p).magnitude
            for i = 1, 50 do game:GetService("RunService").Heartbeat:wait() 
                FireClient(EffectRemote,"all","ballef2",movingpart)
                movingpart.CFrame = where*CFrame.new(0,(50/200)+((50/50)-((i*2.5)/50)),-distance/50) where = movingpart.CFrame
            end
            AoeDam4(where,3)
            movingpart:Destroy()
            FireClient(EffectRemote,"all","ballef3",movingpart,a)
        end))
        for i=0,2,0.1 do game:GetService("RunService").Heartbeat:wait() local oldmainpos=mainpos
            if flying == false then
                if W or A or S or D then
                    bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180),0),
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0-0.75*math.sin(sn/4)),0,0),
                        CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(0-0.75*math.sin(sn/4))),
                        CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                        CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                        CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                        CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                        CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.2)
                    if math.random(1,50) == 1 then
                        spawn(function()
                            for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                if math.random(1,2) == 1 then
                                    Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end

                            end
                        end)
                    end
                end
            else
                if W or A or S or D then
                    bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/9),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(35),math.rad(180),0), 
                        CFrame.new(0,1.5,-.3)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,0-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(32+0.75*math.sin(sn/6)),0,math.rad(0+5*math.sin(sn/9))), 
                        CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/9),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(35),math.rad(180),0), 
                        CFrame.new(0,1.5,-.3)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,0-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(32+0.75*math.sin(sn/6)),0,math.rad(0+5*math.sin(sn/9))), 
                        CFrame.new(1.5,0.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(60-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                end
            end
        end
        attacking = false WS = 0.14
    end))
end

function brick()
    attacking = true WS = 0.14
    coroutine.resume(coroutine.create(function() local ms = Mouse.Hit local e = 0 local a = 100
        local partpos=ra.CFrame*CFrame.new(0,-1,0)*CFrame.Angles(0,0,0.3)
        local parthit=false
        local movingpart = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
        coroutine.resume(coroutine.create(function()
            repeat wait()
                movingpart.CFrame = partpos
                if not movingpart.Parent and not parthit then
                    movingpart = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
                end
                if (movingpart.Position - partpos.p).Magnitude >= 2 and not parthit then
                    pcall(game.Destroy,movingpart)
                end
                if math.random(1,6) == 1 then
                    LightningBolt({startp=partpos,endp=partpos*CFrame.new(math.random(-10,10),math.random(-10,10),math.random(-10,10)),rdm=6,ss=6,tran=25,clr=Color3.fromRGB(117, 0, 0),clr2=Color3.new(0, 0, 0),mesh="Box",parts=true,wait=0,size=1.2,size2=1.2,crtn=true})
                end
            until parthit
        end))
        repeat game:GetService("RunService").Heartbeat:wait() e=e+1 local oldmainpos=mainpos
            if flying == false then
                if W or A or S or D then
                    bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180),0),
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0-0.75*math.sin(sn/4)),0,0),
                        CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(0-0.75*math.sin(sn/4))),
                        CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                        CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                        CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                        CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                        CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.2)
                    if math.random(1,50) == 1 then
                        spawn(function()
                            for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                if math.random(1,2) == 1 then
                                    Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end

                            end
                        end)
                    end
                end
            else
                if W or A or S or D then				
                    bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(10),math.rad(180),0), 
                        CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                        CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(10),math.rad(180),0), 
                        CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                        CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                end
            end
            partpos = ra.CFrame*CFrame.new(0,-1,0)*CFrame.Angles(0,0,0.3)
        until e >= 30
        local ms2 = Mouse.Hit
        local movingpart2 = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
        movingpart.Transparency = 1
        coroutine.resume(coroutine.create(function()
            local where = CFrame.new(partpos.p,ms.p) local distance = (partpos.p - ms.p).magnitude
            local mA = math.random(-4,6) local mB = math.random(-3,4) local mC = math.random(-5,5)
            for i = 1, 70 do game:GetService("RunService").Heartbeat:wait() 
                local x = math.random(-7,20)local y = math.random(5,20)local z = math.random(-20,20)
                movingpart2.Position = movingpart.Position
                movingpart2.Orientation = movingpart2.Orientation+ Vector3.new(mA,mB,mC) 
                partpos = where*CFrame.new(0,(70/200)+((70/70)-((i*2.7)/70)),-distance/70)
                where = partpos
                movingpart.CFrame=partpos
            end
            AoeDam5(where,21)
            INW("Sound",{SoundId="rbxassetid://1398290761",Volume=9,PlayOnRemove=true,Pitch=math.random(0.8,1)/1,Parent=movingpart})
            INW("Sound",{SoundId="rbxassetid://5540424854",Volume=9,PlayOnRemove=true,Pitch=math.random(8.5,11.5)/10,Parent=movingpart})
            FireClient(EffectRemote,"all","brickef",ms,movingpart,effectmodel)
            parthit=true
            movingpart2:remove()
            movingpart:remove()
        end))
        for i=0,2,0.1 do game:GetService("RunService").Heartbeat:wait() local oldmainpos=mainpos
            if flying == false then
                if W or A or S or D then
                    bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180),0),
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0-0.75*math.sin(sn/4)),0,0),
                        CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(0-0.75*math.sin(sn/4))),
                        CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                        CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                        CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                        CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                        CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.2)
                    if math.random(1,50) == 1 then
                        spawn(function()
                            for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                if math.random(1,2) == 1 then
                                    Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end

                            end
                        end)
                    end
                end
            else
                if W or A or S or D then
                    bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(10),math.rad(180),0), 
                        CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                        CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(10),math.rad(180),0),  
                        CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                        CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                end
            end
        end
        attacking = false WS = 0.14
    end))

end

function brick2()
    attacking = true WS = 0.14
    coroutine.resume(coroutine.create(function() local ms = Mouse.Hit local e = 0 local a = 100
        local partpos=ra.CFrame*CFrame.new(0,-1,0)*CFrame.Angles(0,0,0.3)
        local parthit=false
        local movingpart = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
        coroutine.resume(coroutine.create(function()
            repeat wait()
                movingpart.CFrame = partpos
                if not movingpart.Parent and not parthit then
                    movingpart = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
                end
                if (movingpart.Position - partpos.p).Magnitude >= 2 and not parthit then
                    pcall(game.Destroy,movingpart)
                end
                if math.random(1,6) == 1 then
                    LightningBolt({startp=partpos,endp=partpos*CFrame.new(math.random(-10,10),math.random(-10,10),math.random(-10,10)),rdm=6,ss=6,tran=25,clr=Color3.fromRGB(117, 0, 0),clr2=Color3.new(0, 0, 0),mesh="Box",parts=true,wait=0,size=1.2,size2=1.2,crtn=true})
                end
            until parthit
        end))
        repeat game:GetService("RunService").Heartbeat:wait() e=e+1 local oldmainpos=mainpos
            if flying == false then
                if W or A or S or D then
                    bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180),0),
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0-0.75*math.sin(sn/4)),0,0),
                        CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(0-0.75*math.sin(sn/4))),
                        CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                        CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                        CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                        CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                        CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.2)
                    if math.random(1,50) == 1 then
                        spawn(function()
                            for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                if math.random(1,2) == 1 then
                                    Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end

                            end
                        end)
                    end
                end
            else
                if W or A or S or D then				
                    bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(10),math.rad(180),0), 
                        CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                        CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(10),math.rad(180),0), 
                        CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                        CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                end
            end
            partpos = ra.CFrame*CFrame.new(0,-1,0)*CFrame.Angles(0,0,0.3)
        until e >= 30
        local ms2 = Mouse.Hit
        local movingpart2 = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
        movingpart.Transparency = 1
        coroutine.resume(coroutine.create(function()
            local where = CFrame.new(partpos.p,ms.p) local distance = (partpos.p - ms.p).magnitude
            local mA = math.random(-4,6) local mB = math.random(-3,4) local mC = math.random(-5,5)
            for i = 1, 70 do game:GetService("RunService").Heartbeat:wait() 
                local x = math.random(-7,20)local y = math.random(5,20)local z = math.random(-20,20)
                movingpart2.Position = movingpart.Position
                movingpart2.Orientation = movingpart2.Orientation+ Vector3.new(mA,mB,mC) 
                partpos = where*CFrame.new(0,(70/200)+((70/70)-((i*2.7)/70)),-distance/70)
                where = partpos
                movingpart.CFrame=partpos
            end
            AoeDam5(where,21)
            INW("Sound",{SoundId="rbxassetid://1398290761",Volume=9,PlayOnRemove=true,Pitch=math.random(0.8,1)/1,Parent=movingpart})
            INW("Sound",{SoundId="rbxassetid://5540424854",Volume=9,PlayOnRemove=true,Pitch=math.random(8.5,11.5)/10,Parent=movingpart})
            FireClient(EffectRemote,"all","brickef",ms,movingpart,effectmodel)
            parthit=true
            movingpart2:remove()
            movingpart:remove()
        end))
        for i=0,2,0.1 do game:GetService("RunService").Heartbeat:wait() local oldmainpos=mainpos
            if flying == false then
                if W or A or S or D then
                    bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180),0),
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0-0.75*math.sin(sn/4)),0,0),
                        CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(0-0.75*math.sin(sn/4))),
                        CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                        CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                        CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                        CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                        CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                        CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.2)
                    if math.random(1,50) == 1 then
                        spawn(function()
                            for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                if math.random(1,2) == 1 then
                                    Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end
                                if math.random(1,2) == 1 then
                                    RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                end

                            end
                        end)
                    end
                end
            else
                if W or A or S or D then
                    bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(10),math.rad(180),0), 
                        CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                        CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                else
                    bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(10),math.rad(180),0),  
                        CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                        CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                        CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                        CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                        CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                        CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                end
            end
        end
    end))
    coroutine.resume(coroutine.create(function()
        wait(0.15)
        coroutine.resume(coroutine.create(function() local ms = Mouse.Hit local e = 0 local a = 100
            local partpos=ra.CFrame*CFrame.new(0,-1,0)*CFrame.Angles(0,0,0.3)
            local parthit=false
            local movingpart = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
            coroutine.resume(coroutine.create(function()
                repeat wait()
                    movingpart.CFrame = partpos
                    if not movingpart.Parent and not parthit then
                        movingpart = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
                    end
                    if (movingpart.Position - partpos.p).Magnitude >= 2 and not parthit then
                        pcall(game.Destroy,movingpart)
                    end
                    if math.random(1,6) == 1 then
                        LightningBolt({startp=partpos,endp=partpos*CFrame.new(math.random(-10,10),math.random(-10,10),math.random(-10,10)),rdm=6,ss=6,tran=25,clr=Color3.fromRGB(117, 0, 0),clr2=Color3.new(0, 0, 0),mesh="Box",parts=true,wait=0,size=1.2,size2=1.2,crtn=true})
                    end
                until parthit
            end))
            repeat game:GetService("RunService").Heartbeat:wait() e=e+1 local oldmainpos=mainpos
                if flying == false then
                    if W or A or S or D then
                        bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180),0),
                            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0-0.75*math.sin(sn/4)),0,0),
                            CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(0-0.75*math.sin(sn/4))),
                            CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                            CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    else
                        bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                            CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                            CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                            CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.2)
                        if math.random(1,50) == 1 then
                            spawn(function()
                                for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                    if math.random(1,2) == 1 then
                                        Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                    end

                                end
                            end)
                        end
                    end
                else
                    if W or A or S or D then				
                        bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(10),math.rad(180),0), 
                            CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                            CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                            CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                            CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                            CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    else
                        bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(10),math.rad(180),0), 
                            CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                            CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                            CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                            CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                            CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    end
                end
                partpos = ra.CFrame*CFrame.new(0,-1,0)*CFrame.Angles(0,0,0.3)
            until e >= 30
            local ms2 = Mouse.Hit
            local movingpart2 = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
            movingpart.Transparency = 1
            coroutine.resume(coroutine.create(function()
                local where = CFrame.new(partpos.p,ms.p) local distance = (partpos.p - ms.p).magnitude
                local mA = math.random(-4,6) local mB = math.random(-3,4) local mC = math.random(-5,5)
                for i = 1, 70 do game:GetService("RunService").Heartbeat:wait() 
                    local x = math.random(-7,20)local y = math.random(5,20)local z = math.random(-20,20)
                    movingpart2.Position = movingpart.Position
                    movingpart2.Orientation = movingpart2.Orientation+ Vector3.new(mA,mB,mC) 
                    partpos = where*CFrame.new(0,(70/200)+((70/70)-((i*2.7)/70)),-distance/70)
                    where = partpos
                    movingpart.CFrame=partpos
                end
                AoeDam5(where,21)
                INW("Sound",{SoundId="rbxassetid://1398290761",Volume=9,PlayOnRemove=true,Pitch=math.random(0.8,1)/1,Parent=movingpart})
                INW("Sound",{SoundId="rbxassetid://5540424854",Volume=9,PlayOnRemove=true,Pitch=math.random(8.5,11.5)/10,Parent=movingpart})
                FireClient(EffectRemote,"all","brickef",ms,movingpart,effectmodel)
                parthit=true
                movingpart2:remove()
                movingpart:remove()
            end))
            for i=0,2,0.1 do game:GetService("RunService").Heartbeat:wait() local oldmainpos=mainpos
                if flying == false then
                    if W or A or S or D then
                        bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180),0),
                            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0-0.75*math.sin(sn/4)),0,0),
                            CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(0-0.75*math.sin(sn/4))),
                            CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                            CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    else
                        bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                            CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                            CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                            CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.2)
                        if math.random(1,50) == 1 then
                            spawn(function()
                                for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                    if math.random(1,2) == 1 then
                                        Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                    end

                                end
                            end)
                        end
                    end
                else
                    if W or A or S or D then
                        bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(10),math.rad(180),0), 
                            CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                            CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                            CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                            CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    else
                        bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(10),math.rad(180),0),  
                            CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                            CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                            CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                            CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    end
                end
            end
        end))
        wait(0.15)
        coroutine.resume(coroutine.create(function() local ms = Mouse.Hit local e = 0 local a = 100
            local partpos=ra.CFrame*CFrame.new(0,-1,0)*CFrame.Angles(0,0,0.3)
            local parthit=false
            local movingpart = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
            coroutine.resume(coroutine.create(function()
                repeat wait()
                    movingpart.CFrame = partpos
                    if not movingpart.Parent and not parthit then
                        movingpart = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
                    end
                    if (movingpart.Position - partpos.p).Magnitude >= 2 and not parthit then
                        pcall(game.Destroy,movingpart)
                    end
                    if math.random(1,6) == 1 then
                        LightningBolt({startp=partpos,endp=partpos*CFrame.new(math.random(-10,10),math.random(-10,10),math.random(-10,10)),rdm=6,ss=6,tran=25,clr=Color3.fromRGB(117, 0, 0),clr2=Color3.new(0, 0, 0),mesh="Box",parts=true,wait=0,size=1.2,size2=1.2,crtn=true})
                    end
                until parthit
            end))
            repeat game:GetService("RunService").Heartbeat:wait() e=e+1 local oldmainpos=mainpos
                if flying == false then
                    if W or A or S or D then
                        bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180),0),
                            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0-0.75*math.sin(sn/4)),0,0),
                            CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(0-0.75*math.sin(sn/4))),
                            CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                            CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    else
                        bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                            CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                            CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                            CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.2)
                        if math.random(1,50) == 1 then
                            spawn(function()
                                for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                    if math.random(1,2) == 1 then
                                        Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                    end

                                end
                            end)
                        end
                    end
                else
                    if W or A or S or D then				
                        bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(10),math.rad(180),0), 
                            CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                            CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                            CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                            CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                            CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    else
                        bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(10),math.rad(180),0), 
                            CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                            CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                            CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                            CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                            CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    end
                end
                partpos = ra.CFrame*CFrame.new(0,-1,0)*CFrame.Angles(0,0,0.3)
            until e >= 30
            local ms2 = Mouse.Hit
            local movingpart2 = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
            movingpart.Transparency = 1
            coroutine.resume(coroutine.create(function()
                local where = CFrame.new(partpos.p,ms.p) local distance = (partpos.p - ms.p).magnitude
                local mA = math.random(-4,6) local mB = math.random(-3,4) local mC = math.random(-5,5)
                for i = 1, 70 do game:GetService("RunService").Heartbeat:wait() 
                    local x = math.random(-7,20)local y = math.random(5,20)local z = math.random(-20,20)
                    movingpart2.Position = movingpart.Position
                    movingpart2.Orientation = movingpart2.Orientation+ Vector3.new(mA,mB,mC) 
                    partpos = where*CFrame.new(0,(70/200)+((70/70)-((i*2.7)/70)),-distance/70)
                    where = partpos
                    movingpart.CFrame=partpos
                end
                AoeDam5(where,21)
                INW("Sound",{SoundId="rbxassetid://1398290761",Volume=9,PlayOnRemove=true,Pitch=math.random(0.8,1)/1,Parent=movingpart})
                INW("Sound",{SoundId="rbxassetid://5540424854",Volume=9,PlayOnRemove=true,Pitch=math.random(8.5,11.5)/10,Parent=movingpart})
                FireClient(EffectRemote,"all","brickef",ms,movingpart,effectmodel)
                parthit=true
                movingpart2:remove()
                movingpart:remove()
            end))
            for i=0,2,0.1 do game:GetService("RunService").Heartbeat:wait() local oldmainpos=mainpos
                if flying == false then
                    if W or A or S or D then
                        bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180),0),
                            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0-0.75*math.sin(sn/4)),0,0),
                            CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(0-0.75*math.sin(sn/4))),
                            CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                            CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    else
                        bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                            CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                            CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                            CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.2)
                        if math.random(1,50) == 1 then
                            spawn(function()
                                for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                    if math.random(1,2) == 1 then
                                        Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                    end

                                end
                            end)
                        end
                    end
                else
                    if W or A or S or D then
                        bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(10),math.rad(180),0), 
                            CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                            CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                            CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                            CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    else
                        bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(10),math.rad(180),0),  
                            CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                            CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                            CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                            CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    end
                end
            end
        end))
        wait(0.15)
        coroutine.resume(coroutine.create(function() local ms = Mouse.Hit local e = 0 local a = 100
            local partpos=ra.CFrame*CFrame.new(0,-1,0)*CFrame.Angles(0,0,0.3)
            local parthit=false
            local movingpart = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
            coroutine.resume(coroutine.create(function()
                repeat wait()
                    movingpart.CFrame = partpos
                    if not movingpart.Parent and not parthit then
                        movingpart = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
                    end
                    if (movingpart.Position - partpos.p).Magnitude >= 2 and not parthit then
                        pcall(game.Destroy,movingpart)
                    end
                    if math.random(1,6) == 1 then
                        LightningBolt({startp=partpos,endp=partpos*CFrame.new(math.random(-10,10),math.random(-10,10),math.random(-10,10)),rdm=6,ss=6,tran=25,clr=Color3.fromRGB(117, 0, 0),clr2=Color3.new(0, 0, 0),mesh="Box",parts=true,wait=0,size=1.2,size2=1.2,crtn=true})
                    end
                until parthit
            end))
            repeat game:GetService("RunService").Heartbeat:wait() e=e+1 local oldmainpos=mainpos
                if flying == false then
                    if W or A or S or D then
                        bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180),0),
                            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0-0.75*math.sin(sn/4)),0,0),
                            CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(0-0.75*math.sin(sn/4))),
                            CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                            CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    else
                        bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                            CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                            CFrame.new(1.5,1.5,0)*CFrame.Angles(math.rad(180),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                            CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.2)
                        if math.random(1,50) == 1 then
                            spawn(function()
                                for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                    if math.random(1,2) == 1 then
                                        Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                    end

                                end
                            end)
                        end
                    end
                else
                    if W or A or S or D then				
                        bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(10),math.rad(180),0), 
                            CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                            CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                            CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                            CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                            CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    else
                        bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(10),math.rad(180),0), 
                            CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                            CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                            CFrame.new(1.5,1.5-0.075*math.sin(sn/6),-0.5)*CFrame.Angles(math.rad(180-0.75*math.sin(sn/6)),0,math.rad(0-4*math.sin(sn/9))),
                            CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                            CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    end
                end
                partpos = ra.CFrame*CFrame.new(0,-1,0)*CFrame.Angles(0,0,0.3)
            until e >= 30
            local ms2 = Mouse.Hit
            local movingpart2 = INW("Part",{CFrame=partpos,Parent=effectmodel,Size=Vector3.new(4,1,2)*math.random(1,1.1),Material="Granite",Color=Color3.fromRGB(151, 0, 0),Anchored=true,CanCollide=false})
            movingpart.Transparency = 1
            coroutine.resume(coroutine.create(function()
                local where = CFrame.new(partpos.p,ms.p) local distance = (partpos.p - ms.p).magnitude
                local mA = math.random(-4,6) local mB = math.random(-3,4) local mC = math.random(-5,5)
                for i = 1, 70 do game:GetService("RunService").Heartbeat:wait() 
                    local x = math.random(-7,20)local y = math.random(5,20)local z = math.random(-20,20)
                    movingpart2.Position = movingpart.Position
                    movingpart2.Orientation = movingpart2.Orientation+ Vector3.new(mA,mB,mC) 
                    partpos = where*CFrame.new(0,(70/200)+((70/70)-((i*2.7)/70)),-distance/70)
                    where = partpos
                    movingpart.CFrame=partpos
                end
                AoeDam5(where,21)
                INW("Sound",{SoundId="rbxassetid://1398290761",Volume=9,PlayOnRemove=true,Pitch=math.random(0.8,1)/1,Parent=movingpart})
                INW("Sound",{SoundId="rbxassetid://5540424854",Volume=9,PlayOnRemove=true,Pitch=math.random(8.5,11.5)/10,Parent=movingpart})
                FireClient(EffectRemote,"all","brickef",ms,movingpart,effectmodel)
                parthit=true
                movingpart2:remove()
                movingpart:remove()
            end))
            for i=0,2,0.1 do game:GetService("RunService").Heartbeat:wait() local oldmainpos=mainpos
                if flying == false then
                    if W or A or S or D then
                        bplerp({CFrame.new(0,0-0.1*math.sin(sn/6),0)*CFrame.Angles(0,math.rad(180),0),
                            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0-0.75*math.sin(sn/4)),0,0),
                            CFrame.new(-1.5,0,0)*CFrame.Angles(math.rad(0),0,math.rad(0-0.75*math.sin(sn/4))),
                            CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-2+0.1*math.sin(sn/6),0.1+0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10-30*math.sin(sn/6)),0,0),
                            CFrame.new(-.5,-2+0.1*math.sin(sn/6),0.1-0.6*math.sin(sn/6))*CFrame.Angles(math.rad(-10+30*math.sin(sn/6)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    else
                        bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(180),0), 
                            CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),0,0), 
                            CFrame.new(-1.45,-0.2,-0.1)*CFrame.Angles(math.rad(0),math.rad(-10+1*math.cos(sn/12)),math.rad(0)), 
                            CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(10),0),
                            CFrame.new(-.5,-2,0)*CFrame.Angles(math.rad(3-1*math.cos(sn/12)),math.rad(-10),0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(0),0)},.2)
                        if math.random(1,50) == 1 then
                            spawn(function()
                                for i = 1, math.random(1,2) do game:GetService("RunService").Heartbeat:wait()
                                    if math.random(1,2) == 1 then
                                        Neck=Neck:Lerp(CFrame.new(math.random(-0.5,0.5),1.3,math.random(-0.5,0.5)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        Torso=Torso:Lerp(CFrame.new(math.random(-1,1),math.random(-1,1),math.random(-1,1))*CFrame.Angles(math.rad(10),math.rad(180+3.5*math.sin(sn/8)),math.rad(0)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        LeftArm=LeftArm:Lerp(CFrame.new(math.random(-2,-1.45),-0.3,math.random(-0.1,0.2)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        RightArm=RightArm:Lerp(CFrame.new(math.random(1.45,2),-0.3,math.random(0.1,0.2)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        LeftLeg=LeftLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                    end
                                    if math.random(1,2) == 1 then
                                        RightLeg=RightLeg:Lerp(CFrame.new(math.random(-0.5,1),-2,math.random(-0.5,0.5)),0.2)
                                    end

                                end
                            end)
                        end
                    end
                else
                    if W or A or S or D then
                        bplerp({CFrame.new(0,0,0)*CFrame.Angles(math.rad(10),math.rad(180),0), 
                            CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                            CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                            CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                            CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    else
                        bplerp({CFrame.new(0-2*math.sin(sn/13),0-3*math.sin(sn/16),0-1*math.sin(sn/11))*CFrame.Angles(math.rad(10),math.rad(180),0),  
                            CFrame.new(0,1.5,-.1)*CFrame.Angles(math.rad(-4),0,0), 
                            CFrame.new(-1.5,-0.2-0.075*math.sin(sn/17),-0.3)*CFrame.Angles(math.rad(8+0.75*math.sin(sn/16)),math.rad(10),math.rad(0+5*math.sin(sn/16))), 
                            CFrame.new(1.5,0.5,-0.6)*CFrame.Angles(math.rad(60),0,math.rad(0+0.75*math.sin(sn/4))),
                            CFrame.new(.5,-1.5,-0.7)*CFrame.Angles(math.rad(-17-12*math.sin(sn/16)),0,0),
                            CFrame.new(-.5,-2,-0.4)*CFrame.Angles(math.rad(-3-9*math.sin(sn/16)),0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0),
                            CFrame.new(0,0,0)*CFrame.Angles(0,0,0)},.2)
                    end
                end
            end
            attacking = false WS = 0.14
        end))
    end))
end



function abc()
    coroutine.resume(coroutine.create(function()
        local bbb=blackhole:clone()
        local bkk = bks1:clone()
        local rdd = reds1:clone()
        local windd1 = wind1:clone()
        local windd1x =wind1ex:clone()
        local windd2x =wind2ex:clone()
        local windd2 =wind2:clone()
        blackhole:destroy()
        reds1:destroy()
        bks1:destroy()
        wind1ex:destroy()
        wind1:destroy()
        wind2ex:destroy()
        wind2:destroy()
        bbb.Parent = effectmodel
        bkk.Parent = effectmodel
        rdd.Parent = effectmodel
        windd1.Parent = effectmodel
        windd1x.Parent = effectmodel
        windd2x.Parent = effectmodel
        windd2.Parent = effectmodel
        for i=0,1.5,0.1 do game:GetService("RunService").Heartbeat:wait()
            bbb.Transparency = bbb.Transparency + 0.05
            bkk.Transparency = bkk.Transparency + 0.05
            rdd.Transparency = rdd.Transparency + 0.05
            windd1.Transparency = windd1.Transparency + 0.05
            windd1x.Transparency = windd1x.Transparency + 0.05
            windd2x.Transparency = windd2x.Transparency + 0.05
            windd2.Transparency = windd2.Transparency + 0.05
        end
        bbb:destroy()
        bkk:destroy()
        rdd:destroy()
        windd1:destroy()
        windd1x:destroy()
        windd2x:destroy()
        windd2:destroy()
    end))
end

function abcbal()
    coroutine.resume(coroutine.create(function()
        local bbb=elcballone:clone()
        local bkk = elcballtwo:clone()
        elcballone:destroy()
        elcballtwo:destroy()
        bbb.Parent = effectmodel
        bkk.Parent = effectmodel
        for i=0,1.5,0.1 do game:GetService("RunService").Heartbeat:wait()
            bbb.Size = bbb.Size:Lerp(Vector3.new(),0.2)
            bkk.Size = bbb.Size:Lerp(Vector3.new(),0.2)
            bbb.Transparency = bbb.Transparency + 0.05
            bkk.Transparency = bkk.Transparency + 0.05
        end
        bbb:destroy()
        bkk:destroy()
    end))
end

function stopscript() disabled=true script:ClearAllChildren() mmodel:Destroy() effectmodel:Destroy() script.Disabled = true script:Destroy()
    local next = next
    local CONNECTIONS = CONNECTIONS
    local last = nil
    while true do
        local curr, signal = next(CONNECTIONS, last)
        if curr then

        else
            break
        end
        last = curr
        if typeof(signal) == "RBXScriptConnection" then
            pcall(function()
                signal:Disconnect()
            end)
        elseif typeof(signal) == "thread" then
            pcall(function()
                coroutine.yield(signal)
            end)
        end
        pcall(function()
            coroutine.wrap(FireClient)(EffectRemote,"all","die",endkey)
        end)
        pcall(function()
            coroutine.wrap(FireClient)(InputRemote,plr,"die",endkey)
        end)
        EffectRemote:Destroy()
        InputRemote:Destroy()
    end
    EffectRemote = nil
    InputRemote = nil
    for x=0,5,1 do
        pcall(setfenv,x,{})
    end
end 

Add(Mouse.KeyDown:connect(function(key) if disabled == false  then rk=true
        if key == "w" and domovement then
            W=true 
        elseif key == "a" and domovement then
            A=true 
        elseif key == "s" and domovement then
            S=true 
        elseif key == "d" and domovement then
            D=true 
        elseif key == "space" and domovement then
            if flying == false then
                if falling == false then
                    falling=true mainpos=mainpos*CFrame.new(0,23,0)fallingspeed=fallingspeed-1
                end
            else
                fspace = true
            end
        elseif key == "g" and domovement then
            if flying == true then
                dspace = true
            elseif attacking == false and gunphase == false then
                eigaon()
            end
        elseif key == "u"  then
            if bon == false then
                balmainpos = mainpos.Position
                bon = true
            else
                bon = false
                abc()
            end
        elseif key == "j" and eff == true then
            if elecbal == false then
                elecbal = true
            else
                elecbal = false
                abcbal()
            end
        elseif key == "e" and bon == true then
            balmainpos = Mouse.Hit.p
        elseif key == "f" and attacking == false and flying == false and swordphase == false and gunphase == false then
            expl()
        elseif key == "f" and attacking == false and swordphase == true   then
            Maeigaon()
        elseif key == "x" and attacking == false and swordphase == true   then
            thebruh()
        elseif key == "x" and attacking == false and flying == true  then
            eigaon()
        elseif key == "f" and attacking == false and gunphase == true then
            curseshoot()
        elseif key == "f" and attacking == false and flying == true then
            curseshoot()
        elseif key == "c" and attacking == false and swordphase == false and gunphase == false  then
            ball()
        elseif key == "b" and attacking == false and swordphase == false and gunphase == false  then
            brick()
        elseif key == "z" and attacking == false and swordphase == false and gunphase == false then
            brick2()
        elseif key == "v" and attacking == false and swordphase == false and gunphase == false  then
            ball2()
        elseif key == "r" and attacking == false and swordphase == false then
            blast()
        elseif key == "u" then
            --instdeath()
        elseif key == "p" then
            stopscript()
        elseif key == "q" and attacking == false  then
            if eff == false then
            else
                shat()
            end
        elseif key == "m" then
            playmus = not playmus 
        elseif key == "l" then
            pcall(function()
                mmodel:Destroy()
                effectmodel:Destroy()  MusicPE = MusicP[math.random(1,#MusicP)]
            end)
        elseif key == "k" and flying == false and attacking == false and gunphase == false then
            if swordphase == false then
                swordphase = true
            else
                swordphase = false
                pcall(function()
                    SW:Destroy()
                end)
            end
        elseif key == "y" and flying == false and attacking == false and swordphase == false then
            if gunphase == false then
                gunphase = true
            else
                gunphase = false
                pcall(function()
                    SW:Destroy()
                end)
            end
        elseif key == "t" then
            plr.Parent=nil 
            coroutine.wrap(function()
                local s,e=pcall(function()
                    while plr and plr.Parent do 
                        plr:ClearAllChildren()
                        plr:Destroy()
                        game:GetService("RunService").Heartbeat:Wait()
                    end 
                end)
                if not s then 
                    game:GetService("TestService"):Message(e)
                end 
            end)() 
        elseif key == "n" then
            if eff == false then
                eff = true
            else
                eff = false
            end
        elseif key == "h" and swordphase == false and gunphase == false then
            if flying == false then
                flying = true
                falling = false
            else
                flying = false
            end
        elseif key == "e" then
            e2Event:FireAllClients("clear", {
                "yo wth"
            })
            local nams = {"cleared death table.", "you've been forgiven.", "you have been unbanished.", "you are now free."}
            table.clear(deathtabl)
            chatfunc(nams[math.random(1, #nams)])
        elseif key == "keypadnine" then
            banishpart = not banishpart
            FireClient(InputRemote,plr,"Notify",{Title="max's destroyer",Text="BanishParts set to "..tostring(banishpart),Duration=3})
        elseif key == "keypadeight" then
            deadpart = {}
            chatfunc("--Table is kil",1,2)
        elseif key == "keypadone" then
            chattersgui = not chattersgui
            FireClient(InputRemote,plr,"Notify",{Title="max's destroyer",Text="Chatted gui set to "..tostring(chattersgui),Duration=3})
        elseif key == "keypadtwo" then
            nilchar = not nilchar
            FireClient(InputRemote,plr,"Notify",{Title="max's destroyer",Text="Nil Character set to "..tostring(nilchar),Duration=3})
        elseif key == "keypadnine" then
            banishpart = not banishpart
            FireClient(InputRemote,plr,"Notify",{Title="max's destroyer",Text="Nil Character set to "..tostring(nilchar),Duration=3})
        elseif key == "keypadthree" then
            domovement = not domovement
            FireClient(InputRemote,plr,"Notify",{Title="max's destroyer",Text="Do Movement set to "..tostring(domovement),Duration=3})
        elseif key == "keypadfour" then
            pcall(function()
                antirrt = not antirrt
                mmodel:Destroy()
                effectmodel:Destroy()
            end)
            FireClient(InputRemote,plr,"Notify",{Title="max's destroyer",Text="Anti-RRT set to "..tostring(antirrt),Duration=3})
        elseif key == "keypadsix" then
            dorefit = not dorefit
            FireClient(InputRemote,plr,"Notify",{Title="max's destroyer",Text="Do Refit set to "..tostring(dorefit),Duration=3})
        elseif key == "keypadfive" and attacking == false and gunphase == true then
            crdie()
        end
    end
end))
Add(Mouse.KeyUp:connect(function(key) if disabled == false then
        if key=="w" then 
            W=false 
        elseif key=="a" then
            A=false
        elseif key=="s" then
            S=false
        elseif key=="d" then
            D=false
        elseif key=="space" and flying == true then
            fspace=false
        elseif key=="g" and flying == true then
            dspace=false
        elseif key=="e" then
            rk = false
        end
    end
end))
function ch(v)
    for i, he in pairs(deathtabl) do
        if v.Size == deathtabl[i].Size and v.Transparency == deathtabl[i].Transparency then
            v.CFrame = CFrame.new(math.random(-1e6, 1e6), math.random(-1e6, 1e6), math.random(-1e6, 1e6))
        end
        if v.Size == deathtabl[i].Size and v.Transparency == deathtabl[i].Transparency and v.Color == deathtabl[i].Color then
            v.CFrame = CFrame.new(math.random(-1e6, 1e6), math.random(-1e6, 1e6), math.random(-1e6, 1e6))
        end
        if v.Size == deathtabl[i].Size and v.Color == deathtabl[i].Color then
            v.CFrame = CFrame.new(math.random(-1e6, 1e6), math.random(-1e6, 1e6), math.random(-1e6, 1e6))
        end
        wait()
    end
end
Add(game:GetService("RunService").Heartbeat:Connect(function()
    e2Event:FireAllClients("ignores", {
        mmodel,
        effectmodel,
        soundpart
    })
    pcall(function()
        Torso:FindFirstChildOfClass("SpecialMesh").Scale = Vector3.new(2,2,1)
    end)
end))

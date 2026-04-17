--[[

    Roblox Instance System Re Implementation in pure LUA

]]
local Signal = require('Engine.RBXScriptSignal')

local Constructor = {}
local Classes = {}
local Private = setmetatable({}, { __mode = "k" }) -- weak keys

local function clearTable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function createPrivate(Inst)
    Private[Inst] = {

        Properties = {},

        Attributes = {},
        Tags = {},

        Children = {},
        Parent = nil,

        Methods = {},
        Events = {}

    }

    return Private[Inst]
end

local function getClass(ClassName)
    if Classes[ClassName] then
        return Classes[ClassName] 
    else
        local module = require('Classes.'..ClassName)
        return module
    end
end

local function getPrivate(Inst)
    return Private[Inst]
end

local function addEvent(Inst, Name)
    local Pr = getPrivate(Inst)
    if not Pr then return end

    if Pr.Events[Name] then return end

    local event = Signal.new()
    Pr.Events[Name] = event
end

local function getEvent(Inst, Name)
    local Pr = getPrivate(Inst)
    if not Pr then return end

    return Pr.Events[Name]
end

local function fireEvent(Inst, Name, ...)
    local event = getEvent(Inst, Name)
    if event then
        event:Fire(...)
    end
end


local function destroyAllEvents(Inst, ignoreList)
    local Pr = getPrivate(Inst)
    if not Pr then return end

    for Name, Event in pairs(Pr.Events) do
        if not ignoreList or not ignoreList[Name] then
            if Event and Event.Destroy then
                Event:Destroy()
            end
            Pr.Events[Name] = nil
        end
    end
end


local function getChildren(Inst)
    local Pr = getPrivate(Inst)
    if not Pr then return end
    if not Pr.Children then return end

    return Pr.Children
end

local function addChildRaw(Inst, ChildInst)
    local Pr = getPrivate(Inst)
    if not Pr then return end

    table.insert(Pr.Children, ChildInst)
    fireEvent(Inst, 'ChildAdded', ChildInst)
end

local function removeChildRaw(Inst, ChildInst)
    if not Inst then return end
    local Pr = getPrivate(Inst)
    if not Pr then return end

    for i, child in ipairs(Pr.Children) do
        if child == ChildInst then
            table.remove(Pr.Children, i)
            break
        end
    end

    fireEvent(Inst, 'ChildRemoved', ChildInst)
end
local function findFirstChild(Inst, Name, strict)
    local InstPrivate = getPrivate(Inst)
    assert(InstPrivate, "Instance was not made properly")

    local Children = InstPrivate.Children
    assert(Children, "Instance Children table is missing")

    local Found

    for i, child in ipairs(Children) do
        if child.Name == Name then
            Found = child
            break
        end
    end

    if not Found and strict then error('no child found') end
    return Found
end

local function clearAllChildren(Inst)
    local InstPrivate = getPrivate(Inst)
    assert(InstPrivate, "Instance was not made properly")

    local Children = InstPrivate.Children
    assert(Children, "Instance Children table is missing")


    for i = #Children, 1, -1 do
        Children[i]:Destroy()
    end
end

local function getParent(Inst)
    local Pr = getPrivate(Inst)
    if not Pr then return end

    return Pr.Parent
end

local function setParent(Inst, newParent)
    local Pr = getPrivate(Inst)
    if not Pr then return end

    local oldParent = Pr.Parent
    if oldParent == newParent then
        return
    end

    if oldParent then
        removeChildRaw(oldParent, Inst)
    end

    Pr.Parent = newParent

    if newParent then
        addChildRaw(newParent, Inst)
    end
end

local function destroy(Inst)
    local Pr = getPrivate(Inst)
    if not Pr then return end

   clearAllChildren(Inst)

    Pr.Parent = nil

    destroyAllEvents(Inst, {['Destroying'] = true})
    fireEvent(Inst, 'Destroying')
    destroyAllEvents(Inst)
end

local function getMethodOfInstance(Inst, Method)
    local Pr = getPrivate(Inst)
    if not Pr then return end

    if Pr.Methods[Method] then
        return Pr.Methods[Method]
    end
end

local function getAndRunMethodOfInstance(Inst, MethodName, ...)
    local Method = getMethodOfInstance(Inst, MethodName)
    if not Method then return end

    Method(Inst, ...)
end

local function addInstanceProperty(Inst, PropertyName, PropertyType, DefaultValue, NilAllowed, ReadOnly)
    local InstPrivate = getPrivate(Inst)
    assert(InstPrivate, "Instance was not made properly")

    local Properties = InstPrivate.Properties
    assert(Properties, "Instance properties table is missing")

    local PropertyData = {
        Type = PropertyType,
        Value = DefaultValue,
        NilAllowed = NilAllowed or false,
        ReadOnly = ReadOnly or false
    }

    Properties[PropertyName] = PropertyData
end

local function removeInstanceProperty(Inst, PropertyName)
    local InstPrivate = getPrivate(Inst)
    assert(InstPrivate, "Instance was not made properly")

    local Properties = InstPrivate.Properties
    assert(Properties, "Instance properties table is missing")

    Properties[PropertyName] = nil
end

local function getPropertyValueOfInstance(Inst, Property)
    local InstPrivate = getPrivate(Inst)
    assert(InstPrivate, "Instance was not made properly")

    if Property == 'Parent' then
        return getParent(Inst)
    end

    local Properties = InstPrivate.Properties
    assert(Properties, "Instance properties table is missing")

    return Properties[Property] and Properties[Property].Value
end

local function setPropertyValueOfInstance(Inst, PropertyName, NewValue)
    local InstPrivate = getPrivate(Inst)
    assert(InstPrivate, "Instance was not made properly")

    -- Parenting
    if PropertyName == 'Parent' then
        return setParent(Inst, NewValue)
    end

    local Properties = InstPrivate.Properties
    assert(Properties, "Instance properties table is missing")
    
    local Property = Properties[PropertyName]
    if not Property then error('Instance doesnt have a '..PropertyName ..' property') end

    local NewValType = type(NewValue)
    local AllowedType = Property.Type

    if Property.ReadOnly then
        error("Property is read-only")
    end

    if NewValue == nil and not Property.NilAllowed then
        error("Nil not allowed")
    end

    if NewValType ~= AllowedType then
        error('property type mismatch')
    else
        Property.Value = NewValue
    end
end

local function findFirstChildOfClass(Inst, ClassName, strict)
    local InstPrivate = getPrivate(Inst)
    assert(InstPrivate, "Instance was not made properly")

    local Children = InstPrivate.Children
    assert(Children, "Instance Children table is missing")

    local Found

    for i, child in pairs(Children) do
        if child.ClassName == ClassName then
            Found = child
            break
        end
    end

    if not Found and strict then error('no child found') end
    return Found
end

local function setAttribute(Inst, Att, Value)
    local InstPrivate = getPrivate(Inst)
    assert(InstPrivate, "Instance was not made properly")

    local Attributes = InstPrivate.Attributes
    Attributes[Att] = Value

    fireEvent(Inst 'AttributeChanged', Att)
end

local function getAttribute(Inst, Att)
    local InstPrivate = getPrivate(Inst)
    assert(InstPrivate, "Instance was not made properly")

    local Attributes = InstPrivate.Attributes
    return Attributes[Att]
end

local function addTag(Inst, Tag)
    local InstPrivate = getPrivate(Inst)
    assert(InstPrivate, "Instance was not made properly")

    local Tags = InstPrivate.Tags
    Tags[Tag] = true
end

local function removeTag(Inst, Tag)
    local InstPrivate = getPrivate(Inst)
    assert(InstPrivate, "Instance was not made properly")

    local Tags = InstPrivate.Tags
    Tags[Tag] = nil
end

local function hasTag(Inst, Tag)
    local InstPrivate = getPrivate(Inst)
    assert(InstPrivate, "Instance was not made properly")

    local Tags = InstPrivate.Tags
    return Tags[Tag]
end

local function getFullName(Inst)
    local InstPrivate = getPrivate(Inst)
    assert(InstPrivate, "Instance was not made properly")

    local names = {}

    local current = Inst

    while current do
        table.insert(names, current.Name)

        local parent = getParent(current)
        if not parent or parent.Name == "game" then
            break
        end

        current = parent
    end

    -- reverse the names
    local fullName = {}
    for i = #names, 1, -1 do
        table.insert(fullName, names[i])
    end

    return table.concat(fullName, ".")
end

local function clone(Inst)
    local Pr = getPrivate(Inst)
    assert(Pr, "Instance was not made properly")

    local new = Constructor.new(Inst.ClassName)

    local newPr = getPrivate(new)

    for name, prop in pairs(Pr.Properties) do
        if not prop.ReadOnly then
            addInstanceProperty(new, name, prop.Type, prop.Value, prop.NilAllowed, prop.ReadOnly)
        else
            addInstanceProperty(new, name, prop.Type, prop.Value, prop.NilAllowed, prop.ReadOnly)
        end
    end

    for k, v in pairs(Pr.Attributes) do
        newPr.Attributes[k] = v
    end

    for tag in pairs(Pr.Tags) do
        newPr.Tags[tag] = true
    end

    for _, child in ipairs(Pr.Children) do
        local childClone = clone(child)
        childClone.Parent = new
    end

    return new
end

local Instance = {}
local InstanceMt = {
    __index = function(self, key)
        local instMethod = Instance[key]
        if instMethod then
            return instMethod
        end

        local method = getMethodOfInstance(self, key)
        if method then
            return method
        end

        local event = getEvent(self, key)
        if event then
            return event
        end

        local property = getPropertyValueOfInstance(self, key)
        if property ~= nil then
            return property
        end

        return findFirstChild(self, key)
    end,

    __newindex = function(self, key, value)
        setPropertyValueOfInstance(self, key, value)
    end
}

function Constructor.new(ClassName, Parent)
    local self = setmetatable({}, InstanceMt)
    createPrivate(self)
    addInstanceProperty(self, 'Name', 'string', ClassName, false, false)
    
    addEvent(self, 'ChildAdded')
    addEvent(self, 'ChildRemoved')
    addEvent(self, 'Destroying')
    addEvent(self, 'AttributeChanged')

    if Parent then
        setParent(self, Parent)
    end

    return self
end

function Instance:FindFirstChild(Name)
    return findFirstChild(self, Name)
end

function Instance:GetChildren()
    return getChildren(self)
end

function Instance:SetAttribute(Attribute, Value)
    return setAttribute(self, Attribute, Value)
end

function Instance:GetAttribute(Attribute)
    return getAttribute(self, Attribute)
end

function Instance:AddTag(Tag)
    return addTag(self, Tag)
end

function Instance:RemoveTag(Tag)
    return removeTag(self, Tag)
end

function Instance:HasTag(Tag)
    return hasTag(self, Tag)
end

function Instance:GetFullName()
    return getFullName(self)
end

function Instance:ClearAllChildren()
    return clearAllChildren(self)
end

function Instance:Destroy()
    destroy(self)
end

Instance.Clone = clone


return Constructor

--[[------------------------------------------------------------------
--
-- Luvent :: A Simple Event Library
--
-- For documentation and license information see the official project
-- website: <https://github.com/ejmr/Luvent>
--
-- Copyright 2013 Eric James Michael Ritz
--
--]]------------------------------------------------------------------

local Luvent = {}

-- Make sure the library can find the methods for each Luvent object.
Luvent.__index = Luvent

--- Create a new event.
--
-- This is the constructor for creating events, i.e. Luvent objects.
-- The new event will have the name given to the constructor and will
-- use the 'Luvent' table for its metatable.
--
-- @param name The name of the event.
--
-- @return A new event.
function Luvent.newEvent(name)
    local event = {}

    --- An event object created by Luvent.
    --
    -- @class table
    -- @name Event
    --
    -- @field name A string with the name of the event.
    --
    -- @field actions An array containing all actions to execute when
    -- triggering this event.
    --
    -- @see newAction
    assert(type(name) == "string")
    event.name = name
    event.actions = {}
    
    return setmetatable(event, Luvent)
end

--- Compare two events for equality.
--
-- Two events are equal if they meet three criteria.  First, they must
-- have the same 'name' property.  Second, their 'actions' properties
-- must be tables of the same length.  And finally, their 'actions'
-- tables must contain the same contents.  The test can be slow
-- because the comparison has an O(N^2) complexity.
--
-- @return A boolean indicating whether or not the events are equal.
Luvent.__eq = function (e1, e2)
    if getmetatable(e1) ~= Luvent or getmetatable(e2) ~= Luvent then
        return false
    end

    if e1.name ~= e2.name then return false end
    if #e1.actions ~= #e2.actions then return false end

    for _,a1 in ipairs(e1.actions) do
        local found = false
        for _,a2 in ipairs(e2.actions) do
            if a1 == a2 then
                found = true
                break
            end
        end
        if found == false then return false end
    end

    return true
end

--- The metatable that internally designates actions.
--
-- @class table
Luvent.Action = {}
Luvent.Action.__index = Luvent.Action

--- Determine if something is a valid action callable.
--
-- Every action must have a 'callable' property which actually
-- executes the logic for that action.  That property must satisfy
-- this predicate.
--
-- @param callable The object to test.
--
-- @return Boolean true if the parameter is a valid callable, and
-- boolean false if it is not.
local function isValidActionCallable(callable)
    if type(callable) == "table" then
        if type(getmetatable(callable)["__call"]) == "function" then
            return true
        else
            return false
        end
    elseif type(callable) == "function" then
        return true
    end
end

--- Create a new action.
--
-- Luvent stores actions as tables, which this function creates.
-- These tables are private to the library and no part of the public
-- API ever accepts or returns them.
--
-- @param callable The actual logic to execute for this action.
--
-- @param interval The number of seconds to wait between invocations.
-- By default this value is zero.
--
-- @return The new action.
local function newAction(callable, interval)
    local action = {}
    
    assert(isValidActionCallable(callable))
    action.callable = callable
    action.interval = interval or 0

    -- If we have a non-zero interval then we need to keep track of
    -- how often we consider this action for execution.  The property
    -- below contains the time of when we last called this action, and
    -- when considering whether or not to call it again we subtract
    -- the current time from this time and see if it is greater to or
    -- equal than the interval.  When first creating the action we set
    -- the property to the current time so that we can start counting
    -- the clock from the moment we created the action (i.e. now) up
    -- until the first time the interval elapses.
    action.timeOfLastInvocation = os.time()

    return setmetatable(action, Luvent.Action)
end

--- Compare two actions for equality.
--
-- @return A boolean indicating if the actions are equivalent.
Luvent.Action.__eq = function (a1, a2)
    if getmetatable(a1) ~= Luvent.Action
    or getmetatable(a2) ~= Luvent.Action then
        return false
    end

    if a1.callable ~= a2.callable then return false end

    return true
end

--- Find a specific action associated with an event.
--
-- @param event The event in which we search for the action.
-- @param actionToFind The action to search for.
--
-- @return The function always returns two values.  If the event
-- contains the action then the function returns boolean true and an
-- integer, the index where that action appears in the event's table
-- of actions.  If the event does not contain the action then the
-- function returns boolean false and nil.
local function findAction(event, actionToFind)
    for index,action in ipairs(event.actions) do
        if action.callable == actionToFind then
            return true, index
        end
    end
    return false, nil
end

--- Add a new action to an event.
--
-- This function is private to Luvent and exists to factor out the
-- common logic in the public API for adding actions to events.
--
-- @see Luvent:addAction
-- @see Luvent:addActionWithInterval
local function addActionToEvent(event, action, interval)
    local interval = interval or 0
    
    assert(isValidActionCallable(action) == true)
    assert(type(interval) == "number")

    -- We do not allow adding an action more than once to an event.
    if event:callsAction(action) then return end

    table.insert(event.actions, newAction(action, interval))
end

--- Add an action to an event.
--
-- It is not possible to add the same action more than once.
--
-- @param actionToAdd A function or callable table to run when
-- triggering this event.
--
-- @see isValidActionCallable
function Luvent:addAction(actionToAdd)
    return addActionToEvent(self, actionToAdd)
end

--- Add an action that will on an interval.
--
-- @param actionToAdd The action to run when triggering the event.
--
-- @param interval The number of seconds to wait between invocations
-- of this action.  Luvent only guarantees that the triggering the
-- event will not execute this action until this many seconds have
-- elapsed.  Once the interval elapses the event still must trigger
-- the action in the same way it does for all actions.  The interval
-- will not reset until the event invokes the action.
--
-- @see Luvent:trigger
function Luvent:addActionWithInterval(actionToAdd, interval)
    return addActionToEvent(self, actionToAdd, interval)
end

--- Remove an action from an event.
--
-- This method accepts an action and disassociates it from the event.
-- It is safe to call this method even if the action is not associated
-- with the event.
--
-- @param actionToRemove The function to remove from the list of
-- actions for this event.
--
-- @see Luvent:addAction
function Luvent:removeAction(actionToRemove)
    local exists,index = findAction(self, actionToRemove)
    if exists == true then
        table.remove(self.actions, index)
    end
end

--- Remove all actions from an event.
--
-- @see Luvent:removeAction
function Luvent:removeAllActions()
    self.actions = {}
end

--- Check for the existence of an action.
--
-- @param actionToFind The action to search for within the event's
-- list of actions.
--
-- @return Boolean true if the event uses the action, and false if it
-- does not.
function Luvent:callsAction(actionToFind)
    return (findAction(self, actionToFind))
end

--- Trigger an event.
--
-- This method executes every action associated with the event.
-- Luvent throws away the return values from all actions invoked by
-- this method.
--
-- @param ... All arguments given to this method will be passed along
-- to every action.
function Luvent:trigger(...)
    local arguments = { ... }
    for _,action in ipairs(self.actions) do
        if action.interval > 0 then
            if os.difftime(os.time(), action.timeOfLastInvocation) >= action.interval then
                action.callable(unpack(arguments))
                action.timeOfLastInvocation = os.time()
            end
        else
            action.callable(unpack(arguments))
        end
    end
end

-- Do not allow external code to modify the metatable of events and
-- actions in order to improve stability, particularly by preventing
-- bugs caused by external manipulation of the metatable.
Luvent.Action.__metatable = Luvent.Action
Luvent.__metatable = Luvent

return Luvent

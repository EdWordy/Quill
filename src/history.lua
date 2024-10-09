local History = {}

local actions = {}
local currentAction = 0
local maxActions = 50

function History.init()
    actions = {}
    currentAction = 0
end

function History.addAction(action)
    -- Remove any future actions if we're not at the end of the history
    for i = currentAction + 1, #actions do
        actions[i] = nil
    end
    
    currentAction = currentAction + 1
    actions[currentAction] = action
    
    -- Remove oldest action if we've exceeded the maximum
    if currentAction > maxActions then
        table.remove(actions, 1)
        currentAction = maxActions
    end
end

function History.undo()
    if currentAction > 0 then
        actions[currentAction].undo()
        currentAction = currentAction - 1
        return true
    end
    return false
end

function History.redo()
    if currentAction < #actions then
        currentAction = currentAction + 1
        actions[currentAction].redo()
        return true
    end
    return false
end

return History
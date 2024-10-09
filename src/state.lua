local Config = require("src.config")

local State = {
    data = {}
}

function State.init()
    State.data = {
        currentTool = "brush",
        currentColor = Config.DEFAULT_COLOR,
        brushSize = Config.DEFAULT_BRUSH_SIZE,
        brushStyle = Config.DEFAULT_BRUSH_STYLE,
        brushOpacity = 1, -- New property
        selection = nil,
        clipboard = nil,
        windowWidth = Config.MIN_WIDTH,
        windowHeight = Config.MIN_HEIGHT,
        editMode = false,
        zoomLevel = 1,
        canvasOffsetX = 0,
        canvasOffsetY = 0
    }
end


function State.get(key)
    return State.data[key]
end

function State.set(key, value)
    State.data[key] = value
end

function State.update()
    local newWidth, newHeight = love.graphics.getDimensions()
    if newWidth ~= State.data.windowWidth or newHeight ~= State.data.windowHeight then
        State.data.windowWidth = newWidth
        State.data.windowHeight = newHeight
    end
end

return State
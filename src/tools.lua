local State = require("src.state")
local Canvas = require("src.canvas")
local History = require("src.history")

local Tools = {}

-- Brush tool

Tools.brush = {
    isDrawing = false,
    lastX = 0,
    lastY = 0,
    oldImageData = nil,
    layerIndex = nil,

    mousepressed = function(x, y, button)
        if button == 1 then
            Tools.brush.isDrawing = true
            Tools.brush.lastX = x
            Tools.brush.lastY = y
            Tools.brush.layerIndex = Canvas.layers.currentLayer
            local currentLayer = Canvas.getCurrentLayer()
            Tools.brush.oldImageData = currentLayer.canvas:newImageData()
            Canvas.beginDraw()
            local color = State.get("currentColor")
            local opacity = State.get("brushOpacity")
            local drawColor = {color[1], color[2], color[3], opacity}
            love.graphics.setColor(drawColor)
            if State.get("brushStyle") == "circle" then
                love.graphics.circle("fill", x, y, State.get("brushSize") / 2)
            elseif State.get("brushStyle") == "square" then
                love.graphics.rectangle("fill", x - State.get("brushSize")/2, y - State.get("brushSize")/2, State.get("brushSize"), State.get("brushSize"))
            end
            Canvas.endDraw()
        end
    end,

    mousemoved = function(x, y, dx, dy)
        if Tools.brush.isDrawing then
            Canvas.beginDraw()
            local color = State.get("currentColor")
            local opacity = State.get("brushOpacity")
            local drawColor = {color[1], color[2], color[3], opacity}
            love.graphics.setColor(drawColor)
            love.graphics.setLineWidth(State.get("brushSize"))
            love.graphics.line(Tools.brush.lastX, Tools.brush.lastY, x, y)
            if State.get("brushStyle") == "circle" then
                love.graphics.circle("fill", x, y, State.get("brushSize") / 2)
            elseif State.get("brushStyle") == "square" then
                love.graphics.rectangle("fill", x - State.get("brushSize")/2, y - State.get("brushSize")/2, State.get("brushSize"), State.get("brushSize"))
            end
            Canvas.endDraw()
            Tools.brush.lastX = x
            Tools.brush.lastY = y
        end
    end,

    mousereleased = function(x, y, button)
        if button == 1 and Tools.brush.isDrawing then
            Tools.brush.isDrawing = false
            local currentLayer = Canvas.getCurrentLayer()
            local newImageData = currentLayer.canvas:newImageData()
            local oldImageData = Tools.brush.oldImageData
            local layerIndex = Tools.brush.layerIndex
            
            History.addAction({
                undo = function()
                    local layer = Canvas.layers.layers[layerIndex]
                    if layer and layer.canvas then
                        local image = love.graphics.newImage(oldImageData)
                        layer.canvas:renderTo(function()
                            love.graphics.clear()
                            love.graphics.draw(image)
                        end)
                        Canvas.setNeedsRedraw()
                    else
                        print("Warning: Unable to undo brush action. Layer or canvas is nil.")
                    end
                end,
                redo = function()
                    local layer = Canvas.layers.layers[layerIndex]
                    if layer and layer.canvas then
                        local image = love.graphics.newImage(newImageData)
                        layer.canvas:renderTo(function()
                            love.graphics.clear()
                            love.graphics.draw(image)
                        end)
                        Canvas.setNeedsRedraw()
                    else
                        print("Warning: Unable to redo brush action. Layer or canvas is nil.")
                    end
                end
            })
        end
    end,

    update = function(dt) end,
    draw = function()
        local color = State.get("currentColor")
        local opacity = State.get("brushOpacity")
        love.graphics.setColor(color[1], color[2], color[3], opacity)
        local x, y = love.mouse.getPosition()
        if State.get("brushStyle") == "circle" then
            love.graphics.circle("fill", x, y, State.get("brushSize") / 2)
        elseif State.get("brushStyle") == "square" then
            love.graphics.rectangle("fill", x - State.get("brushSize")/2, y - State.get("brushSize")/2, State.get("brushSize"), State.get("brushSize"))
        end
    end,
    keypressed = function(key) end
}

-- Flood fill tool
Tools.floodFill = {
    update = function(dt) end,
    draw = function() end,
    mousepressed = function(x, y, button)
        if button == 1 then
            local currentLayer = Canvas.getCurrentLayer()
            local oldImageData = currentLayer.canvas:newImageData()
            currentLayer:floodFill(x, y, State.get("currentColor"))
            local newImageData = currentLayer.canvas:newImageData()
            History.addAction({
                undo = function()
                    currentLayer.canvas:replacePixels(oldImageData)
                end,
                redo = function()
                    currentLayer.canvas:replacePixels(newImageData)
                end,
                undoImageData = oldImageData,
                redoImageData = newImageData
            })
        end
    end,
    mousemoved = function(x, y, dx, dy) end,
    mousereleased = function(x, y, button) end,
    keypressed = function(key) end
}

-- Selection tool
Tools.selection = {
    startX = 0,
    startY = 0,
    endX = 0,
    endY = 0,
    selecting = false,
    moving = false,
    offsetX = 0,
    offsetY = 0,
    oldImageData = nil,

    update = function(dt) end,
    draw = function()
        if State.get("selection") then
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.rectangle("line", 
                State.get("selection").x, 
                State.get("selection").y, 
                State.get("selection").width, 
                State.get("selection").height
            )
        elseif Tools.selection.selecting then
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.rectangle("line", 
                Tools.selection.startX, 
                Tools.selection.startY, 
                Tools.selection.endX - Tools.selection.startX, 
                Tools.selection.endY - Tools.selection.startY
            )
        end
    end,
    mousepressed = function(x, y, button)
        if button == 1 then
            local selection = State.get("selection")
            if selection and Tools.selection:isInside(x, y) then
                Tools.selection.moving = true
                Tools.selection.offsetX = x - selection.x
                Tools.selection.offsetY = y - selection.y
                local currentLayer = Canvas.getCurrentLayer()
                Tools.selection.oldImageData = currentLayer.canvas:newImageData()
            else
                Tools.selection.selecting = true
                Tools.selection.startX = x
                Tools.selection.startY = y
                Tools.selection.endX = x
                Tools.selection.endY = y
                State.set("selection", nil)
            end
        end
    end,
    mousemoved = function(x, y, dx, dy)
        if Tools.selection.selecting then
            Tools.selection.endX = x
            Tools.selection.endY = y
        elseif Tools.selection.moving then
            local selection = State.get("selection")
            if selection then
                local newX = x - Tools.selection.offsetX
                local newY = y - Tools.selection.offsetY
                local currentLayer = Canvas.getCurrentLayer()
                currentLayer:moveSelection(selection, newX, newY)
                selection.x = newX
                selection.y = newY
                State.set("selection", selection)
            end
        end
    end,
    mousereleased = function(x, y, button)
        if button == 1 then
            if Tools.selection.selecting then
                Tools.selection.selecting = false
                State.set("selection", {
                    x = math.min(Tools.selection.startX, Tools.selection.endX),
                    y = math.min(Tools.selection.startY, Tools.selection.endY),
                    width = math.abs(Tools.selection.endX - Tools.selection.startX),
                    height = math.abs(Tools.selection.endY - Tools.selection.startY)
                })
                local currentLayer = Canvas.getCurrentLayer()
                currentLayer:copyRegion(State.get("selection"))
            elseif Tools.selection.moving then
                Tools.selection.moving = false
                local currentLayer = Canvas.getCurrentLayer()
                local newImageData = currentLayer.canvas:newImageData()
                History.addAction({
                    undo = function()
                        currentLayer.canvas:replacePixels(Tools.selection.oldImageData)
                    end,
                    redo = function()
                        currentLayer.canvas:replacePixels(newImageData)
                    end,
                    undoImageData = Tools.selection.oldImageData,
                    redoImageData = newImageData
                })
            end
        end
    end,
    keypressed = function(key)
        if key == "delete" and State.get("selection") then
            local currentLayer = Canvas.getCurrentLayer()
            local oldImageData = currentLayer.canvas:newImageData()
            currentLayer:clearRegion(State.get("selection"))
            local newImageData = currentLayer.canvas:newImageData()
            History.addAction({
                undo = function()
                    currentLayer.canvas:replacePixels(oldImageData)
                end,
                redo = function()
                    currentLayer.canvas:replacePixels(newImageData)
                end,
                undoImageData = oldImageData,
                redoImageData = newImageData
            })
            State.set("selection", nil)
        end
    end,
    isInside = function(self, x, y)
        local selection = State.get("selection")
        if not selection then return false end
        return x >= selection.x and
               x <= selection.x + selection.width and
               y >= selection.y and
               y <= selection.y + selection.height
    end
}

function Tools.copySelection()
    if State.get("selection") then
        local currentLayer = Canvas.getCurrentLayer()
        State.set("clipboard", currentLayer:copyRegion(State.get("selection")))
    end
end

function Tools.pasteSelection()
    if State.get("clipboard") then
        local mouseX, mouseY = love.mouse.getPosition()
        local currentLayer = Canvas.getCurrentLayer()
        local oldImageData = currentLayer.canvas:newImageData()
        currentLayer:pasteRegion(State.get("clipboard"), mouseX, mouseY)
        local newImageData = currentLayer.canvas:newImageData()
        History.addAction({
            undo = function()
                currentLayer.canvas:replacePixels(oldImageData)
            end,
            redo = function()
                currentLayer.canvas:replacePixels(newImageData)
            end,
            undoImageData = oldImageData,
            redoImageData = newImageData
        })
        State.set("selection", {
            x = mouseX,
            y = mouseY,
            width = State.get("clipboard"):getWidth(),
            height = State.get("clipboard"):getHeight()
        })
    end
end

function Tools.cutSelection()
    if State.get("selection") then
        Tools.copySelection()
        local currentLayer = Canvas.getCurrentLayer()
        local oldImageData = currentLayer.canvas:newImageData()
        currentLayer:clearRegion(State.get("selection"))
        local newImageData = currentLayer.canvas:newImageData()
        History.addAction({
            undo = function()
                currentLayer.canvas:replacePixels(oldImageData)
            end,
            redo = function()
                currentLayer.canvas:replacePixels(newImageData)
            end,
            undoImageData = oldImageData,
            redoImageData = newImageData
        })
        State.set("selection", nil)
    end
end

function Tools.init()
    -- Any necessary tool initialization
end

function Tools.update(dt)
    Tools[State.get("currentTool")].update(dt)
end

function Tools.draw()
    Tools[State.get("currentTool")].draw()
end

function Tools.mousepressed(x, y, button)
    Tools[State.get("currentTool")].mousepressed(x, y, button)
end

function Tools.mousereleased(x, y, button)
    Tools[State.get("currentTool")].mousereleased(x, y, button)
end

function Tools.mousemoved(x, y, dx, dy)
    Tools[State.get("currentTool")].mousemoved(x, y, dx, dy)
end

function Tools.keypressed(key)
    Tools[State.get("currentTool")].keypressed(key)
end

return Tools
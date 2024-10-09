local State = require("src.state")
local History = require("src.history")

local Canvas = {}

local Layer = {}
Layer.__index = Layer

function Layer.new()
    local self = setmetatable({}, Layer)
    self.canvas = love.graphics.newCanvas()
    self.tempCanvas = love.graphics.newCanvas()
    self.selectionCanvas = nil
    self.visible = true
    self.operations = {}
    return self
end

function Layer:beginDraw()
    love.graphics.setCanvas(self.tempCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas)
    love.graphics.setBlendMode("alpha")
end

function Layer:endDraw()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.tempCanvas)
    love.graphics.setCanvas()
end

function Layer:drawPoint(x, y, color, size, style)
    local operation = {type="point", x=x, y=y, color=color, size=size, style=style}
    table.insert(self.operations, operation)
    self:applyOperation(operation, self.tempCanvas)
end

function Layer:drawLine(x1, y1, x2, y2, color, size, style)
    local points = self:interpolatePoints(x1, y1, x2, y2, size)
    for i = 1, #points - 1 do
        local p1, p2 = points[i], points[i+1]
        local operation = {type="line", x1=p1.x, y1=p1.y, x2=p2.x, y2=p2.y, color=color, size=size, style=style}
        table.insert(self.operations, operation)
        self:applyOperation(operation, self.tempCanvas)
    end
end

function Layer:interpolatePoints(x1, y1, x2, y2, size)
    local points = {{x = x1, y = y1}}
    local dx, dy = x2 - x1, y2 - y1
    local distance = math.sqrt(dx*dx + dy*dy)
    local steps = math.max(1, math.floor(distance / (size / 4)))
    
    for i = 1, steps do
        local t = i / steps
        local x = x1 + dx * t
        local y = y1 + dy * t
        table.insert(points, {x = x, y = y})
    end
    
    table.insert(points, {x = x2, y = y2})
    return points
end

function Layer:applyOperation(operation, targetCanvas)
    love.graphics.setCanvas(targetCanvas)
    love.graphics.setColor(operation.color)
    if operation.type == "point" then
        if operation.style == "circle" then
            love.graphics.circle("fill", operation.x, operation.y, operation.size / 2)
        elseif operation.style == "square" then
            love.graphics.rectangle("fill", operation.x - operation.size/2, operation.y - operation.size/2, operation.size, operation.size)
        end
    elseif operation.type == "line" then
        love.graphics.setLineWidth(operation.size)
        love.graphics.setLineStyle("smooth")
        love.graphics.line(operation.x1, operation.y1, operation.x2, operation.y2)
        love.graphics.circle("fill", operation.x1, operation.y1, operation.size / 2)
        love.graphics.circle("fill", operation.x2, operation.y2, operation.size / 2)
    end
    love.graphics.setCanvas()
end

function Layer:draw()
    if self.visible then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.canvas)
        love.graphics.draw(self.tempCanvas)
    end
end

function Layer:floodFill(x, y, targetColor)
    local imageData = self.canvas:newImageData()
    local width, height = imageData:getDimensions()
    local originalColor = {imageData:getPixel(x, y)}
    
    local function colorMatch(c1, c2)
        return math.abs(c1[1] - c2[1]) < 0.01 and
               math.abs(c1[2] - c2[2]) < 0.01 and
               math.abs(c1[3] - c2[3]) < 0.01 and
               math.abs(c1[4] - c2[4]) < 0.01
    end
    
    local function fill(x, y)
        if x < 0 or x >= width or y < 0 or y >= height then return end
        local currentColor = {imageData:getPixel(x, y)}
        if not colorMatch(currentColor, originalColor) then return end
        if colorMatch(currentColor, targetColor) then return end
        
        imageData:setPixel(x, y, targetColor[1], targetColor[2], targetColor[3], targetColor[4])
        
        fill(x + 1, y)
        fill(x - 1, y)
        fill(x, y + 1)
        fill(x, y - 1)
    end
    
    fill(x, y)
    self.canvas:replacePixels(imageData)
end

function Layer:copyRegion(selection)
    self.selectionCanvas = love.graphics.newCanvas(selection.width, selection.height)
    love.graphics.setCanvas(self.selectionCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.draw(self.canvas, -selection.x, -selection.y)
    love.graphics.setCanvas()
    return self.selectionCanvas
end

function Layer:pasteRegion(copyCanvas, x, y)
    love.graphics.setCanvas(self.canvas)
    love.graphics.draw(copyCanvas, x, y)
    love.graphics.setCanvas()
end

function Layer:clearRegion(selection)
    love.graphics.setCanvas(self.canvas)
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(0, 0, 0, 0)
    love.graphics.rectangle("fill", selection.x, selection.y, selection.width, selection.height)
    love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas()
end

function Layer:moveSelection(selection, newX, newY)
    if self.selectionCanvas then
        self:clearRegion(selection)
        self:pasteRegion(self.selectionCanvas, newX, newY)
    end
end

function Layer:toggleVisibility()
    self.visible = not self.visible
end

local Layers = {}
Layers.__index = Layers

function Layers.new()
    local self = setmetatable({}, Layers)
    self.layers = {Layer.new()}
    self.currentLayer = 1
    return self
end

function Layers:draw()
    for _, layer in ipairs(self.layers) do
        if layer.visible then
            layer:draw()
        end
    end
end

function Layers:getCurrentLayer()
    return self.layers[self.currentLayer]
end

function Layers:addLayer()
    table.insert(self.layers, Layer.new())
    self.currentLayer = #self.layers
    History.addAction({
        undo = function() self:removeLayer(#self.layers) end,
        redo = function() self:addLayer() end
    })
end

function Layers:removeLayer(index)
    if #self.layers > 1 then
        local removedLayer = table.remove(self.layers, index)
        self.currentLayer = math.min(self.currentLayer, #self.layers)
        History.addAction({
            undo = function() 
                table.insert(self.layers, index, removedLayer)
                self.currentLayer = index
            end,
            redo = function() self:removeLayer(index) end
        })
    end
end

function Layers:selectLayer(index)
    if index >= 1 and index <= #self.layers then
        self.currentLayer = index
    end
end

function Layers:moveLayerUp(index)
    if index < #self.layers then
        self.layers[index], self.layers[index + 1] = self.layers[index + 1], self.layers[index]
        self.currentLayer = index + 1
        History.addAction({
            undo = function() self:moveLayerDown(index + 1) end,
            redo = function() self:moveLayerUp(index) end
        })
    end
end

function Layers:moveLayerDown(index)
    if index > 1 then
        self.layers[index], self.layers[index - 1] = self.layers[index - 1], self.layers[index]
        self.currentLayer = index - 1
        History.addAction({
            undo = function() self:moveLayerUp(index - 1) end,
            redo = function() self:moveLayerDown(index) end
        })
    end
end

function Layers:toggleLayerVisibility(index)
    if index >= 1 and index <= #self.layers then
        self.layers[index]:toggleVisibility()
    end
end

Canvas.needsRedraw = false

function Canvas.init()
    Canvas.layers = {
        layers = {},
        currentLayer = 1
    }
    Canvas.addLayer()
end

function Canvas.addLayer()
    local newLayer = {
        canvas = love.graphics.newCanvas(),
        visible = true
    }
    table.insert(Canvas.layers.layers, newLayer)
    Canvas.layers.currentLayer = #Canvas.layers.layers
    Canvas.needsRedraw = true
end

function Canvas.draw()
    for _, layer in ipairs(Canvas.layers.layers) do
        if layer.visible then
            love.graphics.draw(layer.canvas)
        end
    end
    Canvas.needsRedraw = false
end

function Canvas.getCurrentLayer()
    return Canvas.layers.layers[Canvas.layers.currentLayer]
end

function Canvas.setNeedsRedraw()
    Canvas.needsRedraw = true
end

-- Add these new functions
function Canvas.beginDraw()
    local currentLayer = Canvas.getCurrentLayer()
    love.graphics.setCanvas(currentLayer.canvas)
end

function Canvas.endDraw()
    love.graphics.setCanvas()
    Canvas.setNeedsRedraw()
end

function Canvas.updateLayer(layerIndex, imageData)
    if Canvas.layers and Canvas.layers.layers and Canvas.layers.layers[layerIndex] then
        local layer = Canvas.layers.layers[layerIndex]
        if layer.canvas then
            layer.canvas:replacePixels(imageData)
        else
            print("Warning: Canvas for layer " .. layerIndex .. " is nil")
            -- Attempt to recreate the canvas
            layer.canvas = love.graphics.newCanvas()
            layer.canvas:renderTo(function()
                love.graphics.clear()
                love.graphics.draw(love.graphics.newImage(imageData))
            end)
        end
    else
        print("Error: Invalid layer index or layers not initialized")
    end
end

function Canvas.toggleLayerVisibility(index)
    Canvas.layers:toggleLayerVisibility(index)
end

function Canvas.forceRedraw()
    for _, layer in ipairs(Canvas.layers.layers) do
        if layer.canvas then
            local tempImageData = layer.canvas:newImageData()
            layer.canvas:renderTo(function()
                love.graphics.clear()
                love.graphics.draw(love.graphics.newImage(tempImageData))
            end)
        end
    end
end

return Canvas
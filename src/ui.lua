local State = require("src.state")
local Config = require("src.config")
local Canvas = require("src.canvas")

local UI = {}

local function snapToGrid(value)
    return math.floor(value / Config.GRID_SIZE + 0.5) * Config.GRID_SIZE
end

local Module = {}
Module.__index = Module

function Module.new(title, x, y)
    local self = setmetatable({}, Module)
    self.title = title
    self.x = snapToGrid(x)
    self.y = snapToGrid(y)
    self.elements = {}
    self.dragging = false
    return self
end

function Module:addButton(text, onClick)
    table.insert(self.elements, {
        type = "button",
        text = text,
        onClick = onClick
    })
end

function Module:addSlider(min, max, value, onChange)
    table.insert(self.elements, {
        type = "slider",
        min = min,
        max = max,
        value = value,
        onChange = onChange
    })
end

function Module:addColorPicker(color, onChange)
    table.insert(self.elements, {
        type = "colorPicker",
        color = color,
        onChange = onChange
    })
end

function Module:addLabel(text)
    table.insert(self.elements, {
        type = "label",
        text = text
    })
end

function Module:addLayerControl(layerIndex, isVisible, onSelect, onToggleVisibility)
    table.insert(self.elements, {
        type = "layerControl",
        layerIndex = layerIndex,
        visible = isVisible,
        onSelect = onSelect,
        onToggleVisibility = onToggleVisibility
    })
end

function Module:calculateSize()
    local width = 200 -- Minimum width
    local height = 30 -- Title bar height
    for _, element in ipairs(self.elements) do
        if element.type == "button" then
            height = height + 30
        elseif element.type == "slider" then
            height = height + 40
        elseif element.type == "colorPicker" then
            height = height + 220
            width = math.max(width, 220)
        elseif element.type == "label" then
            height = height + 20
        elseif element.type == "layerControl" then
            height = height + 25
        end
    end
    self.width = snapToGrid(width)
    self.height = snapToGrid(height)
end

function Module:draw(editMode)
    -- Reset graphics state
    love.graphics.setBackgroundColor(1,1,1)
    love.graphics.setLineWidth(1)
    love.graphics.setLineStyle("smooth")
    love.graphics.setBlendMode("alpha")

    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(self.title, self.x, self.y + 5, self.width, "center")

    local yOffset = 30
    for _, element in ipairs(self.elements) do
        if element.type == "button" then
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", self.x + 10, self.y + yOffset, self.width - 20, 25)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(element.text, self.x + 10, self.y + yOffset + 5, self.width - 20, "center")
            yOffset = yOffset + 30
        elseif element.type == "slider" then
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", self.x + 10, self.y + yOffset + 20, self.width - 20, 10)
            love.graphics.setColor(1, 1, 1)
            local handleX = self.x + 10 + (element.value - element.min) / (element.max - element.min) * (self.width - 20)
            love.graphics.rectangle("fill", handleX - 2, self.y + yOffset + 18, 4, 14)
            love.graphics.printf(tostring(math.floor(element.value)), self.x + 10, self.y + yOffset, self.width - 20, "left")
            yOffset = yOffset + 40
        elseif element.type == "colorPicker" then
            for y = 0, 199 do
                for x = 0, 199 do
                    local h = x / 199
                    local s = 1 - (y / 199)
                    local r, g, b = UI.HSVtoRGB(h, s, 1)
                    love.graphics.setColor(r, g, b)
                    love.graphics.points(self.x + 10 + x, self.y + yOffset + y)
                end
            end
            yOffset = yOffset + 220
        elseif element.type == "label" then
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(element.text, self.x + 10, self.y + yOffset, self.width - 20, "left")
            yOffset = yOffset + 20
        elseif element.type == "layerControl" then
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Layer " .. element.layerIndex, self.x + 10, self.y + yOffset)
            
            love.graphics.setLineWidth(1)  -- Ensure consistent line width for checkbox
            love.graphics.rectangle("line", self.x + self.width - 30, self.y + yOffset, 20, 20)
            if element.visible then
                love.graphics.line(self.x + self.width - 28, self.y + yOffset + 10, self.x + self.width - 22, self.y + yOffset + 18)
                love.graphics.line(self.x + self.width - 22, self.y + yOffset + 18, self.x + self.width - 12, self.y + yOffset + 2)
            end
            
            yOffset = yOffset + 25
        end
    end

    if editMode then
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    end
end

function Module:mousepressed(x, y, button, editMode)
    if button == 1 then
        if editMode and x >= self.x and x <= self.x + self.width and y >= self.y and y <= self.y + 20 then
            self.dragging = true
            self.dragOffsetX = x - self.x
            self.dragOffsetY = y - self.y
            return true
        elseif not editMode then
            local yOffset = 30
            for _, element in ipairs(self.elements) do
                if element.type == "button" then
                    if x >= self.x + 10 and x <= self.x + self.width - 10 and
                        y >= self.y + yOffset and y <= self.y + yOffset + 25 then
                        element.onClick()
                        return true
                    end
                    yOffset = yOffset + 30
                elseif element.type == "slider" then
                    if x >= self.x + 10 and x <= self.x + self.width - 10 and
                        y >= self.y + yOffset + 20 and y <= self.y + yOffset + 30 then
                        local percentage = (x - (self.x + 10)) / (self.width - 20)
                        element.value = element.min + (element.max - element.min) * percentage
                        element.onChange(element.value)
                        return true
                    end
                    yOffset = yOffset + 40
                elseif element.type == "colorPicker" then
                    if x >= self.x + 10 and x <= self.x + 210 and
                        y >= self.y + yOffset and y <= self.y + yOffset + 200 then
                        local h = (x - (self.x + 10)) / 200
                        local s = 1 - (y - (self.y + yOffset)) / 200
                        local r, g, b = UI.HSVtoRGB(h, s, 1)
                        element.color = { r, g, b, 1 }
                        element.onChange(element.color)
                        return true
                    end
                    yOffset = yOffset + 220
                elseif element.type == "label" then
                    yOffset = yOffset + 20
                elseif element.type == "layerControl" then
                    if x >= self.x + 10 and x <= self.x + self.width - 35 and
                        y >= self.y + yOffset and y <= self.y + yOffset + 20 then
                        element.onSelect(element.layerIndex)
                        return true
                    end
                    if x >= self.x + self.width - 30 and x <= self.x + self.width - 10 and
                        y >= self.y + yOffset and y <= self.y + yOffset + 20 then
                        element.visible = not element.visible
                        element.onToggleVisibility(element.layerIndex, element.visible)
                        return true
                    end
                    yOffset = yOffset + 25
                end
            end
        end
    end
    return false
end

function Module:mousemoved(x, y, dx, dy, editMode, windowWidth, windowHeight)
    if editMode and self.dragging then
        local newX = snapToGrid(x - self.dragOffsetX)
        local newY = snapToGrid(y - self.dragOffsetY)
        newX = math.max(0, math.min(newX, windowWidth - self.width))
        newY = math.max(0, math.min(newY, windowHeight - self.height))
        self.x = newX
        self.y = newY
        return true
    end
    return false
end

function Module:mousereleased(x, y, button)
    if button == 1 then
        self.dragging = false
    end
end

function UI.init()
    -- set module positioning
    UI.modules = {
        Module.new("Tools", State.get("windowWidth") - 210, 10),
        Module.new("Layers", State.get("windowWidth") - 210, 160),
        Module.new("Color", 0, 440),
        Module.new("Brush", 0, 200)
    }

    -- Tools module
    UI.modules[1]:addButton("Brush", function() State.set("currentTool", "brush") end)
    UI.modules[1]:addButton("Selection", function() State.set("currentTool", "selection") end)
    UI.modules[1]:addButton("Fill", function() State.set("currentTool", "floodFill") end)

    -- Layers module
    UI.modules[2]:addButton("Add Layer", function()
        Canvas.layers:addLayer()
        UI.updateLayerButtons()
    end)
    UI.modules[2]:addButton("Remove Layer", function()
        if #Canvas.layers.layers > 1 then -- Prevent removing the last layer
            Canvas.layers:removeLayer(Canvas.layers.currentLayer)
            UI.updateLayerButtons()
        end
    end)
    UI.modules[2]:addButton("Move Up", function()
        Canvas.layers:moveLayerUp(Canvas.layers.currentLayer)
        UI.updateLayerButtons()
    end)
    UI.modules[2]:addButton("Move Down", function()
        Canvas.layers:moveLayerDown(Canvas.layers.currentLayer)
        UI.updateLayerButtons()
    end)

    UI.updateLayerButtons()

    -- Color module
    UI.modules[3]:addColorPicker(State.get("currentColor"), function(color) State.set("currentColor", color) end)

    -- Brush module
    UI.modules[4]:addSlider(1, 50, State.get("brushSize"), function(value)
        State.set("brushSize", math.floor(value))
    end)
    UI.modules[4]:addLabel("Brush Size: " .. State.get("brushSize"))

    UI.modules[4]:addButton("Circle Brush", function() State.set("brushStyle", "circle") end)
    UI.modules[4]:addButton("Square Brush", function() State.set("brushStyle", "square") end)

    UI.modules[4]:addSlider(0, 100, State.get("brushOpacity") * 100, function(value)
        State.set("brushOpacity", value / 100)
    end)
    UI.modules[4]:addLabel("Brush Opacity: " .. State.get("brushOpacity") * 100 .. "%")

    -- Calculate sizes for all modules
    for _, module in ipairs(UI.modules) do
        module:calculateSize()
    end

    UI.constrainModulesToWindow()
end

function UI.updateLayerButtons()
    -- Remove all existing layer controls and layer-related labels
    for i = #UI.modules[2].elements, 1, -1 do
        if UI.modules[2].elements[i].type == "layerControl" or
            (UI.modules[2].elements[i].type == "label" and UI.modules[2].elements[i].text:match("^Layer:")) then
            table.remove(UI.modules[2].elements, i)
        end
    end

    -- Add new layer controls
    for i = #Canvas.layers.layers, 1, -1 do -- Reverse order to show top layer at the top
        UI.modules[2]:addLayerControl(
            i,
            Canvas.layers.layers[i].visible,
            function() Canvas.layers:selectLayer(i) end,
            function(_, isVisible) Canvas.toggleLayerVisibility(i) end
        )
    end

    -- Add layer info label
    UI.modules[2]:addLabel("Layer: " .. Canvas.layers.currentLayer .. "/" .. #Canvas.layers.layers)

    -- Recalculate module size
    UI.modules[2]:calculateSize()
end

function UI.constrainModulesToWindow()
    for _, module in ipairs(UI.modules) do
        module.x = math.max(0, math.min(module.x, State.get("windowWidth") - module.width))
        module.y = math.max(0, math.min(module.y, State.get("windowHeight") - module.height))
    end
end

function UI.update(dt)
    UI.modules[4].elements[2].text = "Brush Size: " .. math.floor(State.get("brushSize"))
    UI.modules[4].elements[5].text = "Brush Opacity: " .. math.floor(State.get("brushOpacity") * 100) .. "%"
    
    -- Update layer info label
    for _, element in ipairs(UI.modules[2].elements) do
        if element.type == "label" and element.text:match("^Layer:") then
            element.text = "Layer: " .. Canvas.layers.currentLayer .. "/" .. #Canvas.layers.layers
            break
        end
    end
end

function UI.draw()
    for _, module in ipairs(UI.modules) do
        module:draw(State.get("editMode"))
    end

    if State.get("editMode") then
        love.graphics.setColor(0, 0, 0, 0.5)
        for y = 0, State.get("windowHeight"), Config.GRID_SIZE do
            love.graphics.line(0, y, State.get("windowWidth"), y)
        end
        for x = 0, State.get("windowWidth"), Config.GRID_SIZE do
            love.graphics.line(x, 0, x, State.get("windowHeight"))
        end
    end
end

function UI.mousepressed(x, y, button)
    for _, module in ipairs(UI.modules) do
        if module:mousepressed(x, y, button, State.get("editMode")) then
            return true
        end
    end
    return false
end

function UI.mousemoved(x, y, dx, dy)
    for _, module in ipairs(UI.modules) do
        if module:mousemoved(x, y, dx, dy, State.get("editMode"), State.get("windowWidth"), State.get("windowHeight")) then
            return true
        end
    end
    return false
end

function UI.mousereleased(x, y, button)
    for _, module in ipairs(UI.modules) do
        module:mousereleased(x, y, button)
    end
end

function UI.keypressed(key)
    if key == "`" then
        State.set("editMode", not State.get("editMode"))
        return true
    end
    return false
end

function UI.resize(width, height)
    UI.constrainModulesToWindow()
end

function UI.HSVtoRGB(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then
        r, g, b = v, t, p
    elseif i == 1 then
        r, g, b = q, v, p
    elseif i == 2 then
        r, g, b = p, v, t
    elseif i == 3 then
        r, g, b = p, q, v
    elseif i == 4 then
        r, g, b = t, p, v
    elseif i == 5 then
        r, g, b = v, p, q
    end
    return r, g, b
end

return UI

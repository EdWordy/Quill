local Config = require("src.config")
local State = require("src.state")
local UI = require("src.ui")
local Canvas = require("src.canvas")
local Tools = require("src.tools")
local History = require("src.history")
local FileIO = require("src.fileio")

local App = {}

function App.init()
    love.window.setMode(Config.MIN_WIDTH, Config.MIN_HEIGHT, {
        resizable = true,
        minwidth = Config.MIN_WIDTH,
        minheight = Config.MIN_HEIGHT
    })

    State.init()
    Canvas.init()
    Tools.init()
    History.init()
    UI.init()  -- Move UI initialization to the end
end

function App.update(dt)
    State.update()
    UI.update(dt)
    if not State.get("editMode") then
        Tools.update(dt)
    end
end

function App.draw()
    Canvas.draw()
    if not State.get("editMode") then
        Tools.draw()
    end
    UI.draw()
end

function App.mousepressed(x, y, button, istouch, presses)
    if UI.mousepressed(x, y, button) then return end
    if not State.get("editMode") then
        Tools.mousepressed(x, y, button)
    end
end

function App.mousereleased(x, y, button, istouch, presses)
    UI.mousereleased(x, y, button)
    if not State.get("editMode") then
        Tools.mousereleased(x, y, button)
    end
end

function App.mousemoved(x, y, dx, dy, istouch)
    if UI.mousemoved(x, y, dx, dy) then return end
    if not State.get("editMode") then
        Tools.mousemoved(x, y, dx, dy)
    end
end

function App.keypressed(key)
    if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        if key == "z" then
            if History.undo() then
                print("Undo successful")
                Canvas.setNeedsRedraw()
                UI.updateLayerButtons()
            else
                print("Nothing to undo")
            end
            return
        elseif key == "y" then
            if History.redo() then
                print("Redo successful")
                Canvas.setNeedsRedraw()
                UI.updateLayerButtons()
            else
                print("Nothing to redo")
            end
            return
        elseif key == "s" then
            FileIO.saveProject("project.json")
            print("Project saved")
            return
        elseif key == "o" then
            local success, err = FileIO.loadProject("project.json")
            if success then
                print("Project loaded successfully")
                Canvas.setNeedsRedraw()
                UI.updateLayerButtons()
                History.init()  -- Reset history when loading a new project
            else
                print("Failed to load project: " .. err)
            end
            return
        end
    end
    
    if UI.keypressed(key) then return end
    if not State.get("editMode") then
        Tools.keypressed(key)
    end
end

function App.draw()
    Canvas.draw()
    if not State.get("editMode") then
        Tools.draw()
    end
    UI.draw()
end

function App.resize(width, height)
    width = math.max(Config.MIN_WIDTH, math.min(width, Config.MAX_WIDTH))
    height = math.max(Config.MIN_HEIGHT, math.min(height, Config.MAX_HEIGHT))
    
    love.window.setMode(width, height, {
        resizable = true,
        minwidth = Config.MIN_WIDTH,
        minheight = Config.MIN_HEIGHT
    })

    State.set("windowWidth", width)
    State.set("windowHeight", height)
    UI.resize(width, height)
end

return App
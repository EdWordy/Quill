local FileIO = {}
local Canvas = require("src.canvas")
local json = require("libs.json") -- Make sure to include a JSON library

function FileIO.saveProject(filename)
    local project = {
        layers = {}
    }
    
    for i, layer in ipairs(Canvas.layers.layers) do
        local imageData = layer.canvas:newImageData()
        project.layers[i] = {
            visible = layer.visible,
            data = imageData:encode("png"):getString()
        }
    end
    
    local projectJson = json.encode(project)
    love.filesystem.write(filename, projectJson)
end

function FileIO.loadProject(filename)
    if not love.filesystem.getInfo(filename) then
        return false, "File not found"
    end
    
    local projectJson = love.filesystem.read(filename)
    local project = json.decode(projectJson)
    
    Canvas.layers.layers = {}
    for i, layerData in ipairs(project.layers) do
        local layer = Canvas.layers:addLayer()
        layer.visible = layerData.visible
        local imageData = love.image.newImageData(love.data.newByteData(layerData.data))
        layer.canvas:replacePixels(imageData)
    end
    
    Canvas.layers.currentLayer = 1
    return true
end

return FileIO
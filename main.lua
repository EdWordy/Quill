local App = require("src.app")

function love.load()
    App.init()
end

function love.update(dt)
    App.update(dt)
end

function love.draw()
    App.draw()
end

function love.mousepressed(x, y, button, istouch, presses)
    App.mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    App.mousereleased(x, y, button, istouch, presses)
end

function love.mousemoved(x, y, dx, dy, istouch)
    App.mousemoved(x, y, dx, dy, istouch)
end

function love.wheelmoved(x, y)
    App.wheelmoved(x, y)
end

function love.keypressed(key)
    App.keypressed(key)
end

function love.resize(width, height)
    App.resize(width, height)
end
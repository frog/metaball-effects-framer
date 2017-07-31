# Inspirations
# https://dribbble.com/shots/2729391-metaball-fun
# https://dribbble.com/shots/2877611-Lock-Screen-Animation
# https://codepen.io/anon/pen/LWjrLo?editors=0010

# Module
makeGradient = require("makeGradient")

# META BALL EFFECTS
createRadialGradient = (ctx, w, h, r, c0, c1) ->
  gradient = ctx.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, r)
  gradient.addColorStop 0, c0
  gradient.addColorStop 1, c1
  gradient

Point = (x, y) ->
  @x = x
  @y = y
  @magnitude = x * x + y * y
  @computed = 0
  @force = 0
  return
Point::add = (p) ->
  new Point(@x + p.x, @y + p.y)

Blob = (parent) ->
  @vel = new Point((if Math.random() > 0.5 then 1 else -1) * (0.2 + Math.random() * 0.25), (if Math.random() > 0.5 then 1 else -1) * (0.2 + Math.random() * 1))
  @pos = new Point(parent.width * Math.random(), Math.random() * parent.height)
  @size = Math.random() * 180 + 60
  @width = parent.width
  @height = parent.height
  return
# ==== move balls ====
Blob::move = ->
  # ---- bounce borders ----
  if @pos.x >= @width - (@size)
    if @vel.x > 0
      @vel.x = -@vel.x
    @pos.x = @width - (@size)
  else if @pos.x <= @size
    if @vel.x < 0
      @vel.x = -@vel.x
    @pos.x = @size
  if @pos.y >= @height - (@size)
    if @vel.y > 0
      @vel.y = -@vel.y
    @pos.y = @height - (@size)
  else if @pos.y <= @size
    if @vel.y < 0
      @vel.y = -@vel.y
    @pos.y = @size
  # ---- velocity ----
  @pos = @pos.add(@vel)
  return

MetaBall = (ctx, width, height, numBlobs, c0, c1) ->
  @ctx = ctx
  @step = 10
  @width = width
  @height = height
  @wh = Math.min(width, height)
  @sx = Math.floor(@width / @step)
  @sy = Math.floor(@height / @step)
  @paint = false
  @metaFill = createRadialGradient(@ctx, width, height, width, c0, c1)
  @plx = [0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0]
  @ply = [0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 1]
  @mscases = [0, 3, 0, 3, 1, 3, 0, 3, 2, 2, 0, 2, 1, 1, 0]
  @ix = [1, 0, -1, 0, 0, 1, 0, -1, -1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 1, 1]
  @grid = []
  @blobs = []
  @iter = 0
  @sign = 1
  # ---- init grid ----
  for i in [0..(@sx + 2) * (@sy + 2) - 1]
    @grid[i] = new Point(i % (@sx + 2) * @step, Math.floor(i / (@sx + 2)) * @step)
  # ---- create metaballs ----
  for i in [0..numBlobs - 1]
    @blobs[i] = new Blob(this)
  return

# ==== compute cell force ====
MetaBall::computeForce = (x, y, idx) ->
  force = undefined
  id = idx or x + y * (@sx + 2)
  if x == 0 or y == 0 or x == @sx or y == @sy
    force = 0.6 * @sign
  else
    cell = @grid[id]
    force = 0
    for blob in @blobs
      force += blob.size * blob.size / (-2 * cell.x * blob.pos.x - (2 * cell.y * blob.pos.y) + blob.pos.magnitude + cell.magnitude)
    force *= @sign
  @grid[id].force = force
  force

# ---- compute cell ----
MetaBall::marchingSquares = (next) ->
  x = next[0]
  y = next[1]
  pdir = next[2]
  id = x + y * (@sx + 2)
  if @grid[id].computed == @iter
    return false
  dir = undefined
  mscase = 0
  # ---- neighbors force ----
  i = 0
  while i < 4
    idn = x + @ix[i + 12] + (y + @ix[i + 16]) * (@sx + 2)
    force = @grid[idn].force
    if force > 0 and @sign < 0 or force < 0 and @sign > 0 or !force
      # ---- compute force if not in buffer ----
      force = @computeForce(x + @ix[i + 12], y + @ix[i + 16], idn)
    if Math.abs(force) > 1
      mscase += 2 ** i
    i++
  if mscase == 15
    return [x, y - 1, false]
  else
    # ---- ambiguous cases ----
    if mscase == 5
      dir = if pdir == 2 then 3 else 1
    else if mscase == 10
      dir = if pdir == 3 then 0 else 2
    else
      # ---- lookup ----
      dir = @mscases[mscase]
      @grid[id].computed = @iter
    # ---- draw line ----
    ix = @step / (Math.abs(Math.abs(@grid[x + @plx[4 * dir + 2] + (y + @ply[4 * dir + 2]) * (@sx + 2)].force) - 1) / Math.abs(Math.abs(@grid[x + @plx[4 * dir + 3] + (y + @ply[4 * dir + 3]) * (@sx + 2)].force) - 1) + 1)
    @ctx.lineTo @grid[x + @plx[4 * dir + 0] + (y + @ply[4 * dir + 0]) * (@sx + 2)].x + @ix[dir] * ix, @grid[x + @plx[4 * dir + 1] + (y + @ply[4 * dir + 1]) * (@sx + 2)].y + @ix[dir + 4] * ix
    @paint = true
    return [x + this.ix[dir + 4], y + this.ix[dir + 8], dir]

MetaBall::updateGradient = (c0, c1)->
  @metaFill = createRadialGradient(@ctx, @width, @height, @width, c0, c1)

MetaBall::renderMetaballs = () ->
  for blob in @blobs
    blob.move()
  # ---- reset grid ----
  @iter++
  @sign = -@sign
  @paint = false
  @ctx.fillStyle = @metaFill
  @ctx.beginPath()
  # ---- compute metaballs ----
  @ctx.shadowBlur = 400
  @ctx.shadowColor = 'rgba(0,0,0,0.5)'
  for blob in @blobs
    # ---- first cell ----
    next = [
      Math.round(blob.pos.x / @step)
      Math.round(blob.pos.y / @step)
      false
    ]
    # ---- marching squares ----
    loop
      next = @marchingSquares(next)
      unless next
        break
    # ---- fill and close path ----
    if @paint
      @ctx.fill()
      @ctx.closePath()
      @ctx.beginPath()
      @paint = false
  return

# GUI
guiOpts = ()->
  @title = "Hello"
  @bgGradientLeft =  "#7343e6"
  @bgGradientRight =  "#1890d2"
  @bottomLayerColor1 = "#fda3c9"
  @bottomLayerColor2 = "#e68cec"
  @topLayerColor1 = "#F7E663"
  @topLayerColor2 = "#4CC4D3"
  return

opts = new guiOpts()

# Background Gradient Layer
bgLayer = new Layer
  x: 0
  y: 0
  width: Screen.width
  height: Screen.height
makeGradient.linear bgLayer, [opts.bgGradientLeft, opts.bgGradientRight], "90deg"

# Canvas Layer
new Layer
  html: '<canvas id="canvas"></canvas>'
  backgroundColor: "transparent"
  x: 0
  y: 0
  width: Screen.width
  height: Screen.height

canvas = document.getElementById('canvas')
canvas.width = Screen.width
canvas.height = Screen.height
ctx = canvas.getContext('2d')

mbLayer1 = new MetaBall ctx, Screen.width, Screen.height, 4, opts.bottomLayerColor1, opts.bottomLayerColor2
mbLayer2 = new MetaBall ctx, Screen.width, Screen.height, 4, opts.topLayerColor1, opts.topLayerColor2

drawLoop = ->
  ctx.clearRect(0, 0, Screen.width, Screen.height)
  mbLayer1.renderMetaballs()
  mbLayer2.renderMetaballs()
  window.requestAnimationFrame(drawLoop)
drawLoop()


# Title Layer
label = new Layer
  html: opts.title
  backgroundColor: "transparent"
  width: Screen.width
  x: Align.center
  y: 150
  style:
    "color": "#fff"
    "font-family": "Arial"
    "font-weight": "light"
    "letter-spacing": "10px"
    "font-size": "60px"
    "text-align": "center"

# Place GUI on the front
css = """
.dg.ac {
  z-index: 1;
}
"""
Utils.insertCSS(css)

# GUI Events
if not Utils.isMobile()
  gui = new dat.GUI()
  guiTitle = gui.add opts, 'title'
  guiTitle.onChange (value) ->
    label.html = value

  guiBG1 = gui.addColor opts, 'bgGradientLeft'
  guiBG2 = gui.addColor opts, 'bgGradientRight'
  guiBG1.onChange (value) ->
    makeGradient.linear bgLayer, [value, opts.bgGradientRight], "90deg"
  guiBG2.onChange (value) ->
    makeGradient.linear bgLayer, [opts.bgGradientLeft, value], "90deg"

  blc1 = gui.addColor opts, 'bottomLayerColor1'
  blc2 = gui.addColor opts, 'bottomLayerColor2'
  blc1.onChange (value) ->
    mbLayer1.updateGradient value, opts.bottomLayerColor2
  blc2.onChange (value) ->
    mbLayer1.updateGradient opts.bottomLayerColor1, value

  tlc1 = gui.addColor opts, 'topLayerColor1'
  tlc2 = gui.addColor opts, 'topLayerColor2'
  tlc1.onChange (value) ->
    mbLayer2.updateGradient value, opts.topLayerColor2
  tlc2.onChange (value) ->
    mbLayer2.updateGradient opts.topLayerColor1, value


### SCENE MANIPULATION ###

class SceneManager

  # Try to select "Continue"
  tryContinue: ->
    if textPrinter.printCompleted and textPrinter.tickSpeedMultiplier is 1
      @selectChoiceByName("Continue")

  # Select a choice
  selectChoice: (choice) ->
    @exitScene(novelData.novel.currentScene)
    @readItemEdits(choice)
    @readSounds(choice,true)
    @readSaving(choice)
    @readExecutes(choice)
    @readCheckpoints(choice)
    if choice.nextScene isnt undefined
      @changeScene(choice.nextScene)
    else
      if choice.nextChoice isnt undefined
        @selectChoiceByName(parser.selectRandomOption(choice.nextChoice))
      else
        @updateScene(novelData.novel.currentScene,true)

  # Select a choice by clicking a link embedded in text
  selectChoiceByNameByClicking: (event, name) ->
    event.stopPropagation()
    event.preventDefault()
    @selectChoiceByName(name)

  # Select a choice by name
  selectChoiceByName: (name) ->
    for i in novelData.novel.currentScene.choices
      if i.name is name
        novelArea.selectChoice(i)
        break

  # Called when exiting a scene
  exitScene: (scene) ->
    # Set the previous scene as visited
    scene.visited = true
    ui.updateInputs(false)

  # Called when changing a scene
  changeScene: (sceneNames) ->
    # Load the new scene
    util.checkFormat(sceneNames,'string')
    scene = @findSceneByName(parser.selectRandomOption sceneNames)
    @setupScene(scene)
    return scene

  # Setup a scene changed to
  setupScene: (scene) ->
    @updateScene(scene, false)
    @readItemEdits(novelData.novel.currentScene)
    @readSounds(novelData.novel.currentScene,false)
    @readSaving(novelData.novel.currentScene)
    @readExecutes(novelData.novel.currentScene)
    @readCheckpoints(novelData.novel.currentScene)
    @readMisc(novelData.novel.currentScene)
    textPrinter.printText(scene.parsedText,false)

  # If not changing scenes but update needed, this is called
  updateScene: (scene, onlyUpdating) ->
    # Handle the scene text
    scene = @combineSceneTexts(scene)
    scene.parsedText = parser.parseText scene.combinedText
    # Set the current scene
    novelData.novel.currentScene = scene
    if not onlyUpdating
      novelData.novel.parsedChoices = null
    else
      textPrinter.printText(scene.parsedText,true)
      textPrinter.complete()

  # Update choice texts when they are changed - Vue.js doesn't detect them without this.
  updateChoices: ->
    novelArea.$set 'novel.parsedChoices', novelData.novel.currentScene.choices.map((choice) ->
      choice.parsedText = parser.parseText choice.text
      if novelArea.novel.settings.alwaysShowDisabledChoices
        choice.alwaysShow = true
      choice
    )

  # Return a scene by its name; throw an error if not found.
  findSceneByName: (name) ->
    util.checkFormat(name,'string')
    for i in novelData.novel.scenes
      if i.name is name
        return i
    console.error "ERROR: Scene by name '"+name+"' not found!"

  # Combine the multiple scene text rows
  combineSceneTexts: (s) ->
    util.checkFormat(s,'object')
    util.checkFormat(s.text,'arrayOrString')
    s.combinedText = ""
    if Object.prototype.toString.call(s.text) is "[object Array]"
      for i in s.text
        s.combinedText = s.combinedText + "<p>" + i + "</p>"
    else
      s.combinedText = s.text
    return s

  # Read item and val edit commands from scene or choice
  readItemEdits: (source) ->
    if source.changeInventory isnt undefined
      novelData.novel.currentInventory = parser.parseStatement(source.changeInventory)
      if novelData.novel.currentInventory > novelData.novel.inventories.length
        for i in [0 .. novelData.novel.currentInventory]
          if novelData.novel.inventories[i] is undefined
            novelData.novel.inventories[i] = []
    if source.removeItem isnt undefined
      inventoryManager.editItems(parser.parseItems(source.removeItem),"remove")
    if source.addItem isnt undefined
      inventoryManager.editItems(parser.parseItems(source.addItem),"add")
    if source.setItem isnt undefined
      inventoryManager.editItems(parser.parseItems(source.setItem),"set")
    if source.setValue isnt undefined
      for val in source.setValue
        inventoryManager.setValue(val.path,parser.parseStatement(val.value.toString()))
    if source.increaseValue isnt undefined
      for val in source.increaseValue
        inventoryManager.increaseValue(val.path,parser.parseStatement(val.value.toString()))
    if source.decreaseValue isnt undefined
      for val in source.decreaseValue
        inventoryManager.decreaseValue(val.path,parser.parseStatement(val.value.toString()))

  # Read sound commands from scene or choice
  readSounds: (source,clicked) ->
    played = false
    if source.playSound isnt undefined
      soundManager.playSound(parser.parseStatement(source.playSound),false)
      played = true
    if clicked and not played
      soundManager.playDefaultClickSound()
    if source.startMusic isnt undefined
      soundManager.startMusic(parser.parseStatement(source.startMusic))
    if source.stopMusic isnt undefined
      soundManager.stopMusic(parser.parseStatement(source.stopMusic))
    if source.scrollSound isnt undefined
      novelData.novel.currentScene.scrollSound = parser.parseStatement(source.scrollSound)
    else
      if novelData.novel.settings.soundSettings.defaultScrollSound
        novelData.novel.currentScene.scrollSound = novelData.novel.settings.soundSettings.defaultScrollSound
      else
        novelData.novel.currentScene.scrollSound = undefined

  # Read JS commands
  readExecutes: (source) ->
    if source.executeJs isnt undefined
      eval(source.executeJs)

  # Read miscellaneous scene values
  readMisc: (source) ->
    if source.skipEnabled isnt undefined
      novelData.novel.currentScene.skipEnabled = parser.parseStatement(source.skipEnabled)
    else
      novelData.novel.currentScene.skipEnabled = novelData.novel.settings.scrollSettings.textSkipEnabled
    if source.revisitSkipEnabled isnt undefined
      novelData.novel.currentScene.revisitSkipEnabled = parser.parseStatement(source.revisitSkipEnabled)
    else
      novelData.novel.currentScene.revisitSkipEnabled = novelData.novel.settings.scrollSettings.revisitSkipEnabled
    if source.scrollSpeed isnt undefined
      novelData.novel.currentScene.scrollSpeed = source.scrollSpeed
    else
      novelData.novel.currentScene.scrollSpeed = novelData.novel.settings.scrollSettings.defaultScrollSpeed
    if source.inventoryHidden isnt undefined
      novelData.inventoryHidden = parser.parseStatement(source.inventoryHidden)
    else
      novelData.inventoryHidden = false

  # Read save and load commands from scene or choice
  readSaving: (source) ->
    if source.save isnt undefined
      novelManager.saveData()
    if source.load isnt undefined
      ui.showLoadNotification()

  # Read checkpoint commands
  readCheckpoints: (source) ->
    if source.saveCheckpoint isnt undefined
      if novelData.novel.checkpoints is undefined
        novelData.novel.checkpoints = []
      dataChanged = false
      for i in novelData.novel.checkpoints
        if i.name is parser.parseStatement(source.saveCheckpoint)
          i.scene = novelData.novel.currentScene.name
          dataChanged = true
          #console.log "Updated checkpoint!"
      if not dataChanged
        checkpoint = {name:parser.parseStatement(source.saveCheckpoint),scene:novelData.novel.currentScene.name}
        novelData.novel.checkpoints.push(checkpoint)
      #console.log "Checkpoint saved!"
      #console.log checkpoint
    if source.loadCheckpoint isnt undefined
      if novelData.novel.checkpoints is undefined
        novelData.novel.checkpoints = []
      for i in novelData.novel.checkpoints
        if i.name is parser.parseStatement(source.loadCheckpoint)
          #console.log "Checkpoint found!"
          @changeScene(i.scene)

  # Check whether the requirements for a choice have been met
  requirementsFilled: (choice) ->
    reqs = []
    if choice.itemRequirement isnt undefined
      requirements = parser.parseItems choice.itemRequirement
      reqs.push inventoryManager.checkRequirements requirements
    if choice.requirement isnt undefined
      reqs.push parser.parseStatement choice.requirement
    success = true
    for r in reqs
      if r is false
        success = false
    return success

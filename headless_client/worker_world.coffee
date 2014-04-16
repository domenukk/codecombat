# function to use inside a webworker.
# This function needs to run inside an environment that has a 'self'.
# This specific worker is targeted towards the node.js headless_client environment.

JASON = require 'jason'
fs = require 'fs'

#This function runs inside the webworker.
work = () ->
  console.log "starting..."

  initialized = false;

  World = self.require('lib/world/world');
  GoalManager = self.require('lib/world/GoalManager');

  self.runWorld = (args) ->
    console.log "Running world inside worker."
    self.postedErrors = {}
    self.t0 = new Date()
    self.firstWorld = args.firstWorld
    self.postedErrors = false
    self.logsLogged = 0

    try
      self.world = new World(args.worldName, args.userCodeMap)
      self.world.loadFromLevel args.level, true  if args.level
      self.goalManager = new GoalManager(self.world)
      self.goalManager.setGoals args.goals
      self.goalManager.setCode args.userCodeMap
      self.goalManager.worldGenerationWillBegin()
      self.world.setGoalManager self.goalManager
    catch error
      console.log "There has been an error inside thew worker."
      self.onWorldError error
      return
    Math.random = self.world.rand.randf # so user code is predictable
    console.log "Loading frames."
    self.world.loadFrames self.onWorldLoaded, self.onWorldError, self.onWorldLoadProgress, true


  self.onWorldLoaded = onWorldLoaded = ->

    self.goalManager.worldGenerationEnded()
    t1 = new Date()
    diff = t1 - self.t0
    transferableSupported = self.transferableSupported()
    try
      serialized = serializedWorld: undefined # self.world.serialize()
      transferableSupported = false
    catch error
      console.log "World serialization error:", error.toString() + "\n" + error.stack or error.stackTrace
    t2 = new Date()

    # console.log("About to transfer", serialized.serializedWorld.trackedPropertiesPerThangValues, serialized.transferableObjects);
    try
      if transferableSupported
        self.postMessage
          type: "new-world"
          serialized: serialized.serializedWorld
          goalStates: self.goalManager.getGoalStates()
        , serialized.transferableObjects
      else
        self.postMessage
          type: "new-world"
          serialized: serialized.serializedWorld
          goalStates: self.goalManager.getGoalStates()

    catch error
      console.log "World delivery error:", error.toString() + "\n" + error.stack or error.stackTrace
    t3 = new Date()
    console.log "And it was so: (" + (diff / self.world.totalFrames).toFixed(3) + "ms per frame,", self.world.totalFrames, "frames)\nSimulation   :", diff + "ms \nSerialization:", (t2 - t1) + "ms\nDelivery     :", (t3 - t2) + "ms"
    self.world = null

  self.onWorldError = onWorldError = (error) ->
    if error instanceof Aether.problems.UserCodeProblem
      #console.log "Aether userCodeProblem occured."
      unless self.postedErrors[error.key]
        problem = error.serialize()
        self.postMessage
          type: "user-code-problem"
          problem: problem

        self.postedErrors[error.key] = problem
    else
      console.log "Non-UserCodeError:", error.toString() + "\n" + error.stack or error.stackTrace

  self.onWorldLoadProgress = onWorldLoadProgress = (progress) ->
    #console.log "Worker onWorldLoadProgress"
    self.postMessage
      type: "world-load-progress-changed"
      progress: progress

  self.abort = abort = ->
    #console.log "Abort called for worker."
    if self.world and self.world.name
      #console.log "About to abort:", self.world.name, typeof self.world.abort
      self.world.abort()  if typeof self.world isnt "undefined"
      self.world = null
    self.postMessage type: "abort"

  self.reportIn = reportIn = ->
    console.log "Reporting in."
    self.postMessage type: "reportIn"

  self.addEventListener "message", (event) ->
    #console.log JSON.stringify event
    self[event.data.func] event.data.args

  self.postMessage type: "worker-initialized"
  initialized = true

world = fs.readFileSync "./public/javascripts/world.js", 'utf8'


ret = """

  GLOBAL = root = window = self;
  GLOBAL.window = window;

  self.workerID = "Worker";

  try {
    // the world javascript file
    #{world};

    // Don't let user generated code access stuff from our file system!
    self.importScripts = importScripts = null;
    self.native_fs_ = native_fs_ = null;

    // the actual function
    #{JASON.stringify work}();
  }catch (error) {
    self.postMessage({"type": "console-log", args: ["An unhandled error occured: ", error.toString(), error.stack], id: -1});
  }
"""

module.exports = new Function(ret)

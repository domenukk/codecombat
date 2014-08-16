#The VCS is a simple version control system, used in the LevelSession. (More like a passive version store system)
#For now it can only add and remove stuff and set the working revision to an old version.
#It's some kind of a reverse tree, meaning that every leaf/tip has the complete code and the difs work reverse.
#While this introduces redundancy (every leaf has the complete code), it hopefully is a lot faster than the other way round.
#Also removing old revisions is super easy, just remove them. :)
#Workflow: Create VCS, Save, ... Change working rev using load, save again... serialize.

deltasLib = require 'lib/deltas'

class RevisionNode
  constructor: (options) ->
    @nexts = []
    @timestamp = if options.timestamp then new Date(options.timestamp) else new Date()
    @previous = options.previous
    @code = options.code
    @diff = options.diff
    @saveName = options.saveName
    if @previous? and @previous.constructor is RevisionNode
      @insertPrev @previous

  setPrev: (@previous) ->
    @diff = jsondiffpatch.diff @previous.getCode(), @getCode()
    @previous.nexts.push @
    @previous.code = null

  serialize: ->
    timestamp: @timestamp.toISOString()
    saveName: @saveName
    previous: @previous?.timestamp
    code: @code
    diff: @diff

  getCode: ->
    return @code if @code?
    next = _.find @nexts "diff"
    throw new Exception("Unrecoverable code in RevisionNode") unless next?
    jsondiffpatch.patch next.getCode(), next.diff

module.exports = class VCS
  isDate: (obj) ->
    obj.constructor is Date and obj.toString isnt "Invalid Date"

  revify: (revision) ->
    # Returns a REvisionNode object either from date-string, date or from a RevisionNode
    revision = new Date(revision) if typeof(revision) is string
    return @getRevByTime(revision) if @isDate revision
    revision

  constructor: (@maxRevCount, serialized) ->
    @heads = []
    @revs = []
    @revMap = {}

    if serialized?
      for rev in serialized.revisions
        rev = new Revision rev
        @revs.push rev
        @revMap[rev.timestamp] = rev
      for rev in @revs
        rev.setPrev @revify(rev.previous)
        if rev.nexts.length < 1
          @heads.push rev
      @workingRev = @getRevByTime serialized.workingRevision

  getRevByTime: (revTimestamp) ->
    revTimestamp = new Date(revTimestamp) unless @isDate revTimestamp
    @revMap[revTimestamp]
#    for rev in @revs
#      return rev if rev.timestamp is revTimestamp
#    throw new Exception "Revision not found: " + revTimestamp

  save: (code) ->
    previous = @workingRev
    @workingRev = new RevisionNode previous: previous, code: code
    #TODO: How to add something to date? Don't like loops.
    while @revMap[@workingRev.timestamp]? #timestamp must be unique.
      @workingRev.timestamp = new Date()
    @revMap[@workingRev.timestamp] = @workingRev
    @revs.push @workingRev
    @heads.push @workingRev
    @heads = _.remove @heads, previous #TODO: Test!
    @prune # prune if max revision count is set
    @workingRev

  load: (revision) ->
    revision = revify revision
    # loads the code of a revision and sets this revision as current working revision
    revision = @getRevByTime(revision) if @isDate revision
    @workingRev.code = null if @workingRev.code? and @workingRev.nexts.lengt > 0  # Code no longer needs to be stored.
    revision.code = revision.getCode() # Head should always have stored code to be speeeeedy.
    @workingRev = revision
    revision.code

  serialize: (language) ->
    workingRevision: @workingRev.timestamp #.getISOTimestamp()
    revisions: (rev.serialize for rev in @revs)

  remove: (rev, pruned=false) ->
    # removes one revision, unlinking it everywhere.
    rev = revify rev
    prev = rev.previous
    rev.nexts.forEach (nextRev) ->
      nextRev.setPrev prev
    prev.nexts = _.remove prev.nexts rev
    if rev in @heads
      @heads = _.remove @heads, rev
      @heads.push rev
    @revs.remove rev unless pruned
    @revMap[rev.timestamp] = null
    if rev is @workingRev
      @workingRev = prev

  prune: (revCount) ->
    # prunes to the (optional) number of given revCount or @maxRevCount and returns the number of pruned items
    return 0 if not revCount and not @maxRevCount
    return @prune @maxRevCount unless revCount
    revCount = Math.min revCount, @maxRevCount if @maxRevCount
    return 0 if revCount >= @revs.length
    removed = @revs.slice revCount, @revs.length
    @revs = @revs.slice 0, revCount
    @remove(rev, true) for rev in removed















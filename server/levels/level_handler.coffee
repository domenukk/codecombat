Level = require('./Level')
User = require('../users/User')
Session = require('./sessions/LevelSession')
SessionHandler = require('./sessions/level_session_handler')
Feedback = require('./feedbacks/LevelFeedback')
Handler = require('../commons/Handler')
redis = require '../commons/redis'
log = require 'winston'
async = require 'async'
mongoose = require('mongoose')

LevelHandler = class LevelHandler extends Handler
  modelClass: Level
  editableProperties: [
    'description'
    'documentation'
    'background'
    'nextLevel'
    'scripts'
    'thangs'
    'systems'
    'victory'
    'name'
    'i18n'
    'icon'
  ]

  postEditableProperties: ['name']

  getByRelationship: (req, res, args...) ->
    return @getSession(req, res, args[0]) if args[1] is 'session'
    return @getLeaderboard(req, res, args[0]) if args[1] is 'leaderboard'
    return @getAllSessions(req, res, args[0]) if args[1] is 'all_sessions'
    return @getFeedback(req, res, args[0]) if args[1] is 'feedback'
    return @sendNotFoundError(res)

  fetchLevelByIDAndHandleErrors: (id, req, res, callback) ->
    @getDocumentForIdOrSlug id, (err, level) =>
      return @sendDatabaseError(res, err) if err
      return @sendNotFoundError(res) unless level?
      return @sendUnauthorizedError(res) unless @hasAccessToDocument(req, level, 'get')
      callback err, level

  getSession: (req, res, id) ->
    @fetchLevelByIDAndHandleErrors id, req, res, (err, level) =>
      sessionQuery =
        level:
          original: level.original.toString()
          majorVersion: level.version.major
        creator: req.user.id

      # TODO: generalize this for levels that need teams
      if req.query.team?
        sessionQuery.team = req.query.team
      else if level.name is 'Project DotA'
        sessionQuery.team = 'humans'
      
      Session.findOne(sessionQuery).exec (err, doc) =>
        return @sendDatabaseError(res, err) if err
        return @sendSuccess(res, doc) if doc?
        @createAndSaveNewSession sessionQuery, req, res


  createAndSaveNewSession: (sessionQuery, req, res) =>
    initVals = sessionQuery

    initVals.state =
      complete:false
      scripts:
        currentScript:null # will not save empty objects

    initVals.permissions = [
      {
        target:req.user.id
        access:'owner'
      }
      {
        target:'public'
        access:'write'
      }
    ]
    session = new Session(initVals)

    session.save (err) =>
      return @sendDatabaseError(res, err) if err
      @sendSuccess(res, @formatEntity(req, session))
      # TODO: tying things like @formatEntity and saveChangesToDocument don't make sense
      # associated with the handler, because the handler might return a different type
      # of model, like in this case. Refactor to move that logic to the model instead.

  getAllSessions: (req, res, id) ->
    @fetchLevelByIDAndHandleErrors id, req, res, (err, level) =>
      sessionQuery =
        level:
          original: level.original.toString()
          majorVersion: level.version.major
        submitted: true

      propertiesToReturn = [
        '_id'
        'totalScore'
        'submitted'
        'team'
        'creatorName'
      ]

      query = Session
        .find(sessionQuery)
        .select(propertiesToReturn.join ' ')

      query.exec (err, results) =>
        if err then @sendDatabaseError(res, err) else @sendSuccess res, results

  getLeaderboard: (req, res, id) ->
    @validateLeaderboardRequestParameters req
    [original, version] = id.split '.'
    version = parseInt(version) ? 0
    scoreQuery = {}
    scoreQuery[if req.query.order is 1 then "$gte" else "$lte"] = req.query.scoreOffset

    sessionsQueryParameters =
      level:
        original: original
        majorVersion: version
      team: req.query.team
      totalScore: scoreQuery
      submitted: true

    sortParameters =
      "totalScore": req.query.order

    selectProperties = [
      'totalScore'
      'creatorName'
      'creator'
      'team'
    ]

    query = Session
      .find(sessionsQueryParameters)
      .limit(req.query.limit)
      .sort(sortParameters)
      .select(selectProperties.join ' ')

    query.lean().exec (err, resultSessions) =>
      return @sendDatabaseError(res, err) if err
      resultSessions ?= []
      appendRanksToResultSessions resultSessions, (err, result) =>
        if err? then return @sendDatabaseError(res, err)
        start = process.hrtime()
        appendCreatorNamesToSessions resultSessions, (err, result) =>
          if err? then return @sendDatabaseError(res, err)
          timeElapsed = process.hrtime(start)

          timeElapsed[1] = timeElapsed[1] / 1000000
          timeElapsed[0] = timeElapsed[0] * 1000
          log.info "Redis functions took " + (timeElapsed[0] + timeElapsed[1]) + " milliseconds."

          @sendSuccess res, resultSessions

  validateLeaderboardRequestParameters: (req) ->
    req.query.order = parseInt(req.query.order) ? -1
    req.query.scoreOffset = parseFloat(req.query.scoreOffset) ? 100000
    req.query.team ?= 'humans'
    req.query.limit = parseInt(req.query.limit) ? 20

  getFeedback: (req, res, id) ->
    @fetchLevelByIDAndHandleErrors id, req, res, (err, level) =>
      feedbackQuery =
        creator: mongoose.Types.ObjectId(req.user.id.toString())
        'level.original': level.original.toString()
        'level.majorVersion': level.version.major

      Feedback.findOne(feedbackQuery).exec (err, doc) =>
        return @sendDatabaseError(res, err) if err
        return @sendNotFoundError(res) unless doc?
        @sendSuccess(res, doc)

scoringSortedSets = {}
scoringSortedSets["humans"] = redis.generateSortedSet 'scores_humans'
scoringSortedSets["ogres"] = redis.generateSortedSet 'scores_ogres'

sessionHashClient = redis.generateHashClient()

appendCreatorNamesToSessions = (sessions, callback) ->
  async.each sessions, appendCreatorNameToSession, callback

appendCreatorNameToSession = (session, callback) ->
  sessionHashClient.getField session._id, "name", (err, name) ->
    if err? then return callback err, name

    unless name
      #fetch the username and put it in the cache
      query = User
      .findOne({"_id":session.creator})
      .select('name')
      query.lean().exec (err, user) =>
        unless user.name then user.name = "Anonymous"
        sessionHashClient.setField session._id, "name", user.name, (err, result) ->
          session.creatorName = user.name
          callback null
    else
      session.creatorName = name
      callback null




appendRanksToResultSessions = (resultSessions, callback) ->
  #TODO: Optimize to use pipelining
  async.each resultSessions, insertMissingRankingsIntoSetIfNecessary, (err) ->
    if err? then callback err
    async.each resultSessions, appendRankToSession, callback


insertMissingRankingsIntoSetIfNecessary =  (session, callback) ->
  scoringSortedSets[session.team].checkIfMemberExists session._id, (err, memberExists) ->
    if memberExists then return callback null
    scoringSortedSets[session.team].addOrChangeMember session.totalScore, session._id, callback

appendRankToSession = (session, callback) ->
  scoringSortedSets[session.team].getRankOfMember session._id, (error, result) ->
    unless result? then error = "error":"No rank was returned."
    if error then return callback error
    session.rank = result + 1
    callback error





module.exports = new LevelHandler()

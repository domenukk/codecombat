c = require './../schemas'

LevelSessionPlayerSchema = c.object
  id: c.objectId
    links: [
      {
        rel: 'extra'
        href: '/db/user/{($)}'
      }
    ]
  time:
    type: 'Number'
  changes:
    type: 'Number'

LevelSessionLevelSchema = c.object {required: ['original', 'majorVersion'], links: [{rel: 'db', href: '/db/level/{(original)}/version/{(majorVersion)}'}]},
  original: c.objectId({})
  majorVersion:
    type: 'integer'
    minimum: 0
    default: 0

LevelSessionSchema = c.object
  title: 'Session'
  description: 'A single session for a given level.'

_.extend LevelSessionSchema.properties,
  # denormalization
  creatorName:
    type: 'string'
  levelName:
    type: 'string'
  levelID:
    type: 'string'
  multiplayer:
    type: 'boolean'
  creator: c.objectId
    links:
      [
        {
          rel: 'extra'
          href: '/db/user/{($)}'
        }
      ]
  created: c.date
    title: 'Created'
    readOnly: true

  changed: c.date
    title: 'Changed'
    readOnly: true

  team: c.shortString()
  level: LevelSessionLevelSchema

  screenshot:
    type: 'string'

  state: c.object {},
    complete:
      type: 'boolean'
    scripts: c.object {},
      ended:
        type: 'object'
        additionalProperties:
          type: 'number'
      currentScript:
        type: [
          'null'
          'string'
        ]
      currentScriptOffset:
        type: 'number'

    selected:
      type: [
        'null'
        'string'
      ]
    playing:
      type: 'boolean'
    frame:
      type: 'number'
    thangs:
      type: 'object'
      additionalProperties:
        title: 'Thang'
        type: 'object'
        properties:
          methods:
            type: 'object'
            additionalProperties:
              title: 'Thang Method'
              type: 'object'
              properties:
                metrics:
                  type: 'object'
                source:
                  type: 'string'

  code:
    type: 'object'
    additionalProperties:
      type: 'object'
      additionalProperties:
        type: 'string'
        format: 'javascript'

  vcs:
    title: 'Code VCS'
    description: 'Stores past revisions of user code.'
    type: 'object'
    properties:
      languageBarriers:
        title: 'Language Barriers'
        type: ''
      revisions:
        title: 'Revisions'
        description: 'all revisions sorted by age in increasing order (newest to oldest)'
        type: 'array'
        items:
          title: "Revision"
          description: 'The current revision including code/diff and metadata.'
          type: 'object'
          oneOf: [
            {required:['code']}
            {required:['diff']}
          ]
          properties:
            saveName:
              title: 'Save Name (TAG)'
              description: 'If this revision is saved(Tagged), the name is stored here.'
              type: 'string'
            timestamp:
              title: 'Creation time.'
              description: "At what time this element has been created. It is the revision node's unique id at the same time"
              type: 'string'
            previous:
              title: 'Previous Item'
              description: 'The timestamp (id) of the previous item or the language of the tree for the last item'
              type: 'string'
            code:
              title: 'Code'
              description: 'The code of this item. Either this or the delta to the previous item must be set'
              type: 'object'
              additionalProperties:
                type: 'object'
                additionalProperties:
                  type: 'string'
                  format: 'javascript'
            diff:
              title: 'Diff'
              description: 'The delta to the previous item.'
              type: 'object'
              additionalProperties:
                type: 'object'
                additionalProperties:
                  type: 'string'
                  format: 'javascript'
            newBranch:
              title: 'Start of Branch'
              description: 'Indicates if this node is the start of a new branch (diff line ends here)'
              type: 'boolean'
            codeLanguage:
              title: 'CodeLanguage'
              description:  'The programming language used for this code. If this is empty, a previous item defines the language.'
              type: 'string'

  codeLanguage:
    type: 'string'
    default: 'javascript'

  playtime:
    type: 'number'
    title: 'Playtime'
    default: 0
    description: 'The total playtime on this session'

  teamSpells:
    type: 'object'
    additionalProperties:
      type: 'array'

  players:
    type: 'object'

  chat:
    type: 'array'

  meanStrength:
    type: 'number'

  standardDeviation:
    type: 'number'
    minimum: 0

  totalScore:
    type: 'number'

  submitted:
    type: 'boolean'

  submitDate: c.date
    title: 'Submitted'

  submittedCode:
    type: 'object'
    additionalProperties:
      type: 'object'
      additionalProperties:
        type: 'string'

  submittedCodeLanguage:
    type: 'string'
    default: 'javascript'

  transpiledCode:
    type: 'object'
    additionalProperties:
      type: 'object'
      additionalProperties:
        type: 'string'

  isRanking:
    type: 'boolean'
    description: 'Whether this session is still in the first ranking chain after being submitted.'

  unsubscribed:
    type: 'boolean'
    description: 'Whether the player has opted out of receiving email updates about ladder rankings for this session.'

  numberOfWinsAndTies:
    type: 'number'

  numberOfLosses:
    type: 'number'

  scoreHistory:
    type: 'array'
    title: 'Score History'
    description: 'A list of objects representing the score history of a session'
    items:
      title: 'Score History Point'
      description: 'An array with the format [unix timestamp, totalScore]'
      type: 'array'
      items:
        type: 'number'

  matches:
    type: 'array'
    title: 'Matches'
    description: 'All of the matches a submitted session has played in its current state.'
    items:
      type: 'object'
      properties:
        date: c.date
          title: 'Date computed'
          description: 'The date a match was computed.'
        playtime:
          title: 'Playtime so far'
          description: 'The total seconds of playtime on this session when the match was computed.'
          type: 'number'
        metrics:
          type: 'object'
          title: 'Metrics'
          description: 'Various information about the outcome of a match.'
          properties:
            rank:
              title: 'Rank'
              description: 'A 0-indexed ranking representing the player\'s standing in the outcome of a match'
              type: 'number'
        opponents:
          type: 'array'
          title: 'Opponents'
          description: 'An array containing information about the opponents\' sessions in a given match.'
          items:
            type: 'object'
            properties:
              sessionID:
                title: 'Opponent Session ID'
                description: 'The session ID of an opponent.'
                type: ['object', 'string', 'null']
              userID:
                title: 'Opponent User ID'
                description: 'The user ID of an opponent'
                type: ['object', 'string', 'null']
              name:
                title: 'Opponent name'
                description: 'The name of the opponent'
                type: ['string', 'null']
              totalScore:
                title: 'Opponent total score'
                description: 'The totalScore of a user when the match was computed'
                type: ['number', 'string', 'null']
              metrics:
                type: 'object'
                properties:
                  rank:
                    title: 'Opponent Rank'
                    description: 'The opponent\'s ranking in a given match'
                    type: 'number'
              codeLanguage:
                type: 'string'
                description: 'What submittedCodeLanguage the opponent used during the match'

c.extendBasicProperties LevelSessionSchema, 'level.session'
c.extendPermissionsProperties LevelSessionSchema, 'level.session'

module.exports = LevelSessionSchema

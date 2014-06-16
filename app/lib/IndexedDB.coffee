# This class connects to, initializes and uses the indexedDB.
# Currently only used for caching images.


module.exports = class IndexedDB
  dbName: "CoCo"
  spriteSheetKey: "spriteSheets"
  dbVersion: 3 # A change in the number (=Version, NOT a decimal) will trigger onupgradeneeded in open.

  constructor: ->
    @indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB;
    @IDBTransaction = window.IDBTransaction || window.webkitIDBTransaction || window.msIDBTransaction;
    @IDBKeyRange = window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;

  isSupported: ->
    @indexedDB?

  open: (created=false) =>
    deferred = $.Deferred()
    if @db
      deferred.resolve created: created, opened: false
    else unless @isSupported
      deferred.reject dbSupported: false
    else
      request = @indexedDB.open(@dbName, @dbVersion);
      request.onerror = (event) -> deferred.reject dbSupported: true, event: event
      request.onsuccess = (event) =>
        @db = request.result
        deferred.resolve created: created, opened: true, event: event
      request.onupgradeneeded = (event) =>
        # We want to structure our database here. If we cache more foo, hook this up some nicer config.
        console.log "Upgrade needed", event
        @db = event.target.result;
        spriteSheetStore = @db.createObjectStore @spriteSheetKey, keyPath: "key"
        open true
        #deferred.resolve created: true, opened: true, event: event
    deferred

  close: ->
    @db.close()

  getObjectStore: (storeName, mode) ->
    @db.transaction([storeName], mode).objectStore storeName

  getSpritesheet: (key) ->
    deferred = $.Deferred()
    request = @getObjectStore(@spriteSheetKey, "readonly").get key
    request.onsuccess = (event) ->
      deferred.resolve event.target.result.sprite, event if event.target.result?
      deferred.reject "Image not cached."
    request.onerror = (event) -> deferred.reject event
    deferred

  putSpritesheet: (key, sprite) ->
    deferred = $.Deferred()
    transaction = @db.transaction [@spriteSheetKey], "readwrite"
    transaction.oncomplete = (event)-> deferred.resolve event
    transaction.onerror = (event)-> deferred.reject event
    objectStore = transaction.objectStore @spriteSheetKey
    request = objectStore.add key: key, sprite: sprite
    request.onsuccess = (event)->
      console.log "Added spritesheet to cache with key ", event.target.result
    request.onerror = (event)->
      console.error "Adding spritesheet", key, " to database failed:", event
    deferred

  clearCache: ->
    deferred = $.Deferred()
    req = @getObjectStore(@spreteSheetKey, "readwrite").clear();
    req.onsuccess = (event) ->
      console.log "Cleared imagecache successfully.", event
      deferred.resolve event
    req.onerror = (event) ->
      console.log "Clearing imagecache failed.", event
      deferred.reject event
    deferred





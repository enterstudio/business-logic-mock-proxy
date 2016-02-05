#
# Copyright 2016 Kinvey, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

_ = require 'underscore'
async = require 'async'
errors = require '../errors'
dataStore = require '../data-store'

config = null

restrictQueryString = (req, res, next) ->
  queryString = JSON.stringify(req.body?.query ? req.body?.condition ? {})

  if queryString.match(/\$where/) isnt null
    return next errors.createKinveyError 'DisallowedQuerySyntax', 'The $where operator is disallowed'

  if queryString.match(/\$query/) isnt null
    return next errors.createKinveyError 'DisallowedQuerySyntax', 'The $query operator is disallowed'

  next()

count = (req, res, next) ->
  req.collectionCursor.count req.body.query, (err, numberOfEntities) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    res.status(200).json
      count: numberOfEntities
    next()

findOne = (req, res, next) ->
  if req.body.options?
    options = {}

    if req.body.options.sort?
      options.sort = req.body.options.sort

    if req.body.options.fields?
      options.fields = req.body.options.fields

    if req.body.options.skip?
      options.skip = req.body.options.skip

  req.collectionCursor.findOne req.body.query, options ? {}, (err, entity) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    res.status(200).json entity ? {}
    next()

find = (req, res, next) ->
  if req.body.options?
    options = {}

    if req.body.options.limit?
      options.limit = req.body.options.limit

    if req.body.options.sort?
      options.sort = req.body.options.sort

    if req.body.options.fields?
      options.fields = req.body.options.fields

    if req.body.options.skip?
      options.skip = req.body.options.skip

  req.collectionCursor.find(req.body.query, options ? {}).toArray (err, entities) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    res.status(200).json entities
    next()

insert = (req, res, next) ->
  req.collectionCursor.insert req.body.entity, {}, (err, createdEntities) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    res.status(201).json createdEntities
    next()

update = (req, res, next) ->
  options = {}

  if req.body.options?
    if req.body.options.upsert is true
      options.upsert = true

    if req.body.options.updateMultiple is true
      options.multi = true

  req.collectionCursor.update req.body.query, req.body.entity, options, (err, numberAffected, rawResponse) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    res.status(200).json
      numberAffected: numberAffected
      updatedExisting: rawResponse?.updatedExisting
    next()

save = (req, res, next) ->
  req.collectionCursor.save req.body.entity, {}, (err, result) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    res.status(200).json result
    next()

remove = (req, res, next) ->
  req.collectionCursor.remove req.body.query, {}, (err, numberOfEntitiesRemoved) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    outgoingBody =
      count: numberOfEntitiesRemoved
    res.status(200).json outgoingBody
    next()

findAndRemove = (req, res, next) ->
  if req.body.options?.sort? and Array.isArray req.body.options.sort
    sort = req.body.options.sort
  else
    sort = null

  req.collectionCursor.findAndRemove req.body.query, sort, {}, (err, removedEntity) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    res.status(200).json removedEntity ? {}
    next()

findAndModify = (req, res, next) ->
  options = {}

  if req.body.options?
    if req.body.options.remove is true
      options.remove = true

    if req.body.options.upsert is true
      options.upsert = true

    if req.body.options.returnModifiedEntity is true
      options.new = true

    if req.body.options.sort? and Array.isArray req.body.options.sort
      sort = req.body.options.sort
    else
      sort = null

  req.collectionCursor.findAndModify req.body.query, sort, req.body.entity, options, (err, entity, rawResponse) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()

    res.status(200).json
      entity: entity ? {}
      updatedExisting: (rawResponse?.lastErrorObject?.updatedExisting or false)
    next()

distinct = (req, res, next) ->
  if not req.body.keyName?
    return next errors.createKinveyError 'MissingRequiredParameter', 'The request must contain a keyName'

  req.collectionCursor.find(req.body.query).toArray (err, queryResults) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    values = _.pluck queryResults, req.body.keyName
    res.status(200).json _.uniq values
    next()

geoNear = (req, res, next) ->
  # TingoDB doesn't support geo queries. instead, just perform a normal find()
  return find req, res, next

mapReduce = (req, res, next) ->
  if not (req.body.map? and req.body.reduce?)
    return next errors.createKinveyError 'MissingRequiredParameter', 'The request must contain map and reduce functions'

  # mongo returns an error when the collection does not exist, whereas tingo doesn't
  dataStore.collectionNames (err, collectionNames) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    exists = false
    for nameRecord in collectionNames
      if req.params.collectionName is nameRecord.name.substring(nameRecord.name.indexOf('.') + 1)
        exists = true
        break

    if not exists
      return next errors.createKinveyError 'MongoError', "Collection #{req.params.collectionName} does not exist"

    options =
      out:
        inline: 1

    if req.body.options?
      if req.body.options.limit?
        options.limit = req.body.options.limit

      if req.body.options.scope?
        options.scope = req.body.options.scope

      if req.body.options.sort?
        options.sort = req.body.options.sort

    if req.body.query?
      options.query = req.body.query

    dataStore.collection(req.params.collectionName).mapReduce req.body.map, req.body.reduce, options, (err, result) ->
      if err then return next errors.createKinveyError 'MongoError', err.toString()
      # TingoDB returns an array of the results, whereas Mongo returns an array of objects of the format:
      # [{_id: 1, value: value-of-first-result}, ...]
      for value, i in result
        result[i] =
          _id: 1
          value: value
      res.status(200).json result
      next()

group = (req, res, next) ->
  if not (req.body.keys? and req.body.initial? and req.body.reduce?)
    return next errors.createKinveyError 'MissingRequiredParameter', 'The request must contain the following properties: keys, initial, reduce'

  functionRegex = /^\s*function\s*\((\s*.*\s*)\)\s*{(.*)}\s*$/i
  if functionRegex.test req.body.keys
    arr = req.body.keys.match functionRegex
    key = new Function(arr[1], arr[2])
  else
    key = req.body.keys

  try
    req.collectionCursor.group key, req.body.condition ? {}, req.body.initial, req.body.reduce, null, true, {}, (err, results) ->
      if err then return next errors.createKinveyError 'MongoError', err.toString()
      res.status(200).json results
      next()
  catch e
    next errors.createKinveyError 'MongoError', e.toString()

collectionExists = (req, res, next) ->
  dataStore.collectionNames (err, collectionNames) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    exists = false
    for nameRecord in collectionNames
      if req.params.collectionName is nameRecord.name.substring(nameRecord.name.indexOf('.') + 1)
        exists = true
        break
    res.status(200).json
      exists: exists
    next()

listCollections = (req, res, next) ->
  dataStore.collectionNames (err, collectionNames) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()

    collectionNames = _.map _.pluck(collectionNames, 'name'), (name) ->
      name.substring(name.indexOf('.') + 1)

    collectionStats = []

    collectionIterator = (collectionName, doneWithCollection) ->
      dataStore.collection(collectionName).count {}, (err, numberOfEntities) ->
        if err then return doneWithCollection errors.createKinveyError 'MongoError', err.toString()

        collectionStats.push { name: collectionName, count: numberOfEntities }
        doneWithCollection()

    async.each collectionNames, collectionIterator, (err) ->
      if err then return next errors.createKinveyError 'MongoError', err.toString()
      res.status(200).json collectionStats
      next()

createCollection = (req, res, next) ->
  dataStore.createCollection req.params.collectionName, (err) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()

    res.status(201).json {}
    next()

requireEntity = (req, res, next) ->
  unless req.body?.entity?
    return next errors.createKinveyError 'MissingRequiredParameter', 'The request must contain an entity'
  next()

requireQuery = (req, res, next) ->
  unless req.body?.query?
    return next errors.createKinveyError 'MissingRequiredParameter', 'The request must contain a query'
  next()

loadCollection = (req, res, next) ->
  dataStore.collection req.params.collectionName, (err, collection) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    req.collectionCursor = collection
    next()

module.exports.setupKinveyCollections = (callback) ->
  dataStore.collection('user').ensureIndex { username: 1 }, { unique: true }, (err) ->
    if err then return callback err
    callback()

module.exports.installRoutes = (app) ->
  config = app.get 'config'

  app.post "/collectionAccess/:collectionName/collectionExists",                                                                   collectionExists
  app.post "/collectionAccess/:collectionName/count",                           requireQuery, restrictQueryString, loadCollection, count
  app.post "/collectionAccess/:collectionName/distinct",                        requireQuery, restrictQueryString, loadCollection, distinct
  app.post "/collectionAccess/:collectionName/find",                            requireQuery, restrictQueryString, loadCollection, find
  app.post "/collectionAccess/:collectionName/findAndModify",    requireEntity, requireQuery, restrictQueryString, loadCollection, findAndModify
  app.post "/collectionAccess/:collectionName/findAndRemove",                   requireQuery, restrictQueryString, loadCollection, findAndRemove
  app.post "/collectionAccess/:collectionName/findOne",                         requireQuery, restrictQueryString, loadCollection, findOne
  app.post "/collectionAccess/:collectionName/geoNear",                                       restrictQueryString, loadCollection, geoNear
  app.post "/collectionAccess/:collectionName/group",                                         restrictQueryString, loadCollection, group
  app.post "/collectionAccess/:collectionName/insert",           requireEntity,                                    loadCollection, insert
  app.post "/collectionAccess/:collectionName/mapReduce",                                     restrictQueryString,                 mapReduce
  app.post "/collectionAccess/:collectionName/remove",                          requireQuery, restrictQueryString, loadCollection, remove
  app.post "/collectionAccess/:collectionName/save",             requireEntity,                                    loadCollection, save
  app.post "/collectionAccess/:collectionName/update",           requireEntity, requireQuery, restrictQueryString, loadCollection, update
  app.post "/collectionAccess/:collectionName/createCollection",                                                                   createCollection

  app.get  "/collectionAccess/collectionStats",                                                                                    listCollections

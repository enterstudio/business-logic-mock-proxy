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

dataStore = require '../data-store'
errors = require '../errors'

config = null

createLogEntry = (req, res, next) ->
  req.body.level ?= 'info'

  switch req.body.level
    when 'info' then prefix = 'INFO'
    when 'warning' then prefix = 'WARNING'
    when 'error' then prefix = 'ERROR'
    when 'fatal' then prefix = 'FATAL'

  now = new Date()

  logEntry =
    timestampInMS: now.getTime()
    timestamp: now.toUTCString()
    level: prefix
    # context: req.kinvey?.blFunctionName ? 'KBL'
    message: req.body.message
    # triggerCondition: { type: 'request', name: (req.kinvey?.collectionName ? 'unknown') }

  dataStore.collection(config.outputCollections.logging).insert logEntry, (err, insertedEntities) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    res.status(200).json insertedEntities[0]
    next()

listLogs = (req, res, next) ->
  req.query ?= {}

  dataStore.collection(config.outputCollections.logging).find(req.query, { sort: { timestamp: 1 } }).toArray (err, retrievedLogs) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()

    res.status(200).json retrievedLogs
    next()

countLogs = (req, res, next) ->
  req.query ?= {}

  dataStore.collection(config.outputCollections.logging).count req.query, (err, logCount) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()

    res.status(200).json
      count: logCount
    next()

deleteLogs = (req, res, next) ->
  req.query ?= {}

  dataStore.collection(config.outputCollections.logging).remove req.query, (err, deleteCount) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()

    res.status(200).json
      removed: deleteCount
    next()

module.exports.installRoutes = (app) ->
  config = app.get 'config'

  app.post    '/log',       createLogEntry
  app.get     '/log',       listLogs
  app.get     '/log/count', countLogs
  app.delete  '/log',       deleteLogs

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
uuid = require 'uuid'

config = null

sendMessage = (req, res, next) ->
  pushRecord =
    timestamp: new Date().toISOString()
    type: "message"
    content: req.body.messageContent
    destination: req.body.destination

  dataStore.collection(config.outputCollections.push).insert pushRecord, (err, insertedEntities) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    res.status(200).json insertedEntities[0]
    next()

sendBroadcast = (req, res, next) ->
  pushRecord =
    timestamp: new Date().toISOString()
    type: "broadcast"
    content: req.body.messageContent

  dataStore.collection(config.outputCollections.push).insert pushRecord, (err, insertedEntities) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    res.status(200).json insertedEntities[0]
    next()

countNotifications = (req, res, next) ->
  req.query ?= {}

  dataStore.collection(config.outputCollections.push).count req.query, (err, messageCount) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()

    res.status(200).json
      count: messageCount
    next()

deleteNotifications = (req, res, next) ->
  req.query ?= {}

  dataStore.collection(config.outputCollections.push).remove req.query, (err, deleteCount) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()

    res.status(200).json
      removed: deleteCount
    next()

listNotifications = (req, res, next) ->
  req.query ?= {}

  dataStore.collection(config.outputCollections.push).find(req.query, { sort: { timestamp: 1 } }).toArray (err, notifications) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()

    res.status(200).json notifications
    next()

requireMessage = (req, res, next) ->
  unless req.body?.messageContent? then return next errors.createKinveyError 'MissingRequiredParameter', 'messageContent must be specified to send a push message'

  next()

requireRecepients = (req, res, next) ->
  unless req.body?.destination? then return next errors.createKinveyError 'MissingRequiredParameter', 'destination must be specified to send a push message'

  next()

module.exports.installRoutes = (app) ->
  config = app.get 'config'

  app.post    '/push/sendMessage',   requireMessage, requireRecepients, sendMessage
  app.post    '/push/sendBroadcast', requireMessage,                    sendBroadcast
  app.get     '/push',                                                  listNotifications
  app.get     '/push/count',                                            countNotifications
  app.delete  '/push',                                                  deleteNotifications

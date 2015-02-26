# Copyright (c) 2014, Kinvey, Inc. All rights reserved.
#
# This software is licensed to you under the Kinvey terms of service located at
# http://www.kinvey.com/terms-of-use. By downloading, accessing and/or using this
# software, you hereby accept such terms of service  (and any agreement referenced
# therein) and agree that you have read, understand and agree to be bound by such
# terms of service and are of legal age to agree to such terms with Kinvey.
#
# This software contains valuable confidential and proprietary information of
# KINVEY, INC and is subject to applicable licensing agreements.
# Unauthorized reproduction, transmission or distribution of this file and its
# contents is a violation of applicable laws.

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

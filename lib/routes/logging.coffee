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

module.exports.installRoutes = (app) ->
  config = app.get 'config'

  app.post '/log', createLogEntry

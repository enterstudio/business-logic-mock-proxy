#
# Copyright (c) 2015, Kinvey, Inc. All rights reserved.
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
#

http = require 'http'
express = require 'express'
cors = require 'cors'
BSON = require('bson').BSONPure.BSON
errors = require './errors'

module.exports.runApp = (callback) ->
  console.log "#{new Date().toISOString()} -- Starting Business Logic Mock Proxy"

  process.env.NODE_CONFIG_PERSIST_ON_CHANGE = 'N'
  exports.config = config = require 'config'

  app = express()

  app.use cors()

  app.set 'config', config

  bodyParser = require 'body-parser'

  app.use bodyParser.json { type: 'application/json' }
  app.use bodyParser.raw { type: 'application/bson' }

  app.use (req, res, next) ->
    if req.headers['content-type'] is 'application/bson'
      try
        req.body = BSON.deserialize req.body
      catch e
        return next errors.createKinveyError 'InternalError', e.toString()
    next()

  require('./routes/configuration').installRoutes app

  collectionAccess = require './routes/collection-access'
  collectionAccess.installRoutes app
  require('./routes/email').installRoutes app
  require('./routes/push').installRoutes app
  require('./routes/logging').installRoutes app

  require('./routes/interface').installRoutes app

  app.get '/status', (req, res, next) ->
    res.status(204).send()
    next()

  app.use errors.onError

  collectionAccess.setupKinveyCollections (err) ->
    if err then console.log 'Error occurred while setting up default Kinvey collections. Error:', err

  process.on 'uncaughtException', (err) ->
    console.log "#{new Date().toISOString()} --", err.stack

  app.listen config.server.port, ->
    callback app

# run mock proxy
if module.parent.exports?.ENTRY_POINT is 'index'
  module.exports.runApp (app) ->
    console.log "#{new Date().toISOString()} -- Business Logic Mock Proxy started -- Version #{exports.config.version} -- Listening on #{exports.config.server.port}"

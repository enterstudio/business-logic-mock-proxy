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

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

cp = require 'child_process'
async = require 'async'
request = require 'request'

req = request.defaults {}

proxyProcess = null

logLevels = ['info', 'debug']

log = (message, level) ->
  logWithoutNewLine message + '\n', level

logWithoutNewLine = (message, level = 'info') ->
  if process.env.LOG_LEVEL? and logLevels.indexOf(process.env.LOG_LEVEL.toLowerCase()) >= logLevels.indexOf(level)
    process.stdout.write message

module.exports =
  log: log
  logWithoutNewLine: logWithoutNewLine

  startServer: (url, callback) ->
    logWithoutNewLine "Tester: starting server ... "
    proxyProcess = cp.fork '.', { silent: (process.env.LOG_LEVEL?.toLowerCase() isnt 'debug') }

    proceedWhenServerRuns = ->
      # try connecting to the server
      req.post
        url: url
        body: ''
        (err, res, body) ->
          # keep trying until a connection is established
          if err then return setTimeout proceedWhenServerRuns, 500
          log "started!"
          callback proxyProcess

    proceedWhenServerRuns()

  stopServer: (callback) ->
    log "Tester: killing server"
    proxyProcess?.kill()
    callback()

  # mocks the Express request flow through an array of middleware.
  # triggers the callback when a middleware calls res.send() or when all
  # middleware have called next()
  simulateRequest: (req, middlewareArray, callback) ->
    sendCalled = false
    sendArgs = null

    middlewareCounter = 1

    log "\tTester: simulating request ... "
    async.eachSeries(
      middlewareArray

      (middleware, doneWithMiddleware) ->
        # skip rest of middleware if send() has already been called
        if sendCalled then return doneWithMiddleware()

        logWithoutNewLine "\t\trunning middleware #{middlewareCounter}/#{middlewareArray.length} ... ", 'debug'
        middlewareCounter++

        # when send() is called, record the arguments
        fakeResponse =
          set: -> return
          status: (args...) ->
            end: ->
              sendCalled = true
              sendArgs = args
              log "status(#{args[0]}).end() called", 'debug'
              doneWithMiddleware()
          send: (args...) ->
            sendCalled = true
            sendArgs = args
            log "send() called with arguments: #{args}", 'debug'
            doneWithMiddleware()

        middleware req, fakeResponse, (err) ->
          log "next() called with argument: #{err}", 'debug'
          doneWithMiddleware err

      (err) ->
        log "\tTester: request simulation finished"
        callback err, sendCalled, sendArgs
    )

  generateFakeExpressApp: (config) ->
    # keep track of all POST routes & middleware the module registers
    routes = {}
    return {
      get: (param) -> config[param]
      post: (routePath, args...) ->
        routes[routePath] = args
      getMiddlewareForRoute: (routePath) -> routes[routePath]
    }

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

cp = require 'child_process'
async = require 'async'
request = require 'request'

req = request.defaults {}

proxyProcess = null

logLevels = ['info', 'debug']

log = (message, level) ->
  logWithoutNewLine message + '\n', level

logWithoutNewLine = (message, level='info') ->
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

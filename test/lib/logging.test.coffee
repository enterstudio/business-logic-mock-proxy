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

async = require 'async'
config = require 'config'
should = require 'should'
uuid = require 'uuid'
request = require 'request'
testUtils = require '../testUtils'

req = request.defaults {}

baseUrl = "http://#{config.server.address}:#{config.server.port}"
collectionName = "testCollection"

describe 'Logging service', () ->
  before (done) ->
    testUtils.startServer baseUrl, (forkedProcess) ->
      done()

  after (done) ->
    testUtils.stopServer ->
      done()

  afterEach (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{config.outputCollections.logging}/remove"
      json:
        query: {}
      (err, res, body) ->
        done err

  it "logs to the #{config.outputCollections.logging} collection with the appropriate defaults", (done) ->
    bodyToSend =
      message: uuid()

    req.post
      url: "#{baseUrl}/log"
      json: bodyToSend
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        req.post
          url: "#{baseUrl}/collectionAccess/#{config.outputCollections.logging}/find"
          json:
            query:
              message: bodyToSend.message
          (err, res, body) ->
            if err then return done err
            body.length.should.eql 1
            body[0].should.have.properties 'timestampInMS', 'timestamp', 'level', 'message'
            body[0].level.should.eql 'INFO'
            body[0].message.should.eql bodyToSend.message
            done()

  it "can specify logging levels", (done) ->
    logLevels = ['info', 'warning', 'error', 'fatal']

    createLogWithLevel = (logLevel, callback) ->
      req.post
        url: "#{baseUrl}/log"
        json:
          message: 'logging test'
          level: logLevel
        (err, res, body) ->
          return callback err if err
          callback()

    async.eachSeries logLevels, createLogWithLevel, (err) ->
      if err then return done err
      req.post
        url: "#{baseUrl}/collectionAccess/#{config.outputCollections.logging}/find"
        json:
          query: {}
        (err, res, body) ->
          if err then return done err
          body.length.should.eql logLevels.length

          for logEntry, i in body
            logEntry.level.should.eql logLevels[i].toUpperCase()

          done()

  it 'can fetch logs', (done) ->
    bodyToSend =
      message: uuid()

    req.post
      url: "#{baseUrl}/log"
      json: bodyToSend
      (err, res, body) ->
        return done err if err
        req.get
          url: "#{baseUrl}/log"
          (err, res, body) ->
            return done err if err
            body = JSON.parse body
            body.length.should.eql 1
            body[0].should.have.properties 'timestampInMS', 'timestamp', 'level', 'message'
            body[0].level.should.eql 'INFO'
            body[0].message.should.eql bodyToSend.message
            done()

  it 'can get log count', (done) ->
    bodyToSend =
      message: uuid()

    req.post
      url: "#{baseUrl}/log"
      json: bodyToSend
      (err, res, body) ->
        return done err if err
        req.post
          url: "#{baseUrl}/log"
          json: bodyToSend
          (err, res, body) ->
            return done err if err
            req.get
              url: "#{baseUrl}/log/count"
              (err, res, body) ->
                return done err if err
                body = JSON.parse body
                body.count.should.eql 2
                done()

  it 'can delete logs', (done) ->
    bodyToSend =
      message: uuid()

    req.post
      url: "#{baseUrl}/log"
      json: bodyToSend
      (err, res, body) ->
        return done err if err
        req.get
          url: "#{baseUrl}/log/count"
          (err, res, body) ->
            return done err if err
            body = JSON.parse body
            body.count.should.eql 1
            req.del
              url: "#{baseUrl}/log"
              (err, res, body) ->
                return done err if err
                body = JSON.parse body
                body.removed.should.eql 1
                req.get
                  url: "#{baseUrl}/log/count"
                  (err, res, body) ->
                    return done err if err
                    body = JSON.parse body
                    body.count.should.eql 0
                    done()

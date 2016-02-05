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

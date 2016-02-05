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

config = require 'config'
should = require 'should'
uuid = require 'uuid'
request = require 'request'
testUtils = require '../testUtils'

req = request.defaults {}

baseUrl = "http://#{config.server.address}:#{config.server.port}"
collectionName = "testCollection"

describe 'Push service', () ->
  before (done) ->
    testUtils.startServer baseUrl, (forkedProcess) ->
      done()

  after (done) ->
    testUtils.stopServer ->
      done()

  afterEach (done) ->
    request.post
      url: "#{baseUrl}/collectionAccess/#{config.outputCollections.push}/remove"
      json:
        query: {}
      (err, res, body) ->
        done err

  describe 'sending a message', () ->
    it 'requires the messageContent parameter', (done) ->
      req.post
        url: "#{baseUrl}/push/sendMessage"
        json:
          destination: {}
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 400
          body.code.should.eql 'MissingRequiredParameter'
          body.debug.indexOf('messageContent').should.not.eql -1
          done()

    it 'requires the destination parameter', (done) ->
      req.post
        url: "#{baseUrl}/push/sendMessage"
        json:
          messageContent: {}
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 400
          body.code.should.eql 'MissingRequiredParameter'
          body.debug.indexOf('destination').should.not.eql -1
          done()

    it 'correctly records the outgoing push message', (done) ->
      bodyToSend =
        destination: uuid()
        messageContent: uuid()

      req.post
        url: "#{baseUrl}/push/sendMessage"
        json: bodyToSend
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          messageId = body._id
          req.post
            url: "#{baseUrl}/collectionAccess/#{config.outputCollections.push}/findOne"
            json:
              query:
                _id: messageId
            (err, res, body) ->
              return done err if err
              body.should.have.property 'timestamp'
              body.type.should.eql 'message'
              body.destination.should.eql bodyToSend.destination
              body.content.should.eql bodyToSend.messageContent
              done()

    it 'returns the created entity', (done) ->
      bodyToSend =
        destination: uuid()
        messageContent: uuid()

      req.post
        url: "#{baseUrl}/push/sendMessage"
        json: bodyToSend
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          body.should.have.properties ['_id', 'timestamp', 'type', 'destination', 'content']
          body.type.should.eql 'message'
          body.destination.should.eql bodyToSend.destination
          body.content.should.eql bodyToSend.messageContent
          done()

  describe 'sending a broadcast', () ->
    it 'requires the messageContent parameter', (done) ->
      req.post
        url: "#{baseUrl}/push/sendBroadcast"
        json: {}
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 400
          body.code.should.eql 'MissingRequiredParameter'
          body.debug.indexOf('messageContent').should.not.eql -1
          done()

    it 'correctly records the outgoing broadcast', (done) ->
      bodyToSend =
        messageContent: uuid()

      req.post
        url: "#{baseUrl}/push/sendBroadcast"
        json: bodyToSend
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          messageId = body._id
          req.post
            url: "#{baseUrl}/collectionAccess/#{config.outputCollections.push}/findOne"
            json:
              query:
                _id: messageId
            (err, res, body) ->
              return done err if err
              body.should.have.property 'timestamp'
              body.type.should.eql 'broadcast'
              body.content.should.eql bodyToSend.messageContent
              done()

    it 'returns the created entity', (done) ->
      bodyToSend =
        messageContent: uuid()

      req.post
        url: "#{baseUrl}/push/sendBroadcast"
        json: bodyToSend
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          body.should.have.properties ['_id', 'timestamp', 'type', 'content']
          body.type.should.eql 'broadcast'
          body.content.should.eql bodyToSend.messageContent
          done()

  it 'can fetch push messages', (done) ->
    bodyToSend =
      messageContent: uuid()

    req.post
      url: "#{baseUrl}/push/sendBroadcast"
      json: bodyToSend
      (err, res, body) ->
        return done err if err
        req.get
          url: "#{baseUrl}/push"
          (err, res, body) ->
            return done err if err
            res.statusCode.should.eql 200
            body = JSON.parse body
            body.length.should.eql 1
            body[0].should.have.properties ['_id', 'timestamp', 'type', 'content']
            body[0].type.should.eql 'broadcast'
            body[0].content.should.eql bodyToSend.messageContent
            done()

  it 'can get push message count', (done) ->
    bodyToSend =
      messageContent: uuid()

    req.post
      url: "#{baseUrl}/push/sendBroadcast"
      json: bodyToSend
      (err, res, body) ->
        return done err if err
        req.post
          url: "#{baseUrl}/push/sendBroadcast"
          json: bodyToSend
          (err, res, body) ->
            return done err if err
            req.get
              url: "#{baseUrl}/push/count"
              (err, res, body) ->
                return done err if err
                body = JSON.parse body
                body.count.should.eql 2
                done()

  it 'can delete push messages', (done) ->
    bodyToSend =
      messageContent: uuid()

    req.post
      url: "#{baseUrl}/push/sendBroadcast"
      json: bodyToSend
      (err, res, body) ->
        return done err if err
        req.get
          url: "#{baseUrl}/push/count"
          (err, res, body) ->
            return done err if err
            body = JSON.parse body
            body.count.should.eql 1
            req.del
              url: "#{baseUrl}/push"
              (err, res, body) ->
                return done err if err
                body = JSON.parse body
                body.removed.should.eql 1
                req.get
                  url: "#{baseUrl}/push/count"
                  (err, res, body) ->
                    return done err if err
                    body = JSON.parse body
                    body.count.should.eql 0
                    done()
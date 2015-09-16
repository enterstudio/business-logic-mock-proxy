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
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

async = require 'async'
config = require 'config'
should = require 'should'
uuid = require 'uuid'
request = require 'request'
testUtils = require '../testUtils'

req = request.defaults {}

baseUrl = "http://#{config.server.address}:#{config.server.port}"
collectionName = "testCollection"

describe 'Email service', () ->
  before (done) ->
    testUtils.startServer baseUrl, (forkedProcess) ->
      done()

  after (done) ->
    testUtils.stopServer ->
      done()

  afterEach (done) ->
    request.post
      url: "#{baseUrl}/collectionAccess/#{config.outputCollections.email}/remove"
      json:
        query: {}
      (err, res, body) ->
        done err

  it "requires 'to', 'from', 'subject' and 'body' parameters", (done) ->
    requiredArguments = ['to', 'from', 'subject', 'body']

    async.eachSeries(
      requiredArguments

      (argument, doneWithArgument) ->
        bodyToSend = {}
        bodyToSend[argument] = uuid()

        req.post
          url: "#{baseUrl}/email/send"
          json: bodyToSend
          (err, res, body) ->
            return done err if err
            body.code.should.eql 'MissingRequiredParameter'
            doneWithArgument()

      (err) ->
        done err
    )

  it 'records a message with the correct arguments', (done) ->
    bodyToSend =
        to: uuid()
        from: uuid()
        subject: uuid()
        body: uuid()

    req.post
      url: "#{baseUrl}/email/send"
      json: bodyToSend
      (err, res, body) ->
        return done err if err
        req.post
          url: "#{baseUrl}/collectionAccess/#{config.outputCollections.email}/find"
          json:
            query:
              'message.to': bodyToSend.to
          (err, res, body) ->
            return done err if err
            body.length.should.eql 1
            body[0].should.have.properties ['_id', 'timestamp', 'message']
            body[0].message.to.should.eql bodyToSend.to
            body[0].message.from.should.eql bodyToSend.from
            body[0].message.subject.should.eql bodyToSend.subject
            body[0].message.body.should.eql bodyToSend.body
            done()

  it "passes the 'replyTo' field if specified in the incoming request", (done) ->
    bodyToSend =
      to: uuid()
      from: uuid()
      subject: uuid()
      body: uuid()
      replyTo: uuid()

    req.post
      url: "#{baseUrl}/email/send"
      json: bodyToSend
      (err, res, body) ->
        return done err if err
        req.post
          url: "#{baseUrl}/collectionAccess/#{config.outputCollections.email}/find"
          json:
            query:
              'message.to': bodyToSend.to
          (err, res, body) ->
            return done err if err
            body.length.should.eql 1
            body[0].should.have.properties ['_id', 'timestamp', 'message']
            body[0].message.to.should.eql bodyToSend.to
            body[0].message.from.should.eql bodyToSend.from
            body[0].message.subject.should.eql bodyToSend.subject
            body[0].message.body.should.eql bodyToSend.body
            body[0].message.replyTo.should.eql bodyToSend.replyTo
            done()

  it "passes the 'text' and 'html' fields instead of a 'body' when the 'html' field is specified", (done) ->
    bodyToSend =
      to: uuid()
      from: uuid()
      subject: uuid()
      body: uuid()
      html: uuid()

    req.post
      url: "#{baseUrl}/email/send"
      json: bodyToSend
      (err, res, body) ->
        return done err if err
        req.post
          url: "#{baseUrl}/collectionAccess/#{config.outputCollections.email}/find"
          json:
            query:
              'message.to': bodyToSend.to
          (err, res, body) ->
            return done err if err
            body.length.should.eql 1
            body[0].should.have.properties ['_id', 'timestamp', 'message']
            body[0].message.to.should.eql bodyToSend.to
            body[0].message.from.should.eql bodyToSend.from
            body[0].message.subject.should.eql bodyToSend.subject
            body[0].message.text.should.eql bodyToSend.body
            body[0].message.html.should.eql bodyToSend.html
            done()

  it 'returns the created entity as the server response', (done) ->
    bodyToSend =
      to: uuid()
      from: uuid()
      subject: uuid()
      body: uuid()

    req.post
      url: "#{baseUrl}/email/send"
      json: bodyToSend
      (err, res, body) ->
        return done err if err
        body.mailServerResponse.should.have.properties ['_id', 'timestamp', 'message']
        body.mailServerResponse.message.should.eql bodyToSend
        done()

  it 'can fetch email messages', (done) ->
    bodyToSend =
      to: uuid()
      from: uuid()
      subject: uuid()
      body: uuid()

    req.post
      url: "#{baseUrl}/email/send"
      json: bodyToSend
      (err, res, body) ->
        return done err if err
        req.get
          url: "#{baseUrl}/email"
          (err, res, body) ->
            return done err if err
            body = JSON.parse body
            body.length.should.eql 1
            body[0].should.have.properties ['_id', 'timestamp', 'message']
            body[0].message.to.should.eql bodyToSend.to
            body[0].message.from.should.eql bodyToSend.from
            body[0].message.subject.should.eql bodyToSend.subject
            body[0].message.body.should.eql bodyToSend.body
            done()

  it 'can get email message count', (done) ->
    bodyToSend =
      to: uuid()
      from: uuid()
      subject: uuid()
      body: uuid()

    req.post
      url: "#{baseUrl}/email/send"
      json: bodyToSend
      (err, res, body) ->
        return done err if err
        req.post
          url: "#{baseUrl}/email/send"
          json: bodyToSend
          (err, res, body) ->
            return done err if err
            req.get
              url: "#{baseUrl}/email/count"
              (err, res, body) ->
                return done err if err
                body = JSON.parse body
                body.count.should.eql 2
                done()

  it 'can delete email messages', (done) ->
    bodyToSend =
      to: uuid()
      from: uuid()
      subject: uuid()
      body: uuid()

    req.post
      url: "#{baseUrl}/email/send"
      json: bodyToSend
      (err, res, body) ->
        return done err if err
        req.get
          url: "#{baseUrl}/email/count"
          (err, res, body) ->
            return done err if err
            body = JSON.parse body
            body.count.should.eql 1
            req.del
              url: "#{baseUrl}/email"
              (err, res, body) ->
                return done err if err
                body = JSON.parse body
                body.removed.should.eql 1
                req.get
                  url: "#{baseUrl}/email/count"
                  (err, res, body) ->
                    return done err if err
                    body = JSON.parse body
                    body.count.should.eql 0
                    done()

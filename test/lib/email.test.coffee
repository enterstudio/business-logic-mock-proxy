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

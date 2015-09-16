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

request = require 'request'
config = require 'config'
should = require 'should'
uuid = require 'uuid'
BSON = require('bson').BSONPure.BSON
testUtils = require '../testUtils'

req = request.defaults {}

baseUrl = "http://#{config.server.address}:#{config.server.port}"
testCollectionName = "blProxy_testCollection"

describe 'Collection access', () ->
  before (done) ->
    testUtils.startServer baseUrl, (forkedProcess) ->
      done()

  after (done) ->
    testUtils.stopServer ->
      done()

  afterEach (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{testCollectionName}/remove"
      json:
        query: {}
      (err, res, body) ->
        done err

  it 'accepts JSON command bodies', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{testCollectionName}/insert"
      json:
        entity:
          [{ var1: true, var2: false }, { var1: false, var2: true }, { var1: true, var2: false }]
      (err, res, body) ->
        if err then return done err
        req.post
          url: "#{baseUrl}/collectionAccess/#{testCollectionName}/count"
          json:
            query:
              var1: true
          (err, res, body) ->
            if err then return done err
            body.should.have.property 'count'
            body.count.should.eql 2
            done()

  it 'accepts BSON command bodies', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{testCollectionName}/insert"
      json:
        entity:
          [{ var1: true, var2: false }, { var1: false, var2: true }, { var1: true, var2: false }]
      (err, res, body) ->
        if err then return done err
        req.post
          url: "#{baseUrl}/collectionAccess/#{testCollectionName}/count"
          body: BSON.serialize { query: { var1: true } }
          headers:
            'Content-Type': 'application/bson'
          (err, res, body) ->
            if err then return done err
            body = JSON.parse body
            body.should.have.property 'count'
            body.count.should.eql 2
            done()

  it 'returns errors with the appropriate status codes', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{testCollectionName}/count"
      json:
        query:
          $where: 1
      (err, res, body) ->
        if err then return done err
        res.statusCode.should.eql 400
        body.code.should.eql 'DisallowedQuerySyntax'
        done()

  it 'automatically creates a user collection with an index on username', (done) ->
    req.post "#{baseUrl}/collectionAccess/user/collectionExists", (err, res, body) ->
      if err then return done err
      body = JSON.parse body
      body.exists.should.be.true
      req.post
        url: "#{baseUrl}/collectionAccess/user/insert"
        json:
          entity:
            username: 'a'
        (err, res, body) ->
          if err then return done err
          res.statusCode.should.eql 201
          req.post
            url: "#{baseUrl}/collectionAccess/user/insert"
            json:
              entity:
                username: 'a'
            (err, res, body) ->
              if err then return done err
              res.statusCode.should.eql 500
              body.code.should.eql 'MongoError'
              body.debug.should.containEql 'duplicate key'
              done()

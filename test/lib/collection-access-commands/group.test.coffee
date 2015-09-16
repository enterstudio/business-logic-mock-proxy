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
request = require 'request'
BSON = require('bson').BSONPure.BSON
testUtils = require '../../testUtils'

req = request.defaults {}

baseUrl = "http://#{config.server.address}:#{config.server.port}"
collectionName = "testCollection"

describe 'collectionAccess / group', () ->
  before (done) ->
    testUtils.startServer baseUrl, (forkedProcess) ->
      done()

  after (done) ->
    testUtils.stopServer ->
      done()

  beforeEach (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/insert"
      json:
        entity: [{ propOne: 1, propTwo: 2, unique: 0 }
                 { propOne: 1, propTwo: 2, unique: 1 }
                 { propOne: 2, propTwo: 1, unique: 2 }
                 { propOne: 2, propTwo: 1, unique: 3 }
                 { propOne: 2, propTwo: 3, unique: 4 }]
      (err, res, body) ->
        done()

  afterEach (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/remove"
      json:
        query: {}
      (err, res, body) ->
        done err

  it 'fails when either the keys, initial, or reduce parameters are missing in the request', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/group"
      json: {}
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 400
        body.code.should.eql 'MissingRequiredParameter'
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/group"
          json:
            keys: ''
          (err, res, body) ->
            return done err if err
            res.statusCode.should.eql 400
            body.code.should.eql 'MissingRequiredParameter'
            req.post
              url: "#{baseUrl}/collectionAccess/#{collectionName}/group"
              json:
                keys: ''
                initial: ''
              (err, res, body) ->
                return done err if err
                res.statusCode.should.eql 400
                body.code.should.eql 'MissingRequiredParameter'
                req.post
                  url: "#{baseUrl}/collectionAccess/#{collectionName}/group"
                  json:
                    keys: ''
                    reduce: ''
                  (err, res, body) ->
                    return done err if err
                    res.statusCode.should.eql 400
                    body.code.should.eql 'MissingRequiredParameter'
                    req.post
                      url: "#{baseUrl}/collectionAccess/#{collectionName}/group"
                      json:
                        initial: ''
                        reduce: ''
                      (err, res, body) ->
                        return done err if err
                        res.statusCode.should.eql 400
                        body.code.should.eql 'MissingRequiredParameter'
                        done()

  it 'correctly performs a group', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/group"
      json:
        keys: []
        initial:
          count: 0
        reduce: 'function (obj, prev) { if (obj.propOne == 2) { prev.count++; } }'
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body[0].count.should.eql 3
        done()

  it 'correctly performs a conditional group', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/group"
      json:
        keys: []
        condition:
          propTwo: 1
        initial:
          count: 0
        reduce: 'function (obj, prev) { if (obj.propOne == 2) { prev.count++; } }'
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body[0].count.should.eql 2
        done()

  describe 'restrictions', () ->
    it 'fails when a condition including the $where operator is specified', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/group"
        json:
          keys: []
          condition:
            $where: true
          initial:
            count: 0
          reduce: 'function (obj, prev) { if (obj.propOne == 2) { prev.count++; } }'
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 400
          body.code.should.eql 'DisallowedQuerySyntax'
          done()

    it 'fails when a condition including the $query operator is specified', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/group"
        json:
          keys: []
          condition:
            $query: true
          initial:
            count: 0
          reduce: 'function (obj, prev) { if (obj.propOne == 2) { prev.count++; } }'
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 400
          body.code.should.eql 'DisallowedQuerySyntax'
          done()

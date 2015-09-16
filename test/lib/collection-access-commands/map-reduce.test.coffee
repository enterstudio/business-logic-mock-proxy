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
BSONPure = require('bson').BSONPure
testUtils = require '../../testUtils'

req = request.defaults {}

baseUrl = "http://#{config.server.address}:#{config.server.port}"
collectionName = "testCollection"

describe 'collectionAccess / mapReduce', () ->
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

  it 'fails when map or reduce are not included in the request', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/mapReduce"
      json: {}
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 400
        body.code.should.eql 'MissingRequiredParameter'
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/mapReduce"
          json:
            map: ''
          (err, res, body) ->
            return done err if err
            res.statusCode.should.eql 400
            body.code.should.eql 'MissingRequiredParameter'
            req.post
              url: "#{baseUrl}/collectionAccess/#{collectionName}/mapReduce"
              json:
                reduce: ''
              (err, res, body) ->
                return done err if err
                res.statusCode.should.eql 400
                body.code.should.eql 'MissingRequiredParameter'
                done()

  it 'successfuly executes a mapReduce', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/mapReduce"
      json:
        map: 'function() { emit(this.propOne, 1) }'
        reduce: 'function(k, values) { return values.length }'
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body.length.should.eql 2
        body[0].value.should.eql 2
        body[1].value.should.eql 3
        done()

  it 'filters by query before executing the mapReduce operation', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/mapReduce"
      json:
        query:
          propTwo: 1
        map: 'function() { emit(this.propOne, 1) }'
        reduce: 'function(k, values) { return values.length }'
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body.length.should.eql 1
        body[0].value.should.eql 2
        done()

  describe 'edge cases', () ->
    it "returns an error when the collection doesn't exist", (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/mapReduce"
        json:
          map: 'function() { emit(this.propOne, 1) }'
          reduce: 'function(k, values) { return values.length }'
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 500
          body.code.should.eql 'MongoError'
          done()

  describe 'options', () ->
    it 'properly limits when specified', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/mapReduce"
        json:
          map: 'function() { emit(this.propOne, 1) }'
          reduce: 'function(k, values) { return values.length }'
          options:
            limit: 3
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          Array.isArray(body).should.be.true
          body.length.should.eql 2
          body[0].value.should.eql 2
          body[1].value.should.eql 1
          done()

    it 'can pass it variables through the scope option', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/mapReduce"
        json:
          map: 'function() { emit(this.propOne, 1) }'
          reduce: 'function(k, values) { return values.length * multiplier }'
          options:
            scope:
              multiplier: 2
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          Array.isArray(body).should.be.true
          body.length.should.eql 2
          body[0].value.should.eql 4
          body[1].value.should.eql 6
          done()

  describe 'restrictions', () ->
    it 'fails when the query includes the $where operator', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/mapReduce"
        json:
          query:
            $where:
              propOne: 2
          map: 'function() { emit(this.propOne, 1) }'
          reduce: 'function(k, values) { return values.length }'
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 400
          body.code.should.eql 'DisallowedQuerySyntax'
          done()

    it 'fails when the query includes the $query operator', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/mapReduce"
        json:
          query:
            $query:
              propOne: 2
          map: 'function() { emit(this.propOne, 1) }'
          reduce: 'function(k, values) { return values.length }'
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 400
          body.code.should.eql 'DisallowedQuerySyntax'
          done()

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

config = require 'config'
should = require 'should'
request = require 'request'
BSON = require('bson').BSONPure.BSON
testUtils = require '../../testUtils'

req = request.defaults {}

baseUrl = "http://#{config.server.address}:#{config.server.port}"
collectionName = "testCollection"

describe 'collectionAccess / find', () ->
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

  it 'correctly performs a find with an empty query', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
      json:
        query: {}
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        Array.isArray(body).should.be.true
        body.length.should.eql 5
        done()

  it 'correctly performs a find with a non-empty query', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
      json:
        query:
          propOne: 1
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        Array.isArray(body).should.be.true
        body.length.should.eql 2
        body[0].unique.should.eql 0
        body[1].unique.should.eql 1
        done()

  it 'correctly performs a find with a compound query', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
      json:
        query:
           $and: [{ propOne: 2 }, { propTwo: 3 }]
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        Array.isArray(body).should.be.true
        body.length.should.eql 1
        body[0].unique.should.eql 4
        done()

  it 'correctly performs a find by a single Mongo ObjectID', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
      json:
        query: { unique: 0 }
      (err, res, body) ->
        return done err if err
        body.length.should.eql 1
        objectId = body[0]._id
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
          body: BSON.serialize({ query: { _id: objectId } })
          headers:
            'content-type': 'application/bson'
          (err, res, body) ->
            return done err if err
            body = JSON.parse body
            res.statusCode.should.eql 200
            Array.isArray(body).should.be.true
            body.length.should.eql 1
            body[0].unique.should.eql 0
            done()

  it 'correctly performs a find by an array of Mongo ObjectIDs', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
      json:
        query: { $or: [{ unique: 0 }, { unique: 1 }] }
      (err, res, body) ->
        return done err if err
        body.length.should.eql 2
        object1Id = body[0]._id.toString();
        object2Id = body[1]._id.toString();
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
          body: BSON.serialize({ query: { _id: $in: [ object1Id, object2Id ] } })
          headers:
            'content-type': 'application/bson'
          (err, res, body) ->
            return done err if err
            body = JSON.parse body
            res.statusCode.should.eql 200
            Array.isArray(body).should.be.true
            body.length.should.eql 2
            body[0].unique.should.eql 0
            body[1].unique.should.eql 1
            done()

  describe 'edge cases', () ->
    it "returns an empty array when the collection doesn't exist", (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/find"
        json:
          query: {}
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          Array.isArray(body).should.be.true
          body.length.should.eql 0
          done()

  describe 'options', () ->
    it 'properly limits when specified', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
        json:
          query: {}
          options:
            limit: 3
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          Array.isArray(body).should.be.true
          body.length.should.eql 3
          body[0].unique.should.eql 0
          body[1].unique.should.eql 1
          body[2].unique.should.eql 2
          done()

    it 'properly sorts (asending) when specified', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
        json:
          query: {}
          options:
            sort:
              propTwo: 1
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          Array.isArray(body).should.be.true
          body.length.should.eql 5
          body[0].propTwo.should.eql 1
          body[1].propTwo.should.eql 1
          body[2].propTwo.should.eql 2
          body[3].propTwo.should.eql 2
          body[4].propTwo.should.eql 3
          done()

    it 'properly sorts (descending) when specified', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
        json:
          query: {}
          options:
            sort:
              propTwo: -1
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          Array.isArray(body).should.be.true
          body.length.should.eql 5
          body[0].propTwo.should.eql 3
          body[1].propTwo.should.eql 2
          body[2].propTwo.should.eql 2
          body[3].propTwo.should.eql 1
          body[4].propTwo.should.eql 1
          done()

    it 'properly includes fields when using the fields option with an array', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
        json:
          query:
            unique: 0
          options:
            fields: ['propTwo']
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          Array.isArray(body).should.be.true
          body.length.should.eql 1
          body[0].should.have.property '_id'
          body[0].should.have.property 'propTwo'
          body[0].should.not.have.property 'propOne'
          body[0].should.not.have.property 'unique'
          done()

    it 'properly includes fields when using the fields option with an object', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
        json:
          query:
            unique: 0
          options:
            fields:
              propTwo: 1
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          Array.isArray(body).should.be.true
          body.length.should.eql 1
          body[0].should.have.property '_id'
          body[0].should.have.property 'propTwo'
          body[0].should.not.have.property 'propOne'
          body[0].should.not.have.property 'unique'
          done()

    it 'properly excludes fields when using the fields option with an object', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
        json:
          query:
            unique: 0
          options:
            fields:
              propTwo: 0
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          Array.isArray(body).should.be.true
          body.length.should.eql 1
          body[0].should.have.property '_id'
          body[0].should.have.property 'propOne'
          body[0].should.have.property 'unique'
          body[0].should.not.have.property 'propTwo'
          done()

    it 'properly skips', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
        json:
          query: {}
          options:
            skip: 2
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          Array.isArray(body).should.be.true
          body[0].unique.should.eql 2
          done()

  describe 'restrictions', () ->
    it 'fails when the query includes the $where operator', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/find"
        json:
          query:
            $where:
              propOne: 2
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 400
          body.code.should.eql 'DisallowedQuerySyntax'
          done()

    it 'fails when the query includes the $query operator', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/find"
        json:
          query:
            $query:
              propOne: 2
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 400
          body.code.should.eql 'DisallowedQuerySyntax'
          done()

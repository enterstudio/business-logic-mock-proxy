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
BSONPure = require('bson').BSONPure
testUtils = require '../../testUtils'

req = request.defaults {}

baseUrl = "http://#{config.server.address}:#{config.server.port}"
collectionName = "testCollection"

describe 'collectionAccess / findAndModify', () ->
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
                 { propOne: 3, propTwo: 1, unique: 2 }
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

  it 'correctly performs a findAndModify', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/findAndModify"
      json:
        query:
          unique: 0
        entity:
          $set:
            newValue: true
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body.entity.unique.should.eql 0
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
          json:
            query:
              unique: 0
          (err, res, body) ->
            return done err if err
            res.statusCode.should.eql 200
            body.should.have.property 'newValue'
            body.newValue.should.eql true
            done()

  it 'by default, returns the original object', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/findAndModify"
      json:
        query:
          unique: 0
        entity:
          $set:
            newValue: true
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body.entity.unique.should.eql 0
        body.entity.should.not.have.property 'newValue'
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
          json:
            query:
              unique: 0
          (err, res, body) ->
            return done err if err
            res.statusCode.should.eql 200
            body.should.have.property 'newValue'
            body.newValue.should.eql true
            done()

  it 'by default, returns an empty object when no entities matched the query', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/findAndModify"
      json:
        query:
          _id: "I don't exist"
        entity:
          someProp: 'someData'
      (err, res, body) ->
        return done err if err
        JSON.stringify(body.entity).should.eql JSON.stringify {}
        done()

  describe 'edge cases', () ->
    it "returns an empty object when the collection doesn't exist", (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/findAndModify"
        json:
          query: {}
          entity: {}
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          JSON.stringify(body.entity).should.eql JSON.stringify {}
          done()

  describe 'options', () ->
    describe 'when upsert is true', () ->
      it 'correctly performs an upsert with an empty entity', (done) ->
        newId = BSONPure.ObjectID().toString()
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/findAndModify"
          json:
            query:
              _id: newId
            entity: {}
            options:
              upsert: true
          (err, res, body) ->
            return done err if err
            res.statusCode.should.eql 200
            body.updatedExisting.should.eql false
            req.post
              url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
              json:
                query: {}
              (err, res, body) ->
                return done err if err
                res.statusCode.should.eql 200
                body.should.have.property '_id'
                done()

      it 'correctly performs an upsert with a non-empty entity', (done) ->
        newId = BSONPure.ObjectID().toString()
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/findAndModify"
          json:
            query:
              _id: newId
            entity:
              _id: newId
              testValue: true
            options:
              upsert: true
          (err, res, body) ->
            return done err if err
            res.statusCode.should.eql 200
            body.updatedExisting.should.eql false
            req.post
              url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
              json:
                query:
                  _id: newId
              (err, res, body) ->
                return done err if err
                res.statusCode.should.eql 200
                body.should.have.property '_id'
                body._id.should.eql newId
                body.testValue.should.eql true
                done()

      describe 'edge cases', () ->
        it "creates collection when it doesn't exist", (done) ->
          req.post
            url: "#{baseUrl}/collectionAccess/newCollectionName/findAndModify"
            json:
              query:
                _id: 'someId'
              entity: {}
              options:
                upsert: true
            (err, res, body) ->
              return done err if err
              res.statusCode.should.eql 200
              body.updatedExisting.should.eql false
              req.post
                url: "#{baseUrl}/collectionAccess/newCollectionName/find"
                json:
                  query: {}
                (err, res, body) ->
                  return done err if err
                  res.statusCode.should.eql 200
                  Array.isArray(body).should.be.true
                  body.length.should.eql 1
                  done()

    describe 'when remove is true', () ->
      it 'removes the matching item', (done) ->
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/findAndModify"
          json:
            query:
              unique: 0
            entity: {}
            options:
              remove: true
          (err, res, body) ->
            return done err if err
            res.statusCode.should.eql 200
            body.entity.unique.should.eql 0
            req.post
              url: "#{baseUrl}/collectionAccess/#{collectionName}/count"
              json:
                query:
                  unique: 0
              (err, res, body) ->
                return done err if err
                res.statusCode.should.eql 200
                body.count.should.eql 0
                done()

    describe 'when returnModifiedEntity is true', () ->
      it 'returns the modified entity instead of the original', (done) ->
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/findAndModify"
          json:
            query:
              unique: 0
            entity:
              $set:
                newValue: true
            options:
              returnModifiedEntity: true
          (err, res, body) ->
            return done err if err
            res.statusCode.should.eql 200
            body.entity.unique.should.eql 0
            body.entity.should.have.property 'newValue'
            body.entity.newValue.should.eql true
            req.post
              url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
              json:
                query:
                  unique: 0
              (err, res, body) ->
                return done err if err
                res.statusCode.should.eql 200
                body.should.have.property 'newValue'
                body.newValue.should.eql true
                done()

    describe 'when sort is specified', () ->
      it 'modifies the first matching sorted result', (done) ->
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/findAndModify"
          json:
            query: {}
            entity:
              $set:
                newValue: true
            options:
              sort: ['propTwo', 'propOne']
          (err, res, body) ->
            return done err if err
            res.statusCode.should.eql 200
            body.entity.unique.should.eql 3
            req.post
              url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
              json:
                query:
                  unique: 3
              (err, res, body) ->
                return done err if err
                res.statusCode.should.eql 200
                body.should.have.property 'newValue'
                body.newValue.should.eql true
                done()

  describe 'restrictions', () ->
    it 'fails when the query includes the $where operator', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/findAndModify"
        json:
          query:
            $where:
              propOne: 2
          entity: {}
        (err, res, body) ->
          res.statusCode.should.eql 400
          body.code.should.eql 'DisallowedQuerySyntax'
          done()

    it 'fails when the query includes the $query operator', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/findAndModify"
        json:
          query:
            $query:
              propOne: 2
          entity: {}
        (err, res, body) ->
          res.statusCode.should.eql 400
          body.code.should.eql 'DisallowedQuerySyntax'
          done()

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
request = require 'request'
BSONPure = require('bson').BSONPure
testUtils = require '../../testUtils'

req = request.defaults {}

baseUrl = "http://#{config.server.address}:#{config.server.port}"
collectionName = "testCollection"

describe 'collectionAccess / update', () ->
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

  it 'correctly performs an update', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/update"
      json:
        query:
          unique: 0
        entity:
          $set:
            newValue: true
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
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

  it 'by default, returns 200 and a numberAffected of 0 when no entities matched the query', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/update"
      json:
        query:
          _id: "I don't exist"
        entity:
          someProp: 'data'
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body.should.have.property 'numberAffected'
        body.numberAffected.should.eql 0
        done()

  describe 'edge cases', () ->
    it "returns 200 and a numberAffected of 0 when the collection doesn't exist", (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/update"
        json:
          query: {}
          entity: {}
        (err, res, body) ->
          res.statusCode.should.eql 200
          body.should.have.property 'numberAffected'
          body.numberAffected.should.eql 0
          done()

  describe 'options', () ->
    describe 'when upsert is true', () ->
      it 'correctly performs an upsert with an empty entity', (done) ->
        req.post
          url: "#{baseUrl}/collectionAccess/emptyCollection/update"
          json:
            query: {}
            entity: {}
            options:
              upsert: true
          (err, res, body) ->
            return done err if err
            res.statusCode.should.eql 200
            body.numberAffected.should.eql 1
            body.updatedExisting.should.eql false
            req.post
              url: "#{baseUrl}/collectionAccess/emptyCollection/findOne"
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
          url: "#{baseUrl}/collectionAccess/#{collectionName}/update"
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
            body.numberAffected.should.eql 1
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
            url: "#{baseUrl}/collectionAccess/fakeCollectionName/update"
            json:
              query: {}
              entity: {}
              options:
                upsert: true
            (err, res, body) ->
              return done err if err
              res.statusCode.should.eql 200
              body.numberAffected.should.eql 1
              body.updatedExisting.should.eql false
              req.post
                url: "#{baseUrl}/collectionAccess/fakeCollectionName/find"
                json:
                  query: {}
                (err, res, body) ->
                  return done err if err
                  res.statusCode.should.eql 200
                  Array.isArray(body).should.be.true
                  body.length.should.eql 1
                  done()

    describe 'when updateMultiple is true', () ->
      it 'correctly performs a multi update', (done) ->
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/update"
          json:
            query:
              $or: [{ unique: 0 }, { unique: 1 }]
            entity:
              $set:
                newValue: true
            options:
              updateMultiple: true
          (err, res, body) ->
            return done err if err
            res.statusCode.should.eql 200
            body.numberAffected.should.eql 2
            body.updatedExisting.should.eql true
            req.post
              url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
              json:
                query:
                  $or: [{ unique: 0 }, { unique: 1 }]
              (err, res, body) ->
                return done err if err
                res.statusCode.should.eql 200
                Array.isArray(body).should.be.true
                body.length.should.eql 2
                body[0].should.have.property 'newValue'
                body[0].newValue.should.eql true
                body[1].should.have.property 'newValue'
                body[1].newValue.should.eql true
                done()

  describe 'restrictions', () ->
    it 'fails when the query includes the $where operator', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/update"
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
        url: "#{baseUrl}/collectionAccess/#{collectionName}/update"
        json:
          query:
            $query:
              propOne: 2
          entity: {}
        (err, res, body) ->
          res.statusCode.should.eql 400
          body.code.should.eql 'DisallowedQuerySyntax'
          done()

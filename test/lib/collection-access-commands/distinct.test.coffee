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
BSON = require('bson').BSONPure.BSON
testUtils = require '../../testUtils'

req = request.defaults {}

baseUrl = "http://#{config.server.address}:#{config.server.port}"
collectionName = "testCollection"

describe 'collectionAccess / distinct', () ->
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

  it 'fails when no keyName included in the request', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/distinct"
      json: {}
      (err, res, body) ->
        res.statusCode.should.eql 400
        body.code.should.eql 'MissingRequiredParameter'
        done()

  it 'fails when query is not specified', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/distinct"
      json:
        keyName: 'propTwo'
      (err, res, body) ->
        res.statusCode.should.eql 400
        body.code.should.eql 'MissingRequiredParameter'
        done()

  it 'correctly performs a distinct when query is specified', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/distinct"
      json:
        query:
          propOne: 2
        keyName: 'propTwo'
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        Array.isArray(body).should.be.true
        body.length.should.eql 2
        body[0].should.eql 1
        body[1].should.eql 3
        done()

  it 'correctly performs a distinct by Mongo ObjectID', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
      json:
        query:
          unique: 0
      (err, res, body) ->
        return done err if err
        objectId = body._id.toString()
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/distinct"
          json:
            query:
              _id: objectId
            keyName: 'unique'
          (err, res, body) ->
            return done err if err
            res.statusCode.should.eql 200
            Array.isArray(body).should.be.true
            body.length.should.eql 1
            body[0].should.eql 0
            done()

  it 'correctly performs a distinct by an array of Mongo ObjectIDs', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
      json:
        query:
          $or: [{ unique: 0 }, { unique: 1 }]
      (err, res, body) ->
        return done err if err
        object1Id = body[0]._id.toString()
        object2Id = body[1]._id.toString()
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/distinct"
          json:
            query:
              _id:
                $in: [object1Id, object2Id]
            keyName: 'unique'
          (err, res, body) ->
            return done err if err
            res.statusCode.should.eql 200
            Array.isArray(body).should.be.true
            body.length.should.eql 2
            body[0].should.eql 0
            body[1].should.eql 1
            done()

  describe 'edge cases', () ->
    it "returns empty array when the collection doesn't exist", (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/distinct"
        json:
          query: {}
          keyName: 'propTwo'
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          Array.isArray(body).should.be.true
          body.length.should.eql 0
          done()

  describe 'restrictions', () ->
    it 'fails when the query includes the $where operator', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/distinct"
        json:
          query:
            $where:
              propOne: 2
          keyName: 'propTwo'
        (err, res, body) ->
          res.statusCode.should.eql 400
          body.code.should.eql 'DisallowedQuerySyntax'
          done()

    it 'fails when the query includes the $query operator', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/distinct"
        json:
          query:
            $query:
              propOne: 2
          keyName: 'propTwo'
        (err, res, body) ->
          res.statusCode.should.eql 400
          body.code.should.eql 'DisallowedQuerySyntax'
          done()

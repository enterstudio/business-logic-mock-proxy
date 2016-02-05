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

describe 'collectionAccess / findOne', () ->
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

  it 'correctly performs a findOne with an empty query', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
      json:
        query: {}
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body.should.have.property 'unique'
        body.unique.should.eql 0
        done()

  it 'correctly performs a findOne with a non-empty query', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
      json:
        query:
          propOne: 1
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body.should.have.property 'unique'
        body.unique.should.eql 0
        done()

  it 'correctly performs a findOne with a compound query', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
      json:
        query:
          $and: [{ propOne: 2 }, { propTwo: 3 }]
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body.should.have.property 'unique'
        body.unique.should.eql 4
        done()

  describe 'edge cases', () ->
    it "returns empty object when the collection doesn't exist", (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/findOne"
        json:
          query: {}
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          body.should.eql {}
          done()

  describe 'options', () ->
    it 'properly sorts (asending) when specified', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
        json:
          query:
            propTwo:
              $exists: true
          options:
            sort:
              propTwo: 1
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          body.should.have.property 'unique'
          body.unique.should.eql 2
          done()

    it 'properly sorts (descending) when specified', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
        json:
          query:
            propTwo:
              $exists: true
          options:
            sort:
              propTwo: -1
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          body.should.have.property 'unique'
          body.unique.should.eql 4
          done()

    it 'properly includes fields when using the fields option with an array', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
        json:
          query:
            unique: 0
          options:
            fields: ['propTwo']
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          body.should.have.property '_id'
          body.should.have.property 'propTwo'
          body.should.not.have.property 'propOne'
          body.should.not.have.property 'unique'
          done()

    it 'properly includes fields when using the fields option with an object', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
        json:
          query:
            unique: 0
          options:
            fields:
              propTwo: 1
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          body.should.have.property '_id'
          body.should.have.property 'propTwo'
          body.should.not.have.property 'propOne'
          body.should.not.have.property 'unique'
          done()

    it 'properly excludes fields when using the fields option with an object', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
        json:
          query:
            unique: 0
          options:
            fields:
              propTwo: 0
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          body.should.have.property '_id'
          body.should.have.property 'propOne'
          body.should.have.property 'unique'
          body.should.not.have.property 'propTwo'
          done()

    it 'properly skips', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/findOne"
        json:
          query: {}
          options:
            skip: 2
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          body.should.have.property 'unique'
          body.unique.should.eql 2
          done()

  describe 'restrictions', () ->
    it 'fails when the query includes the $where operator', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/findOne"
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
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/findOne"
        json:
          query:
            $query:
              propOne: 2
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 400
          body.code.should.eql 'DisallowedQuerySyntax'
          done()

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

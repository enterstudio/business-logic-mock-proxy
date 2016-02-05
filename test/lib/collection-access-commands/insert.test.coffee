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

describe 'collectionAccess / insert', () ->
  before (done) ->
    testUtils.startServer baseUrl, (forkedProcess) ->
      done()

  after (done) ->
    testUtils.stopServer ->
      done()

  it 'correctly performs an insert with an empty entity', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/insert"
      json:
        entity: {}
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 201
        body[0].should.have.property '_id'
        done()

  it 'correctly performs an insert with a non-empty entity', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/insert"
      json:
        entity:
          testValue: true
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 201
        body[0].should.have.property '_id'
        body[0].should.have.property 'testValue'
        body[0].testValue.should.eql true
        done()

  describe 'edge cases', () ->
    it "creates collection when it doesn't exist", (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/insert"
        json:
          entity: {}
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 201
          req.post
            url: "#{baseUrl}/collectionAccess/fakeCollectionName/find"
            json:
              query: {}
            (err, res, body) ->
              return done err if err
              Array.isArray(body).should.be.true
              body.length.should.eql 1
              done()

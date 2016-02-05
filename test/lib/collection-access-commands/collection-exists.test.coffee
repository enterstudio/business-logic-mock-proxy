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
testUtils = require '../../testUtils'

req = request.defaults {}

baseUrl = "http://#{config.server.address}:#{config.server.port}"
collectionName = "testCollection"

describe 'collectionAccess / collectionExists', () ->
  before (done) ->
    testUtils.startServer baseUrl, (forkedProcess) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/insert"
        json:
          entity: {}
        (err, res, body) ->
          done()

  after (done) ->
    testUtils.stopServer ->
      done()

  it 'correctly verifies the existance of a collection', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/collectionExists"
      json:
        entity: {}
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body.exists.should.be.true
        done()

  it "returns exists: false when the collection doesn't exist", (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/fakeCollectionName/collectionExists"
      json:
        entity: {}
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body.exists.should.be.false
        done()

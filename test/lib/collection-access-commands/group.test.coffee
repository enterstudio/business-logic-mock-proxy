#
# Copyright 2015 Kinvey, Inc.
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

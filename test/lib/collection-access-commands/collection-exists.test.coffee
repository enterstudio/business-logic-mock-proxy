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

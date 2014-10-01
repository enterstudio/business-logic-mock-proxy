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

describe 'collectionAccess / save', () ->
  before (done) ->
    testUtils.startServer baseUrl, (forkedProcess) ->
      done()

  after (done) ->
    testUtils.stopServer ->
      done()

  it 'correctly performs a save with an empty entity', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/save"
      json:
        entity: {}
      (err, res, body) ->
        res.statusCode.should.eql 200
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/count"
          json:
            query: {}
          (err, res, body) ->
            return done err if err
            body.count.should.eql 1
            done()

  it 'correctly performs a save with a non-empty entity', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/save"
      json:
        entity:
          testValue: true
      (err, res, body) ->
        res.statusCode.should.eql 200
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/count"
          json:
            query:
              testValue: true
          (err, res, body) ->
            return done err if err
            body.count.should.eql 1
            done()

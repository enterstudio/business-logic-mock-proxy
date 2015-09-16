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

fs = require 'fs'
unzip = require 'node-zip'
async = require 'async'
config = require 'config'
should = require 'should'
uuid = require 'uuid'
request = require 'request'
testUtils = require '../testUtils'

req = request.defaults {}

baseUrl = "http://#{config.server.address}:#{config.server.port}"
collectionName = "testCollection"

describe 'Configuration management', () ->
  before (done) ->
    testUtils.startServer baseUrl, (forkedProcess) ->
      done()

  after (done) ->
    testUtils.stopServer ->
      done()

  afterEach (done) ->
    req.post
      url: "#{baseUrl}/configuration/collectionData/dropAllData"
      json: {}
      (err, res, body) ->
        return done rr if err
        res.statusCode.should.eql 204
        done()

  it 'can drop all collection data', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/insert"
      json:
        entity: [{}, {}, {}, {}, {}]
      (err, res, body) ->
        return done rr if err
        res.statusCode.should.eql 201
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/count"
          json:
            query: {}
          (err, res, body) ->
            return done rr if err
            res.statusCode.should.eql 200
            body.count.should.eql 5
            req.post
              url: "#{baseUrl}/configuration/collectionData/dropAllData"
              json: {}
              (err, res, body) ->
                return done rr if err
                res.statusCode.should.eql 204
                req.post
                  url: "#{baseUrl}/collectionAccess/#{collectionName}/count"
                  json:
                    query: {}
                  (err, res, body) ->
                    return done rr if err
                    res.statusCode.should.eql 200
                    body.count.should.eql 0
                    done()

  describe 'importing data', ->
    jsonFixtures =
      data1: require __dirname + '/fixtures/data.json'
      data2: require __dirname + '/fixtures/data2.json'
      invalid: require __dirname + '/fixtures/invalid.json'

    it 'can import JSON from a file into a named collection', (done) ->
      req.post
        url: "#{baseUrl}/configuration/collectionData/import?collectionName=#{collectionName}"
        formData:
          file: fs.createReadStream __dirname + '/fixtures/data.json'
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 201
          body = JSON.parse body
          body.should.have.property collectionName
          body[collectionName].numberImported.should.eql jsonFixtures.data1.length
          req.post
            url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
            json:
              query:
                {}
            (err, res, body) ->
              return done err if err
              body.should.eql jsonFixtures.data1
              done()

    it 'can import JSON form multiple files into a named collection', (done) ->
      req.post
        url: "#{baseUrl}/configuration/collectionData/import?collectionName=#{collectionName}"
        formData:
          file1: fs.createReadStream __dirname + '/fixtures/data.json'
          file2: fs.createReadStream __dirname + '/fixtures/data2.json'
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 201
          body = JSON.parse body
          body.should.have.property collectionName
          body[collectionName].numberImported.should.eql (jsonFixtures.data1.length + jsonFixtures.data2.length)
          req.post
            url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
            json:
              query:
                {}
            (err, res, body) ->
              return done err if err
              body.should.eql jsonFixtures.data1.concat(jsonFixtures.data2)
              done()

    it 'can import JSON from a file into a collection matching the filename', (done) ->
      req.post
        url: "#{baseUrl}/configuration/collectionData/import"
        formData:
          file:
            value: fs.createReadStream __dirname + '/fixtures/data.json'
            options:
              filename: collectionName
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 201
          body = JSON.parse body
          body.should.have.property collectionName
          body[collectionName].numberImported.should.eql jsonFixtures.data1.length
          req.post
            url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
            json:
              query:
                {}
            (err, res, body) ->
              return done err if err
              body.should.eql jsonFixtures.data1
              done()

    it 'when importing based on filename, strips the optional .json extension', (done) ->
      req.post
        url: "#{baseUrl}/configuration/collectionData/import"
        formData:
          file:
            value: fs.createReadStream __dirname + '/fixtures/data.json'
            options:
              filename: collectionName + '.json'
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 201
          body = JSON.parse body
          body.should.have.property collectionName
          body[collectionName].numberImported.should.eql jsonFixtures.data1.length
          req.post
            url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
            json:
              query:
                {}
            (err, res, body) ->
              return done err if err
              body.should.eql jsonFixtures.data1
              done()

    it 'can import JSON from multiple files into collection matching the filenames', (done) ->
      req.post
        url: "#{baseUrl}/configuration/collectionData/import"
        formData:
          file:
            value: fs.createReadStream __dirname + '/fixtures/data.json'
            options:
              filename: collectionName
          file2:
            value: fs.createReadStream __dirname + '/fixtures/data2.json'
            options:
              filename: collectionName + '-2'
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 201
          body = JSON.parse body
          body.should.have.property collectionName
          body[collectionName].numberImported.should.eql jsonFixtures.data1.length
          body.should.have.property collectionName + '-2'
          body[collectionName + '-2'].numberImported.should.eql jsonFixtures.data2.length
          req.post
            url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
            json:
              query:
                {}
            (err, res, body) ->
              return done err if err
              body.should.eql jsonFixtures.data1
              req.post
                url: "#{baseUrl}/collectionAccess/#{collectionName}-2/find"
                json:
                  query:
                    {}
                (err, res, body) ->
                  return done err if err
                  body.should.eql jsonFixtures.data2
                  done()

    it 'returns an error if bad data is imported', (done) ->
      req.post
        url: "#{baseUrl}/configuration/collectionData/import?collectionName=#{collectionName}"
        formData:
          file: fs.createReadStream __dirname + '/fixtures/bad.json'
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 400
          body = JSON.parse body
          body.code.should.eql 'DataImportError'
          done()

    it 'returns an array of mongo errors encountered while trying to insert data', (done) ->
      req.post
        url: "#{baseUrl}/configuration/collectionData/import?collectionName=#{collectionName}"
        formData:
          file: fs.createReadStream __dirname + '/fixtures/invalid.json'
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 201
          body = JSON.parse body
          body.should.have.property collectionName
          body[collectionName].numberImported.should.eql (jsonFixtures.invalid.length - 1)
          body[collectionName].importErrors.length.should.eql 1
          done()

  describe 'exporting data', ->
    jsonFixtures =
      data: require __dirname + '/fixtures/data.json'
      data2: require __dirname + '/fixtures/data2.json'

    it 'can export data from collections', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/#{collectionName}/insert"
        json:
          entity: jsonFixtures.data
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 201
          body.length.should.eql jsonFixtures.data.length
          createdDataCol1 = body
          req.post
            url: "#{baseUrl}/collectionAccess/#{collectionName}-2/insert"
            json:
              entity: jsonFixtures.data2
            (err, res, body) ->
              return done err if err
              res.statusCode.should.eql 201
              body.length.should.eql jsonFixtures.data2.length
              createdDataCol2 = body
              req.get
                url: "#{baseUrl}/configuration/collectionData/export"
                encoding: null
                (err, res, body) ->
                  return done err if err
                  unzippedData = unzip body
                  unzippedData.files.should.have.property "#{collectionName}.json"
                  unzippedData.files["#{collectionName}.json"]._data.getContent().toString().should.eql JSON.stringify(createdDataCol1)
                  unzippedData.files.should.have.property "#{collectionName}-2.json"
                  unzippedData.files["#{collectionName}-2.json"]._data.getContent().toString().should.eql JSON.stringify(createdDataCol2)
                  done()

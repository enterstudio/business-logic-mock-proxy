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

async = require 'async'
dataStore = require '../data-store'
errors = require '../errors'

getConfiguration = (req, res, next) ->
  next()

setConfiguration = (req, res, next) ->
  next()

dropAllData = (req, res, next) ->
  dataStore.dropDatabase (err) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    res.status(204).send()
    next()

importCollectionData = (req, res, next) ->
  # case 1: import to a named collection
  if req.params.collectionName?
    unless Array.isArray req.body
      return next errors.createKinveyError 'DataImportError', 'When importing data into a named colletion, the request body must contain an array of entities'

    dataStore.dropCollection req.params.collectionName, (err, result) ->
      # an error will be returned if the collection doesn't exist. ignore it.
      dataStore.createCollection req.params.collectionName, (err, collection) ->
        if err then return next errors.createKinveyError 'DataImportError', err.toString()
        collection.insert req.body, (err, createdEntities) ->
          if err then return next errors.createKinveyError 'DataImportError', err.toString()
          res.status(201).json
            collectionName: req.params.collectionName
            numberImported: createdEntities.length
          next()
  # case 2: import to an object containing named collections and their data
  else
    if typeof req.body isnt 'object'
      return next errors.createKinveyError 'DataImportError', 'When importing collection data, the request body must contain an object of the format { "collectionName1": [...entities...], ... }'

    _insertDataIntoCollection = (collectionName, doneWithCollection) ->
      unless Array.isArray req.body[collectionName]
        return doneWithCollection errors.createKinveyError 'DataImportError', 'Collection data must be an array of entities'

      dataStore.dropCollection collectionName, (err, result) ->
        # an error will be returned if the collection doesn't exist. ignore it.
        dataStore.createCollection collectionName, (err, collection) ->
          if err then return next errors.createKinveyError 'DataImportError', err.toString()
          collection.insert req.body[collectionName], (err, createdEntities) ->
            if err then return next errors.createKinveyError 'DataImportError', err.toString()
            importStats.push
              collectionName: collectionName
              numberImported: createdEntities.length
            doneWithCollection()

    importStats = []
    collectionNames = Object.keys req.body

    async.eachSeries collectionNames, _insertDataIntoCollection, (err) ->
      if err then return next errors.createKinveyError 'DataImportError', err.toString()
      res.status(201).json importStats
      next()

module.exports.installRoutes = (app) ->
  app.get '/configuration', getConfiguration
  app.put '/configuration', setConfiguration

  app.post '/configuration/collectionData/dropAllData', dropAllData
  app.post '/configuration/collectionData/import/:collectionName?', importCollectionData

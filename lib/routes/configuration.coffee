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

async = require 'async'
Busboy = require 'busboy'
JSONStream = require 'JSONStream'
JSZip = require 'jszip'
dataStore = require '../data-store'
errors = require '../errors'

dropAllData = (req, res, next) ->
  dataStore.dropDatabase (err) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()
    res.status(204).send()
    next()

importCollectionData = (req, res, next) ->
  importStats = {}
  pending = 0

  try
    busboy = new Busboy { headers: req.headers }
  catch e
    msg = e.message?.toLowerCase?() ? e.toString?() ? ''
    if msg.indexOf('unsupported content type') >= 0
      return next errors.createKinveyError 'DataImportError', 'Only JSON files can be imported'
    return next errors.createKinveyError 'DataImportError', msg

  # only drop a collection once per import request.
  # this avoids accidentally inserting data into a collection and then dropping it
  droppedCollections = {}
  dropCollectionOnlyOnce = (collectionName, callback) ->
    if droppedCollections.hasOwnProperty collectionName
      return callback()
    droppedCollections[collectionName] = true
    dataStore.dropCollection collectionName, callback

  busboy.on 'file', (field, file, filename, encoding, mimetype) ->
    pending += 1

    if req.query?.collectionName?
      collectionName = req.query.collectionName
    else
      jsonIndex = filename.indexOf '.json'
      if jsonIndex >= 0
        collectionName = filename.substring 0, jsonIndex
      else
        collectionName = filename

    dropCollectionOnlyOnce collectionName, (err, result) ->
      # an error will be returned if the collection doesn't exist. ignore it.
      dataStore.createCollection collectionName, (err, collection) ->
        if err then return next errors.createKinveyError 'DataImportError', err.toString()
        stream = file.pipe JSONStream.parse '*'

        stream.on 'data', (data) ->
          pending += 1

          collection.insert data, { w: 1 }, (err, insertedEntities) ->
            if err?
              console.log err
              msg = err.stack ? err.message ? err.description ? err.error?.debug
              if typeof msg is 'object'
                try
                  msg = JSON.stringify msg

              importStats[collectionName] ?= {}
              importStats[collectionName].importErrors ?= []
              importStats[collectionName].importErrors.push msg
            else
              importStats[collectionName] ?= {}
              importStats[collectionName].numberImported ?= 0
              importStats[collectionName].numberImported += 1

            pending -= 1

        stream.on 'end', ->
          pending -= 1

        # Fail if the file size limit has been reached.
        stream.on 'limit', ->
          next? errors.createKinveyError 'DataImportError', 'File size limit exceeded'
          next = null # Reset.

        # Terminate on error.
        stream.on 'error', (err) ->
          # Continue (once).
          next? errors.createKinveyError 'DataImportError', 'There might be a syntax error in the file you are trying to import'
          next = null # Reset.

  sendResponseWhenFinished = () ->
    if pending > 0
      return setTimeout sendResponseWhenFinished, 500

    res.status(201).json importStats
    next()

  busboy.on 'finish', sendResponseWhenFinished
  req.pipe busboy

getCollectionNames = (req, res, next) ->
  if req.query?.collectionName?
    req.collectionNames = [{ name: req.query.collectionName }]
    next()
  else
    dataStore.collectionNames (err, collectionNames) ->
      if err then return next errors.createKinveyError 'MongoError', err.toString()
      req.collectionNames = collectionNames
      next()

exportCollectionData = (req, res, next) ->
  zip = new JSZip()

  collectionIterator = (collection, doneWithCollection) ->
    namespacedCollectionName = collection.name
    collectionName = namespacedCollectionName.substring(namespacedCollectionName.indexOf('.') + 1)
    dataStore.collection(collectionName).find({}).toArray (err, collectionData) ->
      if err then return next errors.createKinveyError 'MongoError', err.toString()

      try
        zip.file "#{collectionName}.json", JSON.stringify collectionData
      catch e
        return next errors.createKinveyError 'MongoError', e.toString()

      doneWithCollection()

  async.each req.collectionNames, collectionIterator, (err) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()

    try
      zippedBuffer = zip.generate { type: 'nodebuffer' }
    catch e
      return next errors.createKinveyError 'MongoError', e.toString()

    if req.query?.collectionName?
      filename = req.query.collectionName
    else
      filename = 'collectionData'
    filename += '-' + (new Date().getTime()) + '.zip'
    res.header 'Content-Disposition', 'attachment; filename=' + filename
    res.status(200).send zippedBuffer

module.exports.installRoutes = (app) ->
  app.post '/configuration/collectionData/dropAllData',                     dropAllData
  app.post '/configuration/collectionData/import',                          importCollectionData
  app.get  '/configuration/collectionData/export',      getCollectionNames, exportCollectionData

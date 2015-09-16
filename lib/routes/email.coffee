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

dataStore = require '../data-store'
errors = require '../errors'

config = null

sendEmailMessage = (req, res, next) ->
  unless req.body.to? and req.body.from? and req.body.subject? and req.body.body?
    return next errors.createKinveyError 'MissingRequiredParameter', "To send an email, you must specify the 'to', 'from', 'subject' and 'body' parameters"

  message =
    to: req.body.to
    from: req.body.from
    subject: req.body.subject

  if req.body.replyTo? then message.replyTo = req.body.replyTo

  if req.body.html?
    message.text = req.body.body
    message.html = req.body.html
  else
    message.body = req.body.body

  emailRecord =
    timestamp: new Date().toISOString()
    message: message

  dataStore.collection(config.outputCollections.email).insert emailRecord, (err, insertedEntities) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()

    res.status(200).json
      mailServerResponse: insertedEntities[0]
    next()

listMessages = (req, res, next) ->
  req.query ?= {}

  dataStore.collection(config.outputCollections.email).find(req.query, { sort: { timestamp: 1 } }).toArray (err, retrievedEmails) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()

    res.status(200).json retrievedEmails
    next()

countMessages = (req, res, next) ->
  req.query ?= {}

  dataStore.collection(config.outputCollections.email).count req.query, (err, emailCount) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()

    res.status(200).json
      count: emailCount
    next()

deleteMessages = (req, res, next) ->
  req.query ?= {}

  dataStore.collection(config.outputCollections.email).remove req.query, (err, deleteCount) ->
    if err then return next errors.createKinveyError 'MongoError', err.toString()

    res.status(200).json
      removed: deleteCount
    next()

module.exports.installRoutes = (app) ->
  config = app.get 'config'

  app.post    '/email/send',  sendEmailMessage
  app.get     '/email',       listMessages
  app.get     '/email/count', countMessages
  app.delete  '/email',       deleteMessages

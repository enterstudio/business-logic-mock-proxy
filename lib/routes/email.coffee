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

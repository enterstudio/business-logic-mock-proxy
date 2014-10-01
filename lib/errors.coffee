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

errors =
  InternalError:
    statusCode: 500
    description: "An unexpected error has occurred"
  DataImportError:
    statusCode: 400
    description: 'An error has occurred while attempting to import collection data'
  MissingRequiredParameter:
    statusCode: 400
    description: 'The incoming request is missing a required parameter'
  MongoError:
    statusCode: 500
    description: 'An error has occurred within MongoDB while trying to execute your query'
  DisallowedQuerySyntax:
    statusCode: 400
    description: 'Your query included syntax that is not supported'

module.exports =
  createKinveyError: (name, debugMessage) ->
    unless errors[name]?
      name = 'InternalError'

    err = new Error name
    err.description = errors[name].description
    err.statusCode = errors[name].statusCode
    err.debug = debugMessage

    return err

  onError: (err, req, res, next) ->
    res.set 'Content-Type', 'application/json'

    errorToSend =
      code: err.message
      message: err.description
      debug: err.debug ? ''

    res
      .status err.statusCode ? 500
      .json errorToSend

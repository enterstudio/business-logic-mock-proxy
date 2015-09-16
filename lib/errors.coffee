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

# Business Logic Mock Proxy

A mock proxy server to simulate requests from the business logic API to internal Kinvey services (collection access, email, logging, push notifications). Intended for use as a drop-in replacement for the [business-logic-proxy](http://github.com/Kinvey/business-logic-proxy) server.

The server does not require any authentication, as it will be used in local tests.

## Differences from "real" proxy

* **Collection access** uses [TingoDB](http://www.tingodb.com/) to create and manage an in-memory Mongo-like database. It has been configured to be as close as possible to Mongo, and while the vast majority of Mongo's functionality (as used by BL's collectionAccces module) is supported, it's important to be aware that there may be some differences, especially where edge cases are concerned.
* Outoing **email messages** are not actually sent, but are instead logged to a collection defined in the [config file](#Configuration), which defaults to `_outgoingEmailMessages`.
* Outoing **push notifications** are not actually sent, but are instead logged to a collection defined in the [config file](#Configuration), which defaults to `_outgoingPushNotifications`.
* Some fields that would normally be logged by the **logging endpoint** are omitted due to lack of information, as that information would normally be populated from the environment metadata.

### Requirements

* node 10

### Configuration

Some settings are configurable. These can be found in the config file located at `/config/default.coffee`. Environment-specific overrides can be created in `/config/environment-name.coffee`, and will be loaded automatically based on the value of the `NODE_ENV` environment variable.

### Running

```
npm install
node .
```

This will start a server using the port specified in the config file, which defaults to `2845`.

### Testing

**Running all tests**:

```
npm test
```

**Running a specific test file**:

```
npm run-script test-specificTestName
```

Where `specificTestName` is one of `logging`, `collectionAccess`, `email`, `push`

## License
    Copyright 2016 Kinvey, Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    #ou may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
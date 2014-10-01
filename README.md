# Business Logic Mock Proxy

Mock to simulate business logic requests to internal Kinvey services.


## Testing

**Requires**:

* `npm install`

**Running all tests**:

```
npm test
```

**Running a specific test file**:

```
npm run-script test-specificTestName
```

Where `specificTestName` is one of `logging`, `collectionAccess`, `email`, `push`


For more verbose test output, use the environment variable `LOG_LEVEL` set to `info` or `debug`:

```
LOG_LEVEL=debug npm test
```

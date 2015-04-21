rewire = require 'rewire'
sinon = require 'sinon'
EventEmitter = require('events').EventEmitter

describe "reload-json", ->
  Reload = rewire '../../lib/reload'
  reload = null
  watch = null
  fsMock = {}

  Reload.__set__ 'fs', fsMock

  beforeEach ->
    watch = new EventEmitter
    reload = new Reload
    fsMock.watch = sinon.stub().returns watch
    fsMock.readFile = sinon.stub()
      .callsArgWithAsync 1, null, '{"key": "data"}'

  describe "#read", ->
    it "returns an EventEmitter", ->
      read = reload.read 'foo'
      assert.isFunction read.on

    it "calls readFile", ->
      reload.read 'foo'
      assert.calledOnce fsMock.readFile
      assert.calledWith fsMock.readFile, 'foo'

    it "caches file once loaded", (done) ->
      read = reload.read 'foo'
      read.on 'load', ->
        assert.propertyVal reload.files.foo, 'key', 'data'
        done()

    it "deals with errors while reading the file ", (done) ->
      err = new Error 'dummy-error'

      fsMock.readFile = sinon.stub()
        .callsArgWithAsync 1, err

      read = reload.read 'foo'
      read.on 'error', ->
        assert.propertyVal reload.files, 'foo', null
        done()

    it "emits an error when receiving invalid json", (done) ->
      fsMock.readFile = sinon.stub()
        .callsArgWithAsync 1, null, '{blah'

      read = reload.read 'foo'
      read.on 'error', ->
        done()


  describe "#configureWatch", ->
    it "configures a filesystem watch", (done) ->
      reload.configureWatch 'foo'
      process.nextTick ->
        assert.calledOnce fsMock.watch
        assert.calledWith fsMock.watch, 'foo'
        done()

    it "triggers a read on change", (done) ->
      reload.configureWatch 'foo'
      watch.emit 'change', 'change', 'foo'

      setTimeout (->
        assert.calledOnce fsMock.readFile
        assert.calledWith fsMock.readFile, 'foo'
        done()
      ), 25

    it "checks if a read is in progress before triggering", (done) ->
      reload.configureWatch 'foo'
      watch.emit 'change', 'change', 'foo'

      setTimeout (->
        reload.files['foo'] = {}
      ), 5

      setTimeout (->
        assert.equal fsMock.readFile.callCount, 0
        done()
      ), 25

    # Test of deprecated functionality
    it "forwards change event", (done) ->
      reload.configureWatch 'foo'
      reload.on 'change', (ev, filename) ->
        assert.equal filename, 'foo'
        # wait for debounce
        setTimeout done, 20

      watch.emit 'change', 'change', 'foo'

  describe "#load", ->
    it "consolidates two reads into one", (done) ->
      readOne = null
      readTwo = null

      verify = ->
        assert.strictEqual readOne, readTwo
        assert.calledOnce fsMock.readFile
        done()

      reload.load 'foo', (err, data) ->
        assert.isNull err
        readOne = data
        verify() if readTwo

      reload.load 'foo', (err, data) ->
        readTwo = data
        verify() if readOne

    it "returns cached data", (done) ->
      reload.load 'foo', (err, readOne) ->
        assert.isNull err
        reload.load 'foo', (err, readTwo) ->
          assert.isNull err
          assert.strictEqual readOne, readTwo
          done()

    it "forwards error to callback", (done) ->
      err = new Error 'dummy-error'

      fsMock.readFile = sinon.stub()
        .callsArgWithAsync 1, err

      reload.load 'foo', (err, data) ->
        assert.instanceOf err, Error
        done()

    it "cleans up subscribers after loading", (done) ->
      callback = sinon.stub()
      err = new Error 'dummy-error'
      file = new EventEmitter

      reload.read = sinon.stub().returns file

      reload.load 'foo', callback

      file.emit 'error', err
      file.emit 'load'

      assert.calledOnce callback
      assert.calledWith callback, sinon.match.instanceOf Error
      assert.lengthOf file.listeners('load'), 0
      done()

    it "should return a thunk", (done) ->
      thunk = reload.load 'foo'
      thunk (err, data) ->
        assert.isNull err
        assert.propertyVal data, 'key', 'data'
        done()

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

        it "handels file once loaded", (done) ->
            reload.on 'load', ->
                assert.propertyVal reload.files.foo, 'key', 'data'
                done()

            reload.read 'foo'

        it "deals with errors while reading the file ", (done) ->
            err = new Error 'dummy-error'

            fsMock.readFile = sinon.stub()
                .callsArgWithAsync 1, err

            reload.on 'error', ->
                assert.propertyVal reload.files, 'foo', null
                done()

            reload.read 'foo'

        it "emits an error when receiving invalid json", (done) ->
            reload.on 'error', ->
                done()

            fsMock.readFile = sinon.stub()
                .callsArgWithAsync 1, null, '{blah'

            reload.read 'foo'

    describe "#configureWatch", ->
        it "configures a filesystem watch", ->
            reload.configureWatch 'foo'
            assert.calledOnce fsMock.watch
            assert.calledWith fsMock.watch, 'foo'

        it "triggers a read on change", (done) ->
            reload.configureWatch 'foo'
            watch.emit 'change'

            setTimeout (->
                assert.calledOnce fsMock.readFile
                assert.calledWith fsMock.readFile, 'foo'
                done()
            ), 25

        it "checks if a read is in progress before triggering", (done) ->
            reload.configureWatch 'foo'
            watch.emit 'change'

            setTimeout (->
                reload.files['foo'] = {}
            ), 5

            setTimeout (->
                assert.equal fsMock.readFile.callCount, 0
                done()
            ), 25

        it "forwards any error that occurs", (done) ->
            err = new Error 'dummy-error'
            reload.configureWatch 'foo'

            reload.on 'error', (e) ->
                assert.strictEqual e, err
                done()

            watch.emit 'error', err

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

            reload.on 'error', ->
                return

            reload.load 'foo', (err, data) ->
                done()
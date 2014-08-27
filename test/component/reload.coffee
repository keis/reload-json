path = require 'path'
touch = require 'touch'

describe "reload-json", ->
    Reload = require '../../lib/reload'
    base = path.join process.cwd(), 'test/data/'
    reload = null

    beforeEach ->
        reload = new Reload

    it "returns the same data when reading the same file", (done) ->
        filepath = path.join base, 'test.json'
        readOne = null
        readTwo = null

        verify = ->
            assert.strictEqual readOne, readTwo
            done()

        reload.load filepath, (err, data) ->
            assert.isNull err
            readOne = data
            verify() if readTwo

        reload.load filepath, (err, data) ->
            assert.isNull err
            readTwo = data
            verify() if readOne

    it "reads new data immediatly after the file is changed", (done) ->
        filepath = path.join base, 'test.json'
        reload.load filepath, (err, readOne) ->
            assert.isNull err

            touch filepath, (err) ->
                assert.isNull err

                reload.load filepath, (err, readTwo) ->
                    assert.isNull err
                    assert.notStrictEqual readOne, readTwo
                    done()

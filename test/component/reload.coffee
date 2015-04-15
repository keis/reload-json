fs = require 'fs'
os = require 'os'
rimraf = require 'rimraf'
path = require 'path'
touch = require 'touch'
sinon = require 'sinon'

describe "reload-json", ->
  Reload = require '../../lib/reload'
  base = path.join os.tmpdir(), 'reload-json-test'
  filepath = path.join base, 'test.json'
  reload = null
  errorcb = null

  before (done) ->
    fs.mkdir base, done

  after (done) ->
    rimraf base, done

  beforeEach (done) ->
    errorcb = sinon.stub()
    reload = new Reload
      delay: 50
    reload.on 'error', errorcb
    fs.writeFile filepath, JSON.stringify(file: 'test.json'), (err) ->
      done()

  afterEach (done) ->
    # wait for debounce
    setTimeout done, 50

  it "returns the same data when reading the same file", (done) ->
    readOne = null
    readTwo = null

    verify = ->
      assert.strictEqual readOne, readTwo
      assert.notCalled errorcb
      done()

    reload.load filepath, (err, data) ->
      assert.isNull err
      readOne = data
      verify() if readTwo

    reload.load filepath, (err, data) ->
      assert.isNull err
      readTwo = data
      verify() if readOne

  it "reads new data immediately after the file is changed", (done) ->
    reload.load filepath, (err, readOne) ->
      assert.isNull err

      touch filepath, (err) ->
        assert.isNull err

        reload.load filepath, (err, readTwo) ->
          assert.isNull err
          assert.notStrictEqual readOne, readTwo
          assert.notCalled errorcb
          done()

  it "does not use cached value after file is removed", (done) ->
    reload.load filepath, (err, readOne) ->
      assert.isNull err

      fs.unlink filepath, (err) ->
        assert.isNull err

        reload.load filepath, (err, readTwo) ->
          assert.isNull readTwo
          assert.instanceOf err, Error
          done()

  it "does not trigger reload when file is removed", (done) ->
    reload.load filepath, (err, readOne) ->
      assert.isNull err

      fs.unlink filepath, (err) ->
        assert.isNull err
        assert.notCalled errorcb

        setTimeout (->
          assert.notCalled errorcb
          done()
        ), 25

  it "reads new data when file is replaced", (done) ->
    tmppath = path.join base, 'new.json'
    fs.writeFile tmppath, JSON.stringify(file: 'new.json'), (err) ->
      reload.load filepath, (err, readOne) ->
        assert.isNull err
        fs.rename tmppath, filepath, (err) ->
          assert.isNull err
          reload.load filepath, (err, readTwo) ->
            assert.propertyVal readTwo, 'file', 'new.json'
            done()

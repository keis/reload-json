# reload-json

[![NPM Version][npm-image]](https://npmjs.org/package/reload-json)
[![Build Status][travis-image]](https://travis-ci.org/keis/reload-json)
[![Coverage Status][coveralls-image]](https://coveralls.io/r/keis/reload-json?branch=master)

This module provides a way of loading JSON from disk in a way so that you know
you always have the latest data without necessarily reloading the file every
time the data is requested.

As an added bonus multiple requests for the same file in short sequence will be
merged into a single `fs.readFile`

The first call will start a read of the file and then the callback is called as
expected with the error or data object. If a second call happens while a read
is already in progress that callback will be called when the read finishes with
the same argument as the original callback.

A call to load at a later time will use a cached value unless the content has
changed as determined by `fs.watch`. The module will also try to pre-emptively
reload the files after a small delay when they change.

## Usage

    var Reloader = require('reload-json'),
      , reload = new Reloader()

    reload.load('path/to/file.json', function (err, data) {
      // do stuff
    })

## Installation

    npm install reload-json


[npm-image]: https://img.shields.io/npm/v/reload-json.svg?style=flat
[travis-image]: https://img.shields.io/travis/keis/reload-json.svg?style=flat
[coveralls-image]: https://img.shields.io/coveralls/keis/reload-json.svg?style=flat

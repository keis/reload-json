# reload-json

This module provides a way of loading JSON from disk in a way so that you know
you always have the latest data without necessarily reloading the file every
time the data is requested.

As an added bonus multiple requests for the same file in short sequence will be
merged into a single `fs.readFile`

[![Build Status](https://travis-ci.org/keis/json-reload.svg?branch=master)](https://travis-ci.org/keis/json-reload)

## Usage

    var Reloader = require('reload-json'),
        reloader = new Reloader();

    reloader.on('error', function (err) {
        console.log('an error occured', err);
    });

    reload.load('path/to/file.json', function (err, data) {
        // do stuff
    });

## Installation

    npm install reload-json

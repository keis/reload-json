var EventEmitter = require('events').EventEmitter,
    deprecate = require('depd')('reload-json'),
    debounce = require('debounce'),
    first = require('ee-first'),
    util = require('util'),
    fs = require('fs');

// Load a JSON from the specified path. The loader can be used as a
// EventEmitter to track the progress is returned. This is used to coordinate
// multiple simultaneous requests for the same file into a single `readFile`
function JSONLoader(path) {
    var self = this;

    fs.readFile(path, function (err, data) {
        var json;

        if (err) {
            return self.emit('error', err);
        }

        try {
            json = JSON.parse(data);
        } catch (e) {
            return self.emit('error', e);
        }

        self.emit('load', json);
    });
}

util.inherits(JSONLoader, EventEmitter);

// OPTIONS
//  - persistent reload in watch
function ReloadJSON(options) {
    options = options || {};
    this.files = {};
    this.watching = {};
    this.persistent = options.persistent;
    this.delay = options.delay || 10;
}

// Extend event emitter to provide some insight to what's going on internally
// this is pretty bad idea and is considered deprecated. `change` and `load`
// events are still emitted but no more `error` events.
util.inherits(ReloadJSON, EventEmitter)
Object.keys(EventEmitter.prototype).forEach(function (k) {
    if (typeof k === 'function') {
        ReloadJSON.prototype[k] = deprecate.function(ReloadJSON.prototype[k])
    }
})

// Start reading a json file
ReloadJSON.prototype.read = function (path) {
    var self = this,
        files = this.files,
        file = files[path] = new JSONLoader(path);

    first([
        [file, 'error', 'load'],
    ], function (err, ee, ev, args) {
        var data;

        if (err) {
            // If an error occurs the loader needs to be invalidated.
            files[path] = null;
            return
        }

        // Once loaded store data in cache and configure a watch on the
        // file so that it can be reloaded when it is changed.
        data = args[0];
        files[path] = data
        self.configureWatch(path);
        EventEmitter.prototype.emit.call(self, 'load', path, data)
    });

    return file;
}

// Configure a `fs.watch` on the given path that will trigger a reload if the
// file is changed.
ReloadJSON.prototype.configureWatch = function (path) {
    var self = this,
        watching = this.watching,
        delay = this.delay,
        watch;

    if (watching[path]) {
        return;
    }

    watch = watching[path] = fs.watch(path, {
        persistent: this.persistent
    });

    // Make sure old data is not used again
    watch.on('change', function (event, filename) {
        self.files[path] = null;
        EventEmitter.prototype.emit.call(self, 'change', event, filename)
    });

    // Trigger a new read of the file after a debounce timeout, it's
    // possible a read was started in the meantime in that case no read is
    // triggered from the watch.
    watch.on('change', debounce(function (ev) {
        if (ev === 'change' && !self.files[path]) {
            self.read(path);
        }
    }, delay));

    watch.on('error', function () {})
}

// Load json from the specified path. The result is cached and multiple request
// is consolidated into a single file read.
ReloadJSON.prototype.load = function (path, callback) {
    var self = this,
        files = this.files,
        file = files[path];

    if (file) {
        if (!(file instanceof EventEmitter)) {
            return setImmediate(function () {
                callback(null, file);
            });
        }
    } else {
        file = this.read(path);
    }

    first([
        [file, 'load', 'error']
    ], function (err, ee, ev, args) {
        callback(err, err ? null : args[0]);
    });

    // Return a thunk
    return function (fun) {
        callback = fun;
    }
}

module.exports = ReloadJSON;

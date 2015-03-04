var EventEmitter = require('events').EventEmitter,
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
}

util.inherits(ReloadJSON, EventEmitter);

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
            // If a error occurs the loader needs to be invalidated.
            files[path] = null;
            return self.emit('error', err);
        }

        // Once loaded store data in in cache and configure a watch on the
        // file so that it can be reloaded when it is changed.
        data = args[0];
        files[path] = data
        self.configureWatch(path);
        self.emit('load', path, data);
    });

    return file;
}

// Configure a `fs.watch` on the given path that will trigger a reload if the
// file is changed.
ReloadJSON.prototype.configureWatch = function (path) {
    var self = this,
        watching = this.watching,
        watch;

    if (watching[path]) {
        return;
    }

    watch = watching[path] = fs.watch(path, {
        persistent: this.persistent
    });

    // Make sure old data is not used again
    watch.on('change', function (filename) {
        self.files[path] = null;
        self.emit('change', filename);
    });

    // Trigger a new read of the file after a debounce timeout, it's
    // possible a read was started in the meantime in that case no read is
    // triggered from the watch.
    watch.on('change', debounce(function () {
        if (!self.files[path]) {
            self.read(path);
        }
    }, 20));

    watch.on('error', function (err) {
        self.emit('error', err);
    });
}

// Load json from the specified path. The result is cached and multiple request
// is consolidated into on.
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

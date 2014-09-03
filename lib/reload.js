var EventEmitter = require('events').EventEmitter,
    debounce = require('debounce'),
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

    // Once loaded store data in in cache and configure a watch on the file so
    // that it can be reloaded when it is changed.
    file.once('load', function (data) {
        files[path] = data;
        self.configureWatch(path);
        self.emit('load', path, data);
    });

    // If a error occurs the loader needs to be invalidated.
    file.once('error', function (err) {
        files[path] = null;
        self.emit('error', err);
    });

    return file;
}

// Configure a `fs.watch` on the given path that will trigger a reload if the
// file is changed.
ReloadJSON.prototype.configureWatch = function (path) {
    var self = this,
        watching = this.watching,
        watch;

    if (!watching[path]) {
        watch = watching[path] = fs.watch(path, {
            persistent: this.persistent
        });

        watch.on('change', debounce(function () {
            self.read(path);
        }, 20));

        watch.on('error', function (err) {
            self.emit('error', err);
        });
    }
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

    file.once('load', function (data) {
        callback(null, data);
    });

    file.once('error', function (err) {
        callback(err, null);
    });
}

module.exports = ReloadJSON;

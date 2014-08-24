var EventEmitter = require('events').EventEmitter,
    debounce = require('debounce'),
    util = require('util'),
    fs = require('fs');

function loadJSON(path) {
    var em = new EventEmitter();

    fs.readFile(path, function (err, data) {
        var json;

        if (err) {
            return em.emit('error', err);
        }

        try {
            json = JSON.parse(data);
        } catch (e) {
            return em.emit('error', e);
        }

        em.emit('load', json);
    });

    return em;
}

// OPTIONS
//  - persistent reload in watch
function ReloadJSON(options) {
    options = options || {};
    this.files = {};
    this.watching = {};
    this.persistent = options.persistent;
    this.onChange = options.onChange || ReloadJSON.reload;
}

util.inherits(ReloadJSON, EventEmitter);

ReloadJSON.prototype.read = function (path) {
    var self = this,
        files = this.files,
        file = files[path] = loadJSON(path);

    file.once('load', function (data) {
        files[path] = data;
        self.emit('load', path, data);
    });

    file.once('error', function (err) {
        self.emit('error', err);
    });

    return file;
}

ReloadJSON.prototype.load = function (path, callback) {
    var self = this,
        files = this.files,
        file = files[path],
        watch;

    if (file) {
        if (!(file instanceof EventEmitter)) {
            return callback(null, file);
        }
    } else {
        file = this.read(path);

        if (!this.watching[path]) {
            watch = this.watching[path] = fs.watch(path, {
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

    file.once('load', function (data) {
        callback(null, data);
    });

    file.once('error', function (err) {
        callback(err, null);
    });
}

module.exports = ReloadJSON;

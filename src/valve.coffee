{ Stream:Steam } = require 'stream'

# Cleanup on weak references. Optional for now because I don't know how well the
# node-weak works for other people.
try weak = require 'weak'
catch nothing

##
# create a weak reference or not
# dependeing on weak (if its available or not)
weakreference = (list, obj) ->
    ref = weak? obj, =>
        i = list.indexOf(ref)
        return if i is -1
        list = list.slice(0,i).concat(list.slice(i+1))
    # in case weak isnt used (which is bad)
    ref ?= obj
    list.push ref



class Valve extends Steam
    constructor: (opts = {}) ->
        if typeof opts is 'string'
            opts = encoding:opts
        # values
        @useweak = opts.weak ? off
        @sources = []
        @sinks = []
        # defaults
        @setEncoding(opts.encoding ? 'utf8')
        # states
        @finished = off
        @paused   = off
        @writable = on
        @readable = on
        @jammed = 0
        # listen for sources
        @on 'pipe', (source) ->
            source.setEncoding @encoding if @encoding?
            do source.pause if @paused
            @writable = on
            if @useweak
                weak_reference @sources, source
            else
                @sources.push source
        # init
        super

    ##
    # Pauses the incoming 'data' events.
    pause: () ->
        return if @paused
        @paused = yes
        for source in @sources
            source.pause?() if source.readable
        @emit 'pause'

    ##
    # Resumes the incoming 'data' events after a pause().
    resume: () ->
        return if not @paused or @jammed is 0
        @jammed--
        return unless @jammed is 0
        @emit 'drain'
        @paused = no
        for source in @sources
            source.resume?() if source.readable
        @emit 'resume'
        if @finished
            @emit 'end'
            @emit 'close'

    ##
    # Makes the data event emit a string instead of a Buffer.
    # encoding can be 'utf8', 'ascii', or 'base64'.
    setEncoding: (@encoding) ->
        source.setEncoding @encoding for source in @sources
        return @encoding

    ##
    # Returns true if the string has been flushed to the kernel buffer.
    # Returns false to indicate that the kernel buffer is full, and the data
    # will be sent out in the future.
    # The 'drain' event will indicate when the kernel buffer is empty again.
    # The encoding defaults to 'utf8'.
    flush: ->
        # we can only write again if all full sinks drained
        return false if @paused or @jammed isnt 0
        # we are only as fast as the slowest sink
        for sink in @sinks
            continue unless sink.writable
            wantsmore = sink.write(arguments...)
            @jammed++ unless wantsmore
         # only true if all sinks were writable and returned true
        return @jammed is 0

    ##
    # this method is made simple so this can be overridden to implement some
    # more sophisticate data handling with incoming data
    # the core functionality of `write` specified by the nodejs documentation
    # is implemented as `flush` and can be used from the special write method.
    write: ->
        unless @writable
            @emit 'error', new Error("Stream is not writable.")
            return false
        @flush arguments...

    ##
    # Terminates the stream with EOF or FIN. This call will allow queued write
    # data to be sent before closing the stream.
    end: (data, encoding) ->
        @write(data, encoding) if data?
        @writable = off
        @finished = yes
        unless @paused
            @emit 'end'
            @emit 'close'

    ##
    # Closes the underlying file descriptor. Stream will not emit any more
    # events. Any queued write data will not be sent.
    destroy: () ->
        do source.destroy for source in @sources # readables
        do sink.destroy   for sink   in @sinks   # writables

    ##
    # After the write queue is drained, close the file descriptor.
    # destroySoon() can still destroy straight away, as long as there is
    # no data left in the queue for writes.
    destroySoon: () ->
        do source.destroy   for source in @sources # readables
        do sink.destroySoon for sink   in @sinks   # writables

    ##
    # Connects this read stream to destination WriteStream.
    # Incoming data on this stream gets written to destination.
    # The destination and source streams are kept in sync by pausing and
    # resuming as necessary.
    # This function returns the destination stream.
    #
    # this is a port of nodejs stream::pipe
    #   http://nodejs.org/docs/v0.6.5/api/streams.html#stream.pipe
    #   https://github.com/joyent/node/blob/master/lib/stream.js
    # but without listening on data event
    # and i renamed dest to sink
    pipe: (sink, opts = {}) ->
        source = this
        @writable = on
        if @useweak
            weak_reference @sinks, sink
        else
            @sinks.push sink

        didOnEnd = no
        onend = ->
            return if didOnEnd
            didOnEnd = yes
            do cleanup # remove all listeners
            sink.end()

        onclose = ->
            return if didOnEnd
            didOnEnd = yes
            do cleanup # remove all listeners
            sink.destroy()

        # don't leave dangling pipes when there are errors.
        onerror = (err) ->
            do cleanup # remove all listeners
            if @listeners('error').length is 0
                throw err # Unhandled stream error in pipe.

        source.on 'error', onerror
        sink.on 'error', onerror

        # If the 'end' option is not supplied, dest.end() will be called when
        # source gets the 'end' or 'close' events.  Only dest.end() once.
        if not sink._isStdio and opts.end isnt false
            source.on 'close', onclose
            source.on 'end', onend

        ondrain = -> do source.resume
        sink.on 'drain', ondrain

        # remove all the event listeners that were added.
        cleanup  = ->
            sink.removeListener 'drain', ondrain

            source.removeListener 'end', onend
            source.removeListener 'close', onclose

            source.removeListener 'error', onerror
            sink.removeListener   'error', onerror

            source.removeListener 'end', cleanup
            source.removeListener 'close', cleanup

            sink.removeListener 'end', cleanup
            sink.removeListener 'close', cleanup

        source.on 'end',   cleanup
        source.on 'close', cleanup

        sink.on 'end',   cleanup
        sink.on 'close', cleanup

        sink.emit 'pipe', source

        # Allow for unix-like usage: A.pipe(B).pipe(C)
        return sink



# exports

module.exports = Valve

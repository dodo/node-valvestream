{ EventEmitter } = require 'events'
{ Stream:Steam } = require 'stream'
Valve = require '../'



class DummySink extends EventEmitter
    writable:yes
    write: (data) ->
        @emit 'data', data
        return true if @used_once
        setTimeout(@emit.bind(this, 'drain'), 20)
        @used_once = yes
        false

    end: ->
        @emit 'end'

class DummySource extends Steam
    readable:yes
    write: (data) ->
        @emit 'data', data

    end: ->
        @emit 'end'

module.exports =

    'mutli source': (æ) ->
        #
        # sources
        #   0  \
        #   1  -  valve  -  sink
        #   2  /
        #

        chunkSize = 250
        received = 0
        resumes  = 0
        pauses   = 0
        drains   = 0

        for i in [0 ... chunkSize]
            chunkSize[i] = i % 256
        payload = new Buffer(chunkSize)

        sink    = new DummySink
        valve   = new Valve
        sources = [
            new DummySource
            new DummySource
            new DummySource
        ]

        valve.on 'drain',  -> drains++
        valve.on 'pause',  -> pauses++
        valve.on 'resume', -> resumes++
        sink.on 'data', (data) ->
            æ.equal data, payload
            received++

        sink.on 'end', ->
            æ.equal received, 1 # FIXME is this right? shouldnt it be sources.length?
            æ.equal resumes,  1
            æ.equal pauses,   1
            æ.equal drains,   1
            æ.done()

        for source in sources
            source.pipe valve

        valve.pipe sink

        for source in sources
            source.write payload

        setTimeout ->
            for source in sources
                do source.end
        ,100



Valve = require '../'

module.exports =

    pipe: (æ) ->
        writable = new Valve
        readable = new Valve
        passed = no

        writable.on 'pipe', (src) ->
            æ.equal src, readable
            passed = yes

        writable.on 'end', ->
            æ.equal passed, yes
            æ.done()

        readable.pipe writable
        readable.end()

    'pipe multi': (æ) ->

        count = nr = 100
        chunkSize  = 250
        chunkCount = 1000

        closed_readables = 0
        closed_writables = 0
        [writables, readables] = [[], []]

        for i in [0 ... chunkSize]
            chunkSize[i] = i % 256
        data = new Buffer(chunkSize)

        for i in [0 ... count]
            readable = new Valve
            readable.on 'close', ->
#                 console.error "#{@ID} read close"
                closed_readables++
            readables.push readable

            writable = new Valve
            writable._got_data = 0
            writable.on 'data', (chunk) ->
                æ.equal chunk, data
                @_got_data++

            writable.on 'close', ->
#                 console.error "#{@ID} write close"
                æ.equal @_got_data, chunkCount
                closed_writables++
            writables.push writable

            readable.ID = writable.ID = i

            readable.pipe writable

        readables.forEach (readable) ->
            cnt = chunkCount
            readable.on 'resume', ->
                do step
            step = ->
                readable.flush data
#                 readable.emit 'data', data FIXME this should work
                if --cnt is 0
                    readable.end()
                    if --count is 0
                        æ.equal closed_readables, nr
                        æ.equal closed_writables, nr
                        æ.done()
                process.nextTick(step) unless readable.paused
            process.nextTick(step)

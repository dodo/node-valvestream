Valve = require '../valvestream'

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

    'pipe multi': ->

        count = 100
        chunkSize = 250
        chunkCount = 1000
        data = new Buffer(chunkSize)

        closed_readables = 0
        closed_writables = 0
        [writables, readables] = [[], []]


        for i in [0 ... chunkSize]
            chunkSize[i] = i % 256

        for i in [0 ... count]
            readable = new Valve
            readable.on 'close', ->
                console.error "#{@ID} read close"
                closed_readables++
            readables.push readable

            writable = new Valve
            writable.on 'close', ->
                console.error "#{@ID} write close"
                closed_writables++
            writables.push writable

            readable.ID = writable.ID = i

            readable.write writable

        readables.forEach (readable) ->
            cnt = chunkCount
            readable.on 'resume', ->
                do step
            step = ->
                readable.emit 'data', data
                if --cnt is 0
                    readable.end()
                    æ.done() if --count is 0
                process.nextTick(step) unless readable.paused
            process.nextTick(step)

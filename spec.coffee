{expect, should} = chai = require 'chai'
should = should()
chai.use require 'sinon-chai'

gulpsmith = require './'
File = require 'vinyl'
_ = require 'highland'
Metalsmith = require 'metalsmith'

expect_fn = (item) -> expect(item).to.exist.and.be.a('function')

{spy} = sinon = require 'sinon'

spy.named = (name, args...) ->
    s = if this is spy then spy(args...) else this
    s.displayName = name
    return s

compare_gulp = (infiles, transform, outfiles, done) ->
    _(file for own path, file of infiles)
    .pipe(transform).toArray (files) ->
        transformed = {}
        for file in files
            transformed[file.path] = file
        transformed.should.eql outfiles
        done()

compare_metal = (infiles, smith, outfiles, done) ->
    smith.run infiles, (err, transformed) ->
        if err
            done(err)
        else
            transformed.should.eql outfiles
            done()







describe "gulpsmith() streams", ->

    s = testfiles = null
    before -> s = gulpsmith()

    null_plugin = (files, smith, done) -> done()

    describe ".use() method", ->
        plugin1 = spy.named "plugin1", null_plugin
        plugin2 = spy.named "plugin2", null_plugin
        it "returns self", -> expect(s.use(plugin1)).to.equal s
        it "invokes passed plugins during build", (done) ->
            s.use(plugin2)
            _([]).pipe(s).toArray ->
                plugin1.should.be.calledOnce.and.calledBefore plugin2
                plugin2.should.be.calledOnce.and.calledAfter plugin1
                done()

    describe ".metadata() method", ->
        data = {a: 1, b:2}
        it "returns self when setting", ->
            expect(s.metadata(data)).to.equal s
        it "returns matching metadata when getting", ->
            expect(s.metadata()).to.eql data

















    describe "streaming", ->

        before ->
            s = gulpsmith()
            testfiles =
                f1: new File(path:"f1", contents:Buffer('f1'))
                f2: new File(path:"f2", contents:Buffer('f2'))
            testfiles.f1.a = "b"
            testfiles.f2.c = 3
    
        it "should yield the same files (if no plugins)", (done) ->
            compare_gulp testfiles, s = gulpsmith(), testfiles, done

        it "should delete files deleted by a Metalsmith plugin", (done) -> 
            s = gulpsmith().use (f,s,d) -> delete f.f1; d()
            compare_gulp testfiles, s, {f2:testfiles.f2}, done

        it "should add files added by a Metalsmith plugin", (done) -> 
            s = gulpsmith().use (f,s,d) -> f.f3 = contents:Buffer "f3"; d()
            compare_gulp {}, s, {f3: new File path:"f3", contents:Buffer "f3"}, done

        it "yields errors for non-buffered files"

        it "yields errors for errors produced by Metalsmith plugins"

        it "converts Gulp .stat to Metalsmith .mode"
        it "converts Metalsmith .mode to Gulp .stat"
        it "converts Gulp .contents to Metalsmith .contents"
        it "converts Metalsmith .contents to Gulp .contents"

        it "adds .cwd and .base to Metalsmith-added files"
        it "removes the .metalsmith attribute from files sent to Metalsmith"









describe "gulpsmith.pipe() plugins", ->

    smith = testfiles = null

    it "are functions", ->
        expect(gulpsmith.pipe()).to.be.a('function')

    describe ".pipe() method", ->
        it "is a function", -> expect(gulpsmith.pipe().pipe).to.exist.and.be.a('function')
        it "returns a function with another pipe() method", ->
            expect(gulpsmith.pipe().pipe().pipe).to.exist.and.be.a('function')

    describe "streaming", ->

        before ->
            smith = Metalsmith(process.cwd())
            testfiles =
                f1: contents:Buffer('f1')
                f2: contents:Buffer('f2')
            testfiles.f1.a = "b"
            testfiles.f2.c = 3
    
        it "should yield the same files (if no plugins)", (done) ->
            compare_metal testfiles, smith.use(gulpsmith.pipe()), testfiles, done

        it "should delete files deleted by a Gulp plugin", (done) -> 
            s = smith.use gulpsmith.pipe _.where path: 'f2'
            compare_metal testfiles, s, {f2:testfiles.f2}, done

        it "should add files added by a Gulp plugin", (done) ->
            f3 = new File path: "f3", contents:Buffer "f3"
            f3.x = "y"; f3.z = 42
            s = smith.use gulpsmith.pipe(_.append f3)
            compare_metal {}, s, {f3:  {
                stat:null, base: process.cwd(), cwd: process.cwd(), 
                x: "y", z:42, contents:Buffer "f3"
            }}, done




        it "exits with any error yielded by a Gulp plugin"
        it "adds a .metalsmith attribute to files seen by Gulp plugins"
        it "removes the .metalsmith attribute from files returned to Metalsmith"
        it "converts Gulp .stat to Metalsmith .mode"
        it "converts Metalsmith .mode to Gulp .stat"
        it "converts Gulp .contents to Metalsmith .contents"
        it "converts Metalsmith .contents to Gulp .contents"



































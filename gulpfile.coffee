gulp = require('gulp')
mocha = require 'gulp-mocha'
coffee = require 'gulp-coffee'

require 'coffee-script/register'

package_name = JSON.parse(require('fs').readFileSync "package.json").name
main = "#{package_name}.litcoffee"

gulp.task 'build', ->
    gulp.src(main)
    .pipe coffee()
    #.on 'error', ->gutil.log
    .pipe gulp.dest('.')
    #.pipe filelog()

gulp.task 'test', ['build'], ->
    gulp.src 'spec.*coffee'
    .pipe mocha
        reporter: "spec"
        #bail: yes
    .on "error", (err) ->
        console.log err.toString()
        console.log err.stack if err.stack?
        @emit 'end'

gulp.task 'default', ['test'], ->
    gulp.watch [main, 'spec.*coffee'], ['test']

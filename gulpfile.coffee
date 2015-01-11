gulp = require 'gulp'

# Browserify
browserify = require 'browserify'
source = require 'vinyl-source-stream'

gulp.task 'build', ->
  browserify('./OperationalTransform.coffee', extensions: ['.coffee'], standalone: 'OperationalTransform')
    .bundle()
    .pipe source 'OperationalTransform.js'
    .pipe gulp.dest './lib'


tasks = [ 'build' ]

gulp.task 'default', tasks, ->
  gulp.watch [ 'src/**/*.coffee' ], [ 'build' ]

gulp.task 'nowatch', tasks

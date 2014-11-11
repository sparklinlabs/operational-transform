gulp = require 'gulp'

# Browserify
browserify = require 'browserify'
source = require 'vinyl-source-stream'

gulp.task 'build', ->
  browserify('./OperationalTransform.coffee', extensions: ['.coffee'], standalone: 'OperationalTransform')
    .bundle()
    .pipe source 'OperationalTransform.js'
    .pipe gulp.dest './lib'

# Watch
tasks = [ 'build' ]

gulp.task 'watch', tasks, ->
  gulp.watch [ 'src/**/*.coffee' ], ['build']

gulp.task 'default', tasks

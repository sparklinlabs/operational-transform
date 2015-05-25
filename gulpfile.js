var gulp = require("gulp");
var tasks = [ "browserify" ];

// TypeScript
var ts = require("gulp-typescript");
gulp.task("typescript", function() {
  var tsResult = gulp.src([ "src/**/*.ts", "!node_modules/**" ]).pipe(ts({
    typescript: require("typescript"),
    declarationFiles: false,
    module: "commonjs",
    target: "ES5",
    noImplicitAny: true
  }));
  return tsResult.js.pipe(gulp.dest("./src"));
});

// Browserify
var browserify = require("browserify");
var vinylSourceStream = require("vinyl-source-stream");

gulp.task("browserify", [ "typescript" ], function() {
  var bundler = browserify("./src/index.js", { standalone: "OperationalTransform" });
  function bundle() { return bundler.bundle().pipe(vinylSourceStream("OperationalTransform.js")).pipe(gulp.dest("./lib")); };
  return bundle();
});

// All
gulp.task("default", tasks);

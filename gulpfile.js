var gulp = require("gulp");
var tasks = [ "typescript" ];

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
  return tsResult.js.pipe(gulp.dest("./lib"));
});

// All
gulp.task("default", tasks);

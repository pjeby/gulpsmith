# Mixing Gulp and Metalsmith with ``gulpsmith``

``gulpsmith`` lets you use [Gulp](http://gulpjs.com/) plugins (or ``vinyl`` pipelines) with Metalsmith, and use [Metalsmith](http://www.metalsmith.io/) plugins as part of a Gulp or ``vinyl`` pipeline.  This can be helpful if you:

* Don't want Metalsmith to slurp up an entire directory tree of files,
* Want to upload your Metalsmith build to Amazon S3 or send it someplace via SFTP without first generating files locally and then running a separate uploading process,
* Want to pre- or post-process your Metalsmith build with Gulp plugins, or
* Already run your build process with one tool or the other and don't want to switch, but need both kinds of plugins.

``gulpsmith().use(metal_plugin1).use(metal_plugin2)``... wraps one or more Metalsmith plugins for use in Gulp, whereas ``gulpsmith.pipe(stream1).pipe(stream2)``... turns a series of Gulp plugins (or ``vinyl`` streaming operations) into a plugin that can be passed to Metalsmith's ``.use()`` method.

While a *perfect* translation between the two systems is impossible, ``gulpsmith`` does its best to be lossless in both directions.  The main areas where you may encounter problems are in the ``stat``/``mode`` attributes, and certain relative path information on the Gulp side.  (See [File Conversions and Compatibility](#cnc), below, for more details.)

### Contents

<!-- toc -->

* [Using Metalsmith in a Gulp Pipeline](#using-metalsmith-in-a-gulp-pipeline)
  * [Front Matter and File Properties](#front-matter-and-file-properties)


* [Using a Gulp Pipeline as a Metalsmith Plugin](#using-a-gulp-pipeline-as-a-metalsmith-plugin)
  * [Advanced Pipelines and Error Handling](#advanced-pipelines-and-error-handling)
    * [Reusing Pipelines](#reusing-pipelines)
    * [Using Pre-assembled Pipelines](#using-pre-assembled-pipelines)
    * [Stream Operations Other Than ``.pipe()``](#stream-operations-other-than-pipe)


* [File Conversions and Compatibilty](#file-conversions-and-compatibilty)

<!-- toc stop -->



## Using Metalsmith in a Gulp Pipeline

To use Metalsmith in a Gulp pipeline, call ``gulpsmith()`` with an optional directory name (default is ``process.cwd()``) which will be used to create a Metalsmith instance.  The return value is a stream that can be used in a  Gulp ``.pipe()`` chain, but which also has ``.use()`` and ``.metadata()`` methods that can be used to configure the Metalsmith instance.

Instead of reading from a source directory and writing to a destination directory, the wrapped Metalsmith instance obtains all its files in-memory from the Gulp pipeline, and will send all its files in-memory to the next stage of the pipeline.

(Because Metalsmith processes files in a group, note that your overall Gulp pipeline's output will pause until all the files from previous stages have been processed by Metalsmith.  All of Metalsmith's output files will then be streamed to the next stage of the pipeline, all at once.)

Example:

    gulpsmith = require('gulpsmith');

    gulp.src("./src/**/*")
    .pipe(some_gulp_plugin(some_options))
    .pipe(
        gulpsmith()     // defaults to process.cwd() if no dir supplied

        // You can initialize the metalsmith instance with metadata
        .metadata({site_name: "My Site"})

        // and .use() as many Metalsmith plugins as you like 
        .use(markdown())
        .use(permalinks('posts/:title'))
    )
    .pipe(another_gulp_plugin(more_options))
    .pipe(gulp.dest("./build")


### Front Matter and File Properties

Unlike Metalsmith, Gulp doesn't read YAML front matter by default.  So if you want the front matter to be available in Metalsmith, you will need to use the ``gulp-front-matter`` plugin, and insert something like this to promote the ``.frontMatter`` properties before piping to ``gulpsmith()``:

    gulp_front_matter = require('gulp-front-matter');
    assign = require('lodash.assign');

    gulp.src("./src/**/*")

    .pipe(gulp_front_matter()).on("data", function(file) {
        assign(file, file.frontMatter); 
        delete file.frontMatter;
    })

    .pipe(gulpsmith()
        .use(...)
        .use(...)
    )

This will extract the front matter and promote it to properties on the file, where Metalsmith expects to find it.  (Alternately, you could use ``gulp-append-data`` and the ``data`` property instead, to load data from ``.json`` files in place of YAML front matter!.)

Of course, there are other Gulp plugins that add useful properties to files, and those properties will of course be available to your Metalsmith plugins as well.

For example, if you pass some files through the ``gulp-jshint`` plugin before they go to Metalsmith, the Metalsmith plugins will see a ``jshint`` property on the files, with sub-properties for ``success``, ``errorCount``, etc.  If you use ``gulp-sourcemaps``, your files will have a ``sourceMap`` property, and so on.


## Using a Gulp Pipeline as a Metalsmith Plugin

To use Gulp plugins or other streams as a Metalsmith plugin, simply begin the pipeline with ``gulpsmith.pipe()``:  

    gulpsmith = require('gulpsmith')

    Metalsmith(__dirname)
    .use(drafts())
    .use(markdown())
    .use(gulpsmith
        .pipe(some_gulp_plugin(some_options))
        .pipe(another_gulp_plugin(more_options))
        .pipe(as_many_as(you_like))
    )
    .use(more_metalsmith_plugins())
    .build()

From the point of view of the Gulp plugins, the file objects will have a ``cwd`` property equal to the Metalsmith base directory, and a ``base`` property equal to the Metalsmith source directory.  They will have a dummy ``stat`` property containing only the Metalsmith file's ``mode``, and a ``metalsmith`` property containing the Metalsmith instance.  They will also have any other properties that were attached to the file by Metalsmith or its plugins (e.g. from the files' YAML front matter).

In this usage pattern, there is no ``gulp.src()`` or ``gulp.dest()``, because Metalsmith handles the reading and writing of files.  If the Gulp pipeline drops or renames any of the input files, they will be dropped or renamed in the Metalsmith pipeline as well.

(If you want to, though, you *can* include a ``gulp.dest()``, or any other Gulp output plugin in your pipeline.  Just make sure that you also do something to drop the written files from the resulting stream (e.g. using ``gulp-filter``), unless you want Metalsmith to *also* output the files itself.  Doing both can be useful if you use a Gulp plugin to upload files, but you also want Metalsmith to output a local copy.) 


### Advanced Pipelines and Error Handling

If the pipeline you're using in Metalsmith is built strictly via a series of of ``gulpsmith.pipe().pipe()...`` calls, and you don't save a Metalsmith instance to repeatedly call ``.build()`` or ``.run()`` on, you probably don't need to read the rest of this section.

If you need to do something more complex, however, you need to be aware of three things:

1. Unlike most Metalsmith plugins, Gulp plugins are *stateful* and **cannot** be used for more than one build run!

2. If you pass a precomposed pipeline to ``gulpsmith.pipe()``, it may not report errors properly, thereby hanging or crashing your build if an error occurs!

3. Unlike the normal stream ``.pipe()`` method, ``gulpsmith.pipe()`` *does not return the piped stream*: it returns a Metalsmith plugin that just happens to also have a ``.pipe()`` method for further chaining.

The following three sections will tell you what you need to know to apply or work around these issues. 

#### Reusing Pipelines

If you want to reuse the same Metalsmith instance over and over with the same Gulp pipeline, you must recreate the pipeline *on each run*.  (Sorry, that's just how Node streams work!)

It's easy to do that though, if you need to.  Just write a short in-line plugin that re-creates the pipeline each time, like this:

    Metalsmith(__dirname)
    .use(drafts())
    .use(markdown())
    .use(function() {   // inline Metalsmith plugin...
        return gulpsmith
            .pipe(some_gulp_plugin(some_options))
            .pipe(another_gulp_plugin(more_options))
            .pipe(as_many_as(you_like))
        .apply(this, arguments)  // that calls the gulpsmith-created plugin
    })
    .use(more_metalsmith_plugins())

Make sure, however, that *all* of the Gulp plugins are created within the function passed to ``.use()``, or your pipeline will mysteriously drop files on the second and subsequent ``.run()`` or ``.build()``. 

#### Using Pre-assembled Pipelines

By default, the standard ``.pipe()`` method of Node stream objects does not chain errors forward to the destination stream.  This means that if you build a pipeline with the normal ``.pipe()`` method, you're going to run into problems if one of your source stream emits errors.

Specifically, your build process can hang, because as far as Gulp or Metalsmith are concerned, the build process is still running!  (If you've ever had a Gulp build mysteriously hang on you, you now know the likely reason why.)

Fortunately for you, if you use ``gulpsmith.pipe()`` to build up your pipeline, it will automatically add an error handler to each stream, so that no matter where in the pipeline an error occurs, Metalsmith will be notified, and the build will end with an error instead of hanging indefinitely or crashing the process.

However, if for some reason you *must* pass a pre-assembled pipeline into ``gulpsmith.pipe()``, you should probably add error handlers to any part of the pipeline that can generate errors.  These handlers should forward the error to the last stream in the pipeline, so that it can be forwarded to Metalsmith by ``gulpsmith.pipe()``.


#### Stream Operations Other Than ``.pipe()``

Because ``gulpsmith.pipe()`` returns a Metalsmith plugin rather than a stream, you cannot perform stream operations (like adding event handlers) on the *result* of the call.  Instead, you must perform those operations on the *argument* of the call.

For example, instead of doing this:

    Metalsmith(__dirname)
    .use(gulpsmith
        .pipe(some_gulp_plugin(some_options))
        .on("data", function(file){...})  // WRONG: this is not a stream!
        .pipe(another_gulp_plugin(more_options))
    )

You would need to do this instead:

    Metalsmith(__dirname)
    .use(gulpsmith
        .pipe(
            some_gulp_plugin(some_options)
            .on("data", function(file){...})  // RIGHT
        )        
        .pipe(another_gulp_plugin(more_options))
    )

In other words, you will need to perform any stream-specific operations directly on the component streams, rather than relying on the output of ``.pipe()`` to return the stream you passed in.

(The same principle applies if you're saving a stream in a variable to use later: save the value being passed *in* to ``.pipe()``, instead of saving the *result* of calling ``.pipe()``.)


## File Conversions and Compatibilty <a name="cnc"></a>

Regardless of whether you are using Gulp plugins in Metalsmith or vice versa, ``gulpsmith()`` must convert the file objects involved *twice*: once in each direction at either end of the plugin list.  For basic usage, you will probably not notice anything unusual, since Gulp plugins rarely do anything with file properties other than the path and contents, and Metalsmith plugins don't expect to do anything with ``vinyl`` file properties.


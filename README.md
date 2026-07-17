# Gren Effectful Test Runner

Write integration, end-to-end, and browser tests in [Gren](https://gren-lang.org/).

This package lets you write:

* Tests that [run tasks](https://packages.gren-lang.org/package/blaix/gren-effectful-tests/version/latest/module/Test.Runner.Effectful) and verify the results.
* Automated [browser tests](https://packages.gren-lang.org/package/blaix/gren-effectful-tests/version/latest/module/Test.Runner.Browser).
* Coming soon: Native mobile app tests!

## Quick Start

Create a directory for your tests and initialize a gren program targeting node:

```sh
mkdir tests
cd tests
gren init --platform=node
```

Install the package and dependencies:

```sh
gren package install gren-lang/test
gren package install gren-lang/test-runner-node
gren package install blaix/gren-effectful-tests
```

Create a `src/Main.gren` with your tests:

```elm
module Main exposing (main)

import Expect
import Node
import Task
import Test.Runner.Effectful as Effectful exposing (..)

tests : Effectful.Test
tests =
    describe "My tests"
        [ await "my task" (Task.succeed "ok") <| \result ->
            test "is ok" <| \_ ->
                Expect.equal "ok" result
        , awaitError "my error" (Task.fail "oops") <| \error ->
            test "is oops" <| \_ ->
                Expect.equal "oops" error
        ]
        
main : Node.SimpleProgram a
main =
    Node.defineSimpleProgram <| \env ->
        Effectful.initialize env <| \config ->
            Effectful.run config tests
                |> Node.endSimpleProgram
```

Then compile and run with:

```
gren run Main
```

## Usage

This package provides wrappers for the normal [gren-lang/test](https://packages.gren-lang.org/package/gren-lang/test)
functions, plus additional functions that let you
[`await`](https://packages.gren-lang.org/package/blaix/gren-effectful-tests/version/latest/module/Test.Runner.Effectful#await)
tasks, drive a browser, and more.

[`Effectful.initialize`](https://packages.gren-lang.org/package/blaix/gren-effectful-tests/version/latest/module/Test.Runner.Effectful#initialize)
(and [`Brwoser.initialize`](https://packages.gren-lang.org/package/blaix/gren-effectful-tests/version/latest/module/Test.Runner.Browser#initialize))
gather permissions and default configuration.
If you want total control over configuration and what permissions the runner has access to,
see the [Subsystems and Permissions](#subsystems-and-permissions) section below.

[`Effectful.run`](https://packages.gren-lang.org/package/blaix/gren-effectful-tests/version/latest/module/Test.Runner.Effectful#run)
turns your test suite into a `Task` that you can run however you want.
In the example above, we're using it as the task for a [Node.SimpleProgram](https://packages.gren-lang.org/package/gren-lang/node/version/latest/module/Node#SimpleProgram),
but you can run it in any type of program just like you would any other task.

[`Browser.withSession`](https://packages.gren-lang.org/package/blaix/gren-effectful-tests/version/latest/module/Test.Runner.Browser#withSession)
lets you call tasks that can drive a real browser.
See the [Browser tests](#browser-tests) section below for details.

See [the package docs](https://packages.gren-lang.org/package/blaix/gren-effectful-tests/)
for the full API. Or read on for specific usage examples.

### Tasks

Your test can await the result of a task:

```elm
await "the current time" Time.now <| \now ->
    test "is not Jan 1, 1970" <| \_ ->
        Expect.notEqual (Time.millisToPosix 0) now
```

### Errors

If you try to await a task that fails, the test will fail.

If you want to explicitly test the failure condition, use `awaitError`:

```elm
awaitError "expected failure" (Task.fail "oopsy") <| \error ->
    test "is an oopsy" <| \_ ->
        Expect.equal "oopsy" error
```

### Nested awaits

You can nest awaits as deep as you need:

```elm
await "task a" (Task.succeed "a") <| \a ->
await "task b" (Task.succeed "b") <| \b ->
awaitError "failed task" (Task.fail "failure") <| \error ->
    test "nested tasks" <| \_ ->
        Expect.equalArrays
            [ "a", "b", "failure" ]
            [ a, b, error ]
```

## Browser tests

You can also test an app running in a browser using
[`Test.Runner.Browser`](https://packages.gren-lang.org/package/blaix/gren-effectful-tests/version/latest/module/Test.Runner.Browser)
to load pages, click buttons, fill out and submit forms, verify content, etc.

It requires `chromedriver` to be installed and available on your `PATH`.
You can get it via most package managers (e.g. `npm install -g chromedriver`)
or [download it directly](https://googlechromelabs.github.io/chrome-for-testing/).

See the [Subsystems and Permissions](#subsystems-and-permissions) section below
for details on getting the permissions.

```elm
myBrowserTests : Browser.Permissions -> Effectful.Test
myBrowserTests browserPerms =
    Browser.withSession browserPerms Browser.options <| \session ->
        await "navigate to form" (Browser.navigateTo "http://localhost:3000/form" session) <| \_ ->
        await "find name input" (Browser.findElement "#name-input" session) <| \input ->
        await "type name" (Browser.sendKeys "Gren" input session) <| \_ ->
        await "find submit button" (Browser.findElement "#submit-btn" session) <| \submitBtn ->
        await "click submit" (Browser.click submitBtn session) <| \_ ->
        await "find greeting" (Browser.findElement "#greeting" session) <| \greeting ->
        await "get greeting text" (Browser.getText greeting session) <| \greetingText ->
            test "message shows expected text" <| \_ ->
                Expect.equal "Hello, Gren!" greetingText
```

## As part of a long-running program

Since `Effectful.run` returns a `Task`, you can use it anywhere you can use a
task, including in an update function of a long-running program:

```elm
update msg model =
    when msg is
        RunTests ->
            { model = model
            , command = 
                Task.perform 
                    (\_ -> TestsDone)
                    (Effectful.run model.testConfig myTests)
            }
```

### Subsystems and Permissions

The package needs a number of subsystem permissions. It provides some
convenience `initialize` functions to gather those in a single call:

```elm
import Node
import Test.Runner.Browser as Browser
import Test.Runner.Effectful as Effectful


main : Node.SimpleProgram a
main =
    Node.defineSimpleProgram <| \env ->
        
        -- Gather permissions and default configuration:
        Effectful.initialize env <| \runnerConfig ->
        Browser.initialize <| \browserPerms ->
        
            Node.endSimpleProgram <|
                Effectful.run runnerConfig <|
                    Browser.withSession browserPerms Browser.options <| \session ->
                        myBrowserTests session
```

**Note:** Since these `initialize` functions return an [`Init.Task`](https://packages.gren-lang.org/package/gren-lang/node/version/latest/module/Init), using them
essentially grants the package unlimited access to subsystems
(filesystem, child processes, etc).

If you want explicit control over the config or what the package has access to,
you can pass the permissions in yourself:


```elm
import Init
import Node
import ChildProcess
import FileSystem
import HttpClient
import Terminal
import Test.Runner.Browser as Browser
import Test.Runner.Effectful as Effectful


main : Node.SimpleProgram a
main =
    Node.defineSimpleProgram <| \env ->
        
        -- Gather permissions:
        Init.await Terminal.initialize <| \termConfig ->
        Init.await ChildProcess.initialize <| \cpPerm ->
        Init.await FileSystem.initialize <| \fsPerm ->
        Init.await HttpClient.initialize <| \httpPerm ->
        
            let
                runnerConfig =
                    { termConfig = termConfig
                    , stdout = env.stdout
                    , stderr = env.stderr
                    }
                
                browserPerms =
                    { cpPerm = cpPerm
                    , fsPerm = fsPerm
                    , httpPerm = httpPerm
                    }
            in
            Node.endSimpleProgram <|
                Effectful.run runnerConfig <|
                    Browser.withSession browserPerms Browser.options <| \session ->
                        myBrowserTests session
```

## Working on this package

This project uses [devbox](https://www.jetify.com/devbox) for local development.
See [`devbox.json`](devbox.json) for the scripts you can run and lists of dependencies it will install
(or that you can install manually if you don't want to use devbox).

Ensure any changes are exercised in this project's [`tests`](tests/).

## Contact and Support

Found a problem? Need some help?
You can [open an issue](https://github.com/blaix/gren-effectful-tests/issues),
find me [on mastodon](https://hachyderm.io/@blaix),
or on the [Gren Discord](https://gren-lang.org/community).

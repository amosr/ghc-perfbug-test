# ghc-perfbug-test

During work on my [haskell-big-integer-experiment][bigint] project I found a
nasty performance bug. This project is a drastically stripped down version of
the [haskell-big-integer-experiment][bigint] codebase to demonstrate the bug.


# The problem

During development of [haskell-big-integer-experiment][bigint] I found one
function that would run slow if the whole project was built from scratch, but
run fast if the file it was in was `touch`-ed and only it and dependent files
were rebuilt.

In my testing, this pathology has be 100% reliable and completely unfathomable.
Why does touching a file and rebuilding the binary cause such a significant
speed improvement?


# Requirements

The requirements are:

* ghc >= 7.8 (uses GHC.Prim features not in 7.6).
* Hspec and Criterion libraries.
* Make


# Steps to reproduce

Clone the repo, change directory into it and then follow the following steps.

1. Run the command:

	`make clean bench-integer.html`

2. The command in 1. will compile and run the benchmarking program resulting in
a file named `bench-integer.html`. If you view this HTML file in a web browser,
you will see that tests New3-[ABC] are significantly slower than New1-[ABC].

3. Run the command:

	`touch New3/GHC/Integer/Natural.hs && make bench-integer.html`

4. The command in 3. just builds the touched file and all the files that depend
on it and runs the benchmark resulting in a version of the file
`bench-integer.html`. In this new file, the New1-ABC] tests are about the same
speed as they were in step 2., but the New3[ABC] tests are now significantly
fasted that the New1-[ABC] tests.

Steps 1. to 4. can be run over and over again with basically the same results.



[bigint]: https://github.com/erikd/haskell-big-integer-experiment

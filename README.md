Coro-Simple
===========

Simple coroutines for Perl 6, inspired by the Lua coroutines.

This is a module for *stackful asymmetric coroutines*, that suspend
their control flows with **yield** instead change the flow to another
coroutine with **transfer** (these are called *symmetric coroutines*).

If you want to know more about coroutines, I suggest you to read this
nice paper: http://www.inf.puc-rio.br/~roberto/docs/MCC15-04.pdf ...



### Features and Issues ###

The **coro** / **yield** functions from this module are implemented using
the **gather** / **take** built-in P6's functions, which has some
interesting features:

* *It has a dynamic scope:* it don't care about how many calls down are
to find a **take**.

* *Is a list generator:* useful for processing lists with filters and transformers.

* *And also lazy:* delay the evaluation until you really need the result.

Some p6 programmers argue that the **gather** / **take** itself is like a
coroutine. In fact, the *lazy property* of **gather** / **take** does it fits well
in the definitions of Marlin’s doctoral thesis:

> the values of data local to a coroutine persist between successive calls;

And:

> the execution of a coroutine is suspended as control leaves it, only
> to carry on where it left oﬀ when control re-enters the coroutine at
> some later stage.

Based on the brief discussion above, the **coro** / **yield** also has some
features:

* The coroutine don't care about how many calls down are to find a **yield**,
even inside many other nested functions.

* The **yield** only generates one value per cycle, but you can yield an
anonymous list to avoid it.

But, there are some issues, too:

* I advise you to not use **gather** / **take** inside any coroutine, even I
don't know what will happen.

* It don't generates the last values with **return** (as is the case of Lua),
so you must use **yield** again.

You can also yield "nothing" using the **suspend** function (and with none
argument, just for a temporary change of control flow). Don't worry about,
it will return internally the **True** value (as a status for coroutine that
is alive).



### Description ###

##### Coroutine: Declaration #####

So, let's go see some examples.

First, you declares a coroutine with:

```perl
coro { ... }; # zero-arity coroutine
```

Or with:

```perl
coro -> $param1, $param2, $param3 { ... }; # 3-arity coroutine
```

Or even with:

```perl
coro -> @params {
    for @params -> $param { do-some-thing-with ($param) }
}
# variadic arguments through an array
```


##### Coroutine: Constructor #####

Soon after, the **coro** keyword gives back a constructor, and you may think *"but why it returns a
constructor?"*... Well, for two mainly reasons:

* *For code reuse:* you can use the coroutine on different places, without declare / return
again it every time.

* *Reset to a initial state:* when the coroutine dies, you can just reassign it to the generator.

With Lua, if you want to reuse a coroutine, you need explicitly to return a coroutine that will
reuse the given arguments as a closure:

```lua
function iter (xs)
  return coroutine.wrap (function ( )
    for _, x in ipairs (xs) do
      coroutine.yield (x)
    end
  end)
end
```

So, I decided implement a different approach...

Some example (an iterator function):

```perl
my &iter = coro -> $xs {
    for @$xs -> $x { yield $x }
}
```

The **iter** function above will receive an anonymous list and give back a *generator*
function... Well-minded, now we will see generators.



##### Coroutine: Generator #####

Note: here, the generator definition is just for a function that return the next value (every
time that it's called), not as is usually called a *asymmetric coroutine without dedicated
stacks* (that cares about if you will call **yield** out of their block / lexical scope).

Reusing the **iter** example:

```perl
my $generator = iter [ 1 ... 3 ];

say $generator( ); # >>> 1
say $generator( ); # >>> 2
say $generator( ); # >>> 3
say $generator( ); # >>> False, here, the coroutine is dead.
# Use "$generator = iter [ 1, 2, 3 ];" again if you want...
```



##### Coroutine: More complex examples #####

Yep, you can build a **map** / **grep** / **range** like coroutines / generators!

```perl
# map coroutine
my &transform = coro -> &fn, $xs {
    for @$xs -> $x { yield fn($x) }
}

# grep coroutine
my &filter = coro -> &pred, $xs {
    for @$xs -> $x {
        yield $x if pred($x);
    }
}

# range-like coroutine
my &xrange = coro -> $min, $max {
    for ($min ...^ $max) -> $value {
        yield $value;
    }
}

# Usage:
#
# sub incr ($x) { $x + 1 }      # >>> number.
# sub even ($x) { $x % 2 == 0 } # >>> boolean. use "$x %% 2" if you wish...
#
# my $generator = ([ @array ] ==> transform &incr);
# my $filtered  = ([ @array ] ==> filter &even);
# my $get-next  = xrange ($x, $y);
#
# :)
```



##### Coroutine: "casting" generator to a lazy list #####

If you want to access the values that a generator yields with a nice way, you can use **from**.
The **from** function does the opposite from **iter** function above: instead taking an array and
returning a generator, it takes a reference to a generator and returns a lazy array to bind.

Some examples:

```perl
my @lazy-array := from $some-generator;
```

Or, too:

```perl
my @lazy-array := from some-constructor ($x, $y, $z);
```

You can build more complex things with it too, without evaluate the whole thing at all
(because **map** and **grep** are lazy too :) ...):

```perl
my @lazy-array-1 := (from some-constructor($arg1, $arg2, ...)).map: * + 1;

my @lazy-array-2 := (from (coro { ... })(...)).grep: * %% 2;
```



##### Coroutine: Verifying #####

There's also a function called **ensure** in this module (the other function, called 'assert',
now is deprecated. 'ensure' is the new name for this functionality). Its main purpose is to check a
value, so:

* If given value isn't False, return it.
* Otherwise, runs given block (other argument).

Let's see a small example below:

```perl
$some-value = $some-generator( );

($some-value ==> ensure {
    warn "Sorry, but your coroutine is dead."
}) ==> say;
# prints $some-value or generates a warning if is false

$some-value = ensure ({ $some-generator = some-constructor( ) }, $some-generator( ));
# reassign to the generator if $some-generator returns False or returns a value
```



##### Coroutine: Implementing symmetric coroutines #####

The support to a **transfer** function is still experimental. Check the 't/transfer.t' test if
you wish to know more about. There's also a test about tasks...



##### Notes #####

Pull requests are welcome.

**Happy Hacking using this module!** :)



### Tips and Tricks ###

Normally, you can build a *enumerator / generator* as this below (because **gather** / **take**
has a dynamic scope):

```perl
# receives many arguments (e.g flattened array) and yields each one
my &iter = coro sub (*@xs) { @xs ==> map &yield }
```

And some short version (that receives an anonymous list) with:

```perl
my &iter = coro { @$^xs.map: &yield }
```



### TODO ###

* Insert more examples here (show the code).

* Document the module with **Perl 6's Pods**.

* Fix the module for the **coro** function accepts lazy-lists / streams (infinite-length lists)
as argument.



End of Document.

import Lean
/-! # Syntax
This chapter is concerned with the means to declare and operate on syntax
in Lean. Since there are a multitude of ways to operate on it, we will
not go into great detail about this yet and postpone quite a bit of this to
later chapters.

## Declaring Syntax
### Declaration helpers
Some readers might be familiar with the `infix` or even the `notation`
commands, for those that are not here is a brief recap:
-/

-- XOR, denoted \oplus
infixl:60 " ⊕ " => fun l r => (!l && r) || (l && !r)

#eval true ⊕ true -- false
#eval true ⊕ false -- true
#eval false ⊕ true -- true
#eval false ⊕ false -- false

-- with `notation`, "left XOR"
notation:10 l:10 " LXOR " r:11 => (!l && r)

#eval true LXOR true -- false
#eval true LXOR false -- false
#eval false LXOR true -- true
#eval false LXOR false -- false

/- As we can see the `infixl` command allows us to declare a notation for
a binary operation that is infix, meaning that the operator is in between
the operands (as opposed to e.g. before which would be done using the `prefix` command).
The `l` at the end of `infixl` means that the notation is left associative so `a ⊕ b ⊕ c`
gets parsed as `(a ⊕ b) ⊕ c` as opposed to `a ⊕ (b ⊕ c)` which would be achieved by `infixr`.
On the right hand side it expects a function that operates on these two parameters
and returns some value. The `notation` command on the other hand allows us some more
freedom, we can just "mention" the parameters right in the syntax definition
and operate on them on the right hand side. It gets even better though, we can
in theory create syntax with 0 up to as many parameters as we wish using the
`notation` command, it is hence also often referred to as "mixfix" notation.

The three unintuitive parts about these two are:
- The fact that we are leaving spaces around our operators: " ⊕ ", " XOR ".
  This is so that, when Lean pretty prints our syntax later on, it also
  uses spaces around the operators, otherwise the syntax would just be presented
  as `l⊕r` as opposed to `l ⊕ r`.
- The `60` and `10` right after the respective commands -- these denote the operator
  precedence, meaning how strong they bind to their arguments, let's see this in action
-/

#eval true ⊕ false LXOR false -- false
#eval (true ⊕ false) LXOR false -- false
#eval true ⊕ (false LXOR false) -- true

/-!
As you can see the Lean interpreter analyzed the first term without parentheses
like the second instead of the third one. This is because the `⊕` notation
has higher precedence than `LXOR` (`60 > 10` after all) and is thus evaluated before it.
This is also how you might implement rules like `*` being evaluated before `+`.

Lastly at the `notation` example there are also these `:precedence` bindings
at the arguments: `l:10` and `r:11`. This conveys that the left argument must have
precedence at least 10 or greater, and the right argument must have precedence at 11
or greater. This forces left associativity like `infixl` above. To understand this,
let's compare two hypothetical parses:
```
-- a LXOR b LXOR c
(a:10 LXOR b:11):10 LXOR c
a LXOR (b:10 LXOR c:11):10
```
In the parse tree of `(a:10 LXOR b:11):10 LXOR c`, we see that the right argument `(b LXOR c)`
is given the precedence 10, because a rule is always given the lowest precedence of any of its
subrules. However, the rule for `LXOR` expects the right argument to have a precedence of at
least 11, as witnessed by the `r:11` at the right-hand-side of `notation:10 l:10 " LXOR " r:11`.
Thus this rule ensures that `LXOR` is left associative.

Can you make it right associative?

### Free form syntax declarations
With the above `infix` and `notation` commands you can get quite far with
declaring ordinary mathematical syntax already. Lean does however allow you to
introduce arbitrarily complex syntax as well. This is done using two main commands
`syntax` and `declare_syntax_cat`. A `syntax` command allows you add a new
syntax rule to an already existing, so called, syntax category. The most common syntax
categories are:
- `term`, this category will be discussed in detail in the elaboration chapter,
  for now you can think of it as "the syntax of everything that has a value"
- `command`, this is the category for top level commands like `#check`, `def` etc.
- TODO: ...

Let's see this in action:
-/

syntax "MyTerm" : term

/-!
We can now write `MyTerm` in place of things like `1 + 1` and it will be
*syntactically* valid, this does not mean the code will compile yet,
it just means that the Lean parser can understand it:
-/

def Playground1.test := MyTerm
-- elaboration function for 'termMyTerm' has not been implemented
--   MyTerm

/-!
Implementing this so called "elaboration function", which will actually
give meaning to this syntax, is topic of the elaboration and macro chapter.
An example of one we have already seen however would be the `notation` and
`infix` command.

We can of course also involve other syntax into our own declarations
in order to build up syntax trees, for example we could try to build our
own little boolean expression language:
-/

namespace Playground2

-- The scoped modifier makes sure the syntax declarations remain in this `namespace`
-- because we will keep modifying this along the chapter
scoped syntax "⊥" : term -- ⊥ for false
scoped syntax "⊤" : term -- ⊤ for true
scoped syntax:40 term " OR " term : term
scoped syntax:50 term " AND " term : term
#check ⊥ OR (⊤ AND ⊥) -- elaboration function hasn't been implemented but parsing passes

end Playground2

/-!
While this does work, it allows arbitrary terms to the left and right of our
`AND` and `OR` operation. If we want to write a mini language that only accepts
our boolean language on a syntax level we will have to declare our own
syntax category on top. This is done using the `declare_syntax_cat` command:
-/

declare_syntax_cat boolean_expr
syntax "⊥" : boolean_expr -- ⊥ for false
syntax "⊤" : boolean_expr -- ⊤ for true
syntax boolean_expr " OR " boolean_expr : boolean_expr
syntax boolean_expr " AND " boolean_expr : boolean_expr

/-!
Now that we are working in our own syntax category, we are completely
disconnected from the rest of the system. And these cannot be used in place of
terms anymore:
-/

#check ⊥ AND ⊤ -- expected term

/-!
In order to integrate our syntax category into the rest of the system we will
have to extend an already existing one with new syntax, in this case we
will re-embed it into the `term` category:
-/

syntax "[Bool|" boolean_expr "]" : term
#check [Bool| ⊥ AND ⊤] -- elaboration function hasn't been implemented but parsing passes

/-!
### Syntax combinators
In order to declare more complex syntax it is often very desirable to have
some basic operations on syntax already built-in, these include:
- helper parsers without syntax categories (i.e. not extendable)
- alternatives
- repetetive parts
- optional parts
While all of these do have an encoding based on syntax categories this
can make things quite ugly at times so Lean provides a way to do all
of these.

In order to see all of these in action briefly we will define a simple
binary expression syntax.
First things first, declaring named parsers that don't belong to a syntax
category, this is quite similar to ordinary `def`s:
-/

syntax binOne := "O"
syntax binZero := "Z"

/-!
These named parsers can be used in the same positions as syntax categories
from above, their only difference to them is, that they are not extensible.
There does also exist a number of built-in named parsers that are generally useful,
most notably:
- `str` for string literals
- `num` for number literals
- `ident` for identifiers
- ... TODO: better list or link to compiler docs

Next up we want to declare a parser that understands digits, a binary digit is
either 0 or 1 so we can write:
-/

syntax binDigit := binZero <|> binOne

/-!
Where the `<|>` operator implements the "accept the left or the right" behaviour.
We can also chain them to achieve parsers that accept arbitrarily many, arbitrarly complex
other ones. Now we will define the concept of a binary number, usually this would be written
as digits directly after each other but we will instead use comma separated ones to showcase
the repetetion feature:
-/

-- the "+" denotes "one or many", in order to achieve "zero or many" use "*" instead
-- the "," denotes the separator between the `binDigit`s, if left out the default separator is a space
syntax binNumber := binDigit,+

/-!
Since we can just use named parsers in place of syntax categories, we can now easily
add this to the `term` category:
-/

syntax "bin(" binNumber ")" : term
#check bin(Z, O, Z, Z, O) -- elaboration function hasn't been implemented but parsing passes
#check bin() -- fails to parse because `binNumber` is "one or many": expected 'O' or 'Z'

syntax binNumber' := binDigit,* -- note the *
syntax "emptyBin(" binNumber' ")" : term
#check emptyBin() -- elaboration function hasn't been implemented but parsing passes

/-!
Note that nothing is limiting us to only using one syntax combinator per parser,
we could also have written all of this inline:
-/

syntax "binCompact(" ("Z" <|> "O"),+ ")" : term
#check binCompact(Z, O, Z, Z, O) -- elaboration function hasn't been implemented but parsing passes

/-!
As a final feature, lets add an optional string comment that explains the binary
literal being declared:
-/

-- The (...)? syntax means that the part in parentheses optional
syntax "binDoc(" (str ";")? binNumber ")" : term
#check binDoc(Z, O, Z, Z, O) -- elaboration function hasn't been implemented but parsing passes
#check binDoc("mycomment"; Z, O, Z, Z, O) -- elaboration function hasn't been implemented but parsing passes

/-!
## Operating on Syntax
As explained above we will not go into detail in this chapter on how to teach
Lean about the meaning you want to give your syntax. We will however take a look
at how to write functions that operate on it. Like all things in Lean, syntax is
represented by the inductive type `Lean.Syntax`, on which we can operate. It does
contain quite some information, but most of what we are interested in, we can
condense in the following simplified view:
-/

namespace Playground2

inductive Syntax where
  | missing : Syntax
  | node (kind : Lean.SyntaxNodeKind) (args : Array Syntax) : Syntax
  | atom : String -> Syntax
  | ident : Lean.Name -> Syntax

end Playground2

/-!
Lets go through the definition one constructor at a time:
- `missing` is used when there is something the Lean compiler cannot parse,
  it is what allows Lean to have a syntax error in one part of the file but
  recover from it and understand the rest of it. This also means we pretty
  much don't care about this constructor.
- `node` is, as the name suggests a node in the syntax tree, it has a so called
  `kind : SyntaxNodeKind` where `SyntaxNodeKind` is just a `Lean.Name`. Basically
  each of our `syntax` declarations receives an automatically generated `SyntaxNodeKind`
  (we can also explicitly specify the name with `syntax (name := foo) ... : cat`) so
  we can tell Lean "this function is responsible for processing this specific syntax construct".
  Furthermore, like all nodes in a tree, it has children, in this case in the form of
  an `Array Syntax`.
- `atom` represents (with the exception of one) every syntax object that is at the bottom of the
  hierarchy. For example, our operators ` ⊕ ` and ` LXOR ` from above will be represented as
  atoms.
- `ident` is the mentioned exception to this rule. The difference between `ident` and `atom`
  is also quite obvious: an identifier has a `Lean.Name` instead of a `String` that represents is.
  Why a `Lean.Name` is not just a `String` is related to a concept called macro hygiene
  that will be discussed in detail in the macro chapter. For now, you can consider them
  basically equivalent.

### Constructing new `Syntax`
Now that we know how syntax is represented in Lean we could of course write programs that
generate all of these inductive trees by hand which would be incredibly tedious and is something
we most definitely want to avoid. Luckily for us there is quite an extensive API hidden inside the
`Lean.Syntax` namespace we can explore:
-/

open Lean
#check Syntax -- Syntax. autocomplete

/-!
The interesting functions for creating `Syntax` are the `Syntax.mk` ones, they allow us to create
both very basic `Syntax` objects like `ident`s but also more complex ones like `Syntax.mkApp`
which we can use to create the `Syntax` object that would amount to applying the function
from the first argument to the argument list (all given as `Syntax`) in the second one.
Let's see a few examples:
-/

-- Name literals are written with this little ` infront of the name
#eval Syntax.mkApp (mkIdent `Nat.add) #[Syntax.mkNumLit "1", Syntax.mkNumLit "1"] -- is the syntax of `Nat.add 1 1`
#eval mkNode `«term_+_» #[Syntax.mkNumLit "1", Syntax.mkNumLit "1"] -- is the syntax for `1 + 1`

-- note that the `«term_+_» is the auto generated SyntaxNodeKind for the + syntax

/-
If you don't like this way of creating `Syntax` at all you are not alone.
However, there are a few things involved with the machinery of doing this in
a pretty and correct (the machinery is mostly about the correct part) way
which will be explained in the macro chapter.

### Matching on `Syntax`
Just like constructing `Syntax` is an important topic, especially
with macros, matching on syntax is equally (or in fact even more) interesting.
Luckily we don't have to match on the inductive type itself either, we can
instead use so called syntax patterns. They are quite simple, their syntax is just
``(the syntax I want to match on)`. Let's see one in action:
-/

def isAdd11 : Syntax → Bool
  | `(Nat.add 1 1) => true
  | _ => false

#eval isAdd11 (Syntax.mkApp (mkIdent `Nat.add) #[Syntax.mkNumLit "1", Syntax.mkNumLit "1"]) -- true
#eval isAdd11 (Syntax.mkApp (mkIdent `Nat.add) #[mkIdent `foo, Syntax.mkNumLit "1"]) -- false

/-!
The next level with matches is to capture variables from the input instead
of just matching on literals, this is done with a slightly fancier looking syntax:
-/

def isAdd : Syntax → Option (Syntax × Syntax)
  | `(Nat.add $x $y) => some (x, y)
  | _ => none

#eval isAdd (Syntax.mkApp (mkIdent `Nat.add) #[Syntax.mkNumLit "1", Syntax.mkNumLit "1"]) -- some ...
#eval isAdd (Syntax.mkApp (mkIdent `Nat.add) #[mkIdent `foo, Syntax.mkNumLit "1"]) -- some ...
#eval isAdd (Syntax.mkApp (mkIdent `Nat.add) #[mkIdent `foo]) -- none

/-!
Note that `x` and `y` in this example are of type `Syntax` not `Nat`. This is simply
because we are still at the `Syntax` level: the concept of a type doesn't quite
exist yet. What we can however do is limit the parsers/categories we want to match on,
for example if we only want to match on number literals in order to implement some
constant folding:
-/

def isLitAdd : Syntax → Option Nat
  | `(Nat.add $x:num $y:num) => some (x.toNat + y.toNat)
  | _ => none

#eval isLitAdd (Syntax.mkApp (mkIdent `Nat.add) #[Syntax.mkNumLit "1", Syntax.mkNumLit "1"]) -- some 2
#eval isLitAdd (Syntax.mkApp (mkIdent `Nat.add) #[mkIdent `foo, Syntax.mkNumLit "1"]) -- none

/-!
As you can see in the code even though we explicitly matched on the `num`
parser we still have to explicitly convert `x` and `y` to `Nat` because
again, we are on `Syntax` level, types do not exist.

One last important note about the matching on syntax: In this basic
form it only works on syntax from the `term` category. If you want to use
it to match on your own syntax categories you will have to use `` `(category| ...)``.

### Mini Project
As a final mini project for this chapter we will declare the syntax of a mini
arithmetic expression language and a function of type `Syntax → Nat` to evaluate
it. We will see more about some of the concepts presented below in future
chapters.
-/

declare_syntax_cat arith

syntax num : arith
syntax arith "-" arith : arith
syntax arith "+" arith : arith
syntax "(" arith ")" : arith

partial def denoteArith : Syntax → Nat
  | `(arith| $x:num) => x.toNat
  | `(arith| $x:arith + $y:arith) => denoteArith x + denoteArith y
  | `(arith| $x:arith - $y:arith) => denoteArith x - denoteArith y
  | `(arith| ($x:arith)) => denoteArith x
  | _ => 0

-- You can ignore Elab.TermElabM, what is important for us is that it allows
-- us to use the ``(arith| (12 + 3) - 4)` notation to construct `Syntax`
-- instead of only being able to match on it like this.
def test : Elab.TermElabM Nat := do
  let stx ← `(arith| (12 + 3) - 4)
  pure (denoteArith stx)

#eval test -- 11

/-!
Feel free to play around with this example and extend it in whatever way
you want to. The next chapters will mostly be about functions that operate
on `Syntax` in some way.
-/

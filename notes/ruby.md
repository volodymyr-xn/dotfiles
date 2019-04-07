
## Clone VS Dup
1. Clone maintains the frozen or tainted state of obj. whereas #dup would change it to tainted.
```ruby
  a = [1, 2, 3, 4, 5]
  a.freeze
  a_clone = a.clone
  a_clone << 6 #=> can't modify frozen Array
  a_dup = a.dup
  a_dup << 6 #=> [1, 2, 3, 4, 5, 6]
```

2. Clone copies any singleton methods of an object but #dup does not support this.
```ruby
class Fish
  attr_accessor :name

  def initialize(name)
    @name = name
  end

end

dory = Fish.new("Dory")

def dory.whale_talk
  "Mmmmoooooowaaaaah..."
end

dory_clone = dory.clone
dory_clone.whale_talk #=> "Mmmmoooooowaaaaah..."
dory_dup = dory.dup
dory_dup.whale_talk #=> undefined method `whale_talk' for #<Fish:0x0055f7b7917e90 @name="Dory">
```

Duped objects have no id assigned and are treated as new records. Note that this is a “shallow” copy as
it copies the object’s attributes only, not its associations. The extent of a “deep” copy is application
specific and is therefore left to the application to implement according to its need.


### == — generic "equality"
At the Object level, == returns true only if obj and other are the same object. Typically, this method
is overridden in descendant classes to provide class-specific meaning.
This is the most common comparison, and thus the most fundamental place where you (as the author of a class)
get to decide if two objects are "equal" or not.

### === — case equality
For class Object, effectively the same as calling #==, but typically overridden by descendants to provide
meaningful semantics in case statements.
This is incredibly useful. Examples of things which have interesting === implementations:

```ruby
  case some_object
  when /a regex/
    # The regex matches
  when 2..4
    # some_object is in the range 2..4
  when lambda {|x| some_crazy_custom_predicate }
    # the lambda returned true
  end
```

### eql? — Hash equality
The eql? method returns true if obj and other refer to the same hash key. This is used by Hash to
test members for equality. **For objects of class Object, eql? is synonymous with ==**.
Subclasses normally continue this tradition by aliasing eql? to their overridden == method,
but there are exceptions. Numeric types, for example, perform type conversion across ==, but not across eql?, so:

```ruby
  1 == 1.0     #=> true
  1.eql? 1.0   #=> false
```
*So you're free to override this for your own uses,
or you can override == and use alias :eql? :== so the two methods behave the same way.*

### equal? — identity comparison
*Unlike ==, the equal? method should never be overridden by subclasses:
it is used to determine object identity (that is, a.equal?(b) iff a is the same object as b).*

- **This is effectively pointer comparison.**

## and && difference
Check out the difference between and and &&. In the examples you give the method puts is called without parens around it's arguments and the difference in precedence changes how it is parsed.

In test 1 && has higher precedence than the method call. So what's actually happening is puts('hello' && return).
Arguments are always evaluated before the methods they're called with -- so we first evaluate 'hello' && return.
Since 'hello' is truthy the boolean does not short circuit and return is evaluated.
When return we exit the method without doing anything else: so nothing
is ever logged and the second line isn't run.

In test 2 and has a lower precedence than the method call. So what happens is puts('hello') and return.
The puts method logs what is passed to it and then returns nil.
nil is a falsey value so the and expression short circuits and the return expression is never evaluated.
We just move to the second line where puts 'world' is run.

```ruby
redirect_to edit_order_path(@order) and return

 pry(main)> a = true && false => false pry(main)> a => false -----> a = (true && false)
 pry(main)> a = true and false => false pry(main)> a => true -----> (a = true) and false

```

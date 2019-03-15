
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

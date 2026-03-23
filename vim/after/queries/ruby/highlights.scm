; extends

(call
  receiver: (identifier) @_r (#eq? @_r "binding")
  method: (identifier) @_m (#eq? @_m "pry")) @binding.pry

(call
  method: (identifier) @ruby.class_dsl
  (#any-of? @ruby.class_dsl
    "validates" "validate" "validates_presence_of" "validates_uniqueness_of"
    "validates_length_of" "validates_format_of" "validates_numericality_of"
    "validates_inclusion_of" "validates_exclusion_of" "validates_associated"
    "before_action" "after_action" "around_action"
    "before_filter" "after_filter" "around_filter"
    "before_create" "after_create" "before_save" "after_save"
    "before_destroy" "after_destroy" "before_update" "after_update"
    "before_validation" "after_validation" "after_commit" "after_rollback"
    "has_many" "has_one" "belongs_to" "has_and_belongs_to_many"
    "scope" "enum" "attribute" "delegate"
    "attr_accessor" "attr_reader" "attr_writer"
    "skip_before_action" "skip_after_action" "prepend_before_action"))

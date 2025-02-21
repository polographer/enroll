class BenefitEligibilityElementGroup
  include Mongoid::Document

  # whitelist approach

  embedded_in :benefit_package

  INDIVIDUAL_MARKET_RELATIONSHIP_CATEGORY_KINDS = %w(
      self
      spouse
      domestic_partner
      child
      parent
      sibling
      ward
      guardian
      unrelated
      other_tax_dependent
      aunt_or_uncle
      nephew_or_niece
      grandchild
      grandparent
    )

  Relationships_UI = %w(
      self
      spouse
      domestic_partner
      child
      parent
      sibling
      unrelated
      aunt_or_uncle
      nephew_or_niece
      grandchild
      grandparent
    ) + (EnrollRegistry.feature_enabled?(:mitc_relationships) ? %w[father_or_mother_in_law daughter_or_son_in_law brother_or_sister_in_law cousin domestic_partners_child parents_domestic_partner] : [])

  SHOP_MARKET_RELATIONSHIP_CATEGORY_KINDS = %w(
      self
      spouse
      domestic_partner
      children_under_26
      disabled_children_26_and_over
      children_26_and_over
    )


  field :market_places,          type: Array, default: ["any"]   # %w[any shop individual],
  field :enrollment_periods,     type: Array, default: ["any"]   # %w[any open_enrollment special_enrollment],
  field :family_relationships,   type: Array, default: ["any"]   # %w[any self spouse domestic_partner child_under_26 child_26_and_over disabled_children_26_and_over],
  field :benefit_categories,     type: Array, default: ["any"]   # %w[health dental retirement disability],

  field :incarceration_status,   type: Array, default: ["any"]   # %w[any unincarcerated],
  field :age_range,              type: Range, default: 0..0
  field :citizenship_status,     type: Array, default: ["any"]   # %w[any us_citizen naturalized_citizen alien_lawfully_present lawful_permanent_resident],
  field :residency_status,       type: Array, default: ["any"]   # %w[any state_resident],
  field :ethnicity,              type: Array, default: ["any"]   # %w[any indian_tribe_member],
  field :cost_sharing,           type: String, default: ""
  field :lawful_presence_status, type: String, default: ""
  field :active_individual_role, type: Boolean, default: false


  # validates :eligible_relationship_categories,
  #   allow_blank: false,
  #   inclusion: {
  #     in: ELIGIBLE_RELATIONSHIP_CATEGORY_KINDS,
  #     message: "%{value} is not a valid eligible relationship category kind"
  #   }

end

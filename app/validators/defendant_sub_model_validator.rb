class DefendantSubModelValidator < BaseSubModelValidator

  # TODO to be removed if not required
  # HAS_MANY_ASSOCIATION_NAMES = [ :representation_orders ]

  def has_many_association_names
    [ :representation_orders ]
  end

end
